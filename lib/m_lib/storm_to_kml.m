function object_struct = storm_to_kml(object_struct,radar_id,oldest_time,newest_time,tar_fn_list,dest_root,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%init vars
oldest_time_str   = datestr(oldest_time,ddb_tfmt);
newest_time_str   = datestr(newest_time,ddb_tfmt);
radar_id_str      = num2str(radar_id,'%02.0f');
storm_flag        = 0;
cell_stat_kml     = '';
track_kml         = '';
swath_kml         = '';
nowcast_kml       = '';
nowcast_stat_kml  = '';

%init paths
track_path        = [dest_root,track_obj_path];
cell_stats_ffn    = [track_path,radar_id_str,'/cell_stat_',radar_id_str,'.kml'];
track_ffn         = [track_path,radar_id_str,'/track_',radar_id_str,'.kml'];
swath_ffn         = [track_path,radar_id_str,'/swath_',radar_id_str,'.kml'];
nowcast_ffn       = [track_path,radar_id_str,'/nowcast_',radar_id_str,'.kml'];
nowcast_stats_ffn = [track_path,radar_id_str,'/nowcast_stat_',radar_id_str,'.kml'];

scan_path  = [scan_obj_path,radar_id_str,'/'];        
cell_path  = [cell_obj_path,radar_id_str,'/'];
track_path = [track_obj_path,radar_id_str,'/'];      

%init xsec alts
xsec_idx = [];
r_alt    = site_elv_list(site_id_list==radar_id);
vol_alt  = [v_grid:v_grid:v_range]'+r_alt;
for i=1:length(xsec_alt)
    [~,tmp_idx] = min(abs(xsec_alt(i)-vol_alt));
    xsec_idx    = [xsec_idx;tmp_idx];
end

%extract odimh5 atts for radar_id
odimh5_atts   = 'tilt1,tilt2,img_latlonbox,vel_ni,sig_refl_flag,start_timestamp';
jstruct_out   = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
jstruct_out   = clean_jstruct(jstruct_out,6);
if ~isempty(jstruct_out)
    radar_ts       = datenum(jstruct_to_mat([jstruct_out.start_timestamp],'S'),ddb_tfmt);
    vol_latlonbox  = str2num(jstruct_out(1).img_latlonbox.S)./geo_scale;
    vol_vel_ni     = str2num(jstruct_out(1).vel_ni.N);
    vol_tilt1_str  = jstruct_out(1).tilt1.N;
    vol_tilt2_str  = jstruct_out(1).tilt2.N;
    sig_refl_list  = jstruct_to_mat([jstruct_out.sig_refl_flag],'N');
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
    radar_ts      = [];
    sig_refl_list = [];
end

%extract storm atts for radar_id
if any(sig_refl_list)
    %query storm ddb
    storm_atts      = 'subset_id,start_timestamp,track_id,storm_latlonbox,storm_dbz_centlat,storm_dbz_centlon,storm_edge_lat,storm_edge_lon,area,cell_vil,max_tops,max_mesh,orient,maj_axis,min_axis';
    storm_jstruct   = ddb_query('radar_id',radar_id_str,'subset_id',oldest_time_str,newest_time_str,storm_atts,storm_ddb_table);
else
    storm_jstruct   = [];
end

%extract storm ids
if ~isempty(storm_jstruct)
    storm_subset_id = jstruct_to_mat([storm_jstruct.subset_id],'S');
else
    storm_subset_id = {};
end

%generate data from tar_fn_list (scans and storm volumes)
for i=1:length(tar_fn_list)
    %init kmlobj ffn list
    kmlobj_nl = {};
    %extract data_tag
    data_tag       = tar_fn_list{i}(1:end-7);
    data_start_ts  = datenum(data_tag(4:end),r_tfmt);
    data_stop_ts   = addtodate(data_start_ts,radar_timestep,'minute');
    %% scan ground overlays
    %scan1_refl
    if options(1)==1
        %create kml for tilt1 image
        scan_tag      = [data_tag,'.scan1_refl'];
        [link,ffn]    = kml_scan_ppi(dest_root,scan_tag,download_path,vol_latlonbox,scan_path,vol_tilt1_str);
        object_struct = collate_kmlobj(object_struct,radar_id,'',data_start_ts,data_stop_ts,vol_latlonbox,'scan1_refl',link,ffn);
    end
    %scan2_refl
    if options(2)==1
        %create kml for tilt2 image
        scan_tag      = [data_tag,'.scan2_refl'];
        [link,ffn]    = kml_scan_ppi(dest_root,scan_tag,download_path,vol_latlonbox,scan_path,vol_tilt2_str);
        object_struct = collate_kmlobj(object_struct,radar_id,'',data_start_ts,data_stop_ts,vol_latlonbox,'scan2_refl',link,ffn);
    end
    %scan1_vel
    if options(3)==1 && vol_vel_ni~=0
        %create kml for tilt2 image
        scan_tag      = [data_tag,'.scan1_vel'];
        [link,ffn]    = kml_scan_ppi(dest_root,scan_tag,download_path,vol_latlonbox,scan_path,vol_tilt1_str);
        object_struct = collate_kmlobj(object_struct,radar_id,'',data_start_ts,data_stop_ts,vol_latlonbox,'scan1_vel',link,ffn);
    end
    %scan2_vel
    if options(4)==1 && vol_vel_ni~=0
        %create kml for tilt1 image
        scan_tag      = [data_tag,'.scan2_vel'];
        [link,ffn]    = kml_scan_ppi(dest_root,scan_tag,download_path,vol_latlonbox,scan_path,vol_tilt2_str);
        object_struct = collate_kmlobj(object_struct,radar_id,'',data_start_ts,data_stop_ts,vol_latlonbox,'scan2_vel',link,ffn);
    end
    
    %% cell_objects
    h5_fn  = [data_tag,'.storm.h5'];
    h5_ffn = [download_path,h5_fn];
    %check for a h5 dataset with the tar
    if exist(h5_ffn,'file') == 2
        %list groups
        h5_info   = h5info(h5_ffn);
        n_groups  = length(h5_info.Groups);
        %convert each group to volume
        for j=1:n_groups
            %create subset_id
            subset_id         = [datestr(data_start_ts,ddb_tfmt),'_',num2str(j,'%03.0f')];
            storm_tag         = [data_tag,'_',num2str(j,'%03.0f')];
            storm_jstruct_idx = find(ismember(storm_subset_id,subset_id));
            %no matching subset_id entries in ddb
            if isempty(storm_jstruct_idx)
                continue
            end
            %extract storm latlonbox
            storm_latlonbox   = str2num(storm_jstruct(storm_jstruct_idx).storm_latlonbox.S)./geo_scale;
            %extract struct from h5
            group_id          = num2str(j);
            storm_data_struct = h5_data_read(h5_fn,download_path,group_id);
            refl_vol          = double(storm_data_struct.refl_vol)./r_scale;
            smooth_refl_vol   = smooth3(refl_vol); %smooth volume
            %Refl xsections
            if options(5)==1
                for k=1:length(xsec_idx)
                    [link,ffn]    = kml_xsec(dest_root,cell_path,storm_tag,refl_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_refl_cmap,min_dbz,'refl');
                    object_struct = collate_kmlobj(object_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_refl',link,ffn);
                end
            end
            %Dopl xsections
            if options(6)==1 && vol_vel_ni~=0
                vel_vol         = double(storm_data_struct.vel_vol)./r_scale;
                for k=1:length(xsec_idx)
                    [link,ffn]    = kml_xsec(dest_root,cell_path,storm_tag,vel_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_vel_cmap,min_vel,'vel');
                    object_struct = collate_kmlobj(object_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_vel',link,ffn);
                end
            end    
            %inner iso
            if options(7)==1
                [link,ffn]    = kml_iso_collada(dest_root,cell_path,storm_tag,'inneriso',smooth_refl_vol,storm_latlonbox);
                object_struct = collate_kmlobj(object_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'inneriso',link,ffn);
            end
            %outer iso
            if options(8)==1
                [link,ffn]    = kml_iso_collada(dest_root,cell_path,storm_tag,'outeriso',smooth_refl_vol,storm_latlonbox);
                object_struct = collate_kmlobj(object_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'outeriso',link,ffn);
            end
        end
    end
end

%process track objects (replaced every run)
if ~isempty(storm_jstruct)
    %flag storms data
    storm_flag  = 1;
    % create unique track list
    track_id_list      = jstruct_to_mat([storm_jstruct.track_id],'N');
    timestamp_list     = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
    uniq_track_id_list = unique(track_id_list);
    %loop through tracks
    for i=1:length(uniq_track_id_list)
        track_id = uniq_track_id_list(i);
        %skip null track group
        if track_id == 0
            continue
        end
        track_idx     = find(track_id==track_id_list);
        %skip short tracks
        if length(track_idx)<min_track_cells
            continue
        end
        track_jstruct = storm_jstruct(track_idx);
        %% track objects
        if options(9)==1
            cell_stat_kml = kml_cell_stat(cell_stat_kml,track_jstruct,track_id);
        end
        if options(10)==1
            track_kml     = kml_storm_track(track_kml,track_jstruct,track_id,radar_start_ts,radar_stop_ts);
        end
        if options(11)==1
            swath_kml     = kml_storm_swath(swath_kml,track_jstruct,track_id,radar_start_ts,radar_stop_ts);
        end
        %% nowcast, only generate for tracks which extend to the last timestamp in storm_jstruct
        track_timestamp = timestamp_list(track_idx);
        if max(track_timestamp) == max(timestamp_list) && options(12)==1
            [nowcast_kml,nowcast_stat_kml] = kml_storm_nowcast(nowcast_kml,nowcast_stat_kml,track_idx,storm_jstruct,track_id,radar_start_ts,radar_stop_ts);
        end
    end
end

%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config

%scan1_refl
if options(1)==1
    generate_nl_scan(radar_id,object_struct,'scan1_refl',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%scan2_refl
if options(2)==1
    generate_nl_scan(radar_id,object_struct,'scan2_refl',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%scan1_vel
if options(3)==1
    generate_nl_scan(radar_id,object_struct,'scan1_vel',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%scan2_vel
if options(4)==1
    generate_nl_scan(radar_id,object_struct,'scan2_vel',[dest_root,scan_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%xsec_refl
if options(5)==1
    generate_nl_cell(radar_id,storm_jstruct,object_struct,'xsec_refl',[dest_root,cell_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%xsec_vel
if options(6)==1
    generate_nl_cell(radar_id,storm_jstruct,object_struct,'xsec_vel',[dest_root,cell_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%inneriso
if options(7)==1
    generate_nl_cell(radar_id,storm_jstruct,object_struct,'inneriso',[dest_root,cell_path],max_ge_alt,iso_minLodPixels,iso_maxLodPixels);
end
%outeriso
if options(8)==1
    generate_nl_cell(radar_id,storm_jstruct,object_struct,'outeriso',[dest_root,cell_path],max_ge_alt,iso_minLodPixels,iso_maxLodPixels);
end
%cell stats
if options(9)==1
    ge_kml_out(cell_stats_ffn,radar_id_str,cell_stat_kml);
end
%track
if options(10)==1
    ge_kml_out(track_ffn,radar_id_str,track_kml);
end
%swath
if options(11)==1
    ge_kml_out(swath_ffn,radar_id_str,swath_kml);
end
%nowcast
if options(12)==1
    ge_kml_out(nowcast_ffn,radar_id_str,nowcast_kml);
    ge_kml_out(nowcast_stats_ffn,radar_id_str,nowcast_stat_kml);
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

function generate_nl_cell(radar_id,storm_jstruct,object_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for cell or scan objects listed in object_Struct using
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

%keep object_struct entries from radar_id and type 
filt_idx      = find(ismember({object_struct.type},type) & [object_struct.radar_id]==radar_id);
object_struct = object_struct(filt_idx);

%init lists
type_list   = {object_struct.type};
subset_list = {object_struct.subset_id};
r_id_list   = [object_struct.radar_id];
time_list   = [object_struct.start_timestamp];

%build jstruct cell list and storm_id list
jstruct_subset_list = jstruct_to_mat([storm_jstruct.subset_id],'S');
jstruct_track_list  = jstruct_to_mat([storm_jstruct.track_id],'N');

%build track_list
[~,Lib]    = ismember(subset_list,jstruct_subset_list);
track_list = jstruct_track_list(Lib);
%exist if no tracks
if isempty(track_list)
    ge_kml_out([nl_path,nl_name,'.kml'],'','');
    return
end

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
        target_start     = object_struct(target_idx(j)).start_timestamp;
        target_stop      = object_struct(target_idx(j)).stop_timestamp;
        target_latlonbox = object_struct(target_idx(j)).latlonbox;
        target_link      = object_struct(target_idx(j)).nl;
        %nl
        timeSpanStart = datestr(target_start,ge_tfmt);
        timeSpanStop  = datestr(target_stop,ge_tfmt);
        region_kml    = ge_region(target_latlonbox,0,altLod,minlod,maxlod);
        kml_name      = datestr(target_start,r_tfmt);
        tmp_kml       = ge_networklink(tmp_kml,kml_name,target_link,0,'','',region_kml,timeSpanStart,timeSpanStop,1);
    end
    
    %group into folder
    track_name = ['track_id_',num2str(track_id)];
    nl_kml     = ge_folder(nl_kml,tmp_kml,track_name,'',1);
end
%write out
ge_kml_out([nl_path,nl_name,'.kml'],nl_name,nl_kml);


function generate_nl_scan(radar_id,object_struct,type,nl_path,altLod,minlod,maxlod)

%WHAT: generates kml for cell or scan objects listed in object_Struct using
%a radar_id and type filter
load('tmp/global.config.mat')

%init radar_id and type list
type_list = {object_struct.type};
r_id_list = [object_struct.radar_id];
time_list = [object_struct.start_timestamp];
%init vars
scan_latlonbox = object_struct(1).latlonbox; %does not change
region_kml     = ge_region(scan_latlonbox,0,altLod,minlod,maxlod);
%init nl
nl_kml       = '';
name         = [type,'_',num2str(radar_id,'%02.0f')];
%find entries from correct radar_id and type
target_idx   = find(ismember(type_list,type) & r_id_list==radar_id);
%write out offline radar image if no data is present
if isempty(target_idx)
    radar_id_str = num2str(radar_id,'%02.0f');
    nl_kml       = ge_networklink('','Radar Offline',['radar_offline_',radar_id_str,'.kmz'],0,0,60,region_kml,'','',1);
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
    %nl
    timeSpanStart = datestr(target_start,ge_tfmt);
    timeSpanStop  = datestr(target_stop,ge_tfmt);
    kml_name      = datestr(target_start,r_tfmt);
    nl_kml        = ge_networklink(nl_kml,kml_name,target_link,0,'','',region_kml,timeSpanStart,timeSpanStop,1);
end
%write out
ge_kml_out([nl_path,name,'.kml'],name,nl_kml);
