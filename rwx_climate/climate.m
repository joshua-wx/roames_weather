function climate
%WHAT: Core climatology script for roames weather which takes the local
%database built by sync_database and generate outputs for spatial and
%statistical analysis

%setup config names
climate_config_fn  = 'climate.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';
site_info_fn       = 'site_info.txt';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('etc/')

% load climate config
read_config(climate_config_fn);
load([local_tmp_path,climate_config_fn,'.mat'])

% check for conflicts
if ci_flag == 1 && ce_flag == 1
	disp('ce and ci are true, conflicting')
	return
end

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

% Load site info
read_site_info(site_info_fn); load([local_tmp_path,site_info_fn,'.mat']);

% build transforms
transform_path    = [local_tmp_path,'transforms/'];
preallocate_radar_grid(radar_id,transform_path,transform_new)

%% load database
target_ffn  = [db_root,num2str(radar_id,'%02.0f'),'/','database.csv'];
out         = dlmread(target_ffn,',',1,0);
%build local database
storm_date_list          = datenum(out(:,2:7));
storm_trck_list          = out(:,8);
storm_latloncent_list    = out(:,12:13);
storm_ijbox_list         = out(:,14:17);
storm_subset_list        = out(:,9);
storm_stat_list          = struct('area',out(:,22),'area_ewt',out(:,23),'max_cell_vil',out(:,24),'max_dbz',out(:,25),...
    'max_dbz_h',out(:,26),'max_g_vil',out(:,27),'max_mesh',out(:,28),...
    'max_posh',out(:,29),'max_sts_dbz_h',out(:,30),'max_tops',out(:,31),...
    'mean_dbz',out(:,32),'mass',out(:,33),'vol',out(:,34));

%% generate date list
%span dates
date_list        = [datenum(date_start,'yyyy/mm/dd'):datenum(date_stop,'yyyy/mm/dd')];
%filter months
date_list_months = month(date_list);
date_list        = date_list(ismember(date_list_months,month_list));
%filter date_list
if date_list_flag == 1
    filter_date_list = load(date_list_ffn,(date_list_var));
    filter_date_list = filter_date_list.(date_list_var);
    date_list        = date_list(ismember(date_list,filter_date_list));
end
%create date mask
date_mask        = ismember(floor(storm_date_list),date_list);
%% mask cells by var, time and date
%extract mask var
switch data_type
    case 'mesh'
        stat_var        = vertcat(storm_stat_list.max_mesh);
		stormh5_varname = 'MESH_grid';
    case 'posh'
        stat_var        = vertcat(storm_stat_list.max_posh);
		stormh5_varname = 'POSH_grid';
    case 'dbz'
        stat_var        = vertcat(storm_stat_list.max_dbz);
		stormh5_varname = 'max_dbz_grid';
    case 'g_vil'
        stat_var        = vertcat(storm_stat_list.max_g_vil);
		stormh5_varname = 'vil_grid';
    case 'tops_h'
        stat_var        = vertcat(storm_stat_list.max_tops);
		stormh5_varname = 'tops_h_grid';
    case 'sts_h'
        stat_var        = vertcat(storm_stat_list.max_sts_dbz_h);
		stormh5_varname = 'sts_h_grid';
end
%create var mask
if strcmp(data_min,'nan')
    min_mask = true(length(stat_var),1);
else
    min_mask = stat_var >= data_min;
end
if strcmp(data_max,'nan')
    max_mask = true(length(stat_var),1);
else
    max_mask = stat_var >= data_max;
end
%create time mask
time_list      = rem(storm_date_list,1);
time_mask      = time_list>=rem(datenum(time_min,'HH:MM'),1) & time_list<=rem(datenum(time_max,'HH:MM'),1);

%% ci/ce mask
if ci_flag == 1 || ce_flag == 1
    ci_ce_mask      = false(length(storm_date_list),1);
	%date only
	date_list       = floor(storm_date_list);
	%unique list of dates
	uniq_date_list  = unique(date_list);
	%loop through each unique date list (track id only unique for a single day)
	for i=1:length(uniq_date_list)
		%set target date
		target_date  = uniq_date_list(i);
		%find index for cells in target_date
		date_idx     = find(date_list == target_date);
		track_list   = storm_trck_list(date_idx);
		%find max track id for loop
		uniq_track_list = unique(track_list);
		%loop through track ids
		for j=1:length(track_list)
			%find global index of track j
            track_id    = track_list(j);
            if track_id == 0
                continue
            end
			track_idx   = date_idx(track_list==track_id);
			%find dates+time of track j
			track_dates = storm_date_list(track_idx);
			%apply required mask
			if ci_flag == 1
				%find first timestamp of track j for ci
				ci_date = min(track_dates);
				%find index of first timestamp
				ci_idx  = track_idx(track_dates==ci_date(1));
				%set mask
				ci_ce_mask(ci_idx) = true;
			elseif ce_flag == 1
				%extract var for track cells
				track_var     = stat_var(track_idx);
				%sort track vars by time
				[~,sort_idx]  = sort(track_dates);
				track_var     = track_var(sort_idx);
				%calc timestep var diff, with 0 for first timestamp
				track_var_dif = [0;[track_var(2:end)-track_var(1:end-1)]];
				%extract global idx for ce cells
				ce_idx        = track_idx(track_var>ce_diff);
				%set mask
				ci_ce_mask(ce_idx) = true;
			end
		end
	end
else
    ci_ce_mask      = true(length(storm_date_list),1);
end

%% combine masks
data_mask      = min_mask & max_mask & time_mask & date_mask & ci_ce_mask;

%% create plots

%load transform
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
load(transform_fn,'geo_coords','grid_size','img_latlonbox')

%create blank grids
cent_lat_vec = img_latlonbox(1):-centroid_grid:img_latlonbox(2);
cent_lon_vec = img_latlonbox(4):centroid_grid:img_latlonbox(3);
cent_grid    = zeros(length(cent_lat_vec),length(cent_lon_vec));
max_grid     = zeros(grid_size(1),grid_size(2));
mean_grid    = zeros(grid_size(1),grid_size(2));
density_grid = zeros(grid_size(1),grid_size(2));
dir_u_grid   = zeros(grid_size(1),grid_size(2));
dir_v_grid   = zeros(grid_size(1),grid_size(2));

%apply masks
storm_date_list       = storm_date_list(data_mask);
storm_trck_list       = storm_trck_list(data_mask);
storm_latloncent_list = storm_latloncent_list(find(data_mask),:);

for i=1:length(storm_date_list)
    temp_lat = storm_latloncent_list(i,1);
    temp_lon = storm_latloncent_list(i,2);
    [~,lat_ind] = min(abs(cent_lat_vec - temp_lat));
    [~,lon_ind] = min(abs(cent_lon_vec - temp_lon));
    cent_grid(lat_ind,lon_ind) = cent_grid(lat_ind,lon_ind)+1;
end    

cent_grid(cent_grid>12)=12;

%plot centroid grid
R = makerefmat('RasterSize',[length(cent_lat_vec),length(cent_lon_vec)],'LatitudeLimits',[min(cent_lat_vec) max(cent_lat_vec)],'LongitudeLimits',[min(cent_lon_vec) max(cent_lon_vec)]);
generate_map(cent_grid,R,map_config_fn)


function generate_map(data_grid,data_grid_R,map_config_fn)

read_config(map_config_fn);
load(['tmp/',map_config_fn,'.mat'])

%create figure
h = figure('color','w','position',[1 1 fig_w fig_h]); hold on;
ax=axesm('mercator','MapLatLimit',[map_S_lat map_N_lat],'MapLonLimit',[map_W_lon map_E_lon]);
mlabel on; plabel on; framem on; axis off;
setm(ax, 'MLabelLocation', lat_label_int, 'PLabelLocation', lon_label_int,'MLabelRound',lat_label_rnd,'PLabelRound',lon_label_rnd,'LabelUnits','degrees','Fontsize',label_fontsize)
gridm('MLineLocation',lat_grid_res,'PLineLocation',lon_grid_res)
axis tight

%plot data
geoshow(flipud(data_grid),data_grid_R,'DisplayType','texturemap','CDataMapping','scaled'); %geoshow assumes xy coords, so need to flip ij data_grid
caxis([0 max(data_grid(:))]);
cmap = colormap(hot(128));
cmap = flipud(cmap);
colormap(cmap);

%draw coast
if draw_coast==1
    S = shaperead(coast_ffn);
    coast_lat = S(state_id).Y;
    coast_lon = S(state_id).X;
    linem(coast_lat,coast_lon,'k');
end

%draw topo
if draw_topo==1
    [topo_z, topo_refvec] = geotiffread(topo_ffn);
    if topo_resize == 1
       [topo_z,topo_refvec] = resizem(topo_z,topo_scale,topo_refvec);
    end
    if topo_filter == 1
        h = fspecial('gaussian',[topo_filter_sz,topo_filter_sz]);
        topo_z = imfilter(topo_z,h);
    end
    %create contours
    geoshow(topo_z,topo_refvec,'DisplayType','contour','LevelList',[topo_min:topo_step:topo_max],'LineColor','k','LineWidth',topo_linewidth);
end

h = colorbar;
ylabel(h, 'Hailstorm (20mm) 10km Centroid Density')
% %create merged density plot
% %date only
% date_list       = floor(storm_date_list);
% %unique list of dates
% uniq_date_list  = unique(date_list);
% %loop through each unique date list (track id only unique for a single day)
% for i=1:length(uniq_date_list)
% 	%set target date
% 	target_date  = uniq_date_list(i);
% 	%find index for cells in target_date
% 	date_idx     = find(date_list == target_date);
% 	track_list   = storm_trck_list(date_idx);
% 	%find max track id for loop
% 	max_track_id = max(track_list);
% 	%loop through track ids, starting from 0, skip track id 0, no track
% 	for j=1:length(max_track_id)
% 		%find global index of track j
% 		track_idx   = date_idx(track_list==j);		
% 		if length(track_idx)<min_track
% 			continue
% 		end
% 		%loop through each track
% 		for k=2:length(track_idx)
% 			config_path   = [local_tmp_path,climate_config_fn,'.mat'];
%             bw_init_grid  = preprocess_grid(config_path,storm_date,subset_id,stormh5_varname,ij_box,size_grid);
%             bw_finl_grid  = preprocess_grid(config_path,storm_date,subset_id,stormh5_varname,ij_box,size_grid);
% 			%calc hull
%             bw_convhull   = bwconvhull(bw_init_grid+bw_finl_grid);
% 			%append
% 			density_grid  = density_grid + bw_convhull;
% 		end
% 	end
% end
% %plot density grid
% imagesc(density_grid)
% keyboard
% 
% function density_out = preprocess_grid(config_path,storm_date,subset_id,stormh5_varname,ij_box,size_grid)
% %load cliamte config
% load(config_path)
% scaling = 10;
% 
% %initalise grid
% density_out = zeros(size_grid);
% %generate path for storm
% date_vec    = datevec(storm_date);
% stormh5_fn  = [num2str(radar_id,'%02.0f'),'_',datestr(storm_date,'yyyymmdd_HHMMSS'),'.storm.h5'];
% stormh5_ffn = [db_root,'/',num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/',stormh5_fn];
% 
% %read dataset out of h5
% data_grid   = h5read(stormh5_ffn,['/',num2str(subset_id),'/',stormh5_varname]);
% 
% %assign to correct lcoation in grid_out
% density_out(ij_box(1):ij_box(2),ij_box(3):ij_box(4)) = data_grid./scaling;
% 
% %mask as required
% mask_grid   = data_grid >= data_min,data_max
% 
% %up to here
% 
% %extract grid bounds
% grid_lower = opt_struct.proc_opt(2);
% grid_upper = opt_struct.proc_opt(3);
% 
% %clamp grid
% if ~isnan(grid_upper)
%     grid_out(grid_out>=grid_upper) = grid_upper;
% end
% 
% %create density grids for masking and capture
% if ~isnan(grid_lower)
%     density_out = grid_out >= grid_lower; %lower bound
% else
%     density_out = ~isnan(grid_out); %no mask
% end
% % %mask grid
% grid_out    = grid_out.*density_out;
