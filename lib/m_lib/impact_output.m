function impact_output(radar_id_list,newest_timestamp,transform_path)

%WHAT: Collates wind and mesh impact maps into a single image for each
%radar. Output images are transfered to s3.
%Also removes impact files using newest_timestamp and impact_hrs

%load radar colormap and global config
load('global.config.mat')
load([site_info_fn,'.mat'])
load('vis.config.mat')

for i = 1:length(radar_id_list)
    
    %check radar id against impact radar id list
    radar_id = radar_id_list(i);
    if ~ismember(radar_id,impact_radar_id)
		continue
    end
    
    %init blank grid
    transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
    load(transform_fn,'grid_size','img_latlonbox','geo_coords','h_grid_deg')
    impact_grid  =  zeros(grid_size(1),grid_size(2));
    
    %% hail
    %check local path exists
    local_path = [impact_tmp_root,'hail/',num2str(radar_id,'%02.0f'),'/'];
    local_dir  = dir(local_path); local_dir(1:2) = [];
    if isempty(local_dir)
        continue
    end
    %list impact files
    local_fn_list = {local_dir.name};
    remove_idx    = [];
    %build fn datetimes and filter
    for j = 1:length(local_fn_list)
        [~,fn,ext] = fileparts(local_fn_list{j});
        if ~strcmp(ext,'.mat')
            remove_idx = [remove_idx,j];
            continue
        end
        fn_datelist = datenum(fn,r_tfmt);
        if fn_datelist<addtodate(newest_timestamp,-impact_hrs,'hour') || fn_datelist>newest_timestamp
            remove_idx = [remove_idx,j];
        end
    end
    %clear out old files from local path and list
    for j = 1:length(remove_idx)
        delete([local_path,local_fn_list{remove_idx(j)}])
    end
    local_fn_list(remove_idx) = [];
    
    %collate
    master_grid = zeros(grid_size(1),grid_size(2));
    for j = 1:length(local_fn_list)
        load([local_path,local_fn_list{j}])
        master_grid = max(cat(3,master_grid,impact_grid),[],3);
    end
    %write grid out
    tmp_image_ffn = [tempdir,'impact_hail_out.png'];
    %adjust levels
    img_grid = discretize(master_grid,[swath_mesh_threshold,999],'IncludedEdge','left');
    img_grid(isnan(img_grid)) = 0;
    img_cmap = [1,1,1;colormap(flipud(autumn(length(swath_mesh_threshold))))];
    %write file out
    grid_map(tmp_image_ffn,radar_id,img_grid,img_cmap,img_latlonbox,'Radar Hail Size (mm)',cellstr(num2str(swath_mesh_threshold(:)))')
    
    
    %% wind
    %check local path exists
    local_path = [impact_tmp_root,'wind/',num2str(radar_id,'%02.0f'),'/'];
    local_dir  = dir(local_path); local_dir(1:2) = [];
    if isempty(local_dir)
        continue
    end
    %list impact files
    local_fn_list = {local_dir.name};
    remove_idx    = [];
    %build fn datetimes and filter
    for j = 1:length(local_fn_list)
        [~,fn,ext] = fileparts(local_fn_list{j});
        if ~strcmp(ext,'.nc')
            remove_idx = [remove_idx,j];
            continue
        end
        fn_datelist = datenum(fn,r_tfmt);
        if fn_datelist<addtodate(newest_timestamp,-impact_hrs,'hour') || fn_datelist>newest_timestamp
            remove_idx = [remove_idx,j];
        end
    end
    %clear out old files from local path and list
    for j = 1:length(remove_idx)
        delete([local_path,local_fn_list{remove_idx(j)}])
    end
    local_fn_list(remove_idx) = [];
    
    %collate
    %build img_latlonbox
    [img_lat_N,~] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),0);
    [img_lat_S,~] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),180);
    [~,img_lon_E] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),90);
    [~,img_lon_W] = reckon(geo_coords.radar_lat,geo_coords.radar_lon,km2deg(sd_max_rng),270);
    sd_img_latlonbox = [img_lat_N+h_grid_deg/2;img_lat_S-h_grid_deg/2;img_lon_E+h_grid_deg/2;img_lon_W-h_grid_deg/2];

    
    sd_grid_len = sd_max_rng*2 + 1;
    master_grid = zeros(sd_grid_len,sd_grid_len);
    for j = 1:length(local_fn_list)
        sd_u   = ncread([local_path,local_fn_list{j}],'analysis_u');
        sd_v   = ncread([local_path,local_fn_list{j}],'analysis_v');
        sd_wpd = sqrt(sd_u.^2 + sd_v.^2) .* 3.6;
        master_grid = max(cat(3,master_grid, sd_wpd),[],3);
    end
    %write grid out
    tmp_image_ffn = [tempdir,'impact_wind_out.png'];
    %adjust levels
    img_grid = discretize(master_grid,[impact_wind_lvl,999],'IncludedEdge','left');
    img_grid(isnan(img_grid)) = 0;
    img_cmap = [1,1,1;colormap(flipud(jet(length(impact_wind_lvl))))];
    %write file out
    grid_map(tmp_image_ffn,radar_id,fliplr(img_grid),img_cmap,sd_img_latlonbox,'Doppler Wind Speed (km/h)',cellstr(num2str(impact_wind_lvl(:)))')    
    
    keyboard
    %need to save images to s3? remove figures when deployed
    
    
end

function grid_map(out_ffn,radar_id,img_grid,img_cmap,img_latlonbox,colorbar_label,colorbar_ticklabels)
load('vis.config.mat')

%read map config
map_config_fn = ['map.',num2str(radar_id,'%02.0f'),'.config'];
read_config(map_config_fn);
load(['tmp/',map_config_fn,'.mat'])

%create figure
if isdeployed
    h = figure('color','w','position',[1 1 1000 1000],'visible','off');
else
    h = figure('color','w','position',[1 1 1000 1000]);
end
hold on
%set limits
axesm('mercator','MapLatLimit',[map_S_lat map_N_lat],'MapLonLimit',[map_W_lon map_E_lon]);
%set options
mlabel off; plabel off; framem on; axis off;
%plot data
img_grid_R = makerefmat('RasterSize',size(img_grid),'LatitudeLimits',[img_latlonbox(2) img_latlonbox(1)],'LongitudeLimits',[img_latlonbox(4) img_latlonbox(3)]);
geoshow(flipud(img_grid),img_grid_R,'DisplayType','texturemap','CDataMapping','scaled'); %geoshow assumes xy coords, so need to flip ij data_grid
colormap(img_cmap);
caxis([0 size(img_cmap,1)])
%draw coast
for i=1:length(state_id)
    S = shaperead(coast_ffn);
    coast_lat = S(state_id(i)).Y;
    coast_lon = S(state_id(i)).X;
    linem(coast_lat,coast_lon,'k');
end
%draw placemarks
for i=1:length(cities_names)
    out_name = cities_names{i};
    out_lat  = cities_lat(i);
    out_lon  = cities_lon(i);
    out_horz = cities_horz_align{i};
    out_vert = cities_vert_align{i};
    out_ftsz = cities_fontsize(i);
    out_mksz = cities_marksize(i);
    textm(out_lat,out_lon,out_name,'HorizontalAlignment',out_horz,'VerticalAlignment',out_vert,'fontsize',out_ftsz,'FontWeight','bold')
    geoshow(out_lat,out_lon,'DisplayType','point','Marker','o','MarkerSize',out_mksz,'MarkerFaceColor','k','MarkerEdgeColor','k')
end
%create colorbar
c = colorbar('Ticks',1:length(colorbar_ticklabels),'ticklabels',colorbar_ticklabels,'FontSize',12);
c.Label.String   = colorbar_label;
c.Label.FontSize = 16;
%save
saveas(gca,out_ffn,'png');
close(h)