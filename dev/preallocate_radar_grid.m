function preallocate_radar_grid
%WHAT: Calculates regrid coordinates from a national grid (provides
%seamless merging) and the local radar mask

%% init
%paths
addpath('../lib/m_lib')
addpath('../etc')
global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';
out_path          = 'transforms/';
%load sites
read_site_info(site_info_fn);
load([tmp_config_path,site_info_fn,'.mat']);
%load priority
priority_id_list = dlmread('priority_list.txt');
% Load global config files
read_config(global_config_fn);
load([tmp_config_path,global_config_fn,'.mat']);

%% setup national latlon grid
[max_lat,~] = reckon(min_lat,min_lon,km2deg(dist_y_km),180);
[~,max_lon] = reckon(min_lat,min_lon,km2deg(dist_x_km),90);
lat_vec     = linspace(min_lat,max_lat,dist_y_km);
lon_vec     = linspace(min_lon,max_lon,dist_x_km);

%% build global radar weights
weight_grid         = zeros(length(lat_vec),length(lon_vec));
weight_id_grid      = zeros(length(lat_vec),length(lon_vec));
for i=1:length(radar_id_list)
    %extract current ids
    r_id        = radar_id_list(i);
    r_lat       = radar_lat_list(i);
    r_lon       = radar_lon_list(i);
    
    %subset to radar using r_mask_r
    [x_ind,y_ind,r_lat_vec,r_lon_vec] = radar_coords(r_lat,r_lon,lat_vec,lon_vec,r_mask_rng);
    
    %calculate earth distance from radar
    [r_lon_grid,r_lat_grid] = meshgrid(r_lon_vec,r_lat_vec);
    r_gcdist_grid = earth_rad.*acos(sind(r_lat).*sind(r_lat_grid)+...
                        cosd(r_lat).*cosd(r_lat_grid).*cosd(abs(r_lon_grid-r_lon)));   

    %calculating weights
    if ismember(r_id,priority_id_list) %priority radars
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
    r_weight       = exp(-(r_gcdist_grid.^2)./weight1)./weight2;
    r_id           = ones(length(r_lat_grid),length(r_lon_grid)).*r_id;
    g_weight       = weight_grid(y_ind,x_ind);
    g_id           = weight_id_grid(y_ind,x_ind);
    %mask radar weights
    mask           = r_weight>g_weight;
    %update global subsets
    g_weight(mask) = r_weight(mask);
    g_id(mask)     = r_id(mask);
    weight_grid(y_ind,x_ind) = g_weight;
    weight_id_grid(y_ind,x_ind) = g_id;
end

%% generate radar grids
for i=1:length(radar_id_list)
    r_id        = radar_id_list(i);
    r_lat       = radar_lat_list(i);
    r_lon       = radar_lon_list(i);
    r_elv       = radar_elv_list(i)/1000;
    r_earth_rad = earth_rad + r_elv;
    
    %subset to radar using r_mask_rng
    [x_ind,y_ind,r_lat_vec,r_lon_vec] = radar_coords(r_lat,r_lon,lat_vec,lon_vec,r_mask_rng);
    
    %create radar grid
    [r_lon_grid,r_lat_grid,r_alt_grid] = meshgrid(r_lon_vec,r_lat_vec,alt_vec);
    %extract weight ids
    r_weight_id                        = weight_id_grid(y_ind,x_ind);
    %earth distance grid
    r_gcdist_grid = earth_rad.*acos(sind(r_lat).*sind(r_lat_grid)+...
                        cosd(r_lat).*cosd(r_lat_grid).*cosd(abs(r_lon_grid-r_lon)));

    %radar azimuth grid
    r_azi_grid    = real(asin(sin((pi/2)-deg2rad(r_lat_grid)).*sin(deg2rad(r_lon_grid-r_lon))./sin(r_gcdist_grid./earth_rad)));
    %wrap from -pi/2->pi/2 to 0->360deg
    r_azi_grid    = rad2deg(r_azi_grid);
    r_lat_sign    = sign(r_lat_grid-r_lat);
    r_lon_sign    = sign(r_lon_grid-r_lon);
    r_azi_grid(r_lat_sign==-1 & r_lon_sign== 1)  = 180-r_azi_grid(r_lat_sign==-1     & r_lon_sign== 1);
    r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1)  = 180+abs(r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1));
    r_azi_grid(r_lat_sign== 1 & r_lon_sign==-1)  = 360+(r_azi_grid(r_lat_sign==1     & r_lon_sign==-1));

    %elevation grid
    r_elv_grid    = atan((cos(r_gcdist_grid./(ke.*r_earth_rad))-((ke*r_earth_rad)./(ke*r_earth_rad+r_alt_grid-r_elv)))./...
                        sin(r_gcdist_grid./(ke.*r_earth_rad)));
    r_elv_grid    = rad2deg(r_elv_grid);

    %range grid
    r_rng_grid    = sin(r_gcdist_grid./(ke.*r_earth_rad)).*(ke.*r_earth_rad+r_alt_grid-r_elv)./cosd(r_elv_grid);

    %% bound and index
    %create inital output vars
    geo_coords   = struct('r_lon_vec',r_lon_vec,'r_lat_vec',r_lat_vec,'alt_vec',alt_vec);
    r_coords     = [r_azi_grid(:),r_rng_grid(:),r_elv_grid(:)];
    r_size       = size(r_azi_grid);
    %apply boundary filter
    filter_ind   = boundary_filter(r_coords,elv_min,elv_max,rng_min,rng_max);
    r_coords     = r_coords(filter_ind,:);
    %convert to more efficent types
    r_coords     = uint16(r_coords.*100);
    filter_ind   = uint32(filter_ind);
    r_weight_id  = uint8(r_weight_id);
    %save
    tmp_fn   = [out_path,'regrid_transform_',num2str(r_id,'%02.0f'),'.mat'];
    save(tmp_fn,'r_coords','geo_coords','r_size','filter_ind','r_weight_id')
    
end

function filter_ind = boundary_filter(r_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filter_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(r_coords(:,3)>= elv_min & r_coords(:,3)<=elv_max...
    & r_coords(:,2)>=rng_min & r_coords(:,2)<=rng_max);

function [x_ind,y_ind,r_lat_vec,r_lon_vec] = radar_coords(r_lat,r_lon,g_lat_vec,g_lon_vec,r_mask_rng)
%WHAT: extracts subset/index from global lat lon vec using range mask
[y_dist,~]  = distance(r_lat,r_lon,g_lat_vec,ones(1,length(g_lat_vec)).*r_lon);
y_mask      = deg2km(y_dist)<=r_mask_rng;
[x_dist,~]  = distance(r_lat,r_lon,ones(1,length(g_lon_vec)).*r_lat,g_lon_vec);
x_mask      = deg2km(x_dist)<=r_mask_rng;
r_lat_vec   = g_lat_vec(y_mask);
r_lon_vec   = g_lon_vec(x_mask);
x_ind       = find(x_mask);
y_ind       = find(y_mask);