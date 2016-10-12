function [proj_azi,proj_arc,vil_dt,full_trck_stats,full_trck_dt] = project_storm_kml(tn1_ident_ind,ident_db)
%WHAT: Generates a projected azi and arc form the line of best fit for the
%track ending with tn1_ident_ind (maximum length of line fit is limited).
%Also calculated projected 1 minute difference in vil from linear fit.
%INPUT:
%tn1_ident_ind: Index(s) in ident_db of cells to generate fits from
%ident_db: ident_db containing all cells and tracks

%OUTPUT:
%proj_azi: linear fit azi from last cell
%proj_arc: linear fit arc length for next 1min
%vil_dt: change in vil between last track timestep and next 1min using
%linear fit
%full_trck_stats: Full matrix of stats for track
%full_trck_dt: Full list of times for track

%blank vars
proj_azi        = [];
proj_arc        = [];
vil_dt          = [];
full_trck_stats = [];
full_trck_dt    = [];
forecast_offset = 1/24/60; %offset of 1 min

load('tmp/global.config.mat');
load('tmp/kml.config.mat');

%loop through each end cell


%decompose end cell track
tn1_simple_id      = str2num(storm_jstruct(end_cell_idx).track_id.N);
tn1_start_timedate = datenum(storm_jstruct(end_cell_idx).start_timestamp.S,ddb_tfmt);
keyboard%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
trck_ind           = find([ident_db.simple_id]'==tn1_simple_id & [ident_db.start_timedate]'<=tn1_start_timedate);
%sort track index to time
[~,sort_ix]        = sort([ident_db(trck_ind).start_timedate]);
trck_ind           = trck_ind(sort_ix);

%preserve full list of stats/times
full_trck_dt       = vertcat(ident_db(trck_ind).start_timedate);
full_trck_stats    = vertcat(ident_db(trck_ind).stats);

%check track length
if length(trck_ind)>max_track_len
    trck_ind = trck_ind(end-max_track_len+1:end);
    %subset if too long
end

%extract timedate, latloncent for each track cell from ident_db
trck_dt         = vertcat(ident_db(trck_ind).start_timedate);
trck_latloncent = vertcat(ident_db(trck_ind).dbz_latloncent);
trck_latcent    = trck_latloncent(:,1);
trck_loncent    = trck_latloncent(:,2);
trck_stats      = vertcat(ident_db(trck_ind).stats);
trck_vil        = trck_stats(:,12);

%calculate polyfit of lat lon cents
[lat_p,lat_s,lat_mu] = polyfit(trck_dt,trck_latcent,1);
[lon_p,lon_s,lon_mu] = polyfit(trck_dt,trck_loncent,1);
[vil_p,vil_s,vil_mu] = polyfit(trck_dt,trck_vil,1);

%generate dummy forecast for lat, lon and vil
temp_proj_lat1   = polyval(lat_p,trck_dt(end),lat_s,lat_mu);
temp_proj_lon1   = polyval(lon_p,trck_dt(end),lon_s,lon_mu);
temp_proj_vil1   = polyval(vil_p,trck_dt(end),vil_s,vil_mu);
temp_proj_lat2   = polyval(lat_p,trck_dt(end)+forecast_offset,lat_s,lat_mu);
temp_proj_lon2   = polyval(lon_p,trck_dt(end)+forecast_offset,lon_s,lon_mu);
temp_proj_vil2   = polyval(vil_p,trck_dt(end)+forecast_offset,vil_s,vil_mu);
vil_dt           = temp_proj_vil2-temp_proj_vil1;

%use dummy forecast to calc arc and azi
[proj_arc, proj_azi] = distance(temp_proj_lat1,temp_proj_lon1,temp_proj_lat2,temp_proj_lon2);