function preallocate_radar_mosiac

min_lat     = -10;
min_lon     = 112;
dist_y_km   = 3900;
dist_x_km   = 4740;
alt_vec     = [[0.5:0.5:15.5],[16:1:20]];
r_lat       = -27.7178;
r_lon       = 153.2400;
r_elv       = 0.174;
r_mask_r    = 150;

[max_lat,~] = reckon(min_lat,min_lon,km2deg(dist_y_km),180);
[~,max_lon] = reckon(min_lat,min_lon,km2deg(dist_x_km),90);
lat_vec     = linspace(min_lat,max_lat,dist_y_km);
lon_vec     = linspace(min_lon,max_lon,dist_x_km);


[y_dist,az] = distance(r_lat,r_lon,lat_vec,ones(1,length(lat_vec)).*r_lon);
y_mask      = deg2km(y_dist)<=r_mask_r;
[x_dist,az] = distance(r_lat,r_lon,ones(1,length(lon_vec)).*r_lat,lon_vec);
x_mask      = deg2km(x_dist)<=r_mask_r;

r_lat_vec   = lat_vec(y_mask);
r_lon_vec   = lon_vec(x_mask);

[r_lon_grid,r_lat_grid,r_alt_grid] = meshgrid(r_lon_vec,r_lat_vec,alt_vec);

earth_rad   = 6371;
ke          = 4/3;
r_earth_rad = earth_rad + r_elv;

r_gcdist_grid = earth_rad.*acos(sind(r_lat).*sind(r_lat_grid)+...
                    cosd(r_lat).*cosd(r_lat_grid).*cosd(abs(r_lon_grid-r_lon)));
                
r_azi_grid    = asin(sin((pi/2)-deg2rad(r_lat_grid)).*sin(deg2rad(r_lon_grid-r_lon))./sin(r_gcdist_grid./earth_rad));
r_azi_grid    = rad2deg(r_azi_grid);
r_lat_sign    = sign(r_lat_grid-r_lat);
r_lon_sign    = sign(r_lon_grid-r_lon);
r_azi_grid(r_lat_sign==-1 & r_lon_sign==1)  = 180-r_azi_grid(r_lat_sign==-1 & r_lon_sign==1);
r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1) = 180+abs(r_azi_grid(r_lat_sign==-1 & r_lon_sign==-1));
r_azi_grid(r_lat_sign==1 & r_lon_sign==-1)  = 360+(r_azi_grid(r_lat_sign==1 & r_lon_sign==-1));


r_elv_grid    = atan((cos(r_gcdist_grid./(ke.*r_earth_rad))-((ke*r_earth_rad)./(ke*r_earth_rad+r_alt_grid-r_elv)))./...
                    sin(r_gcdist_grid./(ke.*r_earth_rad)));
r_elv_grid    = rad2deg(r_elv_grid);

r_rng_grid    = sin(r_gcdist_grid./(ke.*r_earth_rad)).*(ke.*r_earth_rad+r_alt_grid-r_elv)./cos(r_elv_grid);


keyboard
%[s,~] = distance(r_lat,r_lon,r_lat_grid,r_lon_grid);
%s = deg2km(s);
