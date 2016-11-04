function track_kml = kml_storm_track(track_kml,track_jstruct,track_id)
%WHAT: Generates a storm track kml file using the inputted init and finl
%ident pair.

%INPUT:
%init_ident: column of the ident db entires for the inital cells
%finl_ident: column of the indent db entries for the final cells
%kml_dir: the path to the kml root
%stm_id: the id of the current storm
%region: region latlonbox to use for kml vis
%start_td: start timedate for kml
%stop_td: stop timedate for kml
%cur_vis: visibility for kml

%OUTPUT
%nl_out: network link to the storm path kml file

%load config file
load('tmp/global.config.mat');
load('tmp/kml.config.mat');
%generate the starting and ending coords of the line string segments

init_jstruct = track_jstruct(1:end-1);
finl_jstruct = track_jstruct(2:end);

start_lat_vec = jstruct_to_mat([init_jstruct.storm_dbz_centlat],'N')./geo_scale;
start_lon_vec = jstruct_to_mat([init_jstruct.storm_dbz_centlon],'N')./geo_scale;
end_lat_vec   = jstruct_to_mat([finl_jstruct.storm_dbz_centlat],'N')./geo_scale;
end_lon_vec   = jstruct_to_mat([finl_jstruct.storm_dbz_centlon],'N')./geo_scale;

%select the colour based on the number of elements in the path
path_color_id = length(init_jstruct);
if path_color_id > max_vis_trck_length
    path_color_id = max_vis_trck_length;
end

%generate kml, write to file and create networklinks for the tracks data
name        = ['track_id_',num2str(track_id)];
track_kml   = ge_line_string(track_kml,1,name,['../../track.kml#path_',num2str(path_color_id),'_style'],0,'clampToGround',0,1,start_lat_vec,start_lon_vec,end_lat_vec,end_lon_vec);