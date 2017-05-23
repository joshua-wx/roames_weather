function era_rsite_temps
%WHAT: processes an era-interim dataset of pressure level temps into
%freezing and -20C heights for each radar site across the country

%add paths for lib/etc
addpath('/home/meso/dev/roames_weather/lib/m_lib/')
addpath('/home/meso/dev/roames_weather/etc/')
%init
local_tmp_path  = 'tmp/';
config_input_fn = 'global.config';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%load global config file
read_config(config_input_fn);
load([local_tmp_path,'/',config_input_fn,'.mat'])

%out_dir
out_path = 'out/';
if exist(out_path,'file')==7
    rmdir(out_path,'s')
end
mkdir(out_path)

% site_info.txt
site_warning = read_site_info(site_info_fn,site_info_moved_fn,[1:99],datenum('1997_01_01','yyyy_mm_dd'),floor(now),1);
if site_warning == 1
    disp('site id list and contains ids which exist at two locations (its been reused or shifted), fix using stricter date range (see site_info_old)')
    return
end
load([local_tmp_path,site_info_fn,'.mat']);


ddb_tmp_struct  = struct;
year_list       = 1997:2016;
ddb_table       = 'wxradar_eraint_fzlvl';

for i=1:length(year_list)
    target_year = num2str(year_list(i));
    era_ffn     = ['/run/media/meso/DATA/project_data/era-int_wv/era_wv_',target_year,'.nc'];
    era_lon     = ncread(era_ffn,'longitude');
    era_lat     = ncread(era_ffn,'latitude');
    era_hour    = double(ncread(era_ffn,'time'));
    era_t       = double(ncread(era_ffn,'t'))-273.15;   %K -> C
    era_z       = double(ncread(era_ffn,'z'))./9.80665; %geopot to geopotH
    
    %convert time from hours past 1900-01-01 to matlab time number
    offset_dt = datenum('1900-01-01','yyyy-mm-dd');
    era_dt    = offset_dt + era_hour./24;
    
    %loop through radar sites
    for j=1:length(siteinfo_id_list)
        if siteinfo_id_list(j) ~= 21
           continue
        end
        %init radar data
        site_lat     = siteinfo_lat_list(j);
        site_lon     = siteinfo_lon_list(j);
        site_id      = siteinfo_id_list(j);
        site_start   = siteinfo_start_list(j);
        site_stop    = siteinfo_stop_list(j);
        [~,lat_ind]  = min(abs(era_lat-site_lat));
        [~,lon_ind]  = min(abs(era_lon-site_lon));
        for k=1:length(era_dt)
            %skip era_dates outside site start/stop
            if era_dt(k)<site_start || era_dt(k)>site_stop
                continue
            end
            %extract profile for single time
            t_profile = era_t(lon_ind,lat_ind,:,k);
            z_profile = era_z(lon_ind,lat_ind,:,k);
            %reshape profile
            t_profile = flipud(reshape(t_profile,length(t_profile),1));
            z_profile = flipud(reshape(z_profile,length(z_profile),1));
            %interpolate
            fz_level      = sounding_interp(t_profile,z_profile,0);
            minus20_level = sounding_interp(t_profile,z_profile,-20);
            %add to ddb struct
            [ddb_tmp_struct,tmp_sz] = addtostruct_era(ddb_tmp_struct,fz_level,minus20_level,era_dt(k),site_id);
            %write to ddb
            if tmp_sz==25 || k == length(era_dt)
                ddb_batch_write(ddb_tmp_struct,ddb_table,1);
                pause(0.3)
                %clear ddb_tmp_struct
                ddb_tmp_struct  = struct;
                %display('written_to ddb')
            end
        end
        disp(['finished site ',num2str(site_id),' for year ',num2str(target_year)]);
    end
    disp(['finished year ',num2str(target_year)]);
end
disp(['finished all']);

function intp_h = sounding_interp(snd_temp,snd_height,target_temp)
%WHAT: Provides an interpolated height for a target temperature using a
%sounding vertical profile

intp_h=[];
%find index above and below freezing level
above_ind = find(snd_temp<target_temp,1,'first');
if above_ind > 1  
    below_ind = above_ind-1;
else
    %above ind is either 1 or 0, cannot provide interpolation
    return
end

%attempt to interpolate and floor
intp_h   = interp1(snd_temp(below_ind:above_ind),snd_height(below_ind:above_ind),target_temp);
intp_h   = floor(intp_h);

function [ddb_tmp_struct,tmp_sz] = addtostruct_era(ddb_tmp_struct,fz_level,minus20_level,era_dt,radar_id)

timestamp          = datestr(floor(era_dt),'yyyy-mm-ddTHH:MM:SS'); %floor to day
hour_str           = num2str(hour(era_dt),'%02.0f');
fieldname_0C       = ['lvl_0C_',hour_str,'Z'];
fieldname_minus20C = ['lvl_minus20C_',hour_str,'Z'];
item_id            = ['item_',num2str(radar_id,'%02.0f'),'_',datestr(floor(era_dt),'yyyymmdd')];

%write to dynamo db
ddb_tmp_struct.(item_id).radar_id.N             = num2str(radar_id,'%02.0f');
ddb_tmp_struct.(item_id).eraint_timestamp.S     = timestamp;
ddb_tmp_struct.(item_id).(fieldname_0C).N       = num2str(fz_level);
ddb_tmp_struct.(item_id).(fieldname_minus20C).N = num2str(minus20_level);

tmp_sz =  length(fieldnames(ddb_tmp_struct));
if hour(era_dt)<18 %haven't added the final timestamp for the last day, reduce size by one
    tmp_sz = tmp_sz -1;
end




