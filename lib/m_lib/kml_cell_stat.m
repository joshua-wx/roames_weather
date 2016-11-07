function kml_str = kml_cell_stat(kml_str,storm_jstruct,track_id)

load('tmp/global.config.mat')

timestamps  = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
timestep_mm = mode(minute(timestamps(2:end)-timestamps(1:end-1)));
%init string
%loop through cells
tmp_kml = '';
for i=1:length(storm_jstruct)
    %extract stats
    storm_max_tops    = str2num(storm_jstruct(i).max_tops.N)./stats_scale;
    storm_max_mesh    = str2num(storm_jstruct(i).max_mesh.N)./stats_scale;
    storm_cell_vil    = str2num(storm_jstruct(i).cell_vil.N)./stats_scale;
    storm_cell_vild   = roundn(storm_cell_vil/storm_max_tops*1000,-2);
    storm_dbz_centlat = str2num(storm_jstruct(i).storm_dbz_centlat.N)./geo_scale;
    storm_dbz_centlon = str2num(storm_jstruct(i).storm_dbz_centlon.N)./geo_scale;
    subset_id         = storm_jstruct(i).subset_id.S;
    cell_id           = subset_id(end-2:end);
    start_timestr     = datestr(timestamps(i),ge_tfmt);
    stop_timestr      = datestr(addtodate(timestamps(i),timestep_mm,'minute'),ge_tfmt);
    %generate kml
    name    = [datestr(timestamps(i),r_tfmt),'_',cell_id];
    tmp_kml = ge_balloon_stats_placemark(tmp_kml,1,...
        '../../track.kml#balloon_stats_style',name,storm_cell_vild,storm_max_mesh...
        ,storm_max_tops,subset_id,storm_dbz_centlat,storm_dbz_centlon,...
        start_timestr,stop_timestr);
end
%group into folder
name    = ['track_id_',num2str(track_id)];
kml_str = ge_folder(kml_str,tmp_kml,name,'',1);

