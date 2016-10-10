function iso_kml(type,cell_id,sub_volume,subset_lon_vec,subset_lat_vec,z_vec,kml_dir)

%WHAT
    %takes a subset of volume data the ideally contains one cell and
    %generates kml of georeferenced inner isosurfaces at the input dBZ_level
    %IF
    %"sub_volume,start_timedate,subset_lon_vec,subset_lat_vec,z_vec,dBZ_level"
    %are not supplied, it is assumed that are saved in the file [root,track_data_path,'subv-',cell_id]
%INPUT
    %type: (inneriso or outeriso)
    %sub_volume: 3D matrix contained reflectivity values of an identified
          %storm system
    %subset_lon_vec: long vec
    %subset_lat_vec: lat vec
    %z_vec: subset z_vec from
    %threshold: calculated in cloud_objects3 for iosurfaces
    %kml_dir: kml root dir
%OUTPUT
    %no output variables, instead writes high and low resolution kml files
    %using the file_id strings to form the file names

%Load global config
load('tmp/global.config.mat');
load('tmp/kml.config.mat');

%generate isosurface matrices and select style
if strcmp(type,'inneriso')
    %find dbz threshold
    temp_sub_volume = sub_volume;
    temp_sub_volume(temp_sub_volume<ewt_a)=nan;
    threshold = round(prctile(temp_sub_volume(:),inner_iso_percentile));
    %calc isosurface
    [low_faces,low_vertices,high_faces,high_vertices]=dBZ_isosurface(subset_lon_vec,subset_lat_vec,z_vec,sub_volume,threshold,inner_iso_faces);
    cmap_threshold=(threshold-min_dbz)*2+1;
    style_str=['../doc.kml#inneriso_level_',num2str(cmap_threshold),'_style'];
elseif strcmp(type,'outeriso')
    %set dbz threshold
    threshold=ewt_a;
    %calc isosurface
    [low_faces,low_vertices,high_faces,high_vertices]=dBZ_isosurface(subset_lon_vec,subset_lat_vec,z_vec,sub_volume,threshold,outer_iso_faces);
    style_str=['../doc.kml#outeriso_level_style'];
end

%generate kml from isosurface matrices
celliso_H_kml=ge_multi_poly_placemark2('',style_str,'',1,high_faces,high_vertices,'','');
celliso_L_kml=ge_multi_poly_placemark2('',style_str,'',1,low_faces,low_vertices,'','');

%wrap with document header and footer
celliso_H_kml=ge_document(celliso_H_kml,[type,'_H_',cell_id]);
celliso_L_kml=ge_document(celliso_L_kml,[type,'_L_',cell_id]);    

%write to kmz
ge_kmz_out([type,'_H_',cell_id],celliso_H_kml,[kml_dir,storm_data_path],'');
ge_kmz_out([type,'_L_',cell_id],celliso_L_kml,[kml_dir,storm_data_path],'');

function [low_faces,low_vertices,high_faces,high_vertices]=dBZ_isosurface(lon_vec,lat_vec,z_vec,v,dBZ_level,n_faces)
%HELP: create isosurface polygons in anticlockwise ge format for a set dBZ_level

%INPUT: 3D coord meshes (lon,lat,z) dBZ cartesian volume (v), isosurface
    %level (dBZ_level), number of faces in isosurface (n_faces)
%OUTPUT: pccord: 3xn matrix where c1=lat, c2=lon, c3=z and n is the number
    %of vertices, each face is separted by an NaN

%Load config file
load('tmp/global.config.mat')
load('tmp/kml.config.mat');

%calculate face/vertices of isosurface
%note: dbZ_level is in uint8, convert to double for isosurface function
fv=isosurface(v,double(dBZ_level));

%check to see if there too many faces in the high res isosurface
if length(fv.faces)<n_faces
    high_nfv=fv;
else
    %reduce faces
    high_nfv = reducepatch(fv,n_faces/length(fv.faces));
end

%generate low res isourface
low_nfv=reducepatch(high_nfv,low_res_iso_factor);

low_faces=[]; low_vertices=[];
high_faces=[]; high_vertices=[];

%calculate linear function terms of lat and long
lon_m=(lon_vec(2)-lon_vec(1))/(2-1);
lon_c=lon_vec(1)-lon_m;
lat_m=(lat_vec(2)-lat_vec(1))/(2-1);
lat_c=lat_vec(1)-lat_m;
z_m=(z_vec(2)-z_vec(1))/(2-1);
z_c=z_vec(1)-z_m;

%arrange face vertices to be contiunes (append) and reverse order to
%plot as anticlockwise
if length(low_nfv.faces)>smallest_no_faces
    low_vc = low_nfv.vertices;
    low_faces=fliplr([low_nfv.faces,low_nfv.faces(:,1)]);
    low_vertices=[low_vc(:,1).*lon_m+lon_c,low_vc(:,2).*lat_m+lat_c,low_vc(:,3).*z_m+z_c];

    high_vc = high_nfv.vertices;
    high_faces=fliplr([high_nfv.faces,high_nfv.faces(:,1)]);
    high_vertices=[high_vc(:,1).*lon_m+lon_c,high_vc(:,2).*lat_m+lat_c,high_vc(:,3).*z_m+z_c];
end