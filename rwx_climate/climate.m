function climate
%WHAT: Core climatology script for roames weather which takes the local
%database built by sync_database and generate outputs for spatial and
%statistical analysis

%setup config names
climate_config_fn  = 'climate.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('etc/')

% load climate config
read_config(climate_config_fn);
load([local_tmp_path,climate_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

%% generate date list
%span dates
date_list        = [datenum(date_start,'yyyy/mm/dd'):datenum(date_stop,'yyyy/mm/dd')];
%filter months
date_list_months = month(date_list);
date_list        = date_list(ismember(date_list_months,month_list));
%filter date_list
filter_date_list = load(date_list_ffn,(date_list_var));
filter_date_list = filter_date_list.(date_list_var);
date_list        = date_list(ismember(date_list,filter_date_list));

%% load database
storm_database = [];
for i=1:length(date_list)
    target_date = date_list(i);
    date_vec    = datevec(target_date);
    target_path = [db_root,num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',...
        num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
    target_ffn  = [target_path,'database.mat'];
    %skip date as there is no storm data
    if exist(target_ffn,'file') ~= 2
        continue
    end
    disp(['loading storm database for ',datestr(target_date)]);
    load(target_ffn,'storm_struct');
    storm_database = [storm_database,storm_struct];
end

%% add tracking data
track_vec= nowcast_wdss_tracking(storm_database,false,'');
for i=1:length(storm_database)
    storm_database(i).track   = track_vec(i);
end

%% mask cells by var and time
%extract mask var
switch data_type
    case 'mesh'
        mask_var = vertcat(storm_database.max_mesh);
    case 'dbz'
        mask_var = vertcat(storm_database.max_dbz);
    case 'g_vil'
        mask_var = vertcat(storm_database.max_g_vil);
    case 'tops_h'
        mask_var = vertcat(storm_database.max_tops);
    case 'sts_h'
        mask_var = vertcat(storm_database.max_sts_dbz_h);
end
%create var mask
if strcmp(data_min,'nan')
    min_mask = true(length(mask_var),1);
else
    min_mask = mask_var >= data_min;
end
if strcmp(data_max,'nan')
    max_mask = true(length(mask_var),1);
else
    max_mask = mask_var >= data_max;
end
%create time mask
datestr_list   = [storm_database.start_timestamp]';
datetime_list  = datenum(datestr_list,ddb_tfmt);
time_list      = rem(datetime_list,1);
time_mask      = time_list>=rem(datenum(time_min,'HH:MM'),1) & time_list<=rem(datenum(time_max,'HH:MM'),1);
%apply mask
data_mask      = min_mask & max_mask & time_mask;
storm_database = storm_database(data_mask);

%build vol struct

%% generate tracks for each day (don't want to overload tracking)
uniq_date_list = unique(floor(datetime_list));
for i=1:length(uniq_date_list)
    target_date = uniq_date_list(i);
    target_mask = target_date==floor(datetime_list);
    target_db   = storm_database(target_mask);
    
    track_vec   = nowcast_wdss_tracking(storm_database,false,'')
    keyboard
    
end
keyboard
