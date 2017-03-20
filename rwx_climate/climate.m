function climate
%WHAT: Core climatology script for roames weather which takes the local
%database built by sync_database and generate outputs for spatial and
%statistical analysis

%setup config names
climate_config_fn  = 'climate.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';
site_info_fn       = 'site_info.txt';

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

% Load site info
read_site_info(site_info_fn); load([local_tmp_path,site_info_fn,'.mat']);

% build transforms
transform_path    = [local_tmp_path,'transforms/'];
preallocate_radar_grid(radar_id,transform_path,transform_new)

%% load database
target_ffn  = [db_root,num2str(radar_id,'%02.0f'),'/','database.csv'];
out         = dlmread(target_ffn,',',1,0);
%build local database
storm_date_list          = datenum(out(:,2:7));
storm_trck_list          = out(:,8);
storm_latloncent_list    = out(:,12:13);
storm_stat_list          = struct('area',out(:,22),'area_ewt',out(:,23),'max_cell_vil',out(:,24),'max_dbz',out(:,25),...
    'max_dbz_h',out(:,26),'max_g_vil',out(:,27),'max_mesh',out(:,28),...
    'max_posh',out(:,29),'max_sts_dbz_h',out(:,30),'max_tops',out(:,31),...
    'mean_dbz',out(:,32),'mass',out(:,33),'vol',out(:,34));

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
%create date mask
date_mask        = ismember(floor(storm_date_list),date_list);
%% mask cells by var, time and date
%extract mask var
switch data_type
    case 'mesh'
        mask_var = vertcat(storm_stat_list.max_mesh);
    case 'dbz'
        mask_var = vertcat(storm_stat_list.max_dbz);
    case 'g_vil'
        mask_var = vertcat(storm_stat_list.max_g_vil);
    case 'tops_h'
        mask_var = vertcat(storm_stat_list.max_tops);
    case 'sts_h'
        mask_var = vertcat(storm_stat_list.max_sts_dbz_h);
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
time_list      = rem(storm_date_list,1);
time_mask      = time_list>=rem(datenum(time_min,'HH:MM'),1) & time_list<=rem(datenum(time_max,'HH:MM'),1);

%% combine masks
data_mask      = min_mask & max_mask & time_mask & date_mask;

%% create plots

%load transform
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
load(transform_fn,'grid_size','img_latlonlox')

%create grid
if strcmp(grid_type,'centroid')
    cent_lat_vec = img_latlonlox(2):centroid_grid:img_latlonlox(1);
    cent_lon_vec = img_latlonlox(4):centroid_grid:img_latlonlox(3);
    out_grid     = zeros(length(cent_lat_vec),length(cent_lon_vec));
else
    out_grid     = zeros(grid_size(1),grid_size(2));
end

% to do: 
%implement merged density plots (or centroids if too hard) and a map for
%Sydney meeting
%preprocess sydney data and copy onto HDD (03 and 71), also send to bom
