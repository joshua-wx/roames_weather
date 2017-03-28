function [ffn_list,datetime_list,radarid_list] = ddb_filter_staging(ddb_table,oldest_time,newest_time,radar_id_list,data_type)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: filters volumes in staging ddb and generates a list of their respective
% h5 ffn's (either storm or odim). Removes entries from ddb table which
% pass time and radar_id filter
% INPUTS
% ddb_table: ddb table name (str)
% oldest_time: oldest time of sort key (in datenum, double)
% newest_time: newest time of sort key (in datenum, double)
% radar_id_list: list of radar ids
% data_type: filters ddb entries using this value (str)
% RETURNS
% ffn_list: list of h5 files (cell array of strings)
% datetime_list: date stamps of h5 files (double array)
% radarid_list: radar id of h5 files (int array)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%init pending_list
ffn_list      = {};
datetime_list = [];
radarid_list  = [];

%read staging index
p_exp            = 'data_type,data_id,data_ffn'; %attributes to return
jstruct          = ddb_query_part('data_type',data_type,'S',p_exp,ddb_table);
if isempty(jstruct)
    return
end
%extract filename list
staging_ffn_list  = jstruct_to_mat([jstruct.data_ffn],'S');
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
        %clean ddb table (delete)
        delete_struct           = struct;
        delete_struct.data_id   = jstruct(j).data_id;
        delete_struct.data_type = jstruct(j).data_type;
        ddb_rm_item(delete_struct,ddb_table);
    end
end
