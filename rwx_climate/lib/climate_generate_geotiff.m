function climate_generate_geotiff(radar_id,raster,R)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT:    generates image geotiff for the provided data grid and config settings
% INPUTS:  
% RETURNS: 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%read climate config
load('tmp/climate.config.mat')
load('tmp/global.config.mat')

image_ffn   = [num2str(radar_id,'%02.0f'),'_',data_type,'.tif'];
geotiff_ffn = [out_root,num2str(radar_id,'%02.0f'),'/',image_ffn];

geotiffwrite(geotiff_ffn,raster,R)