function preallocate_radar_grid(radar_id_list,out_path,force_update)
%WHAT: Calculates regrid coordinates from a national grid (provides
%seamless merging) and the local radar mask

%% init
%paths
global_config_fn  = 'global.config';
tmp_config_path   = 'tmp/';
% Load global config files
load([tmp_config_path,global_config_fn,'.mat']);
%load sites
load([tmp_config_path,site_info_fn,'.mat']);
%create output path
if exist(out_path,'file')~=7
    mkdir(out_path)
end
%% setup national latlon grid
v_grid  = bom_v_grid;
h_grid  = bom_h_rng;
lat_vec = max_lat:-h_grid:min_lat; %matrix coords
lon_vec = min_lon:h_grid:max_lon;
alt_vec = v_grid:v_grid:v_tops;

%% generate radar grids
for i=1:length(radar_id_list)

	%find radar_id index from config file
	siteinfo_idx    = find(radar_id_list(i)==siteinfo_id_list);
	%extract current ids
    radar_id        = siteinfo_id_list(siteinfo_idx);
    radar_lat       = roundn(siteinfo_lat_list(siteinfo_idx),-2);
    radar_lon       = roundn(siteinfo_lon_list(siteinfo_idx),-2);
    radar_alt       = siteinfo_alt_list(siteinfo_idx)/1000;
    radar_alt_vec   = alt_vec + radar_alt;

    %check if transform file exists and needs replacing
	out_fn       = [out_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
    if exist(out_fn,'file')==2 && force_update==0
		disp(['Skipping transform build for ',num2str(radar_id)]);
		continue
	end
    disp(['Building transform for ',num2str(radar_id)]);
    %subset to radar using radar_mask_rng
    [~,~,radar_lat_vec,radar_lon_vec]      = radar_grid(radar_lat,radar_lon,lat_vec,lon_vec,radar_mask_rng);
    
    %generate regrid coords
    [radar_azi_grid,radar_elv_grid,radar_rng_grid] = preallocate_transform(radar_lat,radar_lon,radar_alt,radar_lat_vec,radar_lon_vec,radar_alt_vec,earth_rad,ke);
    
    %% bound and index
    %create inital output vars
    geo_coords       = struct('radar_lon_vec',radar_lon_vec,'radar_lat_vec',radar_lat_vec,'radar_alt_vec',radar_alt_vec,...
        'radar_lat',radar_lat,'radar_lon',radar_lon,'radar_alt',radar_alt);
    radar_coords     = [radar_azi_grid(:),radar_rng_grid(:),radar_elv_grid(:)];
    grid_size        = size(radar_azi_grid);
    %convert to more efficent types
    radar_coords     = uint16(radar_coords.*100);
    img_azi          = radar_azi_grid(:,:,1);
    img_rng          = radar_rng_grid(:,:,1);
    img_latlonbox    = [max(radar_lat_vec)+h_grid/2;min(radar_lat_vec)-h_grid/2;max(radar_lon_vec)+h_grid/2;min(radar_lon_vec)-h_grid/2]; %including offets to corners
    %save
    tmp_fn     = [out_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
    h_grid_deg = h_grid;
    save(out_fn,'radar_coords','geo_coords','grid_size','img_azi','img_rng','img_latlonbox','v_grid','h_grid_deg')
    
end

function [x_ind,y_ind,radar_lat_vec,radar_lon_vec] = radar_grid(radar_lat,radar_lon,g_lat_vec,g_lon_vec,radar_mask_rng)
%WHAT: extracts subset/index from global lat lon vec using range mask
[y_dist,~]      = distance(radar_lat,radar_lon,g_lat_vec,ones(1,length(g_lat_vec)).*radar_lon);
y_mask          = deg2km(y_dist)<=radar_mask_rng;
[x_dist,~]      = distance(radar_lat,radar_lon,ones(1,length(g_lon_vec)).*radar_lat,g_lon_vec);
x_mask          = deg2km(x_dist)<=radar_mask_rng;
radar_lat_vec   = g_lat_vec(y_mask);
radar_lon_vec   = g_lon_vec(x_mask);
x_ind           = find(x_mask);
y_ind           = find(y_mask);
