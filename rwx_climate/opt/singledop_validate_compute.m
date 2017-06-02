function singledop_validate_compute
%WHAT:
%reads in a climate database and filters by weather station locations to
%produce a list of date/times to extract odimh5 volumes. odimh5 volumes are
%extracted, singledop is run, and extract for locations where there were
%weather stations

%aws
aws_lat_list      = [-27.57,-27.39,-27.97,-27.94,-27.48,-27.63];
aws_lon_list      = [153.01,153.13,152.99,153.43,153.04,152.71];
aws_name_list     = {'Archerfield','YBBN','Beaudesert','Southport','Brisbane','Amberley'};
aws_id_list       = [040211,040842,040983,040764,040913,040004];

%odimh5
radar_id          = 66;
odimh5_s3_bucket  = 's3://roames-weather-odimh5/odimh5_archive/';

%database filter
db_root           = '/run/media/meso/data/rwx_clim_archive/';
mesh_threshold    = 20;  %mm
dist_threshold    = 15;  %km

%out ffn
out_fn = ['sdvalidate_',num2str(radar_id,'%02.0f'),'_',datestr(now,'yyyymmdd_HHMMSS'),'.mat'];

%sd config
sd_sweep          = 0;   %sd sweep (python index)
sd_l              = 5;   %sd decorrelation length (km)
sd_min_rng        = 7;   %sd min range (km)
sd_max_rng        = 70;  %sd max range (km)
sd_thin_azi       = 2;   %sd thin in azi dim
sd_thin_rng       = 8;   %sd thin in rng dim
sd_stat_rng       = 1.5;   %rng from target aws to search for sd point (km)
%add paths
addpath('../../lib/m_lib')
addpath('../../etc')
mkdir('tmp')

%load database
target_ffn        = [db_root,num2str(radar_id,'%02.0f'),'/','database.csv'];
out               = dlmread(target_ffn,',',1,0);
storm_date_list   = datenum(out(:,2:7));
storm_lat_list    = out(:,12);
storm_lon_list    = out(:,13);
storm_mesh_list   = out(:,28);

%mesh filter
mesh_mask       = storm_mesh_list>=mesh_threshold;
storm_date_list = storm_date_list(mesh_mask);
storm_lat_list  = storm_lat_list(mesh_mask);
storm_lon_list  = storm_lon_list(mesh_mask);
storm_mesh_list = storm_mesh_list(mesh_mask);

%dist filter
filter_idx = [];
for i=1:length(aws_lat_list)
    %compute distance and mash
    [dist_deg,~] = distance(aws_lat_list(i),aws_lon_list(i),storm_lat_list,storm_lon_list);
    tmp_idx      = find(deg2km(dist_deg)<=dist_threshold);
    filter_idx   = [filter_idx;tmp_idx];
end
%create unique fetch datetime list
fetch_date_list   = unique(storm_date_list(filter_idx));
%date_mask         = floor(fetch_date_list) == datenum('27-11-2014','dd-mm-yyyy');
%fetch_date_list   = fetch_date_list(date_mask);


sd_wspd_mat       = nan(length(fetch_date_list),length(aws_lat_list));



%extract singledop wind speeds
for i=1:length(fetch_date_list)
    %disp
    disp(['processing odimh5 file ',num2str(i),' of ',num2str(length(fetch_date_list))])
    %build path
    target_date    = fetch_date_list(i);
    target_dvec    = datevec(target_date);
    s3_fn          = [num2str(radar_id,'%02.0f'),'_',datestr(target_date,'yyyymmdd_HHMM'),'00.h5'];
    s3_ffn         = [odimh5_s3_bucket,num2str(radar_id,'%02.0f'),'/',num2str(target_dvec(1)),'/',...
        num2str(target_dvec(2),'%02.0f'),'/',num2str(target_dvec(3),'%02.0f'),'/',s3_fn];
    %download file
    local_h5ffn = tempname;
    file_cp(s3_ffn,local_h5ffn,0,0);
    if exist(local_h5ffn,'file')~=2
        disp('warning, local_h5ffn not found')
        log_cmd_write('tmp/log.validate','s3 cp failed','',local_h5ffn)
        continue
    end
    %read site lat/lon
    site_lat = h5readatt(local_h5ffn,'/where','lat');
    site_lon = h5readatt(local_h5ffn,'/where','lon');
    %run singledop
    local_ncffn  = tempname;
    sdppi_struct = process_read_ppi_data(local_h5ffn,sd_sweep+1); %python to matlab index
    cmd     = ['python sd_winds_ncout2.py',' ',local_h5ffn,' ',local_ncffn,' ',...
        num2str(sdppi_struct.atts.NI),' ',num2str(sd_l),' ',num2str(sd_min_rng),' ',...
        num2str(sd_max_rng),' ',num2str(sd_sweep),' ',num2str(sd_thin_azi),' '...
        num2str(sd_thin_rng)];
    %run single dop - > nc
    [sout,eout] = unix(cmd);
    if sout ~= 0
        disp(eout)
        log_cmd_write('tmp/log.validate','singledop failed','',local_h5ffn)
        continue
    else
        %load nc data
        %read nc grid
        sd_x    = rot90(ncread(local_ncffn,'analysis_x'));
        sd_y    = rot90(ncread(local_ncffn,'analysis_y'));
        %convert to latlon
        mstruct         = defaultm('mercator');
        mstruct.origin  = [site_lat site_lon];
        mstruct.geoid   = almanac('earth','wgs84','kilometers');
        mstruct         = defaultm(mstruct);
        [sd_lat,sd_lon] = minvtran(mstruct,sd_x,sd_y);
        sd_lat_list = sd_lat(:);
        sd_lon_list = sd_lon(:);
        %read nc wind
        sd_u    = ncread(local_ncffn,'analysis_u');
        sd_v    = ncread(local_ncffn,'analysis_v');
        sd_wspd = rot90(sqrt(sd_v.^2 + sd_u.^2)); %convert to km/h
        sd_wspd_list = sd_wspd(:);
    end
    %find nn in sd grid to aws locations
    for j=1:length(aws_lat_list)
        aws_latlon       = [aws_lat_list(j),aws_lon_list(j)];
        dist_mat         = sqrt(sum(bsxfun(@minus, [sd_lat_list,sd_lon_list], aws_latlon).^2,2));
        sd_spd_vec       = sd_wspd_list(deg2km(dist_mat)<=sd_stat_rng);
        sd_wspd_mat(i,j) = mean(sd_spd_vec); %IMPORTANT USING MAX and RADIUS
    end
    %clean
    delete(local_h5ffn)
    delete(local_ncffn)
    %update/save to file
    save(out_fn,'fetch_date_list','sd_wspd_mat','aws_name_list','sd_stat_rng','aws_id_list')
end

%move to s3
file_cp(out_fn,[odimh5_s3_bucket,out_fn],0,0)
%send im
pushover('sd validate','radar processing complete')

keyboard
