function kmlobj_struct = kml_storm(kmlobj_struct,vol_struct,storm_jstruct,tracking_id_list,dest_root,options)

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

proced_idx            = find([storm_jstruct.proced]==false);
%% generate cell objects
for i=1:length(proced_idx)
    %init
    radar_id       = str2num(storm_jstruct(proced_idx(i)).radar_id.N);
    cell_path      = [cell_obj_path,num2str(radar_id,'%02.0f'),'/'];
    data_start_ts  = datenum(storm_jstruct(proced_idx(i)).start_timestamp.S,ddb_tfmt);
    radar_step     = calc_radar_step(vol_struct,radar_id);
    data_stop_ts   = addtodate(data_start_ts,radar_step,'minute');
    data_tag       = [num2str(radar_id,'%02.0f'),'_',datestr(data_start_ts,r_tfmt)];
    sort_id        = storm_jstruct(proced_idx(i)).sort_id.S;
    subset_id      = str2num(storm_jstruct(proced_idx(i)).subset_id.N);
    kml_fn         = [data_tag,'_',num2str(subset_id,'%03.0f')];
    %extract storm latlonbox
    storm_latlonbox   = str2num(storm_jstruct(proced_idx(i)).storm_latlonbox.S);
    %storm_latlonbox   = [storm_latlonbox(1)+h_grid/2,storm_latlonbox(2)-h_grid/2,storm_latlonbox(3)+h_grid/2,storm_latlonbox(4)-h_grid/2]; %stretch for GE coords
    %extract data from struct
    stormh5_ffn       = storm_jstruct(proced_idx(i)).local_stormh5_ffn;
    storm_data_struct = h5_data_read(stormh5_ffn,'',subset_id);
    refl_vol          = double(storm_data_struct.refl_vol)./r_scale;
    smooth_refl_vol   = flipud(smooth3(refl_vol)); %smooth volume
    
    %Refl xsections
    if options(3)==1
        for k=1:length(xsec_idx)
            [link,ffn]    = kml_storm_xsec(dest_root,cell_path,kml_fn,refl_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_refl_cmap,min_dbz,'dbzh');
            kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_dbzh',link,ffn);
        end
    end
    
    %Dopl xsections
    if options(4)==1 && vol_vel_ni~=0
        vel_vol         = double(storm_data_struct.vel_vol)./r_scale;
        for k=1:length(xsec_idx)
            [link,ffn]    = kml_storm_xsec(dest_root,cell_path,kml_fn,vel_vol,xsec_idx(k),xsec_alt(k),storm_latlonbox,interp_vel_cmap,min_vel,'vradh');
            kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,data_start_ts,data_stop_ts,storm_latlonbox,'xsec_vradh',link,ffn);
        end
    end
    
    %iso
    if options(5)==1 || options(6)==1
        [link,ffn]    = kml_storm_collada(dest_root,cell_path,kml_fn,options,smooth_refl_vol,storm_latlonbox);
        kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,data_start_ts,data_stop_ts,storm_latlonbox,'iso',link,ffn);
    end
end

%% tracking objects

%init paths
stats_ffn         = [dest_root,track_obj_path,'stat.kml'];
track_ffn         = [dest_root,track_obj_path,'track.kml'];
swath_ffn         = [dest_root,track_obj_path,'swath.kml'];
swath_stat_ffn    = [dest_root,track_obj_path,'swath_stat.kml'];
nowcast_ffn       = [dest_root,track_obj_path,'nowcast.kml'];
nowcast_stat_ffn  = [dest_root,track_obj_path,'nowcast_stat.kml'];
%init vars
stat_kml          = '';
track_kml         = '';
swath_kml         = '';
swath_stat_kml    = '';
nowcast_kml       = '';
nowcast_stat_kml  = '';

%process track objects (replaced every run for updated radars)
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
        track_jstruct         = storm_jstruct(track_idx);
        track_time            = storm_timestamp_list(track_idx);
        %sort by time
        [track_time,sort_idx] = sort(track_time);
        track_jstruct         = track_jstruct(sort_idx);
        %% track objects
        if options(7)==1
            stat_kml  = kml_storm_stat(stat_kml,track_jstruct,track_id);
        end
        if options(8)==1
            track_kml = kml_storm_track(track_kml,track_jstruct,track_id);
        end
        if options(9)==1
            [swath_kml,swath_stat_kml] = kml_storm_swath(swath_kml,swath_stat_kml,track_jstruct,track_id);
        end
        %% nowcast, only generate for tracks which extend to the last timestamp in storm_jstruct
        if options(10)==1
            %check timestamp of of last cell in track from radar n is the
            %same time as the last scan from radar n
            end_track_radar_id  = storm_radar_id_list(track_idx(end));
            end_track_timestamp = track_time(end);
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
    ge_kml_out(swath_stat_ffn,'Swaths Stats',swath_stat_kml);
end
%nowcast
if options(10)==1
    ge_kml_out(nowcast_ffn,'Nowcasts',nowcast_kml);
    ge_kml_out(nowcast_stat_ffn,'Nowcast Stats',nowcast_stat_kml);
end


function kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,start_ts,stop_ts,storm_latlonbox,type,link,ffn)
%WHAT: Append entry to kmlobj_struct

if isempty(link)
    return
end

tmp_struct = struct('radar_id',radar_id,'sort_id',sort_id,...
    'start_timestamp',start_ts,'stop_timestamp',stop_ts,...
    'latlonbox',storm_latlonbox,'type',type,'nl',link,'ffn',ffn);

kmlobj_struct = [kmlobj_struct,tmp_struct];
