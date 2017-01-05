function preallocate_radar_grid
%WHAT: Calculates regrid coordinates from a national grid (provides
%seamless merging) and the local radar mask

%% init
%paths
global_config_fn  = 'global.config';
priority_fn       = 'priority_list.txt';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';
out_path          = 'transforms/';
%load sites
load([tmp_config_path,site_info_fn,'.mat']);
%load priority
priority_id_list = dlmread(priority_fn);
% Load global config files
load([tmp_config_path,global_config_fn,'.mat']);

%% setup national latlon grid
[max_lat,~] = reckon(min_lat,min_lon,km2deg(dist_y_km),180);
[~,max_lon] = reckon(min_lat,min_lon,km2deg(dist_x_km),90);
lat_vec     = linspace(min_lat,max_lat,dist_y_km/h_grid);
lon_vec     = linspace(min_lon,max_lon,dist_x_km/h_grid);

%% build global radar weights
weight_grid         = zeros(length(lat_vec),length(lon_vec));
weight_id_grid      = zeros(length(lat_vec),length(lon_vec));
for i=1:length(radar_id_list)
    %extract current ids
    radar_id        = radar_id_list(i);
    radar_lat       = radar_lat_list(i);
    radar_lon       = radar_lon_list(i);
    
    %subset to radar using radar_mask_r
    [x_ind,y_ind,radar_lat_vec,radar_lon_vec] = radar_grid(radar_lat,radar_lon,lat_vec,lon_vec,radar_mask_rng);
    
    %calculate earth distance from radar
    [radar_lon_grid,radar_lat_grid] = meshgrid(radar_lon_vec,radar_lat_vec);
    radar_gcdist_grid           = earth_rad.*acos(sind(radar_lat).*sind(radar_lat_grid)+...
                        cosd(radar_lat).*cosd(radar_lat_grid).*cosd(abs(radar_lon_grid-radar_lon)));   

    %calculating weights
    if ismember(radar_id,priority_id_list) %priority radars
        weight1  = 7000;
        weight2  = 1;
    else %nonpriority Radars
        weight1  = 3500;
        weight2  = 10;
    end
    %For priority radars use weight1 = 3500, weight2 = 10
    %this gives 0.1 @ 0km
    %For nonpriority radars, use weight1 = 7000, weight2 = 1
    %this gives 1.0 @ 0 km, 0.25 @ 100km, 0.1 @ 125km, 0 @ 180km
    
    %compare radar weights with global weights
    radar_weight       = exp(-(radar_gcdist_grid.^2)./weight1)./weight2;
    radar_id           = ones(length(radar_lat_grid),length(radar_lon_grid)).*radar_id;
    g_weight       = weight_grid(y_ind,x_ind);
    g_id           = weight_id_grid(y_ind,x_ind);
    %mask radar weights
    mask           = radar_weight>g_weight;
    %update global subsets
    g_weight(mask) = radar_weight(mask);
    g_id(mask)     = radar_id(mask);
    weight_grid(y_ind,x_ind) = g_weight;
    weight_id_grid(y_ind,x_ind) = g_id;
end

%% generate radar grids
for i=1:length(radar_id_list)
    radar_id        = radar_id_list(i);
    radar_lat       = radar_lat_list(i);
    radar_lon       = radar_lon_list(i);
    radar_alt       = radar_alt_list(i)/1000;
    
    %subset to radar using radar_mask_rng
    [x_ind,y_ind,radar_lat_vec,radar_lon_vec]      = radar_grid(radar_lat,radar_lon,lat_vec,lon_vec,radar_mask_rng);
    
    %generate regrid coords
    [radar_azi_grid,radar_elv_grid,radar_rng_grid] = preallocate_transform(radar_lat,radar_lon,radar_alt,radar_lat_vec,radar_lon_vec,alt_vec,earth_rad,ke);
    
    %extract weight ids
    radar_weight_id                                = weight_id_grid(y_ind,x_ind);

    %% bound and index
    %create inital output vars
    geo_coords       = struct('radar_lon_vec',radar_lon_vec,'radar_lat_vec',radar_lat_vec,'radar_alt_vec',alt_vec,...
        'radar_lat',radar_lat,'radar_lon',radar_lon,'radar_alt',radar_alt);
    radar_coords     = [radar_azi_grid(:),radar_rng_grid(:),radar_elv_grid(:)];
    grid_size         = size(radar_azi_grid);
    %apply boundary filter
    filter_ind       = boundary_filter(radar_coords,elv_min,elv_max,rng_min,rng_max);
    radar_coords     = radar_coords(filter_ind,:);
    %convert to more efficent types
    radar_coords     = uint16(radar_coords.*100);
    filter_ind       = uint32(filter_ind);
    radar_weight_id  = uint8(radar_weight_id);
    img_azi          = radar_azi_grid(:,:,1);
    img_rng          = radar_rng_grid(:,:,1);
    %save
    tmp_fn       = [out_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
    save(tmp_fn,'radar_coords','geo_coords','grid_size','filter_ind','radar_weight_id','img_azi','img_rng')
    
end

function filter_ind = boundary_filter(radar_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filteradar_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(radar_coords(:,3)>= elv_min & radar_coords(:,3)<=elv_max...
    & radar_coords(:,2)>=rng_min & radar_coords(:,2)<=rng_max);

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