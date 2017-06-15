function [link,ffn] = kml_singledop_ppi(dest_path,png_ffn,data_tag,geo_coords,h_grid_deg)

load('tmp/interp_cmaps.mat')
load('tmp/vis.config.mat')
load('tmp/global.config.mat')

%build img_latlonbox
[img_lat_N,~] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),0);
[img_lat_S,~] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),180);
[~,img_lon_E] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),90);
[~,img_lon_W] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),270);
img_latlonbox = [img_lat_N+h_grid_deg/2;img_lat_S-h_grid_deg/2;img_lon_E+h_grid_deg/2;img_lon_W-h_grid_deg/2];

%wrap in kmz and generate link
%generate groundoverlay_kml
ppi_img_kml  = ge_groundoverlay('',data_tag,[data_tag,'.png'],img_latlonbox,'','','clamped','',1,1);
%size kmlstr and png into a kmz
kmz_fn  = [data_tag,'.kmz'];
ge_kmz_out(kmz_fn,ppi_img_kml,dest_path,png_ffn); %TO FIX
%create link
link = kmz_fn;
ffn  = [dest_path,kmz_fn];

    
