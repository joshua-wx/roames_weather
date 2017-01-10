function pending_ffn_list = ddb_filter_index(ddb_table,part_key_name,part_key_value,sort_key_name,oldest_time,newest_time)
%WHAT: filters volumes in odimh5 ddb and generates a list of their respective storm.wv.tar files.

%INPUT
%src_dir (see wv_process input)
%oldest_time: oldest time to crop files to (in datenum)
%newest_time: newest time to crop files to (in datenum)
%radar_id_list: site ids of selected radar sites

%OUTPUT
%pending_list: updated list of all processed ftp files

load('tmp/global.config.mat')

%init pending_list
pending_ffn_list = {};
%read staging index
oldest_time_str = datestr(oldest_time,ddb_tfmt);
newest_time_str = datestr(newest_time,ddb_tfmt);
storm_atts      = 'data_ffn'; %attributes to return

for i = 1:length(part_key_value)
    %run query for radar id
    if strcmp(part_key_name,'radar_id')
        part_key_str = num2str(part_key_value(i),'%02.0f');
    else
        part_key_str = datestr(part_key_value(i),ddb_dateid_tfmt);
    end
    jstruct          = ddb_query(part_key_name,part_key_str,sort_key_name,oldest_time_str,newest_time_str,storm_atts,ddb_table);
    %if not empty
    if ~isempty(jstruct)
        %extract data ffn list
        data_ffn_list = jstruct_to_mat([jstruct.data_ffn],'S');
        %append
        pending_ffn_list = [pending_ffn_list;unique(data_ffn_list)];
    end
end
