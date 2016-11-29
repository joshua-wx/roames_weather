function object_struct = kml_odimh5(object_struct,radar_id,download_path,dest_root,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%init vars
scan_path  = [scan_obj_path,radar_id_str,'/'];        

%extract odimh5 atts for radar_id
odimh5_atts        = 'h5_ffn,vel_ni,storm_flag,start_timestamp';
odimh5_jstruct_out = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
odimh5_jstruct_out = clean_jstruct(odimh5_jstruct_out,4);
if ~isempty(odimh5_jstruct_out)
    radar_ts        = datenum(jstruct_to_mat([odimh5_jstruct_out.start_timestamp],'S'),ddb_tfmt);
    vol_vel_ni      = str2num(odimh5_jstruct_out(1).vel_ni.N);
    storm_flag_list = jstruct_to_mat([odimh5_jstruct_out.storm_flag],'N');
    %calc radar timestep
    if length(radar_ts) == 1
        radar_timestep = 10;
    elseif length(radar_ts) > 1
        radar_timestep = mode(minute(radar_ts(2:end)-radar_ts(1:end-1)));
    end
    %set radar start and stop times
    radar_start_ts = min(radar_ts);
    radar_stop_ts  = addtodate(max(radar_ts),radar_timestep,'minute');
else
    storm_flag_list = [];
end


%% scan ground overlays ########### ONLY RUN THIS FOR NEW SCANS!!!! NOT ALL SCANS. MUST BE PART OF LOOP BELOW
for i=1:length(odimh5_jstruct_out)
    odimh5_ffn     = odimh5_jstruct_out(i).h5_ffn.S;
    scan_start_ts  = datenum(odimh5_jstruct_out(i).start_timestamp.S,ddb_tfmt);
    scan_stop_ts   = addtodate(scan_start_ts,radar_timestep,'minute');
    %PPI Reflectivity
    if options(1)==1
        %create kml for refl ppi
        scan_tag                  = [data_tag,'.ppi_refl'];
        [link,ffn,scan_latlonbox] = kml_scan(dest_root,scan_tag,download_path,odimh5_ffn,scan_path);
        object_struct             = collate_kmlobj(object_struct,radar_id,'',scan_start_ts,scan_stop_ts,scan_latlonbox,'ppi_refl',link,ffn);
    end
    %PPI Velocity
    if options(2)==1
        %create kml for vel ppi
        scan_tag                  = [data_tag,'.ppi_vel'];
        [link,ffn,scan_latlonbox] = kml_scan(dest_root,scan_tag,download_path,odimh5_ffn,scan_path);
        object_struct             = collate_kmlobj(object_struct,radar_id,'',scan_start_ts,scan_stop_ts,scan_latlonbox,'ppi_vel',link,ffn);
    end
end

%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config

%PPI Reflectivity
if options(1)==1
    generate_nl_scan(radar_id,object_struct,'ppi_refl',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%PPI Velcoity
if options(2)==1
    generate_nl_scan(radar_id,object_struct,'ppi_vel',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end

function object_struct = collate_kmlobj(object_struct,radar_id,subset_id,start_ts,stop_ts,storm_latlonbox,type,link,ffn)
%WHAT: Append entry to object_struct

if isempty(link)
    return
end

tmp_struct = struct('radar_id',radar_id,'subset_id',subset_id,...
    'start_timestamp',start_ts,'stop_timestamp',stop_ts,...
    'latlonbox',storm_latlonbox,'type',type,'nl',link,'ffn',ffn);

object_struct = [object_struct,tmp_struct];

function generate_nl_scan(radar_id,object_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for scan objects listed in object_Struct using
%a radar_id and type filter
load('tmp/global.config.mat')

%init radar_id and type list
type_list = {object_struct.type};
r_id_list = [object_struct.radar_id];
time_list = [object_struct.start_timestamp];
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
    target_start     = object_struct(target_idx(j)).start_timestamp;
    target_stop      = object_struct(target_idx(j)).stop_timestamp;
    target_link      = object_struct(target_idx(j)).nl;
    target_latlonbox = object_struct(target_idx(j)).latlonbox;
    %nl
    region_kml    = ge_region(target_latlonbox,0,altLod,minlod,maxlod);
    timeSpanStart = datestr(target_start,ge_tfmt);
    timeSpanStop  = datestr(target_stop,ge_tfmt);
    kml_name      = datestr(target_start,r_tfmt);
    nl_kml        = ge_networklink(nl_kml,kml_name,target_link,0,'','',region_kml,timeSpanStart,timeSpanStop,1);
end
%write out
ge_kml_out([nl_path,name,'.kml'],name,nl_kml);
