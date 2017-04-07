function [ffn_list,datetime_list,radarid_list] = sqs_process_staging(sqs_url,oldest_time,newest_time,radar_id_list)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: receives and filters files in sqs and generates a list of their respective
% h5 ffn's (either storm or odim)
% INPUTS
% sqs_url: sqs url (str)
% oldest_time: oldest time of sort key (in datenum, double)
% newest_time: newest time of sort key (in datenum, double)
% radar_id_list: list of radar ids
% RETURNS
% ffn_list: list of h5 files (cell array of strings)
% datetime_list: date stamps of h5 files (double array)
% radarid_list: radar id of h5 files (int array)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%init pending_list
ffn_list      = {};
datetime_list = [];
radarid_list  = [];

%read sqs
staging_ffn_list       = sqs_receive(sqs_url);
%loop through filename list
for j=1:length(staging_ffn_list)
    %extract file radar_id and timestamp
    [~,fn,~] = fileparts(staging_ffn_list{j});
    tmp_radar_id    = str2num(fn(1:2));
    tmp_timestamp   = datenum(fn(4:end),'yyyymmdd_HHMMSS');
    %filter using input vars
    if any(ismember(tmp_radar_id,radar_id_list)) && tmp_timestamp>=oldest_time && tmp_timestamp<=newest_time
        %collate
        ffn_list                = [ffn_list;staging_ffn_list{j}];
        datetime_list           = [datetime_list;tmp_timestamp];
        radarid_list            = [radarid_list;tmp_radar_id];
    end
end
