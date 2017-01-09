function preallocate_mobile_grid(out_path,force_update)
%WHAT: Calculates regrid coordinates from a national grid (provides
%seamless merging) and the local radar mask

%% init
%paths
global_config_fn  = 'global.config';
tmp_config_path   = 'tmp/';
out_path          = 'transforms/';
% Load global config files
load([tmp_config_path,global_config_fn,'.mat']);

%% Generate mapping coordinates
mobile_rng_vec     = -mobile_h_rng:mobile_h_grid:mobile_h_rng;
mobile_alt_vec     = mobile_v_grid:mobile_v_grid:mobile_v_rng;

%mapping coordinates, working in ij coordinates
mstruct            = defaultm('mercator');
mstruct.origin     = [mobile_lat mobile_lon];
mstruct.geoid      = almanac('earth','wgs84','km');
mstruct            = defaultm(mstruct);
%transfore x,y into lat long using centroid
[radar_lat_vec, radar_lon_vec]                 = minvtran(mstruct, mobile_rng_vec, fliplr(mobile_rng_vec));

%check if transform file exists and needs replacing
out_fn       = [out_path,'regrid_transform_',num2str(mobile_id,'%02.0f'),'.mat'];
if exist(out_fn,'file')==2 && force_update==0
	display(['Skipping transform build for ',num2str(radar_id)]);
	contine
end

%% convert to radar geometry coords
%generate regrid coords
[radar_azi_grid,radar_elv_grid,radar_rng_grid] = preallocate_transform(mobile_lat,mobile_lon,mobile_alt,radar_lat_vec,radar_lon_vec,mobile_alt_vec,earth_rad,ke);

%% bound and index
%create inital output vars
geo_coords       = struct('radar_lon_vec',radar_lon_vec,'radar_lat_vec',radar_lat_vec,'radar_alt_vec',mobile_alt_vec,...
    'radar_lat',mobile_lat,'radar_lon',mobile_lon,'radar_alt',mobile_alt);
radar_coords     = [radar_azi_grid(:),radar_rng_grid(:),radar_elv_grid(:)];
grid_size        = size(radar_azi_grid);
%apply boundary filter
filter_ind       = boundary_filter(radar_coords,0,mobile_max_elv,mobile_h_grid,mobile_h_rng);
radar_coords     = radar_coords(filter_ind,:);
%convert to more efficent types
radar_coords     = uint16(radar_coords.*100);
filter_ind       = uint32(filter_ind);
radar_weight_id  = ones(size(radar_azi_grid,1),size(radar_azi_grid,2));
img_azi          = radar_azi_grid(:,:,1);
img_rng          = radar_rng_grid(:,:,1);
%save
save(out_fn,'radar_coords','geo_coords','grid_size','filter_ind','radar_weight_id','img_azi','img_rng')



function filter_ind = boundary_filter(radar_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filteradar_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(radar_coords(:,3)>= elv_min & radar_coords(:,3)<=elv_max...
    & radar_coords(:,2)>=rng_min & radar_coords(:,2)<=rng_max);
