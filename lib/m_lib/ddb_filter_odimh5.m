function [pending_ffn_list,pending_fn_list] = ddb_filter_odimh5(ddb_table,storm_root,oldest_time_str,newest_time_str,radar_id_list)
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
pending_fn_list  = {};
%read staging index
odimh5_atts      = 'radar_id,start_timestamp'; %attributes to return

for i = 1:length(radar_id_list)
    %run query for radar id
    radar_id_str = num2str(radar_id_list(i),'%02.0f');
    jstruct      = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,ddb_table);
    %if not empty
    if ~isempty(jstruct)
        date_list   = jstruct_to_mat([jstruct.start_timestamp],'S');
        vol_datenum = datenum(date_list,ddb_tfmt);
        for i=1:length(vol_datenum)
            date_vec  = datevec(vol_datenum(i));
            storm_fn  = [radar_id_str,'_',datestr(vol_datenum(i),r_tfmt),'.wv.tar'];
            storm_ffn = [storm_root,radar_id_str,'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/',storm_fn];
            %append
            pending_ffn_list = [pending_ffn_list;storm_ffn];
            pending_fn_list  = [pending_fn_list;storm_fn];
        end
    end
end