function tracking_id_out = nowcast_wdss_tracking(storm_jstruct,vol_struct)
%WHAT: For the curr dt and curr radar id, the assocaited cells in
%ident are checks using nn and forecasting methods for temporal and spatial
%association with other cells in ident. Tracks are compiled using ident id
%and storaged in track_ind. Tracks can also be merged.

%PAPER: An Objective Method for Evalusation and Devising Storm-Tracking
%algorithms. Lakshmanan and Smith, April 2010, Weather and Forecasting

%INPUT:
%dest_dir: archive root path
%tn_dt: dt of tn cells
%tn_radar_id: radar ids of tn cells

%OUTPUT:
%storm_jstruct (with updated track ids

%load vars
load('tmp/global.config.mat');
%new vars
tracking_id_out = [];
%abort as necessary
if length(vol_struct)<2
    %only one scan, cannot track
    return
end

%% Load vars
%jstruct vars
storm_radar_id           = jstruct_to_mat([storm_jstruct.radar_id],'N');
storm_subset_id          = jstruct_to_mat([storm_jstruct.subset_id],'N');
storm_start_timestamp    = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),'yyyy-mm-ddTHH:MM:SS');
storm_lat                = jstruct_to_mat([storm_jstruct.storm_dbz_centlat],'N');
storm_lon                = jstruct_to_mat([storm_jstruct.storm_dbz_centlon],'N');
storm_area               = jstruct_to_mat([storm_jstruct.area],'N');
storm_cell_vil           = jstruct_to_mat([storm_jstruct.area],'N');
%move into struct
storm_db                 = struct;
storm_db.radar_id        = storm_radar_id;
storm_db.subset_id       = storm_subset_id;
storm_db.start_timestamp = storm_start_timestamp;
storm_db.lat             = storm_lat;
storm_db.lon             = storm_lon;
storm_db.track_id        = zeros(length(storm_jstruct),1);
storm_db.area            = storm_area;
storm_db.cell_vil        = storm_cell_vil;

next_track_id            = 1;
%needs to loop by sorted timestamps, tracking applied for all cells in a
%shared timestep (tn1). tn cells are filtered by cells in the future?
%remember the differing timesteps between radars!

%% Loop through unique timestamps
uniq_start_timestamp = unique(storm_start_timestamp);
for j=1:length(uniq_start_timestamp)

    %extract ind of tn and tn1 cells from ident_db
    tn_dt         = uniq_start_timestamp(j);
    tn_storm_ind  = find(storm_db.start_timestamp==tn_dt);
    tn1_storm_ind = tn1_search(storm_db,vol_struct,tn_dt);
    
    %skip if no tn1 ind or tn ind
    if isempty(tn1_storm_ind) || isempty(tn_storm_ind)
        continue
    end

    %% Project cells identified in tn1 to their expected locations in tn
    % if the ith tn1 cell is part of a track, then use this track to forecast
    % centroid elseif there are other tracks other than tn1, use their tracks to
    % forecast centroid else, use broad search radius

    %initalise stacks
    tn1_proj_lat    = [];
    tn1_proj_lon    = [];
    tn1_proj_azi    = [];
    tn1_search_dist = [];
    tn1_trck_len    = [];
    tn1_storm_ind_with_tracks = [];

    %extract simple_ids
    storm_track_id = storm_db.track_id;
    tn1_track_id   = storm_track_id(tn1_storm_ind);

    %find track_id for tn1 which exist more than once in storm_id (these are tracks)
    tmp_mask                  = tn1_track_id~=0;
    tn1_storm_ind_with_tracks = tn1_storm_ind(tmp_mask);

    %loop through tn1 inds
    for i=1:length(tn1_storm_ind)

        %case (1): tn1 has a simple track
        if ismember(tn1_storm_ind(i),tn1_storm_ind_with_tracks)
            [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = nowcast_wdss_tracking_project(tn1_storm_ind(i),tn1_storm_ind(i),tn_dt,min_track_len,storm_db);
        %case (2): a minimum of "min_tracks" from other cells have a track
        elseif length(tn1_storm_ind_with_tracks) >= min_other_track_cells
            [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = nowcast_wdss_tracking_project(tn1_storm_ind(i),tn1_storm_ind_with_tracks,tn_dt,min_track_len,storm_db);
        %case (3): use tn1 centroid and very large search area!  
        else
            [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = nowcast_wdss_tracking_project(tn1_storm_ind(i),[],[],[],storm_db);
        end

        %collate
        tn1_proj_lat    = [tn1_proj_lat;temp_proj_lat];
        tn1_proj_lon    = [tn1_proj_lon;temp_proj_lon];
        tn1_proj_azi    = [tn1_proj_azi;temp_proj_azi];
        tn1_search_dist = [tn1_search_dist;temp_search_dist];
        tn1_trck_len    = [tn1_trck_len;temp_trck_len];   
    end

    %% PLOT
    %plot_wdss_tracking(-28.3,153,storm_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

    %% Sort by track len

    %[~,sort_ind]    = sort(tn1_trck_len,'descend');
    temp_sort_vec   = storm_db.cell_vil(tn1_storm_ind);
    [~,sort_ind]    = sort(temp_sort_vec,'descend');
    tn1_proj_lat    = tn1_proj_lat(sort_ind);
    tn1_proj_lon    = tn1_proj_lon(sort_ind);
    tn1_proj_azi    = tn1_proj_azi(sort_ind);
    tn1_search_dist = tn1_search_dist(sort_ind);
    tn1_storm_ind   = tn1_storm_ind(sort_ind);

    %% stormify centroids at tn which are within search_dist of tn1_proj cells

    ist_asc_tn1_ind=[]; ist_asc_tn_ind=[]; 

    for i=1:length(tn1_storm_ind)
        %calculate distance between ith proj tn1 lat lon and all test tn lat lons
        repmat_proj_tn1_lat = repmat(tn1_proj_lat(i),length(tn_storm_ind),1);
        repmat_proj_tn1_lon = repmat(tn1_proj_lon(i),length(tn_storm_ind),1);
        [proj_arclen,~]     = distance(repmat_proj_tn1_lat,repmat_proj_tn1_lon,storm_lat(tn_storm_ind),storm_lon(tn_storm_ind));
        test_dist           = deg2km(proj_arclen);

        %calculate azi between ith tn1 lat lon and all test tn lat lons
        repmat_tn1_lat = repmat(storm_db.lat((tn1_storm_ind(i))),length(tn_storm_ind),1);
        repmat_tn1_lon = repmat(storm_db.lon((tn1_storm_ind(i))),length(tn_storm_ind),1);
        tn1_tn_azi     = azimuth(repmat_tn1_lat,repmat_tn1_lon,storm_lat(tn_storm_ind),storm_lon(tn_storm_ind));

        %find wrapped abs difference between proj angle and test tn tn1
        %association
        temp_angle_diff     = abs(tn1_proj_azi(i)-tn1_tn_azi);
        wrapped_angle_diff  = min(temp_angle_diff,360-temp_angle_diff);
        %filter tn's to those inside the ith tn1 search radius
        temp_ind            = find(test_dist<=tn1_search_dist(i) & or(wrapped_angle_diff<=azi_diff,isnan(tn1_proj_azi(i))));
        result_tn_storm_ind = tn_storm_ind(temp_ind);

        %case: keep UNIQUE cell pairs (1 tn, 1 tn1)
        if length(result_tn_storm_ind)==1 && ~ismember(result_tn_storm_ind,ist_asc_tn_ind)
            ist_asc_tn1_ind=[ist_asc_tn1_ind;tn1_storm_ind(i)];
            ist_asc_tn_ind=[ist_asc_tn_ind;result_tn_storm_ind];
        end
    end
    %% save pass1 associations
    for i=1:length(ist_asc_tn1_ind)
        if storm_db.track_id(ist_asc_tn1_ind(i))~= 0 %assigned associated track_id
            storm_db.track_id(ist_asc_tn_ind(i)) = storm_db.track_id(ist_asc_tn1_ind(i));
        else %assign new track_id
            storm_db.track_id(ist_asc_tn_ind(i))  = next_track_id;
            storm_db.track_id(ist_asc_tn1_ind(i)) = next_track_id;
            next_track_id                         = next_track_id+1;
        end
    end

    %% remove ind from tn1 and tn which have been associated

    %create mask of elements of storm_ind not in asc_ind
    tn_keep_mask  = ~ismember(tn_storm_ind,ist_asc_tn_ind);
    tn1_keep_mask = ~ismember(tn1_storm_ind,ist_asc_tn1_ind);

    %remove ind used in pass1
    tn_storm_ind  = tn_storm_ind(tn_keep_mask);
    tn1_storm_ind = tn1_storm_ind(tn1_keep_mask);
    tn1_proj_lat  = tn1_proj_lat(tn1_keep_mask);
    tn1_proj_lon  = tn1_proj_lon(tn1_keep_mask);
    tn1_proj_azi  = tn1_proj_azi(tn1_keep_mask);

    %% for unassociated tn, stormify all tn1 within dn km (sqrt(An/pi)).
    if ~isempty(tn1_storm_ind) && ~isempty(tn_storm_ind)
        pass2_tn1_ind      = [];
        pass2_tn1_proj_lat = [];
        pass2_tn1_proj_lon = [];
        pass2_tn_ind       = [];

        for i=1:length(tn_storm_ind)
            %calculate tn search radius
            search_radius = max_search_distance;%ceil(sqrt(storm_db(tn_storm_ind(i)).stats(2)/pi));
            %if search_radius>max_search_distance; search_radius=max_search_distance; end

            %build repmat tn for distance fun calculate distance between tn_storm_ind and all repmat_tn1
            repmat_tn_lat = repmat(storm_lat(tn_storm_ind(i)),length(tn1_storm_ind),1);
            repmat_tn_lon = repmat(storm_lon(tn_storm_ind(i)),length(tn1_storm_ind),1);
            [arclen,~]    = distance(tn1_proj_lat,tn1_proj_lon,repmat_tn_lat,repmat_tn_lon);
            test_dist     = deg2km(arclen);

            %calculate azi between ith tn lat lon and all test tn1 lat lons
            tn1_lat        = storm_db.lat(tn1_storm_ind);
            tn1_lon        = storm_db.lon(tn1_storm_ind);
            tn1_tn_azi     = azimuth(tn1_lat,tn1_lon,repmat_tn_lat,repmat_tn_lon);

            %find wrapped abs difference between proj angle and test tn tn1
            %association
            temp_angle_diff    = abs(tn1_proj_azi-tn1_tn_azi);
            wrapped_angle_diff = min(temp_angle_diff,360-temp_angle_diff);
            %filter tn1's to those inside the search radius of the ith tn with
            %the azi criteria
            tn1_temp_ind       = find(test_dist<=search_radius & or(wrapped_angle_diff<=azi_diff,isnan(tn1_proj_azi)));

            %subset into pass2 data
            result_tn1_storm_ind = tn1_storm_ind(tn1_temp_ind);
            repmat_tn_storm_ind  = repmat(tn_storm_ind(i),length(result_tn1_storm_ind),1);
            pass2_tn1_ind        = [pass2_tn1_ind;result_tn1_storm_ind];
            pass2_tn1_proj_lat   = [pass2_tn1_proj_lat;tn1_proj_lat(tn1_temp_ind)];
            pass2_tn1_proj_lon   = [pass2_tn1_proj_lon;tn1_proj_lon(tn1_temp_ind)];
            pass2_tn_ind         = [pass2_tn_ind;repmat_tn_storm_ind];
        end

        if ~isempty(pass2_tn1_ind)
            %apply cost function to all in this set
            %NOTE THE PAIRED INPUT REQUIRED BY cost_function creates duplicates
            %of tn, duplicates of tn1 also exists are these are paired with a
            %tn according to the search radius criteria
            pass2_cost = cost_function(pass2_tn_ind,pass2_tn1_ind,pass2_tn1_proj_lat,pass2_tn1_proj_lon,storm_db);
            %for each unique pass_2_tn1, find min pass2_cost_tn1 and assoicated
            %pass2_tn entry (multiple tn1 for each tn)
            [sort_pass2_tn1,~,ic] = unique(pass2_tn1_ind);
            sort_pass2_tn         = zeros(length(sort_pass2_tn1),1);
            sort_pass2_cost       = zeros(length(sort_pass2_tn1),1);
            for i=1:length(sort_pass2_tn1)
                temp_tn                 = pass2_tn_ind(ic==i);
                temp_cost               = pass2_cost(ic==i);
                [min_cost,min_cost_ind] = min(temp_cost);
                sort_pass2_tn(i)        = temp_tn(min_cost_ind);
                sort_pass2_cost(i)      = min_cost;
            end

            %for each unique sort_pass2_tn, find tn1 entry with min cost and remove others (in
            %tn and cost). This removes duplicates created for pairing in cost
            %function.
            [assoc_pass2_tn,~,ic] = unique(sort_pass2_tn);

            for i=1:length(assoc_pass2_tn)
                temp_tn1          = sort_pass2_tn1(ic==i);
                temp_cost         = sort_pass2_cost(ic==i);
                [~,min_cost_ind]  = min(temp_cost);
                %uodate track_id
                if storm_db.track_id(temp_tn1(min_cost_ind))~= 0 %assigned associated track_id
                    storm_db.track_id(assoc_pass2_tn(i)) = storm_db.track_id(temp_tn1(min_cost_ind));
                else %assign new track_id
                    storm_db.track_id(assoc_pass2_tn(i))      = next_track_id;
                    storm_db.track_id(temp_tn1(min_cost_ind)) = next_track_id;
                    next_track_id                             = next_track_id+1;
                end
            end
        end
    end
end
    
%output
tracking_id_out = storm_db.track_id;


function cost_score=cost_function(tn_storm_ind,tn1_storm_ind,tn1_proj_lat,tn1_proj_lon,storm_db)
%WHAT: Calculates cost function for every tn1_storm_ind : tn_storm_ind
%pair. Both input vectors must be of equal length.

%INPUT: index of tn and tn1 pairs from storm_ind

%OUTPUT: cost_score of pairs using function defined in paper (see header)


%set inital cost to infinte
cost_score=inf(length(tn1_storm_ind),1);

%extract variables for tn
tn_ind_lat  = storm_db.lat(tn_storm_ind);
tn_ind_lon  = storm_db.lon(tn_storm_ind);
tn_ind_area = storm_db.area(tn_storm_ind);
tn_ind_vil  = storm_db.cell_vil(tn_storm_ind);

%extract variables for tn1
tn1_ind_lat  = tn1_proj_lat;
tn1_ind_lon  = tn1_proj_lon;
tn1_ind_area = storm_db.area(tn1_storm_ind);
tn1_ind_vil  = storm_db.cell_vil(tn1_storm_ind);

%calculate cost score for every pair
for i=1:length(tn1_storm_ind)
    cost_score(i) = ((tn_ind_lat(i)-tn1_ind_lat(i))^2+(tn_ind_lon(i)-tn1_ind_lon(i))^2) +...
        (tn1_ind_area(i)/pi) * ( (abs(tn_ind_area(i)-tn1_ind_area(i)) /...
        max([tn_ind_area(i),tn1_ind_area(i)])) +...
        ((abs(tn_ind_vil(i)-tn1_ind_vil(i))/max([tn_ind_vil(i),tn1_ind_vil(i)]))) );
end

function tn1_storm_ind = tn1_search(storm_db,vol_struct,tn_timestamp)
tn1_storm_ind = [];

%loop through radars in storm_db
radar_id_list  = [storm_db.radar_id];
timestamp_list = [storm_db.start_timestamp];
uniq_radar_id_list = unique(radar_id_list);
for i=1:length(uniq_radar_id_list)
    target_radar_id  = uniq_radar_id_list(i);
    %find timesteps from target_radar_id
    target_ind            = find(radar_id_list==target_radar_id);
    target_timesteps      = timestamp_list(target_ind);
    uniq_target_timesteps = unique(target_timesteps);
    %find tn1 timestep
    time_mask             = uniq_target_timesteps<tn_timestamp;
    tn1_timestamp         = max(uniq_target_timesteps(time_mask));
    if isempty(tn1_timestamp)
        continue
    end
    %check if the tn1 and tn step is too large
    radar_step            = calc_radar_step(vol_struct,target_radar_id);
    if minute(tn_timestamp-tn1_timestamp) > (radar_step*2)+1
        continue
    end
    %add target_ind entries where target_timesteps = tn1_timestamp
    tmp_tn1 = target_ind(target_timesteps==tn1_timestamp);
    tn1_storm_ind = [tn1_storm_ind;tmp_tn1];
end



function plot_wdss_tracking(radar_lat,radar_lon,storm_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

figure('units','normalized','outerposition',[0 0 1 1])
hold on
worldmap([radar_lat-2, radar_lat+2],[radar_lon-2, radar_lon+2])
geoshow('landareas.shp', 'FaceColor', [0.5 1.0 0.5]);

[unique_track_id,~,ic]=unique(storm_db.track_id);

for i=1:length(unique_track_id)
    if unique_track_id(i)==0
        continue
    end
    cent_lat = storm_db.lat(ic==i);
    cent_lon = storm_db.lon(ic==i);    
    plotm(cent_lat,cent_lon,'r')
end

for i=1:length(tn1_proj_lat)
    plotm(tn1_proj_lat(i),tn1_proj_lon(i),'bo');
    [lat,lon] = scircle1(tn1_proj_lat(i),tn1_proj_lon(i),km2deg(tn1_search_dist(i)));
    plotm(lat,lon,'k');
end

saveas(gcf,['tmp/img/',datestr(tn_dt),'.png'])

close all
