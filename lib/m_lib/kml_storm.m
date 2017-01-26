function kmlobj_struct = kml_storm(kmlobj_struct,storm_jstruct,vol_struct,storm_tracking,download_ffn_list,dest_root,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure for a single radar_id

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%extract storm ids
if ~isempty(storm_jstruct)
    %storm_subset_id = jstruct_to_mat([storm_jstruct.subset_id],'N');
else
    return
end

%init vars
stat_kml          = '';
track_kml         = '';
swath_kml         = '';
nowcast_kml       = '';
nowcast_stat_kml  = '';

%NEED TO FIX THIS SECTION - HOW WILL THE STORM/TRACK OBJECTS BE STRUCTURED
%IN KML?

%init paths
stats_ffn         = [dest_root,track_obj_path,radar_id_str,'/stat_',radar_id_str,'.kml'];
track_ffn         = [dest_root,track_obj_path,radar_id_str,'/track_',radar_id_str,'.kml'];
swath_ffn         = [dest_root,track_obj_path,radar_id_str,'/swath_',radar_id_str,'.kml'];
nowcast_ffn       = [dest_root,track_obj_path,radar_id_str,'/nowcast_',radar_id_str,'.kml'];
nowcast_stats_ffn = [dest_root,track_obj_path,radar_id_str,'/nowcast_stat_',radar_id_str,'.kml'];

cell_path  = [cell_obj_path,radar_id_str,'/'];

%init index of xsec alts from vol_alt
xsec_idx = [];
r_alt    = siteinfo_alt_list(siteinfo_id_list==radar_id)/1000;
vol_alt  = [v_grid:v_grid:v_tops]'+r_alt;
for i=1:length(xsec_alt)
    [~,tmp_idx] = min(abs(xsec_alt(i)-vol_alt));
    xsec_idx    = [xsec_idx;tmp_idx];
end

%% generate cell objects
for i=1:length(download_ffn_list)
    %extract parts
    [~,temp_fn,~] = fileparts(download_ffn_list(i));
    %calc stop_time
    radar_id   = str2num(temp_fn(1:2));
    radar_step = calc_radar_step(vol_struct,radar_id);
    %extract data_tag
    data_tag       = temp_fn(1:end-7);
    data_start_ts  = datenum(data_tag(4:end),r_tfmt);
    data_stop_ts   = addtodate(data_start_ts,radar_step,'minute');
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
            %check if cell exists in storm_jstruct (may be masked out)
            %no matching subset_id entries in ddb
            if isempty(storm_jstruct_idx)
                continue
            end
            %extract storm latlonbox
            storm_latlonbox   = str2num(storm_jstruct(storm_jstruct_idx).storm_latlonbox.S);
            %extract struct from h5
            group_id          = num2str(j);
            storm_data_struct = h5_data_read(h5_fn,download_path,group_id);
            refl_vol          = double(storm_data_struct.refl_vol)./r_scale;
            smooth_refl_vol   = smooth3(refl_vol); %smooth volume
            %Refl xsections
            if options(3)==1
                for k=1:length(xsec_idx)
                    [link,ffn]    = kml_xsec(dest_root,cell_path,storm_tag,refl_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_refl_cmap,min_dbz,'refl');
                    kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_refl',link,ffn);
                end
            end
            %Dopl xsections
            if options(4)==1 && vol_vel_ni~=0
                vel_vol         = double(storm_data_struct.vel_vol)./r_scale;
                for k=1:length(xsec_idx)
                    [link,ffn]    = kml_xsec(dest_root,cell_path,storm_tag,vel_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_vel_cmap,min_vel,'vel');
                    kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_vel',link,ffn);
                end
            end    
            %inner iso
            if options(5)==1
                [link,ffn]    = kml_storm_collada(dest_root,cell_path,storm_tag,'inneriso',smooth_refl_vol,storm_latlonbox);
                kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'inneriso',link,ffn);
            end
            %outer iso
            if options(6)==1
                [link,ffn]    = kml_storm_collada(dest_root,cell_path,storm_tag,'outeriso',smooth_refl_vol,storm_latlonbox);
                kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'outeriso',link,ffn);
            end
        end
    end
end

%process track objects (replaced every run)
if ~isempty(storm_jstruct)
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
        if options(7)==1
            stat_kml      = kml_storm_stat(stat_kml,track_jstruct,track_id);
        end
        if options(8)==1
            track_kml     = kml_storm_track(track_kml,track_jstruct,track_id,oldest_time,radar_stop_ts);
        end
        if options(9)==1
            swath_kml     = kml_storm_swath(swath_kml,track_jstruct,track_id,oldest_time,radar_stop_ts);
        end
        %% nowcast, only generate for tracks which extend to the last timestamp in storm_jstruct
        track_timestamp = timestamp_list(track_idx);
        if max(track_timestamp) == max(timestamp_list) && options(10)==1
            [nowcast_kml,nowcast_stat_kml] = kml_storm_nowcast(nowcast_kml,nowcast_stat_kml,track_idx,storm_jstruct,track_id,oldest_time,newest_time);
        end
    end
end







%% generate new nl kml for cell and scan objects
%load radar colormap and gobal config
%xsec_refl
if options(3)==1
    generate_nl_cell(radar_id,storm_jstruct,kmlobj_struct,'xsec_refl',[dest_root,cell_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%xsec_vel
if options(4)==1
    generate_nl_cell(radar_id,storm_jstruct,kmlobj_struct,'xsec_vel',[dest_root,cell_path],max_ge_alt,ppi_minLodPixels,ppi_maxLodPixels);
end
%inneriso
if options(5)==1
    generate_nl_cell(radar_id,storm_jstruct,kmlobj_struct,'inneriso',[dest_root,cell_path],max_ge_alt,iso_minLodPixels,iso_maxLodPixels);
end
%outeriso
if options(6)==1
    generate_nl_cell(radar_id,storm_jstruct,kmlobj_struct,'outeriso',[dest_root,cell_path],max_ge_alt,iso_minLodPixels,iso_maxLodPixels);
end
%cell stats
if options(7)==1
    ge_kml_out(stats_ffn,radar_id_str,stat_kml);
end
%track
if options(8)==1
    ge_kml_out(track_ffn,radar_id_str,track_kml);
end
%swath
if options(9)==1
    ge_kml_out(swath_ffn,radar_id_str,swath_kml);
end
%nowcast
if options(10)==1
    ge_kml_out(nowcast_ffn,radar_id_str,nowcast_kml);
    ge_kml_out(nowcast_stats_ffn,radar_id_str,nowcast_stat_kml);
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


function generate_nl_cell(radar_id,storm_jstruct,kmlobj_struct,type,nl_path,altLod,minlod,maxlod)

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
filt_idx      = find(ismember({kmlobj_struct.type},type) & [kmlobj_struct.radar_id]==radar_id);
kmlobj_struct = kmlobj_struct(filt_idx);

%init lists
subset_list = {kmlobj_struct.subset_id};
time_list   = [kmlobj_struct.start_timestamp];

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
        target_start     = kmlobj_struct(target_idx(j)).start_timestamp;
        target_stop      = kmlobj_struct(target_idx(j)).stop_timestamp;
        target_latlonbox = kmlobj_struct(target_idx(j)).latlonbox;
        target_link      = kmlobj_struct(target_idx(j)).nl;
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