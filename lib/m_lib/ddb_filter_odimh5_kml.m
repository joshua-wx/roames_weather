function [jstruct_out,radar_timestep] = ddb_filter_odimh5_kml(odimh5_ddb_table,radar_id,oldest_time,newest_time)
load('tmp/global.config.mat')

jstruct_out     = [];
radar_timestep  = [];
oldest_time_str = datestr(oldest_time,ddb_tfmt);
newest_time_str = datestr(newest_time,ddb_tfmt);
radar_id_str    = num2str(radar_id,'%02.0f');

%%  query odimh5 ddb
odimh5_atts   = 'radar_id,start_timestamp';
jstruct_out   = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
jstruct_out   = clean_jstruct(jstruct_out,2);
if ~isempty(jstruct_out)
    radar_ts  = datenum(jstruct_to_mat([jstruct_out.start_timestamp],'S'),ddb_tfmt);
    %calc radar timestep
    if length(radar_ts) == 1
        radar_timestep = 10;
    elseif length(radar_ts) > 1
        radar_timestep = mode(minute(radar_ts(2:end)-radar_ts(1:end-1)));
    end
end