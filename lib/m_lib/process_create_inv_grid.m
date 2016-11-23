function [aazi_grid,sl_rrange_grid,eelv_grid] = process_create_inv_grid(wv_global_config_fn)

%WHAT
% Builds the regridding cartesian coords from global_config and then
% transforms them into radar coord

%INPUT (FROM global_config)
%h_range: horizontal regridding range
%h_grid: horitonzontal grid size
%v_range: vertical regridding range
%v_grid: vertical grid size

%OUTPUT
%aazi_grid: regridding azimuth coord (deg)
%sl_rrange_grid: regridding slant range coord (m)
%eelv_grid: regridding beam elevation coord (deg)

%load global config
load(wv_global_config_fn);

%cartesian grid setup
x_vec=-h_range:h_grid:h_range;                              %m, X domain vector
y_vec=-h_range:h_grid:h_range;                              %m, Y domain vector
z_vec=[v_grid:v_grid:v_range]';                             %m, Z domain vector, adjusted for radar height
[x_array,y_array,z_array] = meshgrid(x_vec,y_vec,z_vec);    %meshgrid coordinate vectors to 3D arrays

%invert from cartesian to native radar coordinates
Re=8.496*10^6;          %km-1 sph to pol formula constant
%convert to cylindical coordinates, no transform for z=h
[aazi_grid,s,z] = cart2pol(x_array,y_array,z_array);
%calculate elevation angle from h and s
eelv_grid=-(log   (     (-Re - z + Re.*exp((s.*1i)./Re))./...
    (-Re.*exp((s.*1i)./Re) + Re.*exp((2.*s.*1i)./Re) + z.*exp((2.*s.*1i)./Re))  )  .*1i)...
    ./2;
%convert to real
eelv_grid=real(eelv_grid);
%calculate ray length from h,s and ee
sl_rrange_grid=(sin(s./Re).*(Re+z))./cos(eelv_grid);
%convert to deg
aazi_grid=rad2deg(aazi_grid+pi);
eelv_grid=rad2deg(eelv_grid);
