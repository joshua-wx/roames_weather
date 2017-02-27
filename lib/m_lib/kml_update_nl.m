function kml_update_nl(kmlobj_struct,storm_jstruct,track_id_list,dest_root,r_id_list,options)

%init
load('tmp/global.config.mat')
load('tmp/vis.config.mat')

%remove kmlobj which don't have a matching entry in storm_jstruct (BUG)
kml_sort_list       = {kmlobj_struct.sort_id};
jstruct_sort_list   = jstruct_to_mat([storm_jstruct.sort_id],'S');
filter_mask         = ismember(kml_sort_list,jstruct_sort_list);
%check for entries to remove
if any(~filter_mask)
    kmlobj_struct = kmlobj_struct(filter_mask);
    log_cmd_write('tmp/log.update_kml',strjoin(kml_sort_list(~filter_mask)),'','');
end

%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config
for i=1:length(r_id_list)
    %set radar_id
    radar_id  = r_id_list(i);
    ppi_path  = [dest_root,ppi_obj_path,num2str(radar_id,'%02.0f'),'/'];
    cell_path = [dest_root,cell_obj_path,num2str(radar_id,'%02.0f'),'/'];
    %PPI Reflectivity
    if options(1)==1
        generate_nl_ppi(radar_id,kmlobj_struct,'ppi_dbzh',ppi_path,max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
    end
    %PPI Velcoity
    if options(2)==1
        generate_nl_ppi(radar_id,kmlobj_struct,'ppi_vradh',ppi_path,max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
    end
    %xsec_refl
    if options(3)==1
        generate_nl_cell(radar_id,storm_jstruct,track_id_list,kmlobj_struct,'xsec_refl',cell_path,max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
    end
    %xsec_vel
    if options(4)==1
        generate_nl_cell(radar_id,storm_jstruct,track_id_list,kmlobj_struct,'xsec_vel',cell_pathmax_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
    end
    %iso
    if options(5)==1 || options(6)==1
        try
            generate_nl_cell(radar_id,storm_jstruct,track_id_list,kmlobj_struct,'iso',cell_path,max_ge_alt,iso_minLodPixels,iso_maxLodPixels);
        catch err
            keyboard
        end
    end
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

function generate_nl_cell(radar_id,storm_jstruct,track_id_list,kmlobj_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for cell objects listed in object_Struct using
%a radar_id and type filter
load('tmp/global.config.mat')

%init nl
nl_kml       = '';
nl_name      = [type,'_',num2str(radar_id,'%02.0f')];
%exist if no storm struct data
if isempty(storm_jstruct)
    ge_kml_out([nl_path,nl_name,'.kml'],'','');
    return
end

%keep kmlobj_struct entries from radar_id and type 
filt_idx            = find(ismember({kmlobj_struct.type},type) & [kmlobj_struct.radar_id]==radar_id);
kmlobj_struct       = kmlobj_struct(filt_idx);

%init lists
kml_sort_list       = {kmlobj_struct.sort_id};
time_list           = [kmlobj_struct.start_timestamp];

%build jstruct cell list and storm_id list
jstruct_sort_list = jstruct_to_mat([storm_jstruct.sort_id],'S');

%build track_list
[~,Lib]    = ismember(kml_sort_list,jstruct_sort_list);
%exist if no tracks
if isempty(Lib)
    ge_kml_out([nl_path,nl_name,'.kml'],'','');
    return
end
track_list = track_id_list(Lib);

%loop through unique tracks
uniq_track_list = unique(track_list);
for i=1:length(uniq_track_list)
    track_id = uniq_track_list(i);
    %find entries track
    target_idx   = find(track_list==track_id);

    %sort by time
    [~,sort_idx]  = sort(time_list(target_idx));
    target_idx    = target_idx(sort_idx);

    %loop through entries, appending kml
    tmp_kml = '';
    for j=1:length(target_idx)
        %target data
        target_start     = kmlobj_struct(target_idx(j)).start_timestamp;
        target_stop      = kmlobj_struct(target_idx(j)).stop_timestamp;
        target_latlonbox = kmlobj_struct(target_idx(j)).latlonbox;
        target_link      = kmlobj_struct(target_idx(j)).nl;
        target_subset_id = kmlobj_struct(target_idx(j)).sort_id(end-2:end);
        %nl
        timeSpanStart = datestr(target_start,ge_tfmt);
        timeSpanStop  = datestr(target_stop,ge_tfmt);
        region_kml    = ge_region(target_latlonbox,0,altLod,minlod,maxlod);
        kml_name      = [datestr(target_start,r_tfmt),'_',target_subset_id];
        tmp_kml       = ge_networklink(tmp_kml,kml_name,target_link,0,'','',region_kml,timeSpanStart,timeSpanStop,1);
    end
    
    %group into folder
    track_name = ['track_id_',num2str(track_id)];
    nl_kml     = ge_folder(nl_kml,tmp_kml,track_name,'',1);
end
%write out
ge_kml_out([nl_path,nl_name,'.kml'],nl_name,nl_kml);
