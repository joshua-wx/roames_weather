function [swath_kml,swath_placemark_kml] = kml_storm_swath(swath_kml,swath_placemark_kml,track_jstruct,track_id)
%WHAT: Generates a storm swath kml file using the inputted init and finl
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
%nl_out: network link to the storm swath kml file

%load config file
load('tmp/global.config.mat');
load('tmp/vis.config.mat');

for i=1:length(swath_mesh_threshold)
    mesh_threshold = swath_mesh_threshold(i);
    %trace boundaries
    bound_struct = struct;
    for j=1:length(track_jstruct)
        %create mesh mask (merge sub regions)
        mesh_grid = track_jstruct(j).mesh_grid;
        mesh_mask = mesh_grid>=mesh_threshold;
        mesh_mask = bwconvhull(mesh_mask);
        %skip if empty
        if ~any(mesh_mask(:))
            bound_struct(j).lat = [];
            bound_struct(j).lon = [];
            continue
        end
        %setup lat lon vec for mesh
        latlonbox = str2num(track_jstruct(j).storm_latlonbox.S);
        lat_vec   = linspace(latlonbox(1),latlonbox(2),size(mesh_mask,1));
        lon_vec   = linspace(latlonbox(4),latlonbox(3),size(mesh_mask,2));
        %trace boundaries
        bound_idx = bwboundaries(mesh_mask,4); bound_idx = bound_idx{1};
        %grow from centroids of each pixel to boundaries
        bound_lat = [];
        bound_lon = [];
        for k=1:size(bound_idx,1)
            tmp_lat = lat_vec(bound_idx(k,1));
            tmp_lon = lon_vec(bound_idx(k,2));
            bound_lat = [bound_lat;tmp_lat-(h_grid/2);tmp_lat-(h_grid/2);tmp_lat+(h_grid/2);tmp_lat+(h_grid/2)];
            bound_lon = [bound_lon;tmp_lon-(h_grid/2);tmp_lon+(h_grid/2);tmp_lon-(h_grid/2);tmp_lon+(h_grid/2)];
        end
        conv_idx = convhull(bound_lat,bound_lon);
        %add to struct
        bound_struct(j).lat = bound_lat(conv_idx);
        bound_struct(j).lon = bound_lon(conv_idx);
    end
    %convexhull pairs of mesh boundaries
    init_bound  = bound_struct(1:end-1);
    finl_bound  = bound_struct(2:end);
    swath_lat   = [];
    swath_lon   = [];
    for j=1:length(init_bound)
        lat_list = [init_bound(j).lat;finl_bound(j).lat];
        lon_list = [init_bound(j).lon;finl_bound(j).lon];
        if isempty(lat_list)
            continue
        end
        conv_idx = convhull(lon_list,lat_list);
        lon_list = lon_list(conv_idx);
        lat_list = lat_list(conv_idx);
        [lon_list, lat_list]  = poly2cw(lon_list, lat_list);
        [swath_lon,swath_lat] = polybool('union',swath_lon,swath_lat,lon_list,lat_list);
    end
    if ~isempty(swath_lon)
        %convert to counter-clockwise coord order
        [swath_lat_cells,swath_lon_cells] = polysplit(swath_lat,swath_lon);
        for j=1:length(swath_lon_cells)
            tmp_lon = swath_lon_cells{j};
            tmp_lat = swath_lat_cells{j};
            %generate kml, write to file and create networklinks for the tracks data
            place_id            = ['track_id_',num2str(track_id)];
            asset_table         = asset_filter(asset_data_fn,tmp_lat,tmp_lon);
            swath_kml           = ge_swath_poly(swath_kml,['../track.kml#swath_',num2str(i),'_style'],place_id,'','','clampToGround',1,tmp_lon,tmp_lat,repmat(0,length(tmp_lat),1),asset_table);
        end  
    end
end
