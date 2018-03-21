function climate(radar_id_list_in)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Core climatology script for roames weather which takes the local
%database built by sync_database and generate outputs for spatial and
%statistical analysis
% INPUTS
% out_ffn: climate.config and mapping configs
% radar_id_list_in: vector of radar ids
% RETURNS: generates images and output databases
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% init

%close figures
close all

%setup config names
climate_config_fn  = 'climate.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%build transforms
transform_path    = [local_tmp_path,'transforms/'];

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/lib/ge_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('etc/')
addpath('etc/map/')
addpath('lib/')

% load climate config
read_config(climate_config_fn);
load([local_tmp_path,climate_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

% check for conflicts
if ci_flag == 1 && ce_flag == 1
	disp('ce and ci are true, conflicting')
	return
end

% site_info.txt
site_warning = read_site_info(site_info_fn,site_info_moved_fn,radar_id_list,datenum(date_start,'yyyy_mm_dd'),datenum(date_stop,'yyyy_mm_dd'),0);
if site_warning == 1
    disp('site id list and contains ids which exist at two locations (its been reused or shifted), fix using stricter date range (see site_info_old)')
    return
end
load([local_tmp_path,site_info_fn,'.mat']);

%create old path
if exist(old_root,'file') ~= 7
    mkdir(old_root)
end

%read local archive path folders for 'all'
if strcmp(radar_id_list,'all')
    path_dir      = dir(db_root); path_dir(1:2) = [];
    %remove OLD
    old_idx       = find(strcmp({path_dir.name},'OLD'));
    path_dir(old_idx) = [];
    %keep only folders and create radar list
    radar_id_list = str2num(vertcat(path_dir.name));
    is_folder     = vertcat(path_dir.isdir);
    radar_id_list = radar_id_list(is_folder);
end
%override with input var if present
if nargin==1
    radar_id_list = radar_id_list_in;
end

for m = 1:length(radar_id_list)
    
    %process radar m
    radar_id = radar_id_list(m);
    
    %load map filename
    map_config_fn = ['map.',num2str(radar_id,'%02.0f'),'.config'];
    if exist(map_config_fn,'file') ~= 2
        disp('map config file missing for selected radar')
        return
    end
    
    %create output paths and populate with configs
    out_path = [out_root,num2str(radar_id,'%02.0f')];
    %if out path exists, rename and move to old path
    if exist(out_path,'file') == 7
        old_path = [old_root,num2str(radar_id,'%02.0f'),'_',datestr(now,'yyyymmdd-HHMMSS')];
        mkdir(old_path)
        movefile(out_path,old_path);
    end
    %create out path
    mkdir(out_path);
    %copy configs
    copyfile(['etc/',climate_config_fn],out_path);
    copyfile(['etc/map/',map_config_fn],out_path);
    
    %init site info
    site_ind  = find(siteinfo_id_list==radar_id);
    site_lat  = siteinfo_lat_list(site_ind);
    site_lon  = siteinfo_lon_list(site_ind);
    preallocate_radar_grid(radar_id,transform_path,transform_new);

    %% load database from csv

    %set target paths
    target_ffn  = [db_root,num2str(radar_id,'%02.0f'),'/','database.csv'];
    out         = dlmread(target_ffn,',',1,0);

    %build local database from csv
    storm_date_list          = datenum(out(:,2:7));
    storm_trck_list          = out(:,8);
    storm_latloncent_list    = out(:,12:13);
    storm_ijbox_list         = out(:,14:17);
    storm_subset_list        = out(:,9);
    storm_stat_list          = struct('area',out(:,22),'area_ewt',out(:,23),'max_cell_vil',out(:,24),'max_dbz',out(:,25),...
        'max_dbz_h',out(:,26),'max_g_vil',out(:,27),'max_mesh',out(:,28),...
        'max_posh',out(:,29),'max_sts_dbz_h',out(:,30),'max_tops',out(:,31),...
        'mean_dbz',out(:,32),'mass',out(:,33),'vol',out(:,34));

    %% generate masks

    %%%date mask%%%
    %generate date span
    date_list        = [datenum(date_start,'yyyy_mm_dd'):datenum(date_stop,'yyyy_mm_dd')];
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

    %%min/max var masks%%%
    %extract variable from database and assign stormh5 name
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
    %create min mask
    if strcmp(data_min,'nan')
        min_mask = true(length(stat_var),1);
    else
        min_mask = stat_var >= data_min;
    end
    %create max mask
    if strcmp(data_max,'nan')
        max_mask = true(length(stat_var),1);
    else
        max_mask = stat_var >= data_max;
    end

    %%%time mask%%%
    %create time mask using database times
    time_list      = rem(storm_date_list,1);
    time_mask      = time_list>=rem(datenum(time_min,'HH:MM'),1) & time_list<=rem(datenum(time_max,'HH:MM'),1);

    %%% distance mask %%%
    %mask distance from radar site to storm latlon
    if range_flag == 1
        [arclen,~] = distance(site_lat,site_lon,storm_latloncent_list(:,1),storm_latloncent_list(:,2));
        dist_list  = deg2km(arclen);
        dist_mask  = dist_list <= data_range;
    end

    %%% ci/ce mask %%%
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
        %no ci/ce mask
        ci_ce_mask      = true(length(storm_date_list),1);
    end

    %%% combine masks %%%
    data_mask            = min_mask & max_mask & time_mask & date_mask & ci_ce_mask & dist_mask;


    %% Plotting

    %load transforms
    transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
    load(transform_fn,'geo_coords','grid_size','img_latlonbox')

    %%% centroid plot %%%

    %apply mask to database
    cent_date_list       = storm_date_list(data_mask);
    cent_latloncent_list = storm_latloncent_list(data_mask,:);
    cent_rain_year       = climate_rain_year(cent_date_list,rain_yr_start);
    cent_rain_year_count = length(unique(cent_rain_year));
    
    %preallocate
    cent_lat_vec = img_latlonbox(1):-centroid_grid:img_latlonbox(2);
    cent_lon_vec = img_latlonbox(4):centroid_grid:img_latlonbox(3);
    cent_grid    = zeros(length(cent_lat_vec),length(cent_lon_vec));
    %create mapping georef struct
    cent_R       = makerefmat('RasterSize',[length(cent_lat_vec),length(cent_lon_vec)],'LatitudeLimits',[min(cent_lat_vec) max(cent_lat_vec)],'LongitudeLimits',[min(cent_lon_vec) max(cent_lon_vec)]);

    %for each centroid, bin into nearest lat/lon grid point
    for i=1:length(cent_date_list)
        temp_lat    = cent_latloncent_list(i,1);
        temp_lon    = cent_latloncent_list(i,2);
        %index of closest centroid grid cell
        [~,lat_ind] = min(abs(cent_lat_vec - temp_lat));
        [~,lon_ind] = min(abs(cent_lon_vec - temp_lon));
        %add to centroid grid
        cent_grid(lat_ind,lon_ind) = cent_grid(lat_ind,lon_ind)+1;
    end
    
    %image plot centroid grid
    %climate_generate_image(cent_grid,'centroid',radar_id,[],cent_R,map_config_fn,cent_rain_year_count,'Annual Frequency')

    %%% Density/Direction plots %%%

    %apply masks to database
    swth_date_list       = storm_date_list(data_mask);
    swth_trck_list       = storm_trck_list(data_mask);
    swth_latloncent_list = storm_latloncent_list(data_mask,:);
    swth_subset_list     = storm_subset_list(data_mask);
    swth_ijbox_list      = storm_ijbox_list(data_mask,:);
    %rain years
    swth_rain_year       = climate_rain_year(swth_date_list,rain_yr_start);
    swth_rain_year_count = length(unique(swth_rain_year));
    
    %preallocate
    blank_grid    = zeros(grid_size(1),grid_size(2));
    track_grids   = struct('density_grid',blank_grid,'u_grid',blank_grid,'v_grid',blank_grid,'n_grid',blank_grid,'max_grid',blank_grid,'grid_size',grid_size);
    %create mapping georef struct
    radar_lat_vec = geo_coords.radar_lat_vec;
    radar_lon_vec = geo_coords.radar_lon_vec;
    track_R       = makerefmat('RasterSize',[length(radar_lat_vec),length(radar_lon_vec)],'LatitudeLimits',[min(radar_lat_vec) max(radar_lat_vec)],'LongitudeLimits',[min(radar_lon_vec) max(radar_lon_vec)]);

    %create list of unique dates
    flr_swth_date_list  = floor(swth_date_list);
    uniq_swth_date_list = unique(flr_swth_date_list);
    prev_radar_step     = min(round((flr_swth_date_list(2:end)-flr_swth_date_list(1:end-1))*24*60)); %guess radar step
    %loop through each unique date
    for i=1:length(uniq_swth_date_list)

        %init
        %extract current day
        target_date = uniq_swth_date_list(i);
        disp(datestr(target_date));
        %find index of masked database entries which match current date
        date_ind    = find(flr_swth_date_list==target_date);
        track_list  = swth_trck_list(date_ind);
        %remove date_ind values which have track=0 (no track assigned)
        remove_ind  = track_list==0;
        date_ind(remove_ind)   = [];
        track_list(remove_ind) = [];
        %skip date if no tracks left
        if isempty(track_list)
            continue
        end

        %calc radar step for current day (using all timestamps to ensure
        %continuity)
        %find index of unmasked database entries for current date
        storm_list_ind       = floor(storm_date_list)==target_date;
        %generate unique list of date/times
        step_date_list       = storm_date_list(storm_list_ind);
        uniq_step_date_list  = unique(step_date_list);
        %calc difference in minutes for all entries
        all_steps            = round((uniq_step_date_list(2:end)-uniq_step_date_list(1:end-1))*24*60);
        %set radar step to be the min
        radar_step           = min(all_steps);
        if radar_step==0 || radar_step>10
            %use step from previous target_step
            radar_step       = prev_radar_step;
        end
        prev_radar_step      = radar_step;

        %loop through each track id in the current date
        uniq_track_list = unique(track_list);
        for j=1:length(uniq_track_list)
            %extract current track
            target_track = uniq_track_list(j);
            %extract index cells in current track from mask database
            track_subind = track_list==target_track;
            track_ind    = date_ind(track_subind);
            %skip if track too short
            if length(track_ind)<min_track
                continue
            end
            %sort index list by time
            [~,sort_ind] = sort(swth_date_list(track_ind));
            track_ind    = track_ind(sort_ind);
            %pass to track_to_grid, return track_grids containing density and u,v
            track_grids = climate_track_grids(track_grids,track_ind,swth_date_list,swth_latloncent_list,...
                swth_subset_list,swth_ijbox_list,db_root,radar_id,r_scale,stormh5_varname,data_min,radar_step);
        end
    end

    %post process motion field
    %normalise u,v using n_grid (cumulative count)
    mean_grid_u = track_grids.u_grid./track_grids.n_grid;
    mean_grid_v = track_grids.v_grid./track_grids.n_grid;
    [radar_lat_mat,radar_lon_vec] = ndgrid(radar_lat_vec,radar_lon_vec);
    %calc streamliners
    [line_vertices,arrow_vertices] = streamslice(radar_lon_vec,radar_lat_mat,mean_grid_u,mean_grid_v,5);
    vec_data                         = [line_vertices,arrow_vertices];

    %plot density and direction maps
    climate_generate_image(track_grids.density_grid,'merged',radar_id,vec_data,track_R,map_config_fn,swth_rain_year_count,'Mean Annual Occurance')
    %plot max and direction maps
    %climate_generate_image(track_grids.max_grid,'max',radar_id,vec_data,track_R,map_config_fn,swth_rain_year_count,'Maximum Hailsize (mm)')
    
    %temporary max processing
%     mesh_grid = track_grids.max_grid;
%     step_grid = zeros(size(mesh_grid));
%     step_grid(mesh_grid>0 & mesh_grid<25) = 1;
%     step_grid(mesh_grid>=25 & mesh_grid<=50) = 2;
%     step_grid(mesh_grid>50) = 3;
%     fn_out = [date_start,'_mesh_steps.mat'];
%     save(fn_out,'step_grid','geo_coords')
    
    %kml plot merged swatsh grid
    climate_generate_kml(track_grids.density_grid,radar_id,geo_coords,map_config_fn,swth_rain_year_count,swth_date_list,'Mean Annual Occurance')
    climate_generate_geotiff(radar_id,track_grids.density_grid,track_R)
    %climate_generate_kml_hsda(step_grid,radar_id,geo_coords,map_config_fn,swth_rain_year_count,swth_date_list,'Maximum MESH (mm)')
end
disp('RWX Climate plotting complete')
