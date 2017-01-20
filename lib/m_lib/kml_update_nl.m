function kml_update_nl(kmlobj_struct)


%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config

%PPI Reflectivity
if options(1)==1
    generate_nl_ppi(radar_id,kmlobj_struct,'ppi_dbzh',scan_path,max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%PPI Velcoity
if options(2)==1
    generate_nl_ppi(radar_id,kmlobj_struct,'ppi_vradh',scan_path,max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end



function generate_nl_ppi(radar_id,kmlobj_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for ppi objects listed in object_Struct using
%a radar_id and type filter
load('tmp/global.config.mat')

%init radar_id and type list
type_list = {kmlobj_struct.type};
r_id_list = [kmlobj_struct.radar_id];
time_list = [kmlobj_struct.start_timestamp];
%init nl
nl_kml       = '';
name         = [type,'_',num2str(radar_id,'%02.0f')];
%find entries from correct radar_id and type
target_idx   = find(ismember(type_list,type) & r_id_list==radar_id);
%write out offline radar image if no data is present
if isempty(target_idx)
    radar_id_str = num2str(radar_id,'%02.0f');
    nl_kml       = ge_networklink('','Radar Offline',['radar_offline_',radar_id_str,'.kmz'],0,0,60,'','','',1);
    ge_kml_out([nl_path,name,'.kml'],name,nl_kml);
    return
end

%sort by time
[~,sort_idx]  = sort(time_list(target_idx));
target_idx    = target_idx(sort_idx);

%loop through entries, appending kml
for j=1:length(target_idx)
    %target data
    target_start     = kmlobj_struct(target_idx(j)).start_timestamp;
    target_stop      = kmlobj_struct(target_idx(j)).stop_timestamp;
    target_link      = kmlobj_struct(target_idx(j)).nl;
    target_latlonbox = kmlobj_struct(target_idx(j)).latlonbox;
    %nl
    region_kml    = ge_region(target_latlonbox,0,altLod,minlod,maxlod);
    timeSpanStart = datestr(target_start,ge_tfmt);
    timeSpanStop  = datestr(target_stop,ge_tfmt);
    kml_name      = datestr(target_start,r_tfmt);
    nl_kml        = ge_networklink(nl_kml,kml_name,target_link,0,'','',region_kml,timeSpanStart,timeSpanStop,1);
end
%write out
ge_kml_out([nl_path,name,'.kml'],name,nl_kml);