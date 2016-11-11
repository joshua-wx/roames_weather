function ge_radar_offine(path,name,radar_id)

%load site info
load('tmp/site_info.txt.mat')

%load radar latlon
radar_idx = find(radar_id == site_id_list);
radar_lat = site_lat_list(radar_idx);
radar_lon = site_lon_list(radar_idx);
%create latlonbox
offset    = km2deg(100);
latlonbox = [radar_lat+offset,radar_lat-offset,radar_lon+offset,radar_lon-offset];
%create ground overlay
kml_str   = ge_groundoverlay('','Radar Offline','../../radar_offline.png',latlonbox,'','','clamped','',1);
%kmz layer
