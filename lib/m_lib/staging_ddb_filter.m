function [pending_ffn_list,pending_fn_list] = staging_ddb_filter(ddb_table,oldest_time,newest_time,radar_id_list,obj_type)
%WHAT: filters files in scr_dir using the time and site no criteria.

%INPUT
%src_dir (see wv_process input)
%oldest_time: oldest time to crop files to (in datenum)
%newest_time: newest time to crop files to (in datenum)
%radar_id_list: site ids of selected radar sites

%OUTPUT
%pending_list: updated list of all processed ftp files

%init pending_list
pending_ffn_list = {};
pending_fn_list  = {};
%read staging index
p_exp            = 'data_type,data_id,h5_ffn'; %attributes to return
jstruct          = ddb_query_part('data_type',obj_type,'S',p_exp,ddb_table);
staging_ffn_list = jstruct_to_mat([jstruct.h5_ffn],'S');
for j=1:length(staging_ffn_list)
    [~,fn,ext] = fileparts(staging_ffn_list{j});
    tmp_radar_id    = str2num(fn(1:2));
    tmp_timestamp   = datenum(fn(4:end),'yyyymmdd_HHMMSS');
    %filter
    if any(ismember(tmp_radar_id,radar_id_list)) && tmp_timestamp>=oldest_time && tmp_timestamp<=newest_time
        pending_fn_list = [pending_fn_list;[fn,ext]];
        pending_ffn_list = [pending_ffn_list;staging_ffn_list{j}];
        %clean ddb table
        delete_struct           = struct;
        delete_struct.data_id   = jstruct(j).data_id;
        delete_struct.data_type = jstruct(j).data_type;
        ddb_rm_item(delete_struct,ddb_table);  
    end
end