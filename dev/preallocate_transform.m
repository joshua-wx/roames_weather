function [radar_azi_grid,radar_elv_grid,radar_rng_grid] = preallocate_transform(radar_lat,radar_lon,radar_alt,radar_lat_vec,radar_lon_vec,alt_vec,earth_rad,ke)
%WHAT: Converts a lat/lon/alt grid

%add radar alt to earth radius
radar_earth_rad = earth_rad + radar_alt;

%create radar grid
[radar_lon_grid,radar_lat_grid,radar_alt_grid] = meshgrid(radar_lon_vec,radar_lat_vec,alt_vec);

%earth distance grid
radar_gcdist_grid = earth_rad.*acos(sind(radar_lat).*sind(radar_lat_grid)+...
    cosd(radar_lat).*cosd(radar_lat_grid).*cosd(abs(radar_lon_grid-radar_lon)));

%radar azimuth grid
radar_azi_grid    = real(asin(sin((pi/2)-deg2rad(radar_lat_grid)).*sin(deg2rad(radar_lon_grid-radar_lon))./sin(radar_gcdist_grid./earth_rad)));
%wrap from -pi/2->pi/2 to 0->360deg
radar_azi_grid    = rad2deg(radar_azi_grid);
radar_lat_sign    = sign(radar_lat_grid-radar_lat);
radar_lon_sign    = sign(radar_lon_grid-radar_lon);
radar_azi_grid(radar_lat_sign==-1 & radar_lon_sign== 1)  = 180-radar_azi_grid(radar_lat_sign==-1     & radar_lon_sign== 1);
radar_azi_grid(radar_lat_sign==-1 & radar_lon_sign==-1)  = 180+abs(radar_azi_grid(radar_lat_sign==-1 & radar_lon_sign==-1));
radar_azi_grid(radar_lat_sign== 1 & radar_lon_sign==-1)  = 360+(radar_azi_grid(radar_lat_sign==1     & radar_lon_sign==-1));

%elevation grid
radar_elv_grid    = atan((cos(radar_gcdist_grid./(ke.*radar_earth_rad))-((ke*radar_earth_rad)./(ke*radar_earth_rad+radar_alt_grid-radar_alt)))./...
    sin(radar_gcdist_grid./(ke.*radar_earth_rad)));
radar_elv_grid    = rad2deg(radar_elv_grid);

%range grid
radar_rng_grid    = sin(radar_gcdist_grid./(ke.*radar_earth_rad)).*(ke.*radar_earth_rad+radar_alt_grid-radar_alt)./cosd(radar_elv_grid);