function wdss_tracking(tn_dt,tn_radar_id)
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
%updated track_db (saved to file)

%load vars
load('tmp/global.config.mat');

%% Load Databases
tn_radar_id_str   = num2str(tn_radar_id,'%02.0f');
tn_date_start     = floor(tn_dt);
tn_date_start_str = datestr(tn_date_start,'yyyy-mm-ddTHH:MM:SS');
tn_date_stop      = addtodate(tn_date_start+1,-1,'second');
tn_date_stop_str  = datestr(tn_date_stop,'yyyy-mm-ddTHH:MM:SS');
odimh5_p_exp      = 'start_timestamp';
storm_p_exp       = 'subset_id,start_timestamp,track_id,storm_dbz_centlat,storm_dbz_centlon,area,cell_vil';

%create correct archive folder
odimh5_jstruct         = ddb_query('radar_id',tn_radar_id_str,'start_timestamp',tn_date_start_str,tn_date_stop_str,odimh5_p_exp,odimh5_ddb_table);
odimh5_start_timestamp = datenum(jstruct_to_mat([odimh5_jstruct.start_timestamp],'S'),'yyyy-mm-ddTHH:MM:SS');

%extract storm items for the current day
storm_jstruct         = ddb_query('radar_id',tn_radar_id_str,'subset_id',tn_date_start_str,tn_date_stop_str,storm_p_exp,storm_ddb_table);
if isempty(storm_jstruct)
    return %no data is present
end

storm_subset_id       = jstruct_to_mat([storm_jstruct.subset_id],'S');

storm_start_timestamp = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),'yyyy-mm-ddTHH:MM:SS');
storm_lat             = jstruct_to_mat([storm_jstruct.storm_dbz_centlat],'N')./1000;
storm_lon             = jstruct_to_mat([storm_jstruct.storm_dbz_centlon],'N')./1000;
storm_track_id        = jstruct_to_mat([storm_jstruct.track_id],'N');
storm_area            = jstruct_to_mat([storm_jstruct.area],'N')./10;
storm_cell_vil        = jstruct_to_mat([storm_jstruct.area],'N')./10;

storm_db                 = struct;
storm_db.subset_id       = storm_subset_id;
storm_db.start_timestamp = storm_start_timestamp;
storm_db.lat             = storm_lat;
storm_db.lon             = storm_lon;
storm_db.track_id        = storm_track_id;
storm_db.area            = storm_area;
storm_db.cell_vil        = storm_cell_vil;

%init other cars
next_track_id         = max(storm_track_id)+1;
updated_storm_ind     = [];
%% Extract tn and tn1 cells

%check if sufficent scans exist
if length(odimh5_jstruct)<2
    %only one scan, cannot track
    return
else
    %if is more than 2 scans, extract scan dt prior to tn_dt (tn1_dt)
    temp_td             = tn_dt-odimh5_start_timestamp;
    last_scan_interval  = min(temp_td(temp_td>0));
    mode_scan_freq      = mode(minute(odimh5_start_timestamp(2:end)-odimh5_start_timestamp(1:end-1)))/60/24;
    max_search_distance = max_storm_speed*mode_scan_freq*24;
    tn1_dt              = tn_dt-last_scan_interval;
end

%check is last_Scan_internal is too long
if minute(last_scan_interval)>minute(mode_scan_freq)*2+1
    return
end

%case: reprocessing a database from the first time interval where many
%newer scans exist in it.
if isempty(tn1_dt)
    return
end

%extract ind of tn and tn1 cells from ident_db
tn1_storm_ind = find(storm_db.start_timestamp==tn1_dt);
tn_storm_ind  = find(storm_db.start_timestamp==tn_dt);

%skip if no tn1 ind or tn ind
if isempty(tn1_storm_ind) || isempty(tn_storm_ind)
    return
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
tn1_track_id = storm_track_id(tn1_storm_ind);

%find track_id for tn1 which exist more than once in storm_id (these are tracks)
tmp_mask                  = tn1_track_id~=0;
tn1_storm_ind_with_tracks = tn1_storm_ind(tmp_mask);

%loop through tn1 inds
for i=1:length(tn1_storm_ind)
    
    %case (1): tn1 has a simple track
    if ismember(tn1_storm_ind(i),tn1_storm_ind_with_tracks)
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_storm_ind(i),tn1_storm_ind(i),tn_dt,min_track_len,mode_scan_freq,storm_db);
    %case (2): a minimum of "min_tracks" from other cells have a track
    elseif length(tn1_storm_ind_with_tracks) >= min_other_track_cells
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_storm_ind(i),tn1_storm_ind_with_tracks,tn_dt,min_track_len,mode_scan_freq,storm_db);
    %case (3): use tn1 centroid and very large search area!  
    else
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_storm_ind(i),[],[],[],mode_scan_freq,storm_db);
    end
    
    %collate
    tn1_proj_lat    = [tn1_proj_lat;temp_proj_lat];
    tn1_proj_lon    = [tn1_proj_lon;temp_proj_lon];
    tn1_proj_azi    = [tn1_proj_azi;temp_proj_azi];
    tn1_search_dist = [tn1_search_dist;temp_search_dist];
    tn1_trck_len    = [tn1_trck_len;temp_trck_len];   
end

%% PLOT
%plot_wdss_tracking(radar_lat,radar_lon,storm_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

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
        updated_storm_ind                    = [updated_storm_ind;ist_asc_tn_ind(i)];
    else %assign new track_id
        storm_db.track_id(ist_asc_tn_ind(i))  = next_track_id;
        storm_db.track_id(ist_asc_tn1_ind(i)) = next_track_id;
        next_track_id                         = next_track_id+1;
        updated_storm_ind                     = [updated_storm_ind;ist_asc_tn_ind(i);ist_asc_tn1_ind(i)];
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
                updated_storm_ind                    = [updated_storm_ind;assoc_pass2_tn(i)];
            else %assign new track_id
                storm_db.track_id(assoc_pass2_tn(i))      = next_track_id;
                storm_db.track_id(temp_tn1(min_cost_ind)) = next_track_id;
                next_track_id                             = next_track_id+1;
                updated_storm_ind                         = [updated_storm_ind;assoc_pass2_tn(i);temp_tn1(min_cost_ind)];

            end
        end
    end
end
    
%update ddb
for i=1:length(updated_storm_ind)
    tmp_subset_id = storm_db.subset_id{updated_storm_ind(i)};
    tmp_track_id  = num2str(storm_db.track_id(updated_storm_ind(i)));
    ddb_update('radar_id','N',tn_radar_id_str,'subset_id','S',tmp_subset_id,'track_id','N',tmp_track_id,storm_ddb_table);
end

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
    cost_score(i) = ((tn_ind_lat(i)-tn1_ind_lat(i))^2+(tn_ind_lon(i)-tn1_ind_lon(i))^2)...
        + (tn1_ind_area(i)/pi) * ( (abs(tn_ind_area(i)-tn1_ind_area(i))...
        / max([tn_ind_area(i),tn1_ind_area(i)]))...
        + ((abs(tn_ind_vil(i)-tn1_ind_vil(i))/max([tn_ind_vil(i),tn1_ind_vil(i)]))) );
end

function plot_wdss_tracking(radar_lat,radar_lon,storm_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

figure('units','normalized','outerposition',[0 0 1 1])
hold on
worldmap([radar_lat-2, radar_lat+2],[radar_lon-2, radar_lon+2])
geoshow('landareas.shp', 'FaceColor', [0.5 1.0 0.5]);

[unique_track_id,~,ic]=unique(storm_db.track_id);

for i=1:length(unique_track_id);
    cent_lat = storm_db.lat(ic==i);
    cent_lon = storm_db.lon(ic==i);    
    plotm(cent_lat,cent_lon,'r')
end

for i=1:length(tn1_proj_lat);
    plotm(tn1_proj_lat(i),tn1_proj_lon(i),'bo');
    [lat,lon] = scircle1(tn1_proj_lat(i),tn1_proj_lon(i),km2deg(tn1_search_dist(i)));
    plotm(lat,lon,'k');
end

saveas(gcf,['images/',datestr(tn_dt),'.png'])

close all
