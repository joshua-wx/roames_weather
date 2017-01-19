function mask_grid = process_radar_mask(radar_id,rid_list,transform_path)

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

%break for no list
if length(rid_list)==1
    mask_grid = true(size(radar_lon_grid));
end

%loop through radar id list from input
for i=1:length(rid_list)

    %extract other radar id location
    radar_idx       = find(rid_list(i)==siteinfo_id_list);
    other_radar_lat = siteinfo_lat_list(radar_idx);
    other_radar_lon = siteinfo_lon_list(radar_idx);
    
    %skip for distant other sites
    [check_dist,~] = distance(cur_radar_lat,cur_radar_lon,other_radar_lat,other_radar_lon);
    if deg2km(check_dist)>radar_mask_rng*2
        continue
    end
    
    %create distance grid
    radar_gcdist_grid = earth_rad.*acos(sind(other_radar_lat).*sind(radar_lat_grid)+...
                        cosd(other_radar_lat).*cosd(radar_lat_grid).*cosd(abs(radar_lon_grid-other_radar_lon)));

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
    other_weight_grid = exp(-(radar_gcdist_grid.^2)./weight1)./weight2;
    other_rid_grid    = ones(length(radar_lat_grid),length(radar_lon_grid)).*rid_list(i);
    %mask other radar weights
    mask               = other_weight_grid>weight_grid;
    %update global grids
    weight_grid(mask)  = other_weight_grid(mask);
    rid_grid(mask)     = other_rid_grid(mask);
end

%create mask grid
mask_grid = rid_grid==radar_id;

