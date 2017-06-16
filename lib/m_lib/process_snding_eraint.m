function [extract_db,fz_h,minus20_h] = process_snding_eraint(extract_db,timestamp,radar_id,eraint_ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: extract era-interim freezing and -20C heights from a ddb database
%   for a radar sites at an era interim time for climatological processing. Note: extract_db stores only
%   the last extract from the ddb, since climatological processing is for only
%   one radar and ordered by increasing time
% INPUTS
% extract_db: structure contraining last last radar_id/time/value data for
% last extracts (struct)
% timestamp: target timestamp for era_int data (double, datenum)
% radar_id: target radar id for era_int data (int)
% eraint_ddb_table: ddb table name (str)
% RETURNS
% extract_db: structure contraining last last lat/lon/time/value data for
% last extracts (struct)
% fz_h: freezing level height (double, m)
% minus20_h: -20C level height (double,m)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fz_h      = [];
minus20_h = [];

%convert datenum to hour and date for extract
era_hour              = round(hour(timestamp)/6)*6; %round to nearest 6 hour, 00,06,12,18
era_date              = floor(timestamp); %extract date
if era_hour==24 %wrap hour=24 to 00Z on next day
    era_hour = 0;
    era_date = era_date+1;
end
era_hour_str          = num2str(era_hour,'%02.0f'); %era time string

%check if extract_db contains the required information
if ~isempty(extract_db)
    if extract_db(1) == radar_id && extract_db(2) == era_date
        fz_h      = extract_db(3);
        minus20_h = extract_db(4);
    end
end

%create field names
eraint_0C_field       = ['lvl_0C_',era_hour_str,'Z'];
eraint_minus20C_field = ['lvl_minus20C_',era_hour_str,'Z'];
%pull from ddb
jstruct_out  = ddb_get_item(eraint_ddb_table,...
    'radar_id','N',num2str(radar_id,'%02.0f'),...
    'eraint_timestamp','S',datestr(era_date,'yyyy-mm-ddTHH:MM:SS'),'');
if isempty(jstruct_out)
    display('NO ERA_int data')
    keyboard
end
%extract from struct
fz_h         = str2num(jstruct_out.Item.(eraint_0C_field).N);
minus20_h    = str2num(jstruct_out.Item.(eraint_minus20C_field).N);
extract_db = [radar_id,era_date,fz_h,minus20_h];