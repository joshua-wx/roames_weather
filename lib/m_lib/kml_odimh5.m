function kmlobj_struct = kml_odimh5(kmlobj_struct,storm_jstruct,vol_struct,radar_id,download_path,dest_root,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%init vars
scan_path  = [scan_obj_path,num2str(radar_id,'%02.0f'),'/'];

%list download path odimh5 files
download_list    = dir(download_path); download_list(1:2) = [];
download_fn_list = {download_list.name};
%abort if no files
if isempty(download_fn_list)
    return
end
odimh5_fn_list = {};
for i=1:length(download_fn_list)
    [~,fn,ext] = fileparts(download_fn_list{i});
    if ~strcmp(fn(end-4:end),'storm') && strcmp(ext,'.h5')
        odimh5_fn_list = [odimh5_fn_list;download_fn_list{i}];
    end
end
keyboard

%% scan ground overlays ########### CHANGE LOOP TO RUN odimh5_fn_list
for i=1:length(odimh5_jstruct_out)
    odimh5_ffn     = odimh5_jstruct_out(i).data_ffn.S;
    scan_start_ts  = datenum(odimh5_jstruct_out(i).start_timestamp.S,ddb_tfmt);
    scan_stop_ts   = addtodate(scan_start_ts,radar_timestep,'minute');
    %PPI Reflectivity
    if options(1)==1
        %create kml for refl ppi
        scan_tag                  = [data_tag,'.ppi_refl'];
        [link,ffn,scan_latlonbox] = kml_scan(dest_root,scan_tag,download_path,odimh5_ffn,scan_path);
        kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',scan_start_ts,scan_stop_ts,scan_latlonbox,'ppi_refl',link,ffn);
    end
    %PPI Velocity
    if options(2)==1
        %create kml for vel ppi
        scan_tag                  = [data_tag,'.ppi_vel'];
        [link,ffn,scan_latlonbox] = kml_scan(dest_root,scan_tag,download_path,odimh5_ffn,scan_path);
        kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',scan_start_ts,scan_stop_ts,scan_latlonbox,'ppi_vel',link,ffn);
    end
end

%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config

%PPI Reflectivity
if options(1)==1
    generate_nl_scan(radar_id,kmlobj_struct,'ppi_refl',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%PPI Velcoity
if options(2)==1
    generate_nl_scan(radar_id,kmlobj_struct,'ppi_vel',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end

function kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,start_ts,stop_ts,storm_latlonbox,type,link,ffn)
%WHAT: Append entry to kmlobj_struct

if isempty(link)
    return
end

tmp_struct = struct('radar_id',radar_id,'subset_id',subset_id,...
    'start_timestamp',start_ts,'stop_timestamp',stop_ts,...
    'latlonbox',storm_latlonbox,'type',type,'nl',link,'ffn',ffn);

kmlobj_struct = [kmlobj_struct,tmp_struct];

function generate_nl_scan(radar_id,kmlobj_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for scan objects listed in object_Struct using
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
