function kml_str = kml_storm_stat(kml_str,storm_jstruct,track_id)

load('tmp/global.config.mat')

timestamps  = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
timestep_mm = mode(minute(timestamps(2:end)-timestamps(1:end-1)));
%init string
%loop through cells
tmp_kml = '';
for i=1:length(storm_jstruct)
    %extract stats
    storm_max_tops    = str2num(storm_jstruct(i).max_tops.N);
    storm_max_mesh    = str2num(storm_jstruct(i).max_mesh.N);
    storm_cell_vil    = str2num(storm_jstruct(i).cell_vil.N);
    storm_max_tops    = roundn(storm_max_tops/1000,-1);
    storm_cell_vild   = roundn(storm_cell_vil/storm_max_tops,-2);
    storm_dbz_centlat = str2num(storm_jstruct(i).storm_dbz_centlat.N);
    storm_dbz_centlon = str2num(storm_jstruct(i).storm_dbz_centlon.N);
    cell_id           = storm_jstruct(i).subset_id.N;
    start_timestr     = datestr(timestamps(i),ge_tfmt);
    stop_timestr      = datestr(addtodate(timestamps(i),timestep_mm,'minute'),ge_tfmt);
    %generate kml
    name    = [datestr(timestamps(i),r_tfmt),'_',cell_id];
    tmp_kml = ge_balloon_stats_placemark(tmp_kml,1,...
        '../cell.kml#balloon_stats_style',name,storm_cell_vild,storm_max_mesh...
        ,storm_max_tops,cell_id,storm_dbz_centlat,storm_dbz_centlon,...
        '','');
end
%group into folder
name    = ['track_id_',num2str(track_id)];
kml_str = ge_folder(kml_str,tmp_kml,name,'',1);

