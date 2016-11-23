function [fz_h,minus20_h] = ddb_eraint_extract(timestamp,radar_id,eraint_ddb_table)

era_hour              = round(hour(timestamp)/6)*6; %round to nearest 6 hour
era_date              = floor(timestamp); %extract date
if era_hour==24 %wrap hour=24 to 00Z on next day
    era_hour = 0;
    era_date = era_date+1;
end
era_hour_str          = num2str(era_hour,'%02.0f'); %round to nearest 6 hourly block, 00,06,12,18
%create field names
eraint_0C_field       = ['lvl_0C_',era_hour_str,'Z'];
eraint_minus20C_field = ['lvl_minus20C_',era_hour_str,'Z'];
%pull from ddb
jstruct_out  = ddb_get_item(eraint_ddb_table,...
    'radar_id','N',num2str(radar_id,'%02.0f'),...
    'eraint_timestamp','S',datestr(era_date,'yyyy-mm-ddTHH:MM:SS'),'');
if isempty(jstruct_out)
    keyboard
end
%extract from struct
fz_h      = str2num(jstruct_out.Item.(eraint_0C_field).N);
minus20_h = str2num(jstruct_out.Item.(eraint_minus20C_field).N);