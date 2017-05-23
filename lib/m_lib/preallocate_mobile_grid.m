function preallocate_mobile_grid(radar_id,out_path,force_update)
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

%load mobile radar coords
siteinfo_idx    = find(radar_id==siteinfo_id_list);
radar_lat       = roundn(siteinfo_lat_list(siteinfo_idx),-2);
radar_lon       = roundn(siteinfo_lon_list(siteinfo_idx),-2);
radar_alt       = siteinfo_alt_list(siteinfo_idx)/1000;
    
%check if transform file exists and needs replacing
out_fn       = [out_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
if exist(out_fn,'file')==2 && force_update==0
	display(['Skipping transform build for ',num2str(radar_id)]);
	return
end

%% Generate mapping coordinates
v_grid        = mobile_v_grid;
h_grid        = mobile_h_grid;
radar_rng_vec = -mobile_h_rng:h_grid:mobile_h_rng;
radar_alt_vec = [v_grid:v_grid:mobile_v_rng] + radar_alt;

%mapping coordinates, working in ij coordinates
mstruct            = defaultm('mercator');
mstruct.origin     = [radar_lat radar_lon];
mstruct.geoid      = almanac('earth','wgs84','km');
mstruct            = defaultm(mstruct);
%transfore x,y into lat long using centroid
[radar_lat_vec, radar_lon_vec] = minvtran(mstruct, radar_rng_vec, fliplr(radar_rng_vec));

%% convert to radar geometry coords
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
img_latlonbox    = [max(radar_lat_vec);min(radar_lat_vec);max(radar_lon_vec);min(radar_lon_vec)];
%save
h_grid_deg = km2deg(h_grid);
save(out_fn,'radar_coords','geo_coords','grid_size','img_azi','img_rng','img_latlonbox','v_grid','h_grid_deg')

function filter_ind = boundary_filter(radar_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filteradar_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(radar_coords(:,3)>= elv_min & radar_coords(:,3)<=elv_max...
    & radar_coords(:,2)>=rng_min & radar_coords(:,2)<=rng_max);
