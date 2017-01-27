function swath_kml=kml_storm_swath(swath_kml,track_jstruct,track_id)
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
load('tmp/kml.config.mat');

%swath coord
poly_lat = [];
poly_lon = [];

%init
init_jstruct = track_jstruct(1:end-1);
finl_jstruct = track_jstruct(2:end);

%loop through each pair in the two ident dbs
for i=1:length(init_jstruct)
    
    %extract init and final edge coord
    init_lat_edge_coord = str2num(init_jstruct(i).storm_edge_lat.S);
    init_lon_edge_coord = str2num(init_jstruct(i).storm_edge_lon.S);
    finl_lat_edge_coord = str2num(finl_jstruct(i).storm_edge_lat.S);
    finl_lon_edge_coord = str2num(finl_jstruct(i).storm_edge_lon.S);
    
    %collate
    lat_list = roundn([init_lat_edge_coord,finl_lat_edge_coord],-4);
    lon_list  =roundn([init_lon_edge_coord,finl_lon_edge_coord],-4);
    %compute convexhull
    try
        K        = convhull(lon_list,lat_list);
        hull_lat = lat_list(K);
        hull_lon = lon_list(K);
    catch
        %points are collinear
        hull_lat = [min(lat_list),max(lat_list)];
        hull_lon = [min(lon_list),max(lon_list)];
    end
    
    %convert to clockwise coord order
    [hull_lon, hull_lat] = poly2cw(hull_lon, hull_lat);
    
    %collate convex hull swaths
    [poly_lon,poly_lat]  = polybool('union',poly_lon,poly_lat,hull_lon,hull_lat);
end

%select the colour based on the number of elements in the path
swath_color_id = length(init_jstruct);
if swath_color_id > 30
    swath_color_id = 30;
end

close all
%convert to counter-clockwise coord order
[poly_lon, poly_lat] = poly2ccw(poly_lon, poly_lat);

%to prevent an untraced error
ind = find(poly_lat==0 | isnan(poly_lat));
poly_lon(ind) = []; poly_lat(ind)=[];

%generate kml, write to file and create networklinks for the tracks data
name      = ['track_id_',num2str(track_id)];
swath_kml = ge_poly_placemark(swath_kml,['../track.kml#swath_',num2str(swath_color_id),'_style'],name,'','','clampToGround',1,poly_lon,poly_lat,repmat(1,length(poly_lat),1));    