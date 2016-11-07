function build_kml_hierarchy(force_del,root,site_no_selection)
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

%empty string vairables for storing kml
master_kml_str='';
styles_kml_str='';
others_kml_str='';

%% create hierarchy paths and make directories

%Question dialogue if force_del is false or root is not a dir
if isdir(root) && force_del==false
    choice = questdlg('Delete and Rebuild hierarchy?', ...
     'Rebuild Warning', ...
     'Delete','Keep','Keep');
else
    %folder doesn't exist or forced
    choice='Delete';
end

%delete and mkdir kml structure
if strcmp(choice,'Delete')
    %delete hierarchy folder if it exists
    if isdir(root)
        rmdir(root,'s');
    end
    %create hierarchy folders
    mkdir(root);
    mkdir([root,overlays_path]);
    mkdir([root,vol_data_path]);
    mkdir([root,storm_data_path]);
end

%% Load coverage and radar info
load('tmp/site_info.txt.mat')

%generate coverage kml for each radar site
coverage_kml='';
for i=1:length(site_id_list)
    %generate circle latlon
    [temp_lat,temp_lon] = scircle1(site_lat_list(i),site_lon_list(i),km2deg(coverage_range));
    %determine visibility from radar priority column and site selection
    coverage_vis=ismember(site_id_list(i),site_no_selection);
    %write each segment to kml string
    temp_coverage_kml=ge_line_string('',coverage_vis,site_s_name_list{i},'../doc.kml#coverage_style',0,'relativeToGround',0,1,-temp_lat(1:end-1),temp_lon(1:end-1),-temp_lat(2:end),temp_lon(2:end));
    %place segments in a folder
    coverage_kml=ge_folder(coverage_kml,temp_coverage_kml,site_s_name_list{i},'',coverage_vis);
end
%write coverage to kml
ge_kml_out([root,overlays_path,'coverage'],'Coverage',coverage_kml)

%% Build Styles
%NOTE:matlab copy path is different from kml relative path
%iso style
min_iso = (ewt_a-min_dbz)*2+1;
max_iso = (max_dbz-min_dbz)*2;
for i=min_iso:max_iso
    styles_kml_str = ge_poly_style(styles_kml_str,['inneriso_level_',num2str(i),'_style'],html_color(0,interp_refl_cmap(i,:)),1,html_color(1,interp_refl_cmap(i,:)));
end

outeriso_index = (ewt_a-min_dbz)*2+1; %24bit location of index
styles_kml_str = ge_poly_style(styles_kml_str,['outeriso_level_style'],html_color(0,interp_refl_cmap(outeriso_index,:)),1,html_color(1/3,interp_refl_cmap(outeriso_index,:)));

%forecast style with a maximum of n_fcst_steps steps.
forecast_S_colormap = colormap(pink(n_fcst_steps)); %stregthening
forecast_W_colormap = colormap(bone(n_fcst_steps)); %weakening
forecast_N_colormap = colormap(gray(n_fcst_steps)); %no change
for i=1:n_fcst_steps    
styles_kml_str = ge_poly_style(styles_kml_str,['fcst_S_step_',num2str(i),'_style'],'FFFFFFFF',1,html_color(.6,forecast_S_colormap(i,:)));
styles_kml_str = ge_poly_style(styles_kml_str,['fcst_W_step_',num2str(i),'_style'],'FFFFFFFF',1,html_color(.6,forecast_W_colormap(i,:)));
styles_kml_str = ge_poly_style(styles_kml_str,['fcst_N_step_',num2str(i),'_style'],'FFFFFFFF',1,html_color(.6,forecast_N_colormap(i,:)));
end

%balloon style (stats and graph)
styles_kml_str=ge_balloon_stats_style(styles_kml_str,'balloon_stats_style');
styles_kml_str=ge_balloon_graph_style(styles_kml_str,'balloon_graph_style');

%point placemark style for CE
styles_kml_str=ge_point_placemark_style(styles_kml_str,'point_placemark_style');

%track path and swath style
path_colormap=colormap(jet(max_vis_trck_length));
close(gcf);
styles_kml_str=ge_line_style(styles_kml_str,['coverage_style'],html_color(1,[1,1,1]),1);
for i=1:max_vis_trck_length
    styles_kml_str=ge_line_style(styles_kml_str,['path_',num2str(i),'_style'],html_color(.8,path_colormap(i,:)),5);
    styles_kml_str=ge_poly_style(styles_kml_str,['swath_',num2str(i),'_style'],html_color(.8,[0,0,0]),1,html_color(.4,path_colormap(i,:)));
end

%set master kml to start with styles
master_kml_str=styles_kml_str;
close(gcf); %colormap commands trigger a figure window
%% Build Overlay features

%Build kml for screen Overlays (logos)
others_kml_str=ge_screenoverlay(others_kml_str,'ROAMES Logo',[overlays_path,'ROAMES_logo.png'],.03,.04,0,.085,'','');
others_kml_str=ge_screenoverlay(others_kml_str,'BoM Logo',[overlays_path,'bom_logo.gif'],.32,.04,0,.085,'','');
others_kml_str=ge_screenoverlay(others_kml_str,'Refl Colorbar',[overlays_path,'refl_colorbar.png'],.96,.1,0,.4,'','');
others_kml_str=ge_screenoverlay(others_kml_str,'Vel Colorbar',[overlays_path,'vel_colorbar.png'],.92,.1,0,.4,'','');
copyfile('overlays/refl_colorbar.png',[root,overlays_path]); copyfile('overlays/vel_colorbar.png',[root,overlays_path]); copyfile('overlays/bom_logo.gif',[root,overlays_path]); copyfile('overlays/ROAMES_logo.png',[root,overlays_path]);

%coverage maps nls (network link)
others_kml_str=ge_networklink(others_kml_str,'Coverage',[overlays_path,'coverage.kml'],0,0,'','','','',1);

%place overlays in a folder
master_kml_str=ge_folder(master_kml_str,others_kml_str,'Overlays','',1);

%% Build Features

%Layers kml network link
master_kml_str=ge_networklink(master_kml_str,['layers_links'],...
        'layers_links.kml',0,0,180,'','','',1);
%Build master kml file
ge_kml_out([root,'doc'],'master',master_kml_str);