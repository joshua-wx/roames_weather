function preallocate_radar_mosiac

%paths
read_site_info('site_info.txt')
load([tempdir,'site_info.txt','.mat'])

%grid config
min_lat     = -10;
min_lon     = 112;
dist_y_km   = 3900;
dist_x_km   = 4740;
alt_vec     = [[0.5:0.5:15.5],[16:1:20]];
%radar constants
r_mask_r    = 200;      %km from radar
%transform constants
earth_rad   = 6371;     %km
ke          = 4/3;


%% setup national latlon grid
[max_lat,~] = reckon(min_lat,min_lon,km2deg(dist_y_km),180);
[~,max_lon] = reckon(min_lat,min_lon,km2deg(dist_x_km),90);
lat_vec     = linspace(min_lat,max_lat,dist_y_km);
lon_vec     = linspace(min_lon,max_lon,dist_x_km);

for i=1:length(r_id_list)
    r_id        = r_id_list(i);
    r_lat       = r_lat_list(i);
    r_lon       = r_lon_list(i);
    r_elv       = r_elv_list(i)/1000;
    r_earth_rad = earth_rad + r_elv;
    
    %subset to radar using r_mask_r
    [y_dist,~]  = distance(r_lat,r_lon,lat_vec,ones(1,length(lat_vec)).*r_lon);
    y_mask      = deg2km(y_dist)<=r_mask_r;
    [x_dist,~]  = distance(r_lat,r_lon,ones(1,length(lon_vec)).*r_lat,lon_vec);
    x_mask      = deg2km(x_dist)<=r_mask_r;
    r_lat_vec   = lat_vec(y_mask);
    r_lon_vec   = lon_vec(x_mask);

    %create radar grid
    [r_lon_grid,r_lat_grid,r_alt_grid] = meshgrid(r_lon_vec,r_lat_vec,alt_vec);
    
    %earth distance grid
    r_gcdist_grid = earth_rad.*acos(sind(r_lat).*sind(r_lat_grid)+...
                        cosd(r_lat).*cosd(r_lat_grid).*cosd(abs(r_lon_grid-r_lon)));

    %radar azimuth grid
    r_azi_grid    = asin(sin((pi/2)-deg2rad(r_lat_grid)).*sin(deg2rad(r_lon_grid-r_lon))./sin(r_gcdist_grid./earth_rad));
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

    %% precompute multi radar weighting
    w_rng_grid = exp(-(r_gcdist_grid.^2)./2500); %2500 for non-S1 radars, 5000 for S1 radars

    %save
    tmp_fn = ['mosiac_transform_uint_',num2str(r_id,'%02.0f'),'.mat'];
    r_azi_grid = uint16(r_azi_grid.*100);
    r_elv_grid = uint16(r_elv_grid.*100);
    r_rng_grid = uint16(r_rng_grid.*100);
    w_rng_grid = uint16(w_rng_grid.*100);
    
    save(tmp_fn,'r_azi_grid','r_elv_grid','r_rng_grid','w_rng_grid')
    
end