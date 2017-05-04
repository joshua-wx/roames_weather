function kml_build_root(dest_root,site_no_selection,local_dest_flag)
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
load('interp_cmaps.mat')
load('global.config.mat')
load('vis.config.mat')
load(['tmp/',site_info_fn,'.mat']);

%empty string vairables for storing kml
overlay_str  = '';
coverage_str = '';
master_str   = '';

%create path as required
if local_dest_flag==1
    if exist(dest_root,'file') == 7
        rmdir(dest_root,'s');
    end
    mkdir(dest_root);
    mkdir([dest_root,ppi_obj_path]);
    mkdir([dest_root,track_obj_path]);
    mkdir([dest_root,cell_obj_path]);
else
    file_rm([dest_root],1,0)
end

%s3 nl from doc.kml need a url prefix
if strcmp(dest_root(1:2),'s3')
    url_prefix = s3_public_root;
else
    url_prefix = '';
end

%% Styles

ppi_style_str   = '';
track_style_str = '';
cell_style_str  = '';

%nowcast with a maximum of n_fcst_steps steps.
forecast_S_colormap = [255/255,8/255,0/255];
forecast_W_colormap = [255/255,255/255,0/255];
forecast_N_colormap = [255/255,150/255,0/255];
track_style_str     = ge_nowcast_multipoly_style(track_style_str,['fcst_S_style'],html_color(.6,forecast_S_colormap),5,'00FFFFFF');
track_style_str     = ge_nowcast_multipoly_style(track_style_str,['fcst_W_style'],html_color(.6,forecast_W_colormap),3,'00FFFFFF');
track_style_str     = ge_nowcast_multipoly_style(track_style_str,['fcst_N_style'],html_color(.6,forecast_N_colormap),3,'00FFFFFF');

%track path
path_colormap = flipud(colormap(autumn(max_vis_trck_length)));
close(gcf);
for i=1:max_vis_trck_length
    track_style_str = ge_line_style(track_style_str,['path_',num2str(i),'_style'],html_color(.8,path_colormap(i,:)),3);
end
%balloon style (stats and graph)
cell_style_str  = ge_balloon_stats_style(cell_style_str,'balloon_stats_style',url_prefix,icons_path);
%impact swath
swath_colormap = flipud(colormap(autumn(length(swath_mesh_threshold))));
close(gcf);
for i=1:length(swath_mesh_threshold)
    track_style_str = ge_swath_poly_style(track_style_str,['swath_',num2str(i),'_style'],html_color(.8,swath_colormap(i,:)),5,'00FFFFFF',true);
end

%% Build overlay/icon paths and copy images

%transfer overlays,icons and coverage
if ~strcmp(dest_root(1:2),'s3')
    mkdir([dest_root,overlays_path])
    mkdir([dest_root,icons_path])
end
file_cp([pwd,'/etc/',overlays_path,'ROAMES_logo.png'],[dest_root,overlays_path,'ROAMES_logo.png'],0,1)
file_cp([pwd,'/etc/',overlays_path,'dbzh_colorbar.png'],[dest_root,overlays_path,'dbzh_colorbar.png'],0,1)
file_cp([pwd,'/etc/',overlays_path,'vradh_colorbar.png'],[dest_root,overlays_path,'vradh_colorbar.png'],0,1)
file_cp([pwd,'/etc/',icons_path,'graph_icon.png'],[dest_root,icons_path,'graph_icon.png'],0,1)
file_cp([pwd,'/etc/',icons_path,'lightning_icon.png'],[dest_root,icons_path,'lightning_icon.png'],0,1)

%% Overlay Images kml

%Build kml for screen Overlays (logos)
overlay_str = ge_screenoverlay(overlay_str,'ROAMES Logo',[url_prefix,overlays_path,'ROAMES_logo.png'],.03,.04,0,.1,'','');
overlay_str = ge_screenoverlay(overlay_str,'dbzh Colorbar',[url_prefix,overlays_path,'dbzh_colorbar.png'],.96,.1,0,.4,'','');
overlay_str = ge_screenoverlay(overlay_str,'vradh Colorbar',[url_prefix,overlays_path,'vradh_colorbar.png'],.92,.1,0,.4,'','');
master_str  = ge_folder(master_str,overlay_str,'Overlays','',1);

%% Coverage kml

%generate coverage kml for each radar site
site_latlonbox = [];
cov_lat        = [];
cov_lon        = [];
for i=1:length(site_no_selection)
    %site list idx
    siteinfo_idx        = find(siteinfo_id_list==site_no_selection(i));
    %generate circle latlon
    [site_cov_lat, site_cov_lon] = scircle1(siteinfo_lat_list(siteinfo_idx),siteinfo_lon_list(siteinfo_idx),km2deg(coverage_range));
    [site_cov_lon, site_cov_lat] = poly2cw(site_cov_lon, site_cov_lat);
    %union with all coverage
    [cov_lon,cov_lat]   = polybool('Union',cov_lon,cov_lat,site_cov_lon,site_cov_lat);
    %append site latlonbox
    site_latlonbox      = [site_latlonbox;[max(site_cov_lat),min(site_cov_lat),max(site_cov_lon),min(site_cov_lon)]];
end
%split up coverage polygons into cells
[cov_lat,cov_lon] = polysplit(cov_lat,cov_lon);
coverage_str      = ge_line_style(coverage_str,'coverage_style',html_color(0.5,[1,1,1]),2);
for i=1:length(cov_lat)
    %write each polygon to kml string
    temp_lat     = cov_lat{i};
    temp_lon     = cov_lon{i};
    coverage_str = ge_line_string(coverage_str,1,['segment_',num2str(i)],'','','#coverage_style',0,'clampToGround',0,1,temp_lat(1:end-1),temp_lon(1:end-1),temp_lat(2:end),temp_lon(2:end));
end

ge_kml_out([tempdir,'coverage.kml'],'Coverage',coverage_str)
file_mv([tempdir,'coverage.kml'],[dest_root,overlays_path,'coverage.kml'])

%% build master network links
%Layers kml network link
master_str = ge_networklink(master_str,'PPI Imagery',[url_prefix,'ppi.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Track Objects',[url_prefix,'track.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Cell Objects',[url_prefix,'cell.kml'],0,0,'','','','',1);
master_str = ge_networklink(master_str,'Coverage',[url_prefix,overlays_path,'coverage.kml'],0,0,'','','','',1);

%% Build master kml

%Build master kml file
temp_ffn = tempname;
ge_kml_out(temp_ffn,'RoamesWX',master_str);
%transfer to root path
file_mv(temp_ffn,[dest_root,'doc.kml'])

%% build ppi groups kml

%scan.kml
display('building ppi nl kml')
ppi_str  = ppi_style_str;
if options(1)==1
    tmp_str = generate_radar_nl('ppi_dbzh',dest_root,ppi_obj_path,site_no_selection,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
    ppi_str = ge_folder(ppi_str,tmp_str,'PPI DBZH','',1);
end
if options(2)==1
    tmp_str = generate_radar_nl('ppi_vradh',dest_root,ppi_obj_path,site_no_selection,site_latlonbox,ppi_minLodPixels,ppi_maxLodPixels,local_dest_flag);
    ppi_str = ge_folder(ppi_str,tmp_str,'PPI VRADH','',1);
end

if any(options(1:2))
    display('building offline images')
    generate_offline_radar(dest_root,ppi_obj_path,site_no_selection,site_latlonbox)
end

temp_ffn = tempname;
ge_kml_out(temp_ffn,'PPI Objects',ppi_str);
file_mv(temp_ffn,[dest_root,'ppi.kml']);
wait_aws_finish

%cell.kml
display('building cell nl kml')
cell_str  = cell_style_str;
if options(3)==1
    tmp_str   = generate_radar_nl('xsec_dbhz',dest_root,cell_obj_path,site_no_selection,'','','',local_dest_flag);
    cell_str  = ge_folder(cell_str,tmp_str,'XSection Reflectivity','',1);
end
if options(4)==1
    tmp_str   = generate_radar_nl('xsec_vradh',dest_root,cell_obj_path,site_no_selection,'','','',local_dest_flag);
    cell_str  = ge_folder(cell_str,tmp_str,'XSection Doppler','',1);
end
if options(5)==1 || options(6)==1
    tmp_str   = generate_radar_nl('iso',dest_root,cell_obj_path,site_no_selection,'','','',local_dest_flag);
    cell_str  = ge_folder(cell_str,tmp_str,'Isosurface Reflectivity','',1);
end

temp_ffn = tempname;
ge_kml_out(temp_ffn,'Cell Objects',cell_str);
file_mv(temp_ffn,[dest_root,'cell.kml']);
wait_aws_finish

%track.kml
display('building track nl kml')
track_str  = track_style_str;
if options(7)==1
    tmp_str   = generate_nl('stat','Cell Stats',dest_root,track_obj_path,local_dest_flag);
    track_str  = [track_str,tmp_str];
end
if options(8)==1
    tmp_str    = generate_nl('track','Tracks',dest_root,track_obj_path,local_dest_flag);
    track_str  = [track_str,tmp_str];
end
if options(9)==1
    tmp_str    = generate_nl('swath','Impact',dest_root,track_obj_path,local_dest_flag);
    track_str  = [track_str,tmp_str];
end
if options(10)==1
    tmp_str    = generate_nl('nowcast','Nowcast',dest_root,track_obj_path,local_dest_flag);
    track_str  = [track_str,tmp_str];
end

temp_ffn = tempname;
ge_kml_out(temp_ffn,'Track Objects',track_str);
file_mv(temp_ffn,[dest_root,'track.kml']);
wait_aws_finish

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
    radar_id_str  = num2str(radar_id_list(i),'%02.0f');
    kml_path      = [file_path,radar_id_str,'/'];
    kml_full_path = [dest_root,kml_path];
    if local_dest_flag == 1 && exist(kml_full_path,'file')~=7
        mkdir(kml_full_path)
    end 
    %init nl
    kml_name     = radar_id_str;
    kml_fn       = [kml_path,prefix,'_',radar_id_str,'.kml'];
    kml_out      = ge_networklink(kml_out,kml_name,kml_fn,0,0,60,region_kml,'','',1); %refresh every minute or onRegion
    %init radar offline kml network link for ppis, empty for others
    if strcmp(prefix(1:3),'ppi')
        kml2_nl = ge_networklink('','Radar Offline',['radar_offline_',radar_id_str,'.kmz'],0,0,60,'','','',1);
    else
        kml2_nl = '';
    end
    %write out
    ge_kml_out([dest_root,kml_fn],kml_name,kml2_nl);
end

function kml_out = generate_nl(prefix,kml_name,dest_root,file_path,local_dest_flag)
%WHAT: creates network links and empty kml points which the nl point for the specified prefix
kml_out       = '';
%loop through radar ids
%generate ge region kml
region_kml = '';
%init paths
kml_full_path = [dest_root,file_path];
if local_dest_flag == 1 && exist(kml_full_path,'file')~=7
    mkdir(kml_full_path)
end
%init nl
kml_fn       = [file_path,prefix,'.kml'];
kml_out      = ge_networklink(kml_out,prefix,kml_fn,0,0,60,region_kml,'','',1); %refresh every minute or onRegion
%write out
ge_kml_out([dest_root,kml_fn],kml_name,'');


function generate_offline_radar(dest_root,file_path,radar_id_list,site_latlonbox)
%WHAT: generates offline ground overlays for each radar
%loop through radar ids
png_ffn = [pwd,'/etc/overlays/radar_offline.png'];
for i=1:length(radar_id_list)
    radar_id_str = num2str(radar_id_list(i),'%02.0f');
    offline_kml  = ge_groundoverlay('','Radar Offline','radar_offline.png',site_latlonbox(i,:),'','','clamped','',1);
    kmz_fn       = ['radar_offline_',radar_id_str,'.kmz'];
    kml_path     = [dest_root,file_path,radar_id_str,'/'];
    ge_kmz_out(kmz_fn,offline_kml,kml_path,png_ffn);
end
    
