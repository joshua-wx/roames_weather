function pending_ffn_list = ddb_filter_s3h5(ddb_table,sort_key,oldest_time,newest_time,radar_id_list)
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
storm_atts      = 'radar_id,start_timestamp,data_ffn'; %attributes to return

for i = 1:length(radar_id_list)
    %run query for radar id
    radar_id_str = num2str(radar_id_list(i),'%02.0f');
    jstruct      = ddb_query('radar_id',radar_id_str,sort_key,oldest_time_str,newest_time_str,storm_atts,ddb_table);
    %if not empty
    if ~isempty(jstruct)
        %extract data ffn list
        data_ffn_list = jstruct_to_mat([jstruct.data_ffn],'S');
        %append
        pending_ffn_list = [pending_ffn_list;unique(data_ffn_list)];
    end
end
