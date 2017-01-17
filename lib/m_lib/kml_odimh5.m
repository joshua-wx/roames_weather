function kmlobj_struct = kml_odimh5(kmlobj_struct,vol_struct,radar_id,radar_step,download_odimh5_list,dest_root,transform_path,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%init vars
scan_path    = [dest_root,ppi_obj_path,num2str(radar_id,'%02.0f'),'/'];
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];

%list check odimh5 files
local_odimh5_list = {};
for i=1:length(download_odimh5_list)
    [~,fn,ext]      = fileparts(download_odimh5_list{i});
    local_odimh5_fn = [download_path,fn,ext];
    if exist(local_odimh5_fn,'file')==2
        local_odimh5_list = [local_odimh5_list;local_odimh5_fn];
    end
end

%% scan ground overlays ########### CHANGE LOOP TO RUN odimh5_fn_list
if ~isempty(local_odimh5_list)
    
    %load transform
    load(transform_fn,'img_azi','img_rng','img_latlonbox','radar_weight_id')
    img_atts = struct('img_azi',img_azi,'img_rng',img_rng,'img_latlonbox',img_latlonbox);
    
    %create domain mask
    other_rid_list = unique([vol_struct.radar_id]);
    other_rid_list(other_rid_list==radar_id) = []; %remove current radar id
    if ~isempty(other_rid_list)
        radar_mask = ~ismember(radar_weight_id,other_rid_list);
    else
        radar_mask     = true(size(radar_weight_id));
    end
    %struct up atts
    img_atts = struct('img_azi',img_azi,'img_rng',img_rng,'img_latlonbox',img_latlonbox,'radar_mask',radar_mask);
    %loop through new odimh5 files
    for i=1:length(local_odimh5_list)
        odimh5_ffn               = local_odimh5_list{i};
        ppi_struct               = process_read_ppi_data(odimh5_ffn,ppi_sweep);
        [ppi_elv,vol_start_time] = process_read_ppi_atts(odimh5_ffn,ppi_sweep,radar_id);
        vol_stop_time            = addtodate(vol_start_time,radar_step,'minute');
        [~,data_tag,~]           = fileparts(odimh5_ffn);
        %PPI Reflectivity
        if options(1)==1
            %create kml for refl ppi
            scan_tag                  = [data_tag,'.ppi_dbzh.elv_',num2str(ppi_elv,'%02.1f')];
            [link,ffn]                = kml_odimh5_ppi(scan_path,scan_tag,img_atts,ppi_struct,1);
            kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',vol_start_time,vol_stop_time,img_latlonbox,'ppi_dbzh',link,ffn);
        end
        %PPI Velocity
        if options(2)==1
            %create kml for vel ppi
            scan_tag                  = [data_tag,'.ppi_vradh.sweep_',num2str(ppi_elv,'%02.1f')];
            [link,ffn]                = kml_odimh5_ppi(scan_path,scan_tag,img_atts,ppi_struct,2);
            kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',vol_start_time,vol_stop_time,img_latlonbox,'ppi_vradh',link,ffn);
        end
    end
end

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

function kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,vol_start_time,vol_stop_time,storm_latlonbox,type,link,ffn)
%WHAT: Append entry to kmlobj_struct

if isempty(link)
    return
end

tmp_struct = struct('radar_id',radar_id,'subset_id',subset_id,...
    'start_timestamp',vol_start_time,'stop_timestamp',vol_stop_time,...
    'latlonbox',storm_latlonbox,'type',type,'nl',link,'ffn',ffn);

kmlobj_struct = [kmlobj_struct,tmp_struct];

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
