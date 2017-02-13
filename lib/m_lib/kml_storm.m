function kmlobj_struct = kml_storm(kmlobj_struct,vol_struct,storm_jstruct,tracking_id_list,download_ffn_list,dest_root,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure for a single radar_id

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/vis.config.mat')

%extract storm ids
if ~isempty(storm_jstruct)
    %storm_subset_id = jstruct_to_mat([storm_jstruct.subset_id],'N');
else
    return
end

%init index of xsec alts from vol_alt
xsec_idx = [];
vol_alt  = [v_grid:v_grid:v_tops];
for i=1:length(xsec_alt)
    [~,tmp_idx] = min(abs(xsec_alt(i)-vol_alt));
    xsec_idx    = [xsec_idx;tmp_idx];
end

storm_subset_id_list  = jstruct_to_mat([storm_jstruct.sort_id],'S');

%% generate cell objects
for i=1:length(download_ffn_list)
    %extract parts
    [~,temp_fn,~] = fileparts(download_ffn_list{i});
    %calc stop_time
    radar_id   = str2num(temp_fn(1:2));
    radar_step = calc_radar_step(vol_struct,radar_id);
    cell_path  = [cell_obj_path,num2str(radar_id,'%02.0f'),'/'];
    %extract data_tag
    data_tag       = temp_fn(1:end-6);
    data_start_ts  = datenum(data_tag(4:end),r_tfmt);
    data_stop_ts   = addtodate(data_start_ts,radar_step,'minute');
    %% cell_objects
    h5_fn  = [data_tag,'.storm.h5'];
    h5_ffn = [download_path,h5_fn];
    %check for a h5 dataset with the tar
    if exist(h5_ffn,'file') == 2
        %THESE FILES ARE NOT UNTARED
        h5_info   = h5info(h5_ffn);
        n_groups  = length(h5_info.Groups);
        %convert each group to volume
        for j=1:n_groups
            %create subset_id
            subset_id         = [datestr(data_start_ts,ddb_tfmt),'_',num2str(radar_id,'%02.0f'),'_',num2str(j,'%03.0f')];
            kml_fn            = [num2str(radar_id,'%02.0f'),'_',datestr(data_start_ts,r_tfmt),'_',num2str(j,'%03.0f')];
            %match subset to entry in storm_jstruct
            storm_jstruct_idx = find(strcmp(storm_subset_id_list,subset_id));
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
                    [link,ffn]    = kml_storm_xsec(dest_root,cell_path,kml_fn,refl_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_refl_cmap,min_dbz,'dbzh');
                    kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_dbzh',link,ffn);
                end
            end
            %Dopl xsections
            if options(4)==1 && vol_vel_ni~=0
                vel_vol         = double(storm_data_struct.vel_vol)./r_scale;
                for k=1:length(xsec_idx)
                    [link,ffn]    = kml_storm_xsec(dest_root,cell_path,kml_fn,vel_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_vel_cmap,min_vel,'vradh');
                    kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_vradh',link,ffn);
                end
            end    
            %iso
            if options(5)==1 || options(6)==1
                [link,ffn]    = kml_storm_collada(dest_root,cell_path,kml_fn,options,smooth_refl_vol,storm_latlonbox);
                kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,subset_id,data_start_ts,data_stop_ts,storm_latlonbox,'iso',link,ffn);
            end
        end
    end
end

%% tracking objects

%init paths
stats_ffn         = [dest_root,track_obj_path,'stat.kml'];
track_ffn         = [dest_root,track_obj_path,'track.kml'];
swath_ffn         = [dest_root,track_obj_path,'swath.kml'];
nowcast_ffn       = [dest_root,track_obj_path,'nowcast.kml'];
nowcast_stats_ffn = [dest_root,track_obj_path,'nowcast_stat.kml'];
%init vars
stat_kml          = '';
track_kml         = '';
swath_kml         = '';
nowcast_kml       = '';
nowcast_stat_kml  = '';

%process track objects (replaced every run)
if ~isempty(storm_jstruct)
    % create unique track list
    storm_radar_id_list  = jstruct_to_mat([storm_jstruct.radar_id],'N');
    storm_timestamp_list = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
    uniq_track_id_list   = unique(tracking_id_list);
    %loop through tracks
    for i=1:length(uniq_track_id_list)
        track_id = uniq_track_id_list(i);
        %skip null track group
        if track_id == 0
            continue
        end
        track_idx         = find(track_id==tracking_id_list);
        %skip short tracks
        if length(track_idx)<min_track_cells
            continue
        end
        track_jstruct     = storm_jstruct(track_idx);
        %% track objects
        if options(7)==1
            stat_kml      = kml_storm_stat(stat_kml,track_jstruct,track_id);
        end
        if options(8)==1
            track_kml     = kml_storm_track(track_kml,track_jstruct,track_id);
        end
        if options(9)==1
            swath_kml     = kml_storm_swath(swath_kml,track_jstruct,track_id);
        end
        %% nowcast, only generate for tracks which extend to the last timestamp in storm_jstruct
        if options(10)==1
            %check timestamp of of last cell in track from radar n is the
            %same time as the last scan from radar n
            end_track_radar_id  = storm_radar_id_list(track_idx(end));
            end_track_timestamp = storm_timestamp_list(track_idx(end));
            last_radar_timestamp = max(storm_timestamp_list(storm_radar_id_list==end_track_radar_id));
            if end_track_timestamp == last_radar_timestamp
                [nowcast_kml,nowcast_stat_kml] = kml_storm_nowcast(nowcast_kml,nowcast_stat_kml,storm_jstruct,tracking_id_list,track_id);
            end
        end
    end
end

%cell stats
if options(7)==1
    ge_kml_out(stats_ffn,'Cell Stats',stat_kml);
end
%track
if options(8)==1
    ge_kml_out(track_ffn,'Tracks',track_kml);
end
%swath
if options(9)==1
    ge_kml_out(swath_ffn,'Swaths',swath_kml);
end
%nowcast
if options(10)==1
    ge_kml_out(nowcast_ffn,'Nowcasts',nowcast_kml);
    ge_kml_out(nowcast_stats_ffn,'Nowcast Stats',nowcast_stat_kml);
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
