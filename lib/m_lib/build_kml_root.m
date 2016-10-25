function build_kml_root(root_path,site_no_selection)
%WHAT
%Performs the following tasks to prepare for the execution of the
%ge_update_heirarchy script

%1: Saves the set global varibles to a mat files in the local working
    %directory
%2: Builds directory structure required for update script
%3: Generated global styles and preset links to tracking and reion data kml
    %files in doc.kml
%4: Builds the permanent overlay data by generating the kml and copying the
    %images to the correct directories
%5: Calculates a mask for each radar which contains no overlap from other
    %radars within the radar list

%INPUT
    %force_del: if =1 forces removal of all existing folders/files in the root.
                   %(default with no input is 0)
    %root: path to root of ge_kml folder, default is 'ge_ttracks/'
    %site_no_selection: list of site_no
    
%OUTPUT:
%kml folder structure at root, overlay images, doc.kml and layer_links
%files

%% initalise


%load colormap
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/kml.config.mat')
load('tmp/site_info.txt.mat')

%empty string vairables for storing kml
overlay_str  = '';
coverage_str = '';
master_str   = '';

%s3 nl from doc.kml need a url prefix
if strcmp(root_path(1:2),'s3')
    url_prefix = s3_public_root;
else
    url_prefix = '';
end
%% Build Styles
master_str = ge_line_style('','coverage_style',html_color(1,[1,1,1]),1);

%% Overlay Images

%Build kml for screen Overlays (logos)
overlay_str = ge_screenoverlay(overlay_str,'ROAMES Logo',[url_prefix,overlays_path,'ROAMES_logo.png'],.03,.04,0,.085,'','');
overlay_str = ge_screenoverlay(overlay_str,'BoM Logo',[url_prefix,overlays_path,'bom_logo.gif'],.32,.04,0,.085,'','');
overlay_str = ge_screenoverlay(overlay_str,'Refl Colorbar',[url_prefix,overlays_path,'refl_colorbar.png'],.96,.1,0,.4,'','');
overlay_str = ge_screenoverlay(overlay_str,'Vel Colorbar',[url_prefix,overlays_path,'vel_colorbar.png'],.92,.1,0,.4,'','');
master_str  = ge_folder(master_str,overlay_str,'Overlays','',1);

%% Coverage kml

%generate coverage kml for each radar site
for i=1:length(site_id_list)
    %generate circle latlon
    [temp_lat,temp_lon] = scircle1(site_lat_list(i),site_lon_list(i),km2deg(coverage_range));
    %determine visibility from radar priority column and site selection
    coverage_vis        = ismember(site_id_list(i),site_no_selection);
    %write each segment to kml string
    temp_coverage_kml   = ge_line_string('',coverage_vis,num2str(site_id_list(i)),'../doc.kml#coverage_style',0,'relativeToGround',0,1,-temp_lat(1:end-1),temp_lon(1:end-1),-temp_lat(2:end),temp_lon(2:end));
    %place segments in a folder
    coverage_str        = ge_folder(coverage_str,temp_coverage_kml,num2str(site_id_list(i)),'',coverage_vis);
end
ge_kml_out([tempdir,'coverage'],'Coverage',coverage_str)

%% build master network links
%Layers kml network link
master_str = ge_networklink(master_str,'Cell Objects',[url_prefix,'cell.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Track Objects',[url_prefix,'track.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Scan Imagery',[url_prefix,'scan.kml'],0,0,'','','','',1);

%% Build master kml

%Build master kml file
ge_kml_out([tempdir,'doc'],'RoamesWX',master_str);
%transfer to root path
file_mv([tempdir,'doc.kml'],[root_path,'doc.kml'])

%transfer overlays and coverage
if ~strcmp(root_path(1:2),'s3') && exist([root_path,'overlays/'],'file')~=7
    mkdir([root_path,'overlays/'])
end
file_mv([tempdir,'coverage.kml'],[root_path,'overlays/coverage.kml'])
file_cp([pwd,'/',overlays_path,'ROAMES_logo.png'],[root_path,'overlays/','ROAMES_logo.png'],0,1)
file_cp([pwd,'/',overlays_path,'bom_logo.gif'],[root_path,'overlays/','bom_logo.gif'],0,1)
file_cp([pwd,'/',overlays_path,'refl_colorbar.png'],[root_path,'overlays/','refl_colorbar.png'],0,1)
file_cp([pwd,'/',overlays_path,'vel_colorbar.png'],[root_path,'overlays/','vel_colorbar.png'],0,1)

%% build scan groups kml

%scan.kml
scan_str = '';
tmp_str   = generate_radar_nl('scan1_refl',scan_obj_path,site_id_list);
scan_str  = ge_folder(scan_str,tmp_str,'Reflectivity Tilt 1','',1);
tmp_str   = generate_radar_nl('scan2_refl',scan_obj_path,site_id_list);
scan_str  = ge_folder(scan_str,tmp_str,'Reflectivity Tilt 2','',1);
tmp_str   = generate_radar_nl('scan1_vel',scan_obj_path,site_id_list);
scan_str  = ge_folder(scan_str,tmp_str,'Doppler Wind Tilt 1','',1);
tmp_str   = generate_radar_nl('scan2_vel',scan_obj_path,site_id_list);
scan_str  = ge_folder(scan_str,tmp_str,'Doppler Wind Tilt 2','',1);

scan_str  = ge_networklink(scan_str,'Coverage','overlays/coverage.kml',0,0,'','','','',1);

ge_kml_out([tempdir,'scan'],'Scan Objects',scan_str);
file_mv([tempdir,'scan.kml'],[root_path,'scan.kml']);

%track.kml
track_str  = '';
tmp_str    = generate_radar_nl('path',track_obj_path,site_id_list);
track_str  = ge_folder(track_str,tmp_str,'Storm Tracks','',1);
tmp_str    = generate_radar_nl('swath',track_obj_path,site_id_list);
track_str  = ge_folder(track_str,tmp_str,'Storm Swaths','',1);
tmp_str    = generate_radar_nl('nowcast',track_obj_path,site_id_list);
track_str  = ge_folder(track_str,tmp_str,'Storm Nowcasts','',1);
tmp_str    = generate_radar_nl('nowcast_stat',track_obj_path,site_id_list);
track_str  = ge_folder(track_str,tmp_str,'Nowcast Stats','',1);

ge_kml_out([tempdir,'track'],'Track Objects',track_str);
file_mv([tempdir,'track.kml'],[root_path,'track.kml']);

%cell.kml
cell_str  = '';
tmp_str   = generate_radar_nl('isoH',cell_obj_path,site_id_list);
cell_str  = ge_folder(cell_str,tmp_str,'Isosurface HighRes','',1);
tmp_str   = generate_radar_nl('isoL',cell_obj_path,site_id_list);
cell_str  = ge_folder(cell_str,tmp_str,'Isosurface LowRes','',1);
tmp_str   = generate_radar_nl('cell_stat',cell_obj_path,site_id_list);
cell_str  = ge_folder(cell_str,tmp_str,'Cell Stats','',1);

ge_kml_out([tempdir,'cell'],'Cell Objects',cell_str);
file_mv([tempdir,'cell.kml'],[root_path,'cell.kml']);

function kml_out = generate_radar_nl(prefix,file_path,radar_id_list)
kml_out       = '';
for i=1:length(radar_id_list)
    radar_id_str = num2str(radar_id_list(i),'%02.0f');
    kml_name     = radar_id_str;
    kml_fn       = [file_path,prefix,'_',radar_id_str,'.kml'];
    kml_out      = ge_networklink(kml_out,kml_name,kml_fn,0,0,'','','','',1);
end 
