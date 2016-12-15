function [grid_img_struct,dir_img_struct,stats_struct] = clim_grid(opt_struct,filt_ident_ffn,spatial_data)
%WHAT: generates all grids in one loop

%extract spatial data
lat_vec     = spatial_data{2};
lon_vec     = spatial_data{3};

%inialise grids
blank_grid       = zeros(length(lat_vec),length(lon_vec));
grid_img_struct  = struct('wdss_grid',blank_grid,'density_grid',blank_grid,'mean_density_grid',blank_grid,'centroids_list',[]);
dir_img_struct   = struct('u_grid',blank_grid,'v_grid',blank_grid,'n_grid',blank_grid);

%used for tags
year_list=year(opt_struct.td_opt(1)):year(opt_struct.td_opt(2));

%load config files
load('tmp/global.config.mat')


%if 50dbz sfc needs plotting, load snding data
if opt_struct.grid_opt==3
    %catch case of no sounding data
    if isempty(opt_struct.snd_ffn)
        msgbox('Sounding data required to mask 50dbz surface')
        return
    end
    %load sounding data
    load(opt_struct.snd_ffn);
end

%generate blank fields
cell_date_list          = [];
cell_stat_list          = cell(length(filt_ident_ffn),1); %speed up matrix cat'ing
cell_trck_list          = [];
cell_mask_list          = [];
cell_latloncent_list    = [];
cell_pltmask_list       = [];
cell_subsetid_list      = [];
cell_latlonbox_list     = {};
cell_mesh_grid          = {};

%create waitbar for user info
h = waitbar(0,'Building climatology, please wait');
current_percent=0;

%loop through each track year
for i=1:length(filt_ident_ffn)
    %seperate matrix to collate track stats into daily stats for
    %cell_stat_list
    daily_stats       = [];
    
    %extract daily ident and track
    curr_day_ident    = load(filt_ident_ffn{i});
    curr_day_ident    = curr_day_ident.ident_db;
    
    %skip if no days in year
    if isempty(curr_day_ident)
        continue
    end
    
    %update waitbar if on next percentage.
    if round(i/length(filt_ident_ffn)*100)>current_percent
        waitbar(i/length(filt_ident_ffn))
        current_percent=round(i/length(filt_ident_ffn)*100);
    end
    
    %extract unique list of tracks
    [uniq_simple_tracks,~,ci] = unique([curr_day_ident.simple_id]);
    
    %loop through each track in the current day
    for j=1:length(uniq_simple_tracks)
        
        %seperate matrix to collate stats
        
        %extract current track inds
        track_ident_ind = find(ci==j);
        
        %sort track by time
        [~,sort_ind]        = sort([curr_day_ident(track_ident_ind).start_timedate]);
        track_ident_ind     = track_ident_ind(sort_ind);
        
        %time filter
        if opt_struct.td_opt(4)-opt_struct.td_opt(3)~=0
            %extract start_time and remove date component from first
            %cell in track
            track_start_time = curr_day_ident(track_ident_ind(1)).start_timedate;
            track_start_time = track_start_time-floor(track_start_time);
            %skip track if it starts before or after the time
            if track_start_time<opt_struct.td_opt(3) || track_start_time>opt_struct.td_opt(4)
                continue
            end
        end
        
        %skip if too short
        if length(track_ident_ind)<opt_struct.proc_opt(1)
            continue
        end
        
        %MOVE ONTO PROCESSING
        
        %extract filter track stats
        track_stats = vertcat(curr_day_ident(track_ident_ind).stats);
        track_dt    = [curr_day_ident(track_ident_ind).start_timedate];
        
        %extract grid bounds
        grid_lower = opt_struct.proc_opt(2);
        grid_upper = opt_struct.proc_opt(3);
        
        %Filters cells in track by mask threshold, if required
        if ~isnan(grid_lower) || ~isnan(grid_upper)
            
            %Select correct stats
            switch opt_struct.grid_opt
                case 1
                    mask_stats = track_stats(:,15); %mash
                case 2
                    mask_stats = track_stats(:,16); %posh
                case 3
                    mask_stats = track_stats(:,13); %sts height
                case 4
                    mask_stats = track_stats(:,8);  %max dbz
                case 5
                    mask_stats = track_stats(:,7);  %tops                    
                case 6
                    mask_stats = track_stats(:,11);  %vil
            end
            
            %extract freezing level height if in sts sfc mode
            if opt_struct.grid_opt == 3
                %find nearest sounding data to scan_data
                snd_dt_diff      = abs(snd_datenum-track_dt(1));
                [~,snd_ind]      = min(snd_dt_diff);
                curr_snd_fz_h    = snd_fz_h(snd_ind);
                %add mask thresh for dbz sfc to freezing level
                mask_stats       = mask_stats - curr_snd_fz_h;
            else
                curr_snd_fz_h    = nan;
            end
            
            %mask_track
            if ~isnan(grid_lower)
                track_mask = mask_stats>=grid_lower; %lower mask bound
            end
            
            %clamp track
            if ~isnan(grid_upper)
                track_mask(mask_stats>=grid_upper) = grid_upper; %upper clamp bound
            end

            %mask track by area
		%boundary box esk
		%esk_lat_box=[-27.75,-27];
		%esk_lon_box=[152.125,152.625];

		%boundary box beaudesert
		%bnh_lat_box=[-28.25,-27.5];
		%bnh_lon_box=[152.5,153];
        
		%boundary box BAMS MAPS
		bams_lat_box=[-28.51 -26.71];
		bams_lon_box=[151.8 153.6];        

		sts_latlon = vertcat(curr_day_ident(track_ident_ind).dbz_latloncent);

		%mask cells outside of esk
		%esk_mask               = sts_latlon(:,1)>=esk_lat_box(1) & sts_latlon(:,1)<=esk_lat_box(2) & sts_latlon(:,2)>=esk_lon_box(1) & sts_latlon(:,2)<=esk_lon_box(2);
		%track_mask             = track_mask.*esk_mask;

		%mask cells outside of boonah
		%bnh_mask           = sts_latlon(:,1)>=bnh_lat_box(1) & sts_latlon(:,1)<=bnh_lat_box(2) & sts_latlon(:,2)>=bnh_lon_box(1) & sts_latlon(:,2)<=bnh_lon_box(2);
		%track_mask             = track_mask.*bnh_mask;
        
        %mask cells outside of boonah
		bams_mask           = sts_latlon(:,1)>=bams_lat_box(1) & sts_latlon(:,1)<=bams_lat_box(2) & sts_latlon(:,2)>=bams_lon_box(1) & sts_latlon(:,2)<=bams_lon_box(2);
		track_mask          = track_mask.*bams_mask;

        %mask cells outside of the bams domain
        latlon_box = opt_struct.latlon_box;
        if ~isempty(latlon_box)
            box_mask           = sts_latlon(:,1)>=latlon_box(1) & sts_latlon(:,1)<=latlon_box(2) & sts_latlon(:,2)>=latlon_box(3) & sts_latlon(:,2)<=latlon_box(4);
            track_mask         = track_mask.*box_mask;
        end

            
        else
            %set to no mask
            track_mask = ones(1,length(track_dt))';
        end
        
        
        %generate stats
        cell_date_list       = [cell_date_list,track_dt];
        daily_stats          = [daily_stats;track_stats];
        cell_trck_list       = [cell_trck_list,[curr_day_ident(track_ident_ind).simple_id]];
        cell_subsetid_list   = [cell_subsetid_list,[curr_day_ident(track_ident_ind).subset_id]];
        cell_latloncent_list = [cell_latloncent_list;vertcat(curr_day_ident(track_ident_ind).dbz_latloncent)];
        cell_mask_list       = [cell_mask_list;track_mask];
        for l=1:length(track_ident_ind)
            if track_mask(l)
                cell_latlonbox_list  = [cell_latlonbox_list;curr_day_ident(track_ident_ind(l)).subset_latlonbox];
                cell_mesh_grid       = [cell_mesh_grid;curr_day_ident(track_ident_ind(l)).MESH_grid];
            else
                cell_latlonbox_list  = [cell_latlonbox_list;[]];
                cell_mesh_grid       = [cell_mesh_grid;[]];
            end
        end
        %coninue loop if no masked cells and SKIP THIS TRACK
        if ~any(track_mask)
            plot_mask               = false(size(track_mask));
            cell_pltmask_list       = [cell_pltmask_list;plot_mask];
            continue
        end
        
        %Create plot mask
        if opt_struct.ci_opt %CI:passed ~any(track_mask), change mask to first cell
             plot_mask        = false(size(track_mask));
             plot_mask(1)     = true;
             %ind              = find(track_mask==1,1,'first');
             %plot_mask(ind)   = true;
        elseif opt_struct.ce_opt %CE
            %identify cells which have undergone an increase in maximum
            %grid value of >= ce_diff from the track. Set to true. Set
            %failed tracks to false
            %ce stats are dbz
            ce_stats = track_stats(:,15);
            
            cell_init = ce_stats(1:end-1);
            cell_finl = ce_stats(2:end);
            
            ce_mask   = [0;and(cell_init<21,cell_finl>=21)]; %first cell is skipped, set to 0
            
            %cell_diff = [0;ce_stats(2:end)-ce_stats(1:end-1)]; %first cell is skipped, set to 0
            
%             if opt_struct.proc_opt(6)>0 %enhancement
%                 ce_mask   = cell_diff>=opt_struct.proc_opt(6);
%             else %dissipation
%                 ce_mask   = cell_diff<=opt_struct.proc_opt(6);
%             end
            plot_mask = logical(ce_mask);
        else %Plot cells
            plot_mask = logical(track_mask);
        end
        
        %% extract cell profile for 2D PDF plots
        plot_ind = find(plot_mask==1);
        if isempty(plot_ind)
            continue
        else
            for k=1:length(plot_ind)
                
            end
        end
        
        
        
        
        %keep plot mask for later stats analysis
        cell_pltmask_list       = [cell_pltmask_list;plot_mask];
        
        %now plotting doesn't have to worry about plot_opt
        track_ident      = curr_day_ident(track_ident_ind);
        try
        [grid_img_struct,dir_img_struct]  = proc_2dgrid(grid_img_struct,dir_img_struct,plot_mask,track_ident,opt_struct,spatial_data,curr_snd_fz_h);
        catch err
            keyboard
        end
    end
    
    %insert daily stats into cell array
    cell_stat_list{i}    = daily_stats;
end

%close bar
delete(h);

%save stats to struct

cell_stat_list = cell2mat(cell_stat_list);
stats_struct = struct('cell_date_list',cell_date_list,'cell_stat_list',cell_stat_list,'cell_trck_list',cell_trck_list,'cell_mask_list',cell_mask_list,...
    'cell_latloncent_list',cell_latloncent_list,'cell_pltmask_list',cell_pltmask_list,'cell_subsetid_list',cell_subsetid_list,...
    'cell_mesh_grid',cell_mesh_grid,'cell_latlonbox_list',cell_latlonbox_list);



function [grid_img_struct,dir_img_struct] = proc_2dgrid(grid_img_struct,dir_img_struct,plot_mask,track_ident,opt_struct,spatial_data,curr_snd_fz_h)

%initalise temp density grid
size_grid         = size(grid_img_struct.density_grid);
density_grid      = zeros(size_grid);
mean_density_grid = zeros(size_grid);

%CENTROIDS ONLY
if opt_struct.type_opt==5
    %extract track centroid list
    temp_list = vertcat(track_ident(plot_mask).dbz_latloncent);
    %append to cumulative list
    current_list = grid_img_struct.centroids_list;
    grid_img_struct.centroids_list = [temp_list;current_list];
%CALC MERGED DENSITY
elseif opt_struct.type_opt==4
    %cluster segments with bwlabel
    plot_label = bwlabel(plot_mask);
    %loop through segments
    for i=1:max(plot_label)
        
        %extract segment ident entries
        plot_label_ind = find(plot_label==i);
        plot_ident = track_ident(plot_label_ind);
        
        %create inital and final cell track pairs
        if length(plot_ident)>1
            init_ident     = plot_ident(1:end-1);
            finl_ident     = plot_ident(2:end);
            init_pair_mask = plot_label_ind(1:end-1);
            finl_pair_mask = plot_label_ind(2:end);
        else
            init_ident = plot_ident;
            finl_ident = plot_ident;
            init_pair_mask = plot_label_ind;
            finl_pair_mask = plot_label_ind;
        end
        
        for j=1:length(init_ident)
            %extract grid pair
            [~,bw_init_grid] = preprocess_grid(init_ident(j),opt_struct,size_grid,curr_snd_fz_h);
            [~,bw_finl_grid] = preprocess_grid(finl_ident(j),opt_struct,size_grid,curr_snd_fz_h);
            %calc hull
            temp_convhull = bwconvhull(bw_init_grid+bw_finl_grid);
            if sum(temp_convhull(:))>10000
                continue
            end
                
            %add to grid_img
            density_grid = density_grid + temp_convhull;
            %process direction data
            if opt_struct.dir_opt
                pair_mask      = unique([init_pair_mask(j),finl_pair_mask(j)]);
                dir_img_struct = process_dir_grid(dir_img_struct,track_ident,pair_mask,temp_convhull);
            end
        end
    end

else %CALC CELL DENSITY
    for i=1:length(plot_mask)
        if plot_mask(i) == 0
            continue
        else
            temp_ident = track_ident(i);
        end
        
        %extract correct grids and mask
        [temp_grid,bw_temp_grid] = preprocess_grid(temp_ident,opt_struct,size_grid,curr_snd_fz_h);
        %add to density grid 
        density_grid = density_grid + bw_temp_grid;
        %CALC STATS (if required)
        if opt_struct.type_opt==1 %MAX
            %cat wdss_grid and temp_grid in 3rd dimension
            temp_cat=cat(3,grid_img_struct.wdss_grid,temp_grid);
            %find max in third dimension
            grid_img_struct.wdss_grid = max(temp_cat,[],3);
        elseif opt_struct.type_opt==2 %MEAN
            %keep track of sum and use density to calc mean at end
            grid_img_struct.wdss_grid = grid_img_struct.wdss_grid + temp_grid;
            %keep track of total overlaps for mean calculation
            %(density_grid is normalised for every track
            grid_img_struct.mean_density_grid = grid_img_struct.mean_density_grid + bw_temp_grid;
        end

        %process direction data
        if opt_struct.dir_opt
            %calculate direction
            dir_img_struct = process_dir_grid(dir_img_struct,track_ident,i,bw_temp_grid);
        end
    end
end

%set track density grid to logical matrix
density_grid = density_grid>0;
%update track density
grid_img_struct.density_grid = grid_img_struct.density_grid + density_grid;


function [grid_out,density_out] = preprocess_grid(grid_ident,opt_struct,size_grid,curr_snd_fz_h)
%initalise grid
grid_out = zeros(size_grid);
%extract required grid
switch opt_struct.grid_opt
    case 1
        temp_grid = grid_ident.MESH_grid;
    case 2
        temp_grid = grid_ident.POSH_grid;
    case 3
        temp_grid = grid_ident.sts_h_grid;
        temp_grid(isnan(temp_grid)) = 0;
    case 4
        temp_grid = grid_ident.max_dbz_grid;
        temp_grid(temp_grid<0) = 0;
    case 5
        temp_grid = grid_ident.tops_h_grid;
        temp_grid(isnan(temp_grid)) = 0;
    case 6
        temp_grid = grid_ident.vil_grid;
end

%extract freezing level height if in sts sfc mode
if opt_struct.grid_opt == 3
    temp_grid        = temp_grid - curr_snd_fz_h;
end

%reassign to location in domain grid
subset_ijbox   = grid_ident.subset_ijbox;
i_min = subset_ijbox(1);
i_max = subset_ijbox(2);
j_min = subset_ijbox(3);
j_max = subset_ijbox(4);

%assign to correct lcoation in grid_out
grid_out(i_min:i_max,j_min:j_max) = temp_grid;

%extract grid bounds
grid_lower = opt_struct.proc_opt(2);
grid_upper = opt_struct.proc_opt(3);

%clamp grid
if ~isnan(grid_upper)
    grid_out(grid_out>=grid_upper) = grid_upper;
end

%create density grids for masking and capture
if ~isnan(grid_lower)
    density_out = grid_out >= grid_lower; %lower bound
else
    density_out = ~isnan(grid_out); %no mask
end
% %mask grid
grid_out    = grid_out.*density_out;

function dir_img_struct = process_dir_grid(dir_img_struct,track_ident,pair_ind,bw_mask)

%select valid pair of cells from track to generate direction
%for cell i
if length(pair_ind)==2 %pair selected
    init_ident = track_ident(pair_ind(1));
    finl_ident = track_ident(pair_ind(2));
elseif pair_ind == 1 %first cell direction needed, no pair
    init_ident = track_ident(pair_ind);
    finl_ident = track_ident(pair_ind+1);
else                 %~first cell direction needed, no pair
    init_ident = track_ident(pair_ind-1);
    finl_ident = track_ident(pair_ind);
end

%extract init and final edge coord
init_latloncent=init_ident.dbz_latloncent;
finl_latloncent=finl_ident.dbz_latloncent;
init_timedate=init_ident.start_timedate;
finl_timedate=finl_ident.start_timedate;

%calculate vector
[dist,az]       = distance(init_latloncent(:,1),init_latloncent(:,2),finl_latloncent(:,1),finl_latloncent(:,2));
dist            = deg2km(dist);
vel             = dist/((finl_timedate-init_timedate)*24);
az              = mod(90-az,360); %convert from compass to cartesian deg
az_u            = vel*cosd(az);
az_v            = vel*sind(az);

%apply to bw_mask to create u and v layers for current pair
temp_u_grid = bw_mask.*az_u;
temp_v_grid = bw_mask.*az_v;

%add to dir_img_struct
dir_img_struct.u_grid = dir_img_struct.u_grid + temp_u_grid;
dir_img_struct.v_grid = dir_img_struct.v_grid + temp_v_grid;
dir_img_struct.n_grid = dir_img_struct.n_grid + bw_mask;
