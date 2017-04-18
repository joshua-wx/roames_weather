function climate_generate_kml(data_grid,vec_data,data_grid_R,site_lat,site_lon,map_config_fn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT:    generates image kml for the provided data grid and config settings
% INPUTS:  
% RETURNS: 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%read mapping config
read_config(map_config_fn);
load(['tmp/',map_config_fn,'.mat'])
%read climate config
load('tmp/climate.config.mat')

%colorbar_ffn=generate_colorbar(opt_struct.proc_opt(4),'Density');

%init colourmap
img_cmap    = flipud(hot(128));

%resize image
[img_grid,img_cmap] = imresize(data_grid,img_cmap,img_rescale,'nearest','Colormap','original');
img_grid            = double(img_grid);

%create image grids
img_grid    = img_grid./max(img_grid(:)).*128;

%create transparency grid
if kml_transparent_flag == 1
    alpha_grid = img_grid./max(img_grid(:));
else
    alpha_grid = ones(size(img_grid));
end

%convert to rgb
img_grid   = ind2rgb(uint8(img_grid),img_cmap);

%write image to file
tmp_image_ffn = [tempdir,'climate.png'];
imwrite(img_grid,tmp_image_ffn,'Alpha',alpha_grid);

keyboard
%write image to kmz
%create ground overlay kml inside kmz
%create placemark containing legend inside kmz

%link with kml
%object_kml = ge_groundoverlay(object_kml,'GE Climatology','geclim_grid.png',latlonbox,datestr(opt_struct.td_opt(1),ge_tfmt),datestr(opt_struct.td_opt(2),ge_tfmt),'clamped',0,1);


