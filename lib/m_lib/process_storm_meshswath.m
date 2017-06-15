function [swath_kml,swath_placemark_kml] = process_storm_meshswath(swath_kml,swath_placemark_kml,track_jstruct,track_id)
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
            swath_kml           = ge_swath_poly(swath_kml,['../track.kml#swath_',num2str(i),'_style'],place_id,'','','clampToGround',1,tmp_lon,tmp_lat,zeros(length(tmp_lat),1),asset_table);
        end  
    end
