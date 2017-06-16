function pending_ffn_list = ddb_filter_index(ddb_table,part_key_name,part_key_value,sort_key_name,oldest_time,newest_time,radar_id_list)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: filters volumes in ddb and generates a list of their respective
% h5 ffn's (either storm or odim).
% INPUTS
% ddb_table: ddb table name (str)
% part_key_name: name of partition key (str)
% part_key_value: value of partition key (str)
% sort_key_name: name of sort key (str)
% oldest_time: oldest time of sort key (in datenum, double)
% newest_time: newest time of sort key (in datenum, double)
% radar_id_list: list of radar ids
% RETURNS
% pending_ffn_list: list of h5 files (cell array of strings)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load('tmp/global.config.mat')

%init pending_list
pending_ffn_list = {};
%read staging index
oldest_time_str = datestr(oldest_time,ddb_tfmt);
newest_time_str = datestr(newest_time,ddb_tfmt);
ddb_atts        = 'data_ffn,radar_id'; %attributes to return

for i = 1:length(part_key_value)
    %run query for radar id
    if strcmp(part_key_name,'radar_id')
        part_key_str = num2str(part_key_value(i),'%02.0f');
    else
        part_key_str = datestr(part_key_value(i),ddb_dateid_tfmt);
    end
    jstruct          = ddb_query(part_key_name,part_key_str,sort_key_name,oldest_time_str,newest_time_str,ddb_atts,ddb_table);
    %if not empty
    if ~isempty(jstruct)
        %extract data ffn list
        data_ffn_list = utility_jstruct_to_mat([jstruct.data_ffn],'S');
        data_rid_list = utility_jstruct_to_mat([jstruct.radar_id],'N');
        %append
        if isempty(radar_id_list)
            pending_ffn_list = [pending_ffn_list;unique(data_ffn_list)];
        else %include only required radar_ids and append
            rid_mask         = ismember(data_rid_list,radar_id_list);
            pending_ffn_list = [pending_ffn_list;unique(data_ffn_list(rid_mask))];
        end
    end
end
