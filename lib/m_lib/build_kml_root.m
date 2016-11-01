function build_kml_root(dest_root,site_no_selection,local_dest_flag)
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

%create path as required
if local_dest_flag==1
    rmdir(dest_root,'s');
    mkdir(dest_root);
    mkdir([dest_root,scan_obj_path]);
    mkdir([dest_root,track_obj_path]);
    mkdir([dest_root,cell_obj_path]);
end

%s3 nl from doc.kml need a url prefix
if strcmp(dest_root(1:2),'s3')
    url_prefix = s3_public_root;
else
    url_prefix = '';
end

%% Scan Styles
scan_style_str = '';
scan_style_str = ge_line_style(scan_style_str,'coverage_style',html_color(0.5,[1,1,1]),1);

%% Track Styles

track_style_str = '';
%forecast style with a maximum of n_fcst_steps steps.
forecast_S_colormap = colormap(pink(n_fcst_steps)); %stregthening
forecast_W_colormap = colormap(bone(n_fcst_steps)); %weakening
forecast_N_colormap = colormap(gray(n_fcst_steps)); %no change
for i=1:n_fcst_steps    
track_style_str = ge_poly_style(track_style_str,['fcst_S_step_',num2str(i),'_style'],'DDFFFFFF',1,html_color(.6,forecast_S_colormap(i,:)));
track_style_str = ge_poly_style(track_style_str,['fcst_W_step_',num2str(i),'_style'],'DDFFFFFF',1,html_color(.6,forecast_W_colormap(i,:)));
track_style_str = ge_poly_style(track_style_str,['fcst_N_step_',num2str(i),'_style'],'DDFFFFFF',1,html_color(.6,forecast_N_colormap(i,:)));
end

%balloon style (stats and graph)
track_style_str = ge_balloon_stats_style(track_style_str,'balloon_stats_style');
track_style_str = ge_balloon_graph_style(track_style_str,'balloon_graph_style');

%track path and swath style
path_colormap = flipud(colormap(autumn(max_vis_trck_length)));
close(gcf);
for i=1:max_vis_trck_length
    track_style_str = ge_line_style(track_style_str,['path_',num2str(i),'_style'],html_color(.8,path_colormap(i,:)),5);
    track_style_str = ge_poly_style(track_style_str,['swath_',num2str(i),'_style'],html_color(.8,[0,0,0]),1,html_color(.4,path_colormap(i,:)));
end

%% Overlay Images

%Build kml for screen Overlays (logos)
overlay_str = ge_screenoverlay(overlay_str,'ROAMES Logo',[url_prefix,overlays_path,'ROAMES_logo.png'],.03,.04,0,.085,'','');
overlay_str = ge_screenoverlay(overlay_str,'BoM Logo',[url_prefix,overlays_path,'bom_logo.gif'],.32,.04,0,.085,'','');
overlay_str = ge_screenoverlay(overlay_str,'Refl Colorbar',[url_prefix,overlays_path,'refl_colorbar.png'],.96,.1,0,.4,'','');
overlay_str = ge_screenoverlay(overlay_str,'Vel Colorbar',[url_prefix,overlays_path,'vel_colorbar.png'],.92,.1,0,.4,'','');
master_str  = ge_folder(master_str,overlay_str,'Overlays','',1);

%% Coverage kml

%generate coverage kml for each radar site
site_latlonbox = [];
for i=1:length(site_id_list)
    %generate circle latlon
    [temp_lat,temp_lon] = scircle1(site_lat_list(i),site_lon_list(i),km2deg(coverage_range));
    %append site latlonbox
    site_latlonbox      = [site_latlonbox;[max(temp_lat),min(temp_lat),max(temp_lon),min(temp_lon)]];
    %determine visibility from radar priority column and site selection
    coverage_vis        = ismember(site_id_list(i),site_no_selection);
    %write each segment to kml string
    temp_coverage_kml   = ge_line_string('',coverage_vis,num2str(site_id_list(i)),'../scan.kml#coverage_style',0,'relativeToGround',0,1,temp_lat(1:end-1),temp_lon(1:end-1),temp_lat(2:end),temp_lon(2:end));
    %place segments in a folder
    coverage_str        = ge_folder(coverage_str,temp_coverage_kml,num2str(site_id_list(i)),'',coverage_vis);
end
ge_kml_out([tempdir,'coverage.kml'],'Coverage',coverage_str)

%% build master network links
%Layers kml network link
master_str = ge_networklink(master_str,'Scan Imagery',[url_prefix,'scan.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Track Objects',[url_prefix,'track.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Cell Objects',[url_prefix,'cell.kml'],0,0,'','','','',1);

%% Build master kml

%Build master kml file
temp_ffn = tempname;
ge_kml_out(temp_ffn,'RoamesWX',master_str);
%transfer to root path
file_mv(temp_ffn,[dest_root,'doc.kml'])

%transfer overlays and coverage
if ~strcmp(dest_root(1:2),'s3') && exist([dest_root,'overlays/'],'file')~=7
    mkdir([dest_root,'overlays/'])
end
file_mv([tempdir,'coverage.kml'],[dest_root,'overlays/coverage.kml'])
file_cp([pwd,'/etc/',overlays_path,'ROAMES_logo.png'],[dest_root,overlays_path,'ROAMES_logo.png'],0,1)
file_cp([pwd,'/etc/',overlays_path,'bom_logo.gif'],[dest_root,overlays_path,'bom_logo.gif'],0,1)
file_cp([pwd,'/etc/',overlays_path,'refl_colorbar.png'],[dest_root,overlays_path,'refl_colorbar.png'],0,1)
file_cp([pwd,'/etc/',overlays_path,'vel_colorbar.png'],[dest_root,overlays_path,'vel_colorbar.png'],0,1)

%% build scan groups kml

%scan.kml
scan_str  = scan_style_str;
tmp_str   = generate_radar_nl('scan1_refl',dest_root,scan_obj_path,site_id_list,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
scan_str  = ge_folder(scan_str,tmp_str,'Reflectivity Tilt 1','',1);
tmp_str   = generate_radar_nl('scan2_refl',dest_root,scan_obj_path,site_id_list,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
scan_str  = ge_folder(scan_str,tmp_str,'Reflectivity Tilt 2','',1);
tmp_str   = generate_radar_nl('scan1_vel',dest_root,scan_obj_path,site_id_list,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
scan_str  = ge_folder(scan_str,tmp_str,'Doppler Wind Tilt 1','',1);
tmp_str   = generate_radar_nl('scan2_vel',dest_root,scan_obj_path,site_id_list,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
scan_str  = ge_folder(scan_str,tmp_str,'Doppler Wind Tilt 2','',1);

scan_str  = ge_networklink(scan_str,'Coverage','overlays/coverage.kml',0,0,'','','','',1);

temp_ffn = tempname;
ge_kml_out(temp_ffn,'Scan Objects',scan_str);
file_mv(temp_ffn,[dest_root,'scan.kml']);

%track.kml
track_str  = track_style_str;
tmp_str    = generate_radar_nl('track',dest_root,track_obj_path,site_id_list,site_latlonbox,track_minLodPixels,track_maxLodPixels,local_dest_flag);
track_str  = ge_folder(track_str,tmp_str,'Storm Tracks','',1);
tmp_str    = generate_radar_nl('swath',dest_root,track_obj_path,site_id_list,site_latlonbox,track_minLodPixels,track_maxLodPixels,local_dest_flag);
track_str  = ge_folder(track_str,tmp_str,'Storm Swaths','',1);
tmp_str    = generate_radar_nl('nowcast',dest_root,track_obj_path,site_id_list,site_latlonbox,track_minLodPixels,track_maxLodPixels,local_dest_flag);
track_str  = ge_folder(track_str,tmp_str,'Storm Nowcasts','',1);
tmp_str    = generate_radar_nl('nowcast_stat',dest_root,track_obj_path,site_id_list,site_latlonbox,track_minLodPixels,track_maxLodPixels,local_dest_flag);
track_str  = ge_folder(track_str,tmp_str,'Nowcast Stats','',1);
tmp_str    = generate_radar_nl('cell_stat',dest_root,track_obj_path,site_id_list,site_latlonbox,track_minLodPixels,track_maxLodPixels,local_dest_flag);
track_str  = ge_folder(track_str,tmp_str,'Cell Stats','',1);

temp_ffn = tempname;
ge_kml_out(temp_ffn,'Track Objects',track_str);
file_mv(temp_ffn,[dest_root,'track.kml']);

%cell.kml
cell_str  = '';
tmp_str   = generate_radar_nl('inneriso_H',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Inner Isosurface HighRes','',1);
tmp_str   = generate_radar_nl('inneriso_L',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Inner Isosurface LowRes','',1);
tmp_str   = generate_radar_nl('outeriso_H',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Outer Isosurface HighRes','',1);
tmp_str   = generate_radar_nl('outeriso_L',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Outer Isosurface LowRes','',1);
tmp_str   = generate_radar_nl('xsec_refl',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Cross Section Reflectivity','',1);
tmp_str   = generate_radar_nl('xsec_dopl',dest_root,cell_obj_path,site_id_list,'','','',local_dest_flag);
cell_str  = ge_folder(cell_str,tmp_str,'Cross Section Doppler','',1);

temp_ffn = tempname;
ge_kml_out(temp_ffn,'Cell Objects',cell_str);
file_mv(temp_ffn,[dest_root,'cell.kml']);

function kml_out = generate_radar_nl(prefix,dest_root,file_path,radar_id_list,site_latlonbox,minlod,maxlod,local_dest_flag)
%WHAT: creates network links and empty kml points which the nl point to for
%each radar for the specified prefix
kml_out       = '';
%loop through radar ids
for i=1:length(radar_id_list)
    %generate ge region kml
    if ~isempty(site_latlonbox)
        region_kml  = ge_region(site_latlonbox(i,:),0,20000,minlod,maxlod);
    else
        region_kml = '';
    end
    %init paths
    radar_id_str = num2str(radar_id_list(i),'%02.0f');
    kml_path      = [file_path,radar_id_str,'/'];
    kml_full_path = [dest_root,kml_path];
    if local_dest_flag == 1 && exist(kml_full_path,'file')~=7
        mkdir(kml_full_path)
    end 
    %init nl
    kml_name     = radar_id_str;
    kml_fn       = [kml_path,prefix,'_',radar_id_str,'.kml'];
    kml_out      = ge_networklink(kml_out,kml_name,kml_fn,0,0,'',region_kml,'','',1);
    %init empty kml file
    ge_kml_out([dest_root,kml_fn],'','');
end 
