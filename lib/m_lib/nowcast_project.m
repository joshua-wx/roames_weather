function [proj_azi,proj_arc,vil_dt,trck_mesh,trck_vil,trck_top,trck_dt] = nowcast_project(tn1_ident_ind,storm_jstruct)
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
trck_mesh       = [];
trck_vil        = [];
trck_top        = [];
trck_dt         = [];
forecast_offset = 1/24/60; %offset of 1 min

load('tmp/global.config.mat');

%decompose end cell track
track_id           = jstruct_to_mat([storm_jstruct.track_id],'N');
start_timedate     = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
tn1_track_id       = track_id(tn1_ident_ind);
tn1_start_timedate = start_timedate(tn1_ident_ind);
trck_ind           = find(track_id==tn1_track_id & start_timedate<=tn1_start_timedate);
%sort track index to time
[~,sort_ix]        = sort(start_timedate(trck_ind));
trck_ind           = trck_ind(sort_ix);

%check track length
if length(trck_ind)>max_track_len
    trck_ind_fcst = trck_ind(end-max_track_len+1:end);
    %subset if too long
else
    trck_ind_fcst = trck_ind;
end

%extract timedate, latloncent for each track cell from ident_db
trck_dt_fsct    = start_timedate(trck_ind_fcst);
trck_latcent    = jstruct_to_mat([storm_jstruct(trck_ind_fcst).storm_dbz_centlat],'N')./geo_scale;
trck_loncent    = jstruct_to_mat([storm_jstruct(trck_ind_fcst).storm_dbz_centlon],'N')./geo_scale;
trck_vil_fcst   = jstruct_to_mat([storm_jstruct(trck_ind_fcst).cell_vil],'N')./stats_scale;

trck_dt          = start_timedate(trck_ind);
trck_mesh       = jstruct_to_mat([storm_jstruct(trck_ind).max_mesh],'N')./stats_scale;
trck_top        = jstruct_to_mat([storm_jstruct(trck_ind).max_tops],'N')./stats_scale;
trck_vil        = jstruct_to_mat([storm_jstruct(trck_ind).cell_vil],'N')./stats_scale;

%calculate polyfit of lat lon cents
[lat_p,lat_s,lat_mu] = polyfit(trck_dt_fsct,trck_latcent,1);
[lon_p,lon_s,lon_mu] = polyfit(trck_dt_fsct,trck_loncent,1);
[vil_p,vil_s,vil_mu] = polyfit(trck_dt_fsct,trck_vil_fcst,1);

%generate dummy forecast for lat, lon and vil
temp_proj_lat1   = polyval(lat_p,trck_dt_fsct(end),lat_s,lat_mu);
temp_proj_lon1   = polyval(lon_p,trck_dt_fsct(end),lon_s,lon_mu);
temp_proj_vil1   = polyval(vil_p,trck_dt_fsct(end),vil_s,vil_mu);
temp_proj_lat2   = polyval(lat_p,trck_dt_fsct(end)+forecast_offset,lat_s,lat_mu);
temp_proj_lon2   = polyval(lon_p,trck_dt_fsct(end)+forecast_offset,lon_s,lon_mu);
temp_proj_vil2   = polyval(vil_p,trck_dt_fsct(end)+forecast_offset,vil_s,vil_mu);
vil_dt           = temp_proj_vil2-temp_proj_vil1;

%use dummy forecast to calc arc and azi
[proj_arc, proj_azi] = distance(temp_proj_lat1,temp_proj_lon1,temp_proj_lat2,temp_proj_lon2);