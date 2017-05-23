function validate_singledop
%WHAT:
%reads in a climate database and filters by weather station locations to
%produce a list of date/times to extract odimh5 volumes. odimh5 volumes are
%extracted, singledop is run, and extract for locations where there were
%weather stations

aws_lat_list  = [-27.57,-27.39,-27.97,-27.94];
aws_lon_list  = [153.01,153.13,152.99,153.43];
aws_name_list = {'Archerfield','YBBN','Beaudesert','Southport'};
radar_id          = 50;
db_root           = '/run/media/meso/data/rwx_clim_archive/';
mesh_threshold    = 20; %mm
dist_threshold    = 15; %km

%load database
target_ffn  = [db_root,num2str(radar_id,'%02.0f'),'/','database.csv'];
out         = dlmread(target_ffn,',',1,0);
storm_date_list   = datenum(out(:,2:7));
storm_lat_list    = out(:,12);
storm_lon_list    = out(:,13);
storm_mesh_list   = out(:,28);

%mesh filter
mesh_mask = storm_mesh_list>=mesh_threshold;
storm_date_list = storm_date_list(mesh_mask);
storm_lat_list  = storm_lat_list(mesh_mask);
storm_lon_list  = storm_lon_list(mesh_mask);
storm_mesh_list = storm_mesh_list(mesh_mask);

%dist filter    
filter_idx = [];
for i=1:length(aws_lat_list)
    %compute distance and mash
    [dist_deg,~] = distance(aws_lat_list(i),aws_lon_list(i),storm_lat_list,storm_lon_list);
    tmp_idx = find(deg2km(dist_deg)<=dist_threshold);
    filter_idx = [filter_idx;tmp_idx];
end
%create unique fetch date list
fetch_date_list = unique(storm_date_list(filter_idx));

keyboard

%extract singledop wind speeds
singledop_wspd_list = [];
for i=1:length(fetch_date_list)
   %download from s3
   %run single dop - > nc
   %load data from nc
   for j=1:length(aws_lat_list)
       %extract nearest coord for eact aws
       %cat into vec
       %append to singledop_wspd_list
   end
end

%find nearest timeobs in time to the radar obs
aws_wspd_list = [];

%plot!

