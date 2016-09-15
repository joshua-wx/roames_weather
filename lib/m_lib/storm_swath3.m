function swaths_nl=storm_swath3(init_ident,finl_ident,kml_dir,stm_id,region,start_td,stop_td,cur_vis)
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
load('tmp_global_config.mat');
swaths_nl='';

%swath coord
poly_lat=[];
poly_lon=[];

%loop through each pair in the two ident dbs
for i=1:length(init_ident)
    
    %extract init and final edge coord
    try
    init_lat_edge_coord=init_ident(i).subset_lat_edge;
    init_lon_edge_coord=init_ident(i).subset_lon_edge;
    finl_lat_edge_coord=finl_ident(i).subset_lat_edge;
    finl_lon_edge_coord=finl_ident(i).subset_lon_edge;
    catch
        keyboard
    end
    
    %collate
    lat_list=roundn([init_lat_edge_coord,finl_lat_edge_coord],-4);
    lon_list=roundn([init_lon_edge_coord,finl_lon_edge_coord],-4);
    %compute convexhull
    try
        K = convhull(lon_list,lat_list);
        hull_lat=lat_list(K);
        hull_lon=lon_list(K);
    catch
        %points are collinear
        hull_lat=[min(lat_list),max(lat_list)];
        hull_lon=[min(lon_list),max(lon_list)];
    end
    
    %convert to clockwise coord order
    [hull_lon, hull_lat] = poly2cw(hull_lon, hull_lat);
    
    %collate convex hull swaths
    [poly_lon,poly_lat]=polybool('union',poly_lon,poly_lat,hull_lon,hull_lat);
end

%select the colour based on the number of elements in the path
swath_color_id=length(init_ident);
if swath_color_id>30
    swath_color_id=30;
end

close all
%convert to counter-clockwise coord order
[poly_lon, poly_lat] = poly2ccw(poly_lon, poly_lat);

%to prevent an untraced error
ind=find(poly_lat==0 | isnan(poly_lat));
poly_lon(ind)=[]; poly_lat(ind)=[];

%generate kml, write to file and create networklinks for the tracks data
swath_tag=['stm_swath_',stm_id];
swath_kml=ge_poly_placemark('',['../doc.kml#swath_',num2str(swath_color_id),'_style'],swath_tag,'clampToGround',1,poly_lon,poly_lat,repmat(1,length(poly_lat),1));    
ge_kmz_out(swath_tag,swath_kml,[kml_dir,track_data_path],'');
swaths_nl=ge_networklink('',swath_tag,[track_data_path,swath_tag,'.kmz'],0,0,'',region,datestr(start_td,S),datestr(stop_td,S),cur_vis);