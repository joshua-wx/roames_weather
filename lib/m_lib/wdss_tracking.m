function wdss_tracking(dest_dir,tn_dt,tn_radar_id)
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
load('tmp_global_config.mat');
%set ident to global for sub functions usage
global ident_db
%FOR PLOTTING
% [site_id_list,site_lat_list,site_lon_list]=read_site_info;
% radar_lat=-site_lat_list(site_id_list==tn_radar_id);
% radar_lon=site_lon_list(site_id_list==tn_radar_id);
%% Load Databases

%create correct archive folder
date_tag=datevec(floor(tn_dt));
archive_dest=[dest_dir,'IDR',num2str(tn_radar_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/'];

%create db filenames
ident_db_fn=[archive_dest,'ident_db_',datestr(tn_dt,'dd-mm-yyyy'),'.mat'];
intp_db_fn=[archive_dest,'intp_db_',datestr(tn_dt,'dd-mm-yyyy'),'.mat'];

%load ident_db
if exist(ident_db_fn,'file')==2 && exist(intp_db_fn,'file')==2
    ident_db=mat_wrapper(ident_db_fn,'ident_db');
    intp_db=mat_wrapper(intp_db_fn,'intp_db');
else
    %missing databases!
    return
end

%% Extract tn and tn1 cells

%check if sufficent scans exist
if length(intp_db)<2
    %only one scan, cannot track
    return
else
    %if is more than 2 scans, extract scan dt prior to tn_dt (tn1_dt)
    intp_td=vertcat(intp_db.start_timedate);
    temp_td=tn_dt-intp_td;
    last_scan_interval=min(temp_td(temp_td>0));
    mode_scan_freq=mode(minute(intp_td(2:end)-intp_td(1:end-1)))/60/24;
    max_search_distance=max_storm_speed*mode_scan_freq*24;
    tn1_dt=tn_dt-last_scan_interval;
end

%check is last_Scan_internal is too long
if minute(last_scan_interval)>minute(mode_scan_freq)*2+1
    return
end

%     intp_td=vertcat(intp_db.start_timedate);
%     intp_td_diff_minute=minute(intp_td(2:end)-intp_td(1:end-1)); %calculate timesteps in minutes
%     scan_freq=mode(intp_td_diff_minute)/60/24; %find the mode to remove any anomalies and convert back to datenum format
%     max_search_distance=max_storm_speed*scan_freq*24;
%     tn1_dt=tn_dt-scan_freq;
% WHAT HAPPENS WHEN FRAME IS SKIPPED? SHOULD SET TO MAX OF 20MIN BEFORE
% RETURN IS PASSED

%case: reprocessing a database from the first time interval where many
%newer scans exist in it.
if isempty(tn1_dt)
    return
end

%extract ind of tn and tn1 cells from ident_db
tn1_ident_ind=find([ident_db.start_timedate]==tn1_dt);
tn_ident_ind=find([ident_db.start_timedate]==tn_dt);

%skip if no tn1 ind or tn ind
if isempty(tn1_ident_ind) || isempty(tn_ident_ind)
    return
end

%extract tn lat lon centroids
ident_latloncent=vertcat(ident_db.dbz_latloncent);
ident_lat=ident_latloncent(:,1);
ident_lon=ident_latloncent(:,2);

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
tn1_ident_ind_with_tracks = [];

%extract simple_ids
ident_simple_id= vertcat(ident_db.simple_id);
tn1_simple_id = ident_simple_id(tn1_ident_ind);

%find simple_id for tn1 which exist more than once in ident_id (these are tracks)
for i=1:length(tn1_simple_id)
    if sum(tn1_simple_id(i)==ident_simple_id)>1
        tn1_ident_ind_with_tracks = [tn1_ident_ind_with_tracks;tn1_ident_ind(i)];
    end
end

%loop through tn1 inds
for i=1:length(tn1_ident_ind)
    
    %     if ident_db(tn1_ident_ind(i)).index==165
%         keyboard
%     end
    %case (1): tn1 has a simple track
    if ismember(tn1_ident_ind(i),tn1_ident_ind_with_tracks)
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_ident_ind(i),tn1_ident_ind(i),tn_dt,min_track_len,mode_scan_freq,ident_db);
    %case (2): a minimum of "min_tracks" from other cells have a track
    elseif length(tn1_ident_ind_with_tracks) >= min_other_track_cells
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_ident_ind(i),tn1_ident_ind_with_tracks,tn_dt,min_track_len,mode_scan_freq,ident_db);
    %case (3): use tn1 centroid and very large search area!  
    else
        [temp_proj_lat,temp_proj_lon,temp_proj_azi,temp_search_dist,temp_trck_len] = project_storm(tn1_ident_ind(i),[],[],[],mode_scan_freq,ident_db);
    end
    
    %collate
    tn1_proj_lat    = [tn1_proj_lat;temp_proj_lat];
    tn1_proj_lon    = [tn1_proj_lon;temp_proj_lon];
    tn1_proj_azi    = [tn1_proj_azi;temp_proj_azi];
    tn1_search_dist = [tn1_search_dist;temp_search_dist];
    tn1_trck_len    = [tn1_trck_len;temp_trck_len];   
end

%% PLOT
%plot_wdss_tracking(radar_lat,radar_lon,ident_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

%% Sort by track len

%[~,sort_ind]    = sort(tn1_trck_len,'descend');
temp_stats      = vertcat(ident_db(tn1_ident_ind).stats);
[~,sort_ind]    = sort(temp_stats(:,11),'descend');
tn1_proj_lat    = tn1_proj_lat(sort_ind);
tn1_proj_lon    = tn1_proj_lon(sort_ind);
tn1_proj_azi    = tn1_proj_azi(sort_ind);
tn1_search_dist = tn1_search_dist(sort_ind);
tn1_ident_ind   = tn1_ident_ind(sort_ind);

%% Identify centroids at tn which are within search_dist of tn1_proj cells

ist_asc_tn1_ind=[]; ist_asc_tn_ind=[]; 

for i=1:length(tn1_ident_ind)
    %calculate distance between ith proj tn1 lat lon and all test tn lat lons
    repmat_proj_tn1_lat = repmat(tn1_proj_lat(i),length(tn_ident_ind),1);
    repmat_proj_tn1_lon = repmat(tn1_proj_lon(i),length(tn_ident_ind),1);
    [proj_arclen,~]     = distance(repmat_proj_tn1_lat,repmat_proj_tn1_lon,ident_lat(tn_ident_ind),ident_lon(tn_ident_ind));
    test_dist           = deg2km(proj_arclen);

    %calculate azi between ith tn1 lat lon and all test tn lat lons
    repmat_tn1_lat = repmat(ident_db(tn1_ident_ind(i)).dbz_latloncent(1),length(tn_ident_ind),1);
    repmat_tn1_lon = repmat(ident_db(tn1_ident_ind(i)).dbz_latloncent(2),length(tn_ident_ind),1);
    tn1_tn_azi     = azimuth(repmat_tn1_lat,repmat_tn1_lon,ident_lat(tn_ident_ind),ident_lon(tn_ident_ind));

    %find wrapped abs difference between proj angle and test tn tn1
    %association
    temp_angle_diff=abs(tn1_proj_azi(i)-tn1_tn_azi);
    wrapped_angle_diff=min(temp_angle_diff,360-temp_angle_diff);
    %filter tn's to those inside the ith tn1 search radius
    temp_ind=find(test_dist<=tn1_search_dist(i) & or(wrapped_angle_diff<=azi_diff,isnan(tn1_proj_azi(i))));
    result_tn_ident_ind=tn_ident_ind(temp_ind);
%     
%     if ident_db(tn1_ident_ind(i)).index==198
%         keyboard
%     end
    
    %case: keep UNIQUE cell pairs (1 tn, 1 tn1)
    if length(result_tn_ident_ind)==1 && ~ismember(result_tn_ident_ind,ist_asc_tn_ind)
        ist_asc_tn1_ind=[ist_asc_tn1_ind;tn1_ident_ind(i)];
        ist_asc_tn_ind=[ist_asc_tn_ind;result_tn_ident_ind];
    end
end
%% save pass1 associations
for i=1:length(ist_asc_tn1_ind)
        ident_db(ist_asc_tn_ind(i)).simple_id=ident_db(ist_asc_tn1_ind(i)).simple_id;
        %ident_db(ist_asc_tn_ind(i)).complex_id=ident_db(ist_asc_tn1_ind(i)).complex_id;
end

%% remove ind from tn1 and tn which have been associated

%create mask of elements of ident_ind not in asc_ind
tn_keep_mask = ~ismember(tn_ident_ind,ist_asc_tn_ind);
tn1_keep_mask = ~ismember(tn1_ident_ind,ist_asc_tn1_ind);

%remove ind used in pass1
tn_ident_ind  = tn_ident_ind(tn_keep_mask);
tn1_ident_ind = tn1_ident_ind(tn1_keep_mask);
tn1_proj_lat  = tn1_proj_lat(tn1_keep_mask);
tn1_proj_lon  = tn1_proj_lon(tn1_keep_mask);
tn1_proj_azi  = tn1_proj_azi(tn1_keep_mask);

%% for unassociated tn, identify all tn1 within dn km (sqrt(An/pi)).
if ~isempty(tn1_ident_ind) && ~isempty(tn_ident_ind)
    pass2_tn1_ind=[];
    pass2_tn1_proj_lat=[];
    pass2_tn1_proj_lon=[];
    pass2_tn_ind=[];

    for i=1:length(tn_ident_ind)
        %calculate tn search radius
        search_radius=max_search_distance;%ceil(sqrt(ident_db(tn_ident_ind(i)).stats(2)/pi));
        %if search_radius>max_search_distance; search_radius=max_search_distance; end
        
        %build repmat tn for distance fun calculate distance between tn_ident_ind and all repmat_tn1
        repmat_tn_lat=repmat(ident_lat(tn_ident_ind(i)),length(tn1_ident_ind),1);
        repmat_tn_lon=repmat(ident_lon(tn_ident_ind(i)),length(tn1_ident_ind),1);
        [arclen,~] = distance(tn1_proj_lat,tn1_proj_lon,repmat_tn_lat,repmat_tn_lon);
        test_dist=deg2km(arclen);
        
        %calculate azi between ith tn lat lon and all test tn1 lat lons
        tn1_latloncent=vertcat(ident_db(tn1_ident_ind).dbz_latloncent);
        tn1_tn_azi = azimuth(tn1_latloncent(:,1),tn1_latloncent(:,2),repmat_tn_lat,repmat_tn_lon);
        
        %find wrapped abs difference between proj angle and test tn tn1
        %association
        temp_angle_diff=abs(tn1_proj_azi-tn1_tn_azi);
        wrapped_angle_diff=min(temp_angle_diff,360-temp_angle_diff);
        %filter tn1's to those inside the search radius of the ith tn with
        %the azi criteria
        tn1_temp_ind=find(test_dist<=search_radius & or(wrapped_angle_diff<=azi_diff,isnan(tn1_proj_azi)));

        %subset into pass2 data
        result_tn1_ident_ind=tn1_ident_ind(tn1_temp_ind);
        repmat_tn_ident_ind=repmat(tn_ident_ind(i),length(result_tn1_ident_ind),1);
        pass2_tn1_ind=[pass2_tn1_ind;result_tn1_ident_ind'];
        pass2_tn1_proj_lat=[pass2_tn1_proj_lat;tn1_proj_lat(tn1_temp_ind)];
        pass2_tn1_proj_lon=[pass2_tn1_proj_lon;tn1_proj_lon(tn1_temp_ind)];
        pass2_tn_ind=[pass2_tn_ind;repmat_tn_ident_ind];
    end

    if ~isempty(pass2_tn1_ind)
        %apply cost function to all in this set
        %NOTE THE PAIRED INPUT REQUIRED BY cost_function creates duplicates
        %of tn, duplicates of tn1 also exists are these are paired with a
        %tn according to the search radius criteria
        pass2_cost=cost_function(pass2_tn_ind,pass2_tn1_ind,pass2_tn1_proj_lat,pass2_tn1_proj_lon);
        %for each unique pass_2_tn1, find min pass2_cost_tn1 and assoicated
        %pass2_tn entry (multiple tn1 for each tn)
        [sort_pass2_tn1,~,ic]=unique(pass2_tn1_ind);
        sort_pass2_tn=zeros(length(sort_pass2_tn1),1);
        sort_pass2_cost=zeros(length(sort_pass2_tn1),1);
        for i=1:length(sort_pass2_tn1)
            temp_tn=pass2_tn_ind(ic==i);
            temp_cost=pass2_cost(ic==i);
            [min_cost,min_cost_ind]=min(temp_cost);
            sort_pass2_tn(i)=temp_tn(min_cost_ind);
            sort_pass2_cost(i)=min_cost;
        end

        %for each unique sort_pass2_tn, find tn1 entry with min cost and remove others (in
        %tn and cost). This removes duplicates created for pairing in cost
        %function.
        [assoc_pass2_tn,~,ic]=unique(sort_pass2_tn);
        for i=1:length(assoc_pass2_tn)
            temp_tn1=sort_pass2_tn1(ic==i);
            temp_cost=sort_pass2_cost(ic==i);
            [~,min_cost_ind]=min(temp_cost);
            ident_db(assoc_pass2_tn(i)).simple_id=ident_db(temp_tn1(min_cost_ind)).simple_id;
        end
    end
end
    
%write ident_db
mat_wrapper(ident_db_fn,'ident_db',ident_db);

function cost_score=cost_function(tn_ident_ind,tn1_ident_ind,tn1_proj_lat,tn1_proj_lon)
%WHAT: Calculates cost function for every tn1_ident_ind : tn_ident_ind
%pair. Both input vectors must be of equal length.

%INPUT: index of tn and tn1 pairs from ident_ind

%OUTPUT: cost_score of pairs using function defined in paper (see header)
global ident_db

%set inital cost to infinte
cost_score=inf(length(tn1_ident_ind),1);

%extract variables for tn
tn_ind_latloncent=vertcat(ident_db(tn_ident_ind).dbz_latloncent);
tn_ind_lat=tn_ind_latloncent(:,1);
tn_ind_lon=tn_ind_latloncent(:,2);
tn_stats=vertcat(ident_db(tn_ident_ind).stats);
tn_ind_area=tn_stats(:,3);
tn_ind_vil=tn_stats(:,11);

%extract variables for tn1
%tn1_ind_latloncent=vertcat(ident_db(tn1_ident_ind).dbz_latloncent);
%tn1_ind_lat=tn1_ind_latloncent(:,1);
%tn1_ind_lon=tn1_ind_latloncent(:,2);
tn1_ind_lat=tn1_proj_lat;
tn1_ind_lon=tn1_proj_lon;
tn1_stats=vertcat(ident_db(tn1_ident_ind).stats);
tn1_ind_area=tn1_stats(:,3);
tn1_ind_vil=tn1_stats(:,11);

%calculate cost score for every pair
for i=1:length(tn1_ident_ind)
    cost_score(i)=((tn_ind_lat(i)-tn1_ind_lat(i))^2+(tn_ind_lon(i)-tn1_ind_lon(i))^2) + (tn1_ind_area(i)/pi) * ( (abs(tn_ind_area(i)-tn1_ind_area(i))/max([tn_ind_area(i),tn1_ind_area(i)]))+((abs(tn_ind_vil(i)-tn1_ind_vil(i))/max([tn_ind_vil(i),tn1_ind_vil(i)]))) );
end

function plot_wdss_tracking(radar_lat,radar_lon,ident_db,tn1_proj_lat,tn1_proj_lon,tn1_search_dist,tn_dt)

figure('units','normalized','outerposition',[0 0 1 1])
hold on
worldmap([radar_lat-2, radar_lat+2],[radar_lon-2, radar_lon+2])
geoshow('landareas.shp', 'FaceColor', [0.5 1.0 0.5]);

[unique_simple_id,~,ic]=unique([ident_db.simple_id]);

for i=1:length(unique_simple_id);
    centroid_deg=vertcat(ident_db(ic==i).dbz_latloncent);
    plotm(centroid_deg(:,1),centroid_deg(:,2),'r')
end

for i=1:length(tn1_proj_lat);
    plotm(tn1_proj_lat(i),tn1_proj_lon(i),'bo');
    [lat,lon] = scircle1(tn1_proj_lat(i),tn1_proj_lon(i),km2deg(tn1_search_dist(i)));
    plotm(lat,lon,'k');
end

saveas(gcf,['images/',datestr(tn_dt),'.png'])

close all
