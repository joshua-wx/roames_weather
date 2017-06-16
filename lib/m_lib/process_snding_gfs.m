function [extract_db,nn_snd_fz_h,nn_snd_minus20_h] = process_snding_gfs(extract_db,r_lat,r_lon,radar_id,eraint_ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Extracts a realtime analysis sounding from gps .5deg at r_lat, r_lon
% using the rucsoundings.noaa.gov utility and then converts the text data
% from this website into interpoalted freezing and -20C levels. Checks
% against last extract first to determine if http request is required.
% INPUTS
% extract_db: structure contraining last last radar_id/time/value data for last extracts (struct)
% r_lat: extract lat (double)
% r_lon: extract lon (double)
% RETURNS
% extract_db: structure contraining last last radar_id/time/value data for last extracts (struct)
% fz_h: freezing level height (double, m)
% minus20_h: -20C level height (double,m)
% NOTE: extract_db is a nx5 matrix composed to extract date (rounded to
% the hour), lat, lon,nn_snd_fz_h,nn_snd_minus20_h. Prevent lags and
% duplicated extractions
%
% source: http://rucsoundings.noaa.gov/
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%init
nn_snd_fz_h      = [];
nn_snd_minus20_h = [];
%utc time
utc_datenum = utility_utc_time;
%floor hour component of datetime
date_vec    = datevec(utc_datenum);
adj_datenum = datenum(date_vec(1),date_vec(2),date_vec(3),floor(date_vec(4)/6)*6,0,0);

%check if temp data for time/lat/lon exists in extract_db
if ~isempty(extract_db)
    test_row   = [adj_datenum,r_lat,r_lon];
    [Lia,Locb] = ismember(test_row,extract_db(:,1:3),'rows');
    if Lia
        nn_snd_fz_h      = extract_db(Locb,4);
        nn_snd_minus20_h = extract_db(Locb,5);
    end
end

%fetch from web if nothing returned via extract_db
if isempty(nn_snd_fz_h)
    [nn_snd_fz_h,nn_snd_minus20_h] = fetch_gfs_snding(adj_datenum,r_lat,r_lon);
    %catch if gfs extract fails
    if isempty(nn_snd_fz_h)
        %if gfs extract failes, pull data from pervious year in eraint
        %(best guess)
        offset_date = addtodate(now,-2,'year');
        [~,nn_snd_fz_h,nn_snd_minus20_h] = ddb_eraint_extract([],offset_date,radar_id,eraint_ddb_table);
        %don't append to extract_db
    else
        %append gfs data to extract_db
        extract_db                 = [extract_db;[adj_datenum,r_lat,r_lon,nn_snd_fz_h,nn_snd_minus20_h]];
    end
end

%clean gfs extract list (older than 1 day)
if ~isempty(extract_db)
    remove_ind = adj_datenum-extract_db(:,1)>1;
    extract_db(remove_ind,:)=[];
end
    

function [nn_snd_fz_h,nn_snd_minus20_h] = fetch_gfs_snding(adj_datenum,r_lat,r_lon)
%WHAT: fetches gfs soundings from lat/lon for at time adj_datenum using
%urlread

%generate date strings
date_vec  = datevec(adj_datenum);
year_str  = num2str(date_vec(1));
month_str = num2str(date_vec(2));
day_str   = num2str(date_vec(3));
hour_str  = num2str(date_vec(4));

%create url string
snd_url = ['https://rucsoundings.noaa.gov/get_soundings.cgi?data_source=GFS&latest=latest&start_year=',...
    year_str,'&start_month_name=',month_str,'&start_mday=',day_str,'&start_hour=',hour_str,...
    '&start_min=0&n_hrs=1.0&fcst_len=analyses&airport=',num2str(r_lat),'%2C',num2str(r_lon),...
    '&text=Ascii%20text%20%28GSD%20format%29&hydrometeors=false&start=latest'];

%fetch from web
web_str = '';
try
    while isempty(web_str)
        web_str = urlread(snd_url);
    end
catch
    %gfs extract failed url request... send utility_pushover update
    utility_pushover('process gfs fetch failed',snd_url);
    nn_snd_fz_h      = [];
    nn_snd_minus20_h = [];
    return
end

%read into formatted data
C = textscan(web_str,'%f%f%f%f%f%f%f','delimiter',' ','MultipleDelimsAsOne',1,'HeaderLines',6);
snd_height = C{3};
snd_temp   = C{4}/10;

%interpolate using existing functions
nn_snd_fz_h      = sounding_interp(snd_temp,snd_height,0);
nn_snd_minus20_h = sounding_interp(snd_temp,snd_height,-20);


function intp_h = sounding_interp(snd_temp,snd_height,target_temp)
%WHAT: Provides an interpolated height for a target temperature using a
%sounding vertical profile

intp_h=[];
%find index above and below freezing level
above_ind = find(snd_temp<target_temp,1,'first');
if above_ind > 1  
    below_ind = above_ind-1;
else
    %above ind is either 1 or 0, cannot provide interpolation
    return
end

%attempt to interpolate
intp_h   = interp1(snd_temp(below_ind:above_ind),snd_height(below_ind:above_ind),target_temp);
