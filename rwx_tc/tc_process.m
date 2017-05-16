function tc_process
%% init
close all

%vars
tc_config_fn      = 'tc.config';
global_config_fn  = 'global.config';
local_tmp_path    = 'tmp/';
download_path     = [tempdir,'tc_download/'];
transform_path    = [local_tmp_path,'transforms/'];

%create paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
    mkdir(transform_path)
end

%init download path
if exist(download_path,'file')~=7
    mkdir(download_path)
end

%add libs
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/etc')
addpath('/home/meso/dev/roames_weather/bin/json_read');
addpath('/home/meso/dev/shared_lib/export_fig');
addpath('etc')
addpath('tmp')

% load tc_config
read_config(tc_config_fn);
load([local_tmp_path,tc_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat']);

% load site info
site_warning = read_site_info(site_info_fn,site_info_moved_fn,radar_id_list,datenum(date_start,ddb_tfmt),datenum(date_stop,ddb_tfmt),0);
if site_warning == 1
    disp('site id list and contains ids which exist at two locations (its been reused or shifted), fix using stricter date range (see site_info_old)')
    return
end
load([local_tmp_path,site_info_fn,'.mat']);

% Preallocate regridding coordinates
preallocate_radar_grid(radar_id_list,transform_path,force_transform_update)

%%
load('prep_tcdebbie.mat')

%%
rmw_list = zeros(length(composite_date_list),1);

for i=1:size(comp_grid_set,3)
    %extract grid
    comp_grid = comp_grid_set(:,:,i);
    %set min
    comp_grid(comp_grid<12) = min_dbzh;
    %plot image using imagesc
    h = figure('color','w'); hold on
    set(gcf,'PaperUnits','inches','PaperSize',[8,7],'PaperPosition',[0 0 8 7])
    imagesc(comp_grid)
    title(datestr(composite_date_list(i),'yyyy/mm/dd HH:MM'))
    caxis([0 65]);
    cmap = colormap(jet(128));
    colormap([[1,1,1];cmap]);
    yh = colorbar; ylabel(yh, 'Reflectivity (dBZ)');
    axis tight
    if i==1
        %extract user point
        [j_guess,i_guess] = ginput(1);
        j_guess = round(j_guess); i_guess = round(i_guess);
        %close figure
    end
    %extract polar reflectivity
    radius_list = [5:1:50];
    eyewall_pts = 360;
    polar_i    = zeros(length(radius_list),eyewall_pts+1);
    polar_j    = zeros(length(radius_list),eyewall_pts+1);
    polar_dbzh = zeros(length(radius_list),eyewall_pts+1);
    for j = 1:length(radius_list)
        [j_coord,i_coord] = ellipse_points(radius_list(j),radius_list(j),0,j_guess,i_guess,'r',eyewall_pts,0); %generate coord for the ring
        j_coord = round(j_coord); i_coord = round(i_coord);
        polar_i(j,:)    = i_coord;
        polar_j(j,:)    = j_coord;
        linearInd       = sub2ind(size(comp_grid), i_coord, j_coord);
        polar_dbzh(j,:) = comp_grid(linearInd);
    end
    %apply a smoothing filter (5x5km)
    img_filter = fspecial('gaussian',[5 5], 0.5);
    polar_dbzh = imfilter(polar_dbzh,img_filter);
    %find first peak associated with the eyewall
    eyewall_i = zeros(1,eyewall_pts+1);
    eyewall_j = zeros(1,eyewall_pts+1);
    %loop through polar reflectivity data
    for j = 1:length(eyewall_i)
        [~,locs]   = findpeaks(polar_dbzh(:,j));
        if ~isempty(locs)
            eyewall_i(j) = polar_i(locs(1),j);
            eyewall_j(j) = polar_j(locs(1),j);
        else
            eyewall_i(j) = nan;
            eyewall_j(j) = nan;
        end
    end
    %remove nan
    nan_filt = isnan(eyewall_i);
    eyewall_i(nan_filt) = [];
    eyewall_j(nan_filt) = [];
    %plot onto radar image
    plot(eyewall_j,eyewall_i,'.k')
    %fit ellipse
    ellipse_t = fit_ellipse(eyewall_j,eyewall_i,h);
    %[ellp_centroid, maj_rad, min_rad, orient] = fitellipse([eyewall_i;eyewall_j]);
    %plotellipse(ellp_centroid, maj_rad, min_rad, orient, 'k-')
    %ellipse_plot(maj_rad,min_rad,orient,ellp_centroid(2),ellp_centroid(1),'r',eyewall_pts,1);
    %export image
    export_fn  = ['tc_image_',datestr(composite_date_list(i),'yyyymmdd_HHMMSS'),'.png'];
    export_ffn = [local_tmp_path,export_fn];
    print(export_ffn,'-dpng','-r100')
    close(h)
    %set new guess
    i_guess = ellipse_t.Y0_in;
    j_guess = ellipse_t.X0_in;
    %allocate stats
    rmw_list(i) = min([ellipse_t.a,ellipse_t.b]);
end

figure
plot(composite_date_list,rmw_list)
rmw_list = smooth(rmw_list);
datetick('x','HH:MM')
title('Radius of Maximum Winds')
ylabel('Radius (km)')
xlabel('Time')
export_fn  = ['tc_debbie_rmw.png'];
export_ffn = [local_tmp_path,export_fn];
saveas(gcf,export_ffn)

keyboard


function ax = tc_plot(comp_grid,comp_R,composite_lat_vec,composite_lon_vec)


% load tc_config
tc_config_fn      = 'tc.config';
local_tmp_path    = 'tmp/';
read_config(tc_config_fn);
load([local_tmp_path,tc_config_fn,'.mat'])


%% plot
%create figure
h = figure('color','w','position',[1 1 700 700]); hold on;
%set limits
ax = axesm('mercator','MapLatLimit',[min(composite_lat_vec) max(composite_lat_vec)],'MapLonLimit',[min(composite_lon_vec) max(composite_lon_vec)]);
mlabel on; plabel on; framem on; axis off;
setm(ax, 'MLabelLocation', 1, 'PLabelLocation', 1,'MLabelRound',0,'PLabelRound',0,'LabelUnits','degrees','Fontsize',10)
gridm('MLineLocation',1,'PLineLocation',1)
axis tight
geoshow(comp_grid,comp_R,'DisplayType','texturemap','CDataMapping','scaled'); %geoshow assumes xy coords, so need to flip ij data_grid
%assign colourmap
caxis([0 65]);
cmap = colormap(jet(128));
colormap([[1,1,1];cmap]);
ch = colorbar;
ylabel(ch, 'Reflectivity (dBZ)');
%plot coast
S = shaperead(coast_ffn);
coast_lat = S(state_id).Y;
coast_lon = S(state_id).X;
linem(coast_lat,coast_lon,'k');