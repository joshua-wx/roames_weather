function [proj_lat,proj_lon,proj_azi,search_dist,track_length]=nowcast_wdss_tracking_project(tn1_target_ind,tn1_track_ind,tn_dt,proj_min_track_len,storm_db,tn1_radar_step)
%WHAT: Generates a projected lat lon from the init lat lon (ind given by
%tn1_target_ind) using the mean of the proj arc/azi for time tn_dt from tn1
%tracks (given by tn1_track_ind). If no projection can be generated a
%default search distance is returned.
%Designed to only work on linear simple tracks.

%INPUT:
%tn1_target_ind: Index in storm_db of target inital cell to project
%tn1_track_ind: Index(s) in storm_db of cells to generate fits from
%tn_dt: time to generate projection for
%proj_min_track_len: minimum number of cells in a track to generate a fit 
%storm_db: storm_db containing all cells and tracks

%OUTPUT:
%proj_lat: projection of init lat at tn_dt using a linear fit of tn1_track_ind lat(s)
%proj_lon: projection of init lon at tn_dt using a linear fit of tn1_track_ind lon(s)
%search_dist: search radius around projected cell
%track_length: length of simple track

%blank vars
proj_lat     = [];
proj_lon     = [];
proj_azi     = [];
proj_arc     = [];
search_dist  = [];

load('tmp/global.config.mat');

%Search Radius and track length
max_search_distance = max_storm_speed*tn1_radar_step/24;
%extact init lat and lon
init_lat            = storm_db.lat(tn1_target_ind);
init_lon            = storm_db.lon(tn1_target_ind);

%loop through each end cell
for i=1:length(tn1_track_ind)
    
    %decompose end cell track
    tn1_simple_id       = storm_db.track_id(tn1_track_ind(i));
    tn1_start_timestamp = storm_db.start_timestamp(tn1_track_ind(i));
    trck_ind            = find(storm_db.track_id==tn1_simple_id & storm_db.start_timestamp<=tn1_start_timestamp);
    %sort track index to time
    [~,sort_ix]         = sort(storm_db.start_timestamp(trck_ind));
    trck_ind            = trck_ind(sort_ix);
        
    %check track length
    if length(trck_ind)<proj_min_track_len
        %skip if short
        continue
    end
    
    %check track length
    %############################
    %REMOVE THIS CONDITION TO REDUCE LIENARITY ERROR
    if length(trck_ind) > max_track_len
        trck_ind    = trck_ind(end-max_track_len+1:end);
        %subset if too long
    end

    %extract timedate, latloncent for each track cell from storm_db
    trck_dt         = storm_db.start_timestamp(trck_ind);
    trck_latcent    = storm_db.lat(trck_ind);
    trck_loncent    = storm_db.lon(trck_ind);
    trck_area       = storm_db.area(trck_ind);
    
    
    %check distance from target cell latlon
    [dist_check,~] = distance(init_lat,init_lon,trck_latcent,trck_loncent);
    dist_check     = deg2km(dist_check);
    if min(dist_check) > other_track_dist
        %other track is too far away
        continue
    end
    
    %calculate polyfit of lat lon cents
    [lat_p,lat_s,lat_mu] = polyfit(trck_dt,trck_latcent,1);
    [lon_p,lon_s,lon_mu] = polyfit(trck_dt,trck_loncent,1);
    
    %generate dummy forecast from p
    temp_proj_lat1   = polyval(lat_p,trck_dt(end),lat_s,lat_mu);
    temp_proj_lon1   = polyval(lon_p,trck_dt(end),lon_s,lon_mu);    
    temp_proj_lat2   = polyval(lat_p,tn_dt,lat_s,lat_mu);
    temp_proj_lon2   = polyval(lon_p,tn_dt,lon_s,lon_mu);
    
    %use dummy forecast to calc arc and azi
    [temp_arc, temp_azi] = distance(temp_proj_lat1,temp_proj_lon1,temp_proj_lat2,temp_proj_lon2);
    
    %collate
    proj_arc = [proj_arc; temp_arc];
    proj_azi = [proj_azi; temp_azi];
end

%case: proj output
if ~isempty(proj_arc) && ~isempty(proj_azi)
    %take median set
    proj_arc   = median(proj_arc);
    proj_azi_x = cosd(proj_azi);
    proj_azi_y = sind(proj_azi);
    proj_azi   = mod(atan2(median(proj_azi_y),median(proj_azi_x))*180/pi,360);
    
    
    %apply transform to project init lat and lon
    [proj_lat,proj_lon]=reckon(init_lat,init_lon,proj_arc,proj_azi);
    
    %for case (1), tn1 proj using tn1 track. set track length and search distance using simple track
    if isequal(tn1_target_ind,tn1_track_ind)
        track_length = length(trck_ind);
        search_dist  = ceil(sqrt(trck_area(end)/pi));
    else
        %for case (2), tn1 proj using other tracks. set track length to 1 and proj area to max_search_distance
        track_length = 1;
        search_dist  = max_search_distance; %mean(ceil(sqrt(trck_stats(:,2)/pi)));
        proj_azi = nan;
    end

    %cap search radius to max_storm_speed
    if search_dist>max_search_distance; search_dist=max_search_distance; end


%case: np proj output
else
    proj_lat=init_lat;
    proj_lon=init_lon;
    proj_azi=nan; %default westerly steering
    track_length = 1;
    search_dist  = max_search_distance;
    
end
