function climate_generate_kml(data_grid,site_name,site_lat,site_lon,geo_coords)
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
%read climate config
load('tmp/climate.config.mat')
%read mapping config
read_config(map_config_fn);
load(['tmp/',map_config_fn,'.mat'])

%colorbar_ffn=generate_colorbar(opt_struct.proc_opt(4),'Density');

%init colourmap
img_cmap    = flipud(hot(128));
%init kml
kml_str     = '';
kml_str     = ge_swath_poly_style(kml_str,'poly_style',html_color(1,silence_edge_color),silence_line_width,html_color(1,silence_face_color),false);
kml_str     = ge_swath_poly_style(kml_str,'trans_poly',html_color(1/255,silence_edge_color),silence_line_width,html_color(1/255,silence_face_color),true);

%resize image
[img_grid,img_cmap] = imresize(data_grid,img_cmap,img_rescale,'nearest','Colormap','original');
img_grid            = double(img_grid);

%create image grids
img_grid    = img_grid./max(img_grid(:)).*128;

%create transparency grid
if kml_transparent_flag == 1
    alpha_grid = img_grid./max(img_grid(:));
    %shift transparency
    alpha_grid(alpha_grid>0) = alpha_grid(alpha_grid>0)+0.3;
    alpha_grid(alpha_grid>1) = 1;
else
    alpha_grid = ones(size(img_grid));
end

%convert to rgb
img_grid   = ind2rgb(uint8(img_grid),img_cmap);

%write image to file
tmp_image_ffn = [tempdir,'rwx_climate.png'];
imwrite(img_grid,tmp_image_ffn,'Alpha',alpha_grid);

%building latlonbox
kml_N_lat = max(geo_coords.radar_lat_vec);
kml_S_lat = min(geo_coords.radar_lat_vec);
kml_E_lon = max(geo_coords.radar_lon_vec);
kml_W_lon = min(geo_coords.radar_lon_vec);
latlonbox = [kml_N_lat,kml_S_lat,kml_E_lon,kml_W_lon];

%create ground overlay kml
kml_tag   = ['IDR',num2str(radar_id,'%02.0f')];
kml_str = ge_groundoverlay(kml_str,['Radar Climatology for ',site_name,' ',kml_tag],'rwx_climate.png',latlonbox,'','','clamped','',1);

%create silence mask
if draw_silence == 1
    [tmp_lat,tmp_lon] = scircle1(site_lat,site_lon,km2deg(silence_radius));
    kml_str = ge_swath_poly(kml_str,'poly_style','radar_blind_spot','','','clampToGround',1,tmp_lon,tmp_lat,zeros(length(tmp_lat),1),'');
end

%create transparent polygon containing stats
tmp_lat = [kml_N_lat,kml_N_lat,kml_S_lat,kml_S_lat,kml_N_lat];
tmp_lon = [kml_W_lon,kml_E_lon,kml_E_lon,kml_W_lon,kml_W_lon];
html_str = ['<p>',kml_tag,'-',site_name,'</p>',10,...
            '<p>start date',,'</p>',10,...
            
kml_str = ge_swath_poly(kml_str,'trans_poly','balloon_popup_poly','','','clampToGround',1,tmp_lon,tmp_lat,zeros(length(tmp_lat),1),'<p>test</p><img src="rwx_climate.png" />');

%size kmlstr and png into a kmz
kmz_fn    = [kml_tag,'_',site_name,'.kmz'];
ge_kmz_out(kmz_fn,kml_str,out_root,tmp_image_ffn);

keyboard
%write image to kmz
%create ground overlay kml inside kmz
%create placemark containing legend inside kmz

%link with kml
%object_kml = ge_groundoverlay(object_kml,'GE Climatology','geclim_grid.png',latlonbox,datestr(opt_struct.td_opt(1),ge_tfmt),datestr(opt_struct.td_opt(2),ge_tfmt),'clamped',0,1);


