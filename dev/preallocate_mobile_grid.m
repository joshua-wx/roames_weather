function preallocate_mobile_grid
%WHAT: Calculates regrid coordinates from a national grid (provides
%seamless merging) and the local radar mask

%% init
%paths
addpath('../lib/m_lib')
addpath('../etc')
global_config_fn  = 'global.config';
tmp_config_path   = 'tmp/';
out_path          = 'transforms/';
% Load global config files
read_config(global_config_fn);
load([tmp_config_path,global_config_fn,'.mat']);

%% Generate mapping coordinates
rng_vec            = -mobile_h_rng:mobile_h_grid:mobile_h_rng;
alt_vec            = mobile_v_grid:mobile_v_grid:mobile_v_rng;
r_earth_rad        = earth_rad + mobile_elv;

%mapping coordinates, working in ij coordinates
mstruct            = defaultm('mercator');
mstruct.origin     = [mobile_lat mobile_lon];
mstruct.geoid      = almanac('earth','wgs84','km');
mstruct            = defaultm(mstruct);
%transfore x,y into lat long using centroid
[r_lat_vec, r_lon_vec] = minvtran(mstruct, rng_vec, fliplr(rng_vec));
[r_lon_grid,r_lat_grid,r_alt_grid] = meshgrid(r_lon_vec,r_lat_vec,alt_vec);

%% convert to radar geometry coords
%earth distance grid
r_gcdist_grid = earth_rad.*acos(sind(mobile_lat).*sind(r_lat_grid)+...
    cosd(mobile_lat).*cosd(r_lat_grid).*cosd(abs(r_lon_grid-mobile_lon)));
%radar azimuth grid
r_azi_grid    = real(asin(sin((pi/2)-deg2rad(r_lat_grid)).*sin(deg2rad(r_lon_grid-mobile_lon))./sin(r_gcdist_grid./earth_rad)));
%wrap from -pi/2->pi/2 to 0->360deg
r_azi_grid    = rad2deg(r_azi_grid);
r_lat_sign    = sign(r_lat_grid-mobile_lat);
r_lon_sign    = sign(r_lon_grid-mobile_lon);
r_azi_grid(r_lat_sign==-1 & r_lon_sign== 1)  = 180-r_azi_grid(r_lat_sign==-1     & r_lon_sign== 1);
r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1)  = 180+abs(r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1));
r_azi_grid(r_lat_sign== 1 & r_lon_sign==-1)  = 360+(r_azi_grid(r_lat_sign==1     & r_lon_sign==-1));

%elevation grid
r_elv_grid    = atan((cos(r_gcdist_grid./(ke.*r_earth_rad))-((ke*r_earth_rad)./(ke*r_earth_rad+r_alt_grid-mobile_elv)))./...
    sin(r_gcdist_grid./(ke.*r_earth_rad)));
r_elv_grid    = rad2deg(r_elv_grid);

%range grid
r_rng_grid    = sin(r_gcdist_grid./(ke.*r_earth_rad)).*(ke.*r_earth_rad+r_alt_grid-mobile_elv)./cosd(r_elv_grid);

%% bound and index
%create inital output vars
geo_coords   = struct('r_lon_vec',r_lon_vec,'r_lat_vec',r_lat_vec,'alt_vec',alt_vec);
r_coords     = [r_azi_grid(:),r_rng_grid(:),r_elv_grid(:)];
r_size       = size(r_azi_grid);
%apply boundary filter
filter_ind   = boundary_filter(r_coords,0,mobile_max_elv,mobile_h_grid,mobile_h_rng);
r_coords     = r_coords(filter_ind,:);
%convert to more efficent types
r_coords     = uint16(r_coords.*100);
filter_ind   = uint32(filter_ind);
r_weight_id  = ones(size(r_azi_grid,1),size(r_azi_grid,2));
%save
tmp_fn   = [out_path,'regrid_transform_',num2str(mobile_id,'%02.0f'),'.mat'];
save(tmp_fn,'r_coords','geo_coords','r_size','filter_ind','r_weight_id')


function filter_ind = boundary_filter(r_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filter_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(r_coords(:,3)>= elv_min & r_coords(:,3)<=elv_max...
    & r_coords(:,2)>=rng_min & r_coords(:,2)<=rng_max);