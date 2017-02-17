function [last_extract,fz_h,minus20_h] = ddb_eraint_extract(last_extract,timestamp,radar_id,eraint_ddb_table)

%WHAT: extract era-interim freezing and -20C heights from a ddb database
%for a radar sites at an era interim time for climatological processing. Note: last_extract stores only
%the last extract from the ddb, since climatological processing is for only
%one radar and ordered by increasing time

era_hour              = round(hour(timestamp)/6)*6; %round to nearest 6 hour
era_date              = floor(timestamp); %extract date
if era_hour==24 %wrap hour=24 to 00Z on next day
    era_hour = 0;
    era_date = era_date+1;
end
era_hour_str          = num2str(era_hour,'%02.0f'); %round to nearest 6 hourly block, 00,06,12,18

%check if last_extract contains the required information
if ~isempty(last_extract)
    if last_extract(1) == radar_id && last_extract(2) == era_date
        fz_h      = last_extract(3);
        minus20_h = last_extract(4);
        return
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
last_extract = [radar_id,era_date,fz_h,minus20_h];