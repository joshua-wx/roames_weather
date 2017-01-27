function [link,ffn] = kml_storm_collada(dest_root,dest_path,cell_tag,type,refl_vol,storm_latlonbox)

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
load('tmp/interp_cmaps.mat')

%generate isosurface matrices and select style
if strcmp(type,'inneriso')
    %set max faces
    n_faces        = inner_iso_faces;
    %find dbz threshold
    temp_refl_vol = refl_vol;
    temp_refl_vol(temp_refl_vol<ewt_a) = nan;
    %set threshold
    threshold     = round(prctile(temp_refl_vol(:),inner_iso_percentile));
    %set colourmap
    cmap_threshold = (threshold-min_dbzh)*2+1;
    cmap           = [interp_refl_cmap(cmap_threshold,:),inner_alpha]; %add alpha
elseif strcmp(type,'outeriso')
    %set max faces
    n_faces        = outer_iso_faces;
    %set threshold
    threshold      = ewt_a;
    %set colourmap
    cmap_threshold = (ewt_a-min_dbzh)*2+1;
    cmap           = [interp_refl_cmap(cmap_threshold,:),outer_alpha]; %add alpha
end

%generate triangles
[triangles,clat,clon] = dBZ_isosurface(refl_vol,threshold,n_faces,storm_latlonbox);
if isempty(triangles)
    link = [];
    ffn  = [];
    return
end
%% collada high_res

%create empty feature ids
feature_ids    = ones(size(triangles,1),1);
%pad triangles for processing...
triangles      = [feature_ids,triangles,feature_ids];
%calc normals
high_normals   = assign_normals_to_vertices(triangles,feature_ids,true);
%init vars
textures       = cell(size(triangles,1),1);
texcoords      = repmat([0 0 0 1 1 1],size(triangles,1),1);
colors         = [repmat(cmap,size(triangles,1),4)];
%write collada
iso_tag        = [cell_tag,'_',type];
collada_fn     = [iso_tag,'.dae'];
kmz_fn         = [iso_tag,'.kmz'];
temp_ffn       = [tempdir,collada_fn];
index_and_write(temp_ffn,triangles(:,2:10),textures,texcoords,colors,high_normals)
%wrap and centre in kml
kml_str        = ge_model('',1,collada_fn,iso_tag,clat,clon,'','');
%export kml and dae to kmz and move to root
ge_kmz_out(kmz_fn,kml_str,[dest_root,dest_path],temp_ffn);

%init link
link = kmz_fn;
ffn  = [dest_root,dest_path,kmz_fn];

function [triangles,clat,clon] = dBZ_isosurface(v,dBZ_level,n_faces,storm_latlonbox)
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
fv            = isosurface(v,double(dBZ_level));

%find centroid
clat          = storm_latlonbox(2);
clon          = storm_latlonbox(4);

%check to see if there too many faces in the isosurface
if length(fv.faces)>n_faces
    %reduce faces
    fv = reducepatch(fv,n_faces/length(fv.faces));
end

faces     = [];
vertices  = [];
triangles = [];
%arrange face vertices to be contiunes (append) and reverse order to
%plot as anticlockwise
if length(fv.faces)>smallest_no_faces
    faces    = fliplr([fv.faces,fv.faces(:,1)]);
    vertices = fv.vertices;
    %rescale vertices
    vertices  = [vertices(:,1).*h_grid,vertices(:,2).*h_grid,vertices(:,3).*v_grid];
    %expand into full triangles
    triangles = [vertices(faces(:,1),:),vertices(faces(:,2),:),vertices(faces(:,3),:)];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Scripts provided by Ross Batern
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function normals = normals_of_triangles(triangles)
%NORMALS_OF_TRIANGLES
%This function takes in a list of triangle coordinate points and returns
%the associated normal vectors

normals = zeros(size(triangles,1),3);

for i=1:size(normals,1)
    edge_1 = [triangles(i,4)-triangles(i,1),triangles(i,5)-triangles(i,2),triangles(i,6)-triangles(i,3)];
    edge_2 = [triangles(i,7)-triangles(i,4),triangles(i,8)-triangles(i,5),triangles(i,9)-triangles(i,6)];
%     normals(i,:) = cross(edge_1,edge_2);
    normals(i,:) = [edge_1(2)*edge_2(3)-edge_1(3)*edge_2(2),...
        edge_1(3)*edge_2(1)-edge_1(1)*edge_2(3),...
        edge_1(1)*edge_2(2)-edge_1(2)*edge_2(1)];
end

normals = normals./repmat(sqrt(normals(:,1).^2+normals(:,2).^2+normals(:,3).^2),1,3);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function output_normals = assign_normals_to_vertices(triangles,feature_ids,smooth_edges)
%This function takes in a list of triangles, associated feature ids and the
%flag to smooth edges and returns an array with aligned vertex-based
%normals be they smoothed or unsmoothed.

normals = normals_of_triangles(triangles(:,2:10)); %First find normals for each whole triangle

if smooth_edges
    
    vertex_angles = acos([sum((triangles(:,5:7)-triangles(:,2:4)).*...
        (triangles(:,8:10)-triangles(:,2:4)),2)./...
        sqrt(sum((triangles(:,5:7)-triangles(:,2:4)).^2,2))./...
        sqrt(sum((triangles(:,8:10)-triangles(:,2:4)).^2,2)),...
        sum((triangles(:,2:4)-triangles(:,5:7)).*...
        (triangles(:,8:10)-triangles(:,5:7)),2)./...
        sqrt(sum((triangles(:,2:4)-triangles(:,5:7)).^2,2))./...
        sqrt(sum((triangles(:,8:10)-triangles(:,5:7)).^2,2)),...
        sum((triangles(:,5:7)-triangles(:,8:10)).*...
        (triangles(:,2:4)-triangles(:,8:10)),2)./...
        sqrt(sum((triangles(:,2:4)-triangles(:,8:10)).^2,2))./...
        sqrt(sum((triangles(:,2:4)-triangles(:,8:10)).^2,2))]);
    
    [~,~,id_indexes] = unique([triangles(:,1),feature_ids],'rows');
    cnt_indexes = max(id_indexes);
    norm_list = zeros(size(triangles,1)*3,3);
    
    for i=1:cnt_indexes
        tris = triangles(id_indexes==i,2:10);
        norms = repmat(normals(id_indexes==i,:),1,3);
        verts = [tris(:,1:3);tris(:,4:6);tris(:,7:9)];
        vert_angs = [vertex_angles(id_indexes==i,1);vertex_angles(id_indexes==i,2);vertex_angles(id_indexes==i,3)];
        vert_norms = [norms(:,1:3);norms(:,4:6);norms(:,7:9)];
        [~,~,vert_ids] = unique(verts,'rows');
        for j=1:max(vert_ids)
            vert_norms(vert_ids==j,1:3) = repmat(sum(vert_norms(vert_ids==j,:).*repmat(vert_angs(vert_ids==j),1,3),1)./sum(vert_angs(vert_ids==j)),sum(vert_ids==j),1);
        end
        norm_list(repmat(id_indexes,3,1)==i,:) = vert_norms;
    end
    output_normals = [norm_list(1:end/3,:),norm_list(end/3+1:2*end/3,:),...
        norm_list(2*end/3+1:end,:)];

else    %If edges aren't to be smoothed, simply assign normals to all three vertices for every triangle
    output_normals = repmat(normals,1,3);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function index_and_write(filename,triangles,textures,texcoords,colors,normals)

% triangles(:,[2,5,8]) = triangles(:,[2,5,8])*1.005;

[unique_textures,~,tex_indexes] = unique(textures(~cellfun(@isempty,textures)));
if length(tex_indexes)<length(textures)
    old_tex_indexes = tex_indexes;
    tex_indexes = zeros(length(textures),1);
    tex_indexes(~cellfun(@isempty,textures)) = old_tex_indexes;
    colors                        = colors(tex_indexes==0,:);
    [unique_colors,~,col_indexes] = unique(colors,'rows');
    col_indexes     = col_indexes + length(unique_textures);
    unique_textures = [unique_textures;cell(size(unique_colors,1),1)];
    for i=1:size(unique_colors,1)
        unique_textures(size(unique_textures,1)-size(unique_colors,1)+i) = {unique_colors(i,:)};
    end
    tex_indexes(tex_indexes==0) = col_indexes;
end
%Need to trim out texcoords that are given for triangles with textures
[unique_texcoords,~,tc_indexes] = unique([texcoords(:,1:2);texcoords(:,3:4);texcoords(:,5:6)],'rows');
[unique_normals,~,nor_indexes]  = unique([normals(:,1:3);normals(:,4:6);normals(:,7:9)],'rows');
[vertices,~,ver_indexes]        = unique([triangles(:,1:3);triangles(:,4:6);triangles(:,7:9)],'rows');

indexed_tris = [ver_indexes(1:end/3)-1,nor_indexes(1:end/3)-1,tc_indexes(1:end/3)-1,...
    ver_indexes(end/3+1:2*end/3)-1,nor_indexes(end/3+1:2*end/3)-1,tc_indexes(end/3+1:2*end/3)-1,...
    ver_indexes(2*end/3+1:end)-1,nor_indexes(2*end/3+1:end)-1,tc_indexes(2*end/3+1:end)-1,...
    tex_indexes];

write_file(filename,indexed_tris,vertices,unique_normals,unique_texcoords,unique_textures)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function write_file(filename,triangles,vertices,normals,texcoords,textures)

%This function takes in an indexed triangle matrix and associated 
%components and writes a collada mesh file to the given filename
%
% format: triangles = [{ vertex normal texcoord } x 3 tex_index]
%                                        |
%                                        | x n
%                                        V 
%

fid = fopen(filename,'w');
current_time = clock;

fprintf(fid,['<?xml version="1.0" encoding="UTF-8" standalone="no" ?>\n',...
    '<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">\n',...
    '    <asset>\n',...
    '        <contributor>\n',...
    '            <author>',getenv('USERNAME'),'</author>\n',...
    '            <authoring_tool>Matlab v',version,'</authoring_tool>\n',...
    '            <copyright>Roames Asset Services, %u</copyright>\n'...
    '        </contributor>\n',...
    '        <created>',datestr(current_time,29),'T',datestr(current_time,13),'Z</created>\n',...
    '        <modified>',datestr(current_time,29),'T',datestr(current_time,13),'Z</modified>\n',...
    '        <up_axis>Z_UP</up_axis>\n',...
    '    </asset>\n'],current_time(1));

%--------------------------------------------------------------------------
fprintf(fid,'    <library_effects>\n');
for i=1:size(textures,1)
    fprintf(fid,['        <effect id="effect_%u">\n',...
        '            <profile_COMMON>\n'],i);
    if ischar(textures{i})
        fprintf(fid,['                <newparam sid="tex_surface_%u">\n',...
            '                    <surface type="2D">\n',...
            '                        <init_from>tex_image_%u</init_from>\n',...
            '                    </surface>\n',...
            '                </newparam>\n',...
            '                <newparam sid="tex_sample_%u">\n',...
            '                    <sampler2D>\n',...
            '                        <source>tex_surface_%u</source>\n',...
            '                    </sampler2D>\n',...
            '                </newparam>\n',...
            '                <technique sid="COMMON">\n',...
            '                    <lambert>\n',...
            '                        <diffuse>\n',...
            '                            <texture texture="tex_sample_%u" texcoord="UVSET0" />\n',...
            '                        </diffuse>\n',...
            '                    </lambert>\n',...
            '                </technique>\n'],i,i,i,i,i);

    else
        fprintf(fid,['                <technique sid="COMMON">\n',...
'                    <phong>\n',...
'                        <diffuse>\n',...
'                            <color>%f %f %f %f</color>\n',...
'                        </diffuse>\n',...
'                        <transparency><float>%f</float></transparency>\n',...
'                    </phong>\n',...
'                </technique>\n'],textures{i}(1:4),textures{i}(4));
    end
    fprintf(fid,['            </profile_COMMON>\n',...
        '        </effect>\n']);
end
fprintf(fid,'    </library_effects>\n');
%--------------------------------------------------------------------------
if sum(cellfun(@isstr,textures))~=0
fprintf(fid,'    <library_images>\n');
for i=1:size(textures,1)
    if ischar(textures{i})
        fprintf(fid,['        <image id="tex_image_%u">\n',...
'            <init_from>',textures{i},'</init_from>\n',...
'        </image>\n'],i);
    end
end
fprintf(fid,'    </library_images>\n');
end
%--------------------------------------------------------------------------
fprintf(fid,'    <library_materials>\n');
for i=1:size(textures,1)
    fprintf(fid,['        <material id="material_%u">\n',...
        '            <instance_effect url="#effect_%u"/>\n',...
        '        </material>\n'],i,i);
end
fprintf(fid,'    </library_materials>\n');
%--------------------------------------------------------------------------
%Vertices
fprintf(fid,['    <library_geometries>\n',...
    '        <geometry id="default_geometry">\n']);
fprintf(fid,'            <mesh>\n');
fprintf(fid,['                <source id="vertex_list">\n',...
    '                    <float_array id="vertex_array" count="%u">\n'],size(vertices,1)*3);
fprintf(fid,'                    %f %f %f\n',vertices');
fprintf(fid,['                    </float_array>\n',...
    '                    <technique_common>\n',...
    '                        <accessor source="#vertex_array" count="%u" stride="3">\n',...
    '                            <param name="X" type="float" />\n',...
    '                            <param name="Y" type="float" />\n',...
    '                            <param name="Z" type="float" />\n',...
    '                        </accessor>\n',...
    '                    </technique_common>\n',...
    '                </source>\n'],size(vertices,1));
%Normals
fprintf(fid,['                <source id="normal_list">\n',...
    '                    <float_array id="normal_array" count="%u">\n'],size(normals,1)*3);
fprintf(fid,'                        %f %f %f\n',normals');
fprintf(fid,['                    </float_array>\n',...
    '                    <technique_common>\n',...
    '                        <accessor source="#normal_array" count="%u" stride="3">\n',...
    '                            <param name="X" type="float"/>\n',...
    '                            <param name="Y" type="float"/>\n',...
    '                            <param name="Z" type="float"/>\n',...
    '                        </accessor>\n',...
    '                    </technique_common>\n',...
    '                </source>\n'],size(normals,1));
if ~isempty(texcoords)
    fprintf(fid,['				<source id="texcoords">\n',...
        '                    <float_array id="tex_coord_array" count="%u">\n'],size(texcoords,1)*2);
    fprintf(fid,'                    %f %f\n',texcoords');
    fprintf(fid,['                    </float_array>\n',...
        '                    <technique_common>\n',...
        '                        <accessor count="%u" source="#tex_coord_array" stride="2">\n',...
        '                            <param name="T" type="float" />\n',...
        '                            <param name="S" type="float" />\n',...
        '                        </accessor>\n',...
        '                    </technique_common>\n',...
        '                </source>\n'],size(texcoords,1));
end
%Vertices
fprintf(fid,['                <vertices id="vertices">\n',...
    '                    <input semantic="POSITION" source="#vertex_list"/>\n',...
    '                </vertices>\n']);
%Triangles
for i=1:size(textures,1)
    if ischar(textures{i})
        fprintf(fid,['                <triangles count="%u" material="MATERIAL_%u">\n',...
            '                    <input semantic="VERTEX" source="#vertices"    offset="0"/>\n',...
            '                    <input semantic="NORMAL" source="#normal_list" offset="1"/>\n',...
            '                    <input semantic="TEXCOORD" source="#texcoords" offset="2"/>\n',...
            '                    <p>\n'],sum(triangles(:,10)==i),i);
        fprintf(fid,'                        %u %u %u %u %u %u %u %u %u\n',triangles(triangles(:,10)==i,1:9)');
        fprintf(fid,['                    </p>\n',...
            '                </triangles>\n']);
    else
        fprintf(fid,['                <triangles count="%u" material="MATERIAL_%u">\n',...
            '                    <input semantic="VERTEX" source="#vertices"    offset="0"/>\n',...
            '                    <input semantic="NORMAL" source="#normal_list" offset="1"/>\n',...
            '                    <p>\n'],sum(triangles(:,10)==i),i);
        fprintf(fid,'                        %u %u %u %u %u %u\n',triangles(triangles(:,10)==i,[1,2,4,5,7,8])');
        fprintf(fid,['                    </p>\n',...
            '                </triangles>\n']);
    end
end
fprintf(fid,'            </mesh>\n');
fprintf(fid,['        </geometry>\n',...
    '    </library_geometries>\n']);
%--------------------------------------------------------------------------
fprintf(fid,['    <library_visual_scenes>\n',...
    '        <visual_scene id="default_scene">\n',...
    '        <node id="default_node">\n',...
    '            <instance_geometry url="#default_geometry">\n',...
    '                <bind_material>\n',...
    '                    <technique_common>\n']);
for i=1:size(textures,1)
    fprintf(fid,'                        <instance_material symbol="MATERIAL_%u" target="#material_%u"/>\n',i,i);
end
fprintf(fid,['                    </technique_common>\n',...
    '                </bind_material>\n',...
    '            </instance_geometry>\n',...
    '        </node>\n',...
    '        </visual_scene>\n',...
    '    </library_visual_scenes>\n']);
%--------------------------------------------------------------------------
fprintf(fid,['    <scene>\n'...
    '        <instance_visual_scene url="#default_scene"/>\n'...
    '    </scene>\n',...
    '</COLLADA>']);

fclose(fid);