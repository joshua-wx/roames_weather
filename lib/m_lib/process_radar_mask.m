function [mask_grid,geo_coords] = process_radar_mask(radar_id,start_timestep,vol_struct,transform_path)

%% init
%paths
priority_fn = 'priority_list.txt';
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
%load priority
priority_id_list = dlmread(priority_fn);
%load transform data
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
load(transform_fn,'geo_coords')
%preallocate
[radar_lon_grid,radar_lat_grid] = meshgrid(geo_coords.radar_lon_vec,geo_coords.radar_lat_vec);
weight_grid                     = zeros(size(radar_lon_grid));
rid_grid                        = zeros(size(radar_lon_grid));
%extract current ids
radar_idx     = find(radar_id==siteinfo_id_list);
cur_radar_lat = siteinfo_lat_list(radar_idx);
cur_radar_lon = siteinfo_lon_list(radar_idx);

%extract rid_list from vol_struct and filter out recent radars from
%start_timedate
rid_list        = [vol_struct.radar_id];
r_rng_list      = [vol_struct.radar_rng];
time_list       = [vol_struct.start_timestamp];
radar_step      = calc_radar_step(vol_struct,radar_id);
radar_mask_time = radar_step.*1.5;
%filter out unique radar ids by radar_mask_time
time_filter     = minute(start_timestep - time_list) <= radar_mask_time;
rid_list        = rid_list(time_filter);
r_rng_list      = r_rng_list(time_filter);
%extract unique radar_ids
[rid_list,ia,~] = unique(rid_list);
r_rng_list      = r_rng_list(ia);
%loop through radar id list from input
for i=1:length(rid_list)
    
    %extract other radar id location
    radar_idx       = find(rid_list(i)==siteinfo_id_list);
    other_radar_lat = roundn(siteinfo_lat_list(radar_idx),-2);
    other_radar_lon = roundn(siteinfo_lon_list(radar_idx),-2);
    
    %skip for distant other sites
    [check_dist,~] = distance(cur_radar_lat,cur_radar_lon,other_radar_lat,other_radar_lon);
    if deg2km(check_dist)>radar_mask_rng*2
        continue
    end
    
    %create distance grid from target radar to other radar
    radar_gcdist_grid = earth_rad.*acos(sind(other_radar_lat).*sind(radar_lat_grid)+...
                        cosd(other_radar_lat).*cosd(radar_lat_grid).*cosd(abs(radar_lon_grid-other_radar_lon)));
    %calculating weights
    if ismember(rid_list(i),priority_id_list) %priority radars
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
    
    %calculate weights of other radar
    other_weight_grid  = exp(-(radar_gcdist_grid.^2)./weight1)./weight2;
    dist_mask          = radar_gcdist_grid<=r_rng_list(i);
    other_weight_grid  = other_weight_grid.*dist_mask; %apply dist mask
    other_rid_grid     = ones(size(radar_lon_grid)).*rid_list(i);
    %mask other radar weights
    weight_mask        = other_weight_grid>weight_grid;
    %update global grids
    weight_grid(weight_mask) = other_weight_grid(weight_mask);
    rid_grid(weight_mask)    = other_rid_grid(weight_mask);
end

%create mask grid
mask_grid   = rid_grid==radar_id;
