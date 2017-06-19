function kmlobj_struct = vis_storm(kmlobj_struct,vol_struct,storm_jstruct,tracking_id_list,dest_root,transform_path,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure for a single radar_id

%load radar colormap and gobal config
load('interp_cmaps.mat')
load('global.config.mat')
load([site_info_fn,'.mat']);
load('vis.config.mat')

%extract storm ids
if isempty(storm_jstruct) || isempty(vol_struct)
    return
end
vol_radar_id  = [vol_struct.radar_id];
vol_timestamp = [vol_struct.start_timestamp];

proced_idx            = find([storm_jstruct.proced]==false);
%% generate cell objects
for i=1:length(proced_idx)
    %init labels
    radar_id       = str2double(storm_jstruct(proced_idx(i)).radar_id.N);
    cell_path      = [cell_obj_path,num2str(radar_id,'%02.0f'),'/'];
    %init time
    data_start_ts  = datenum(storm_jstruct(proced_idx(i)).start_timestamp.S,ddb_tfmt);
    radar_step     = utility_radar_step(vol_struct,radar_id);
    data_stop_ts   = addtodate(data_start_ts,radar_step,'minute');
    %init tags
    data_tag       = [num2str(radar_id,'%02.0f'),'_',datestr(data_start_ts,r_tfmt)];
    sort_id        = storm_jstruct(proced_idx(i)).sort_id.S;
    %init subset
    subset_id      = str2double(storm_jstruct(proced_idx(i)).subset_id.N);
    kml_fn         = [data_tag,'_',num2str(subset_id,'%03.0f')];
    %init h_grid
    h_grid_deg     = str2double(storm_jstruct(proced_idx(i)).h_grid.N);
    v_grid         = str2double(storm_jstruct(proced_idx(i)).v_grid.N);
    %extract storm latlonbox
    storm_latlonbox   = str2num(storm_jstruct(proced_idx(i)).storm_latlonbox.S); %must be str2num (vector)
    %extract data from struct
    stormh5_ffn       = storm_jstruct(proced_idx(i)).local_stormh5_ffn;
    storm_data_struct = h5_data_read(stormh5_ffn,'',subset_id);
    refl_vol          = double(storm_data_struct.refl_vol)./r_scale;
    smooth_refl_vol   = flipud(smooth3(refl_vol)); %smooth volume
    
    %iso
    if options(3)==1 || options(4)==1
        [link,ffn]    = vis_storm_collada_kml(dest_root,cell_path,kml_fn,options,smooth_refl_vol,storm_latlonbox,h_grid_deg,v_grid);
        kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,data_start_ts,data_stop_ts,storm_latlonbox,'iso',link,ffn);
    end
end

%% tracking objects

%init paths
stats_ffn         = [dest_root,track_obj_path,'stat.kml'];
track_ffn         = [dest_root,track_obj_path,'track.kml'];
swath_ffn         = [dest_root,track_obj_path,'swath.kml'];
nowcast_ffn       = [dest_root,track_obj_path,'nowcast.kml'];
%init vars
stat_kml          = '';
track_kml         = '';
swath_kml         = '';
nowcast_kml       = '';

%process track objects (replaced every run for updated radars)
if ~isempty(storm_jstruct)
    % create unique track list
    storm_radar_id_list  = utility_jstruct_to_mat([storm_jstruct.radar_id],'N');
    storm_timestamp_list = datenum(utility_jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
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
        if length(track_idx) < min_track_cells
            continue
        end
        track_jstruct         = storm_jstruct(track_idx);
        track_time            = storm_timestamp_list(track_idx);
        %sort by time
        [track_time,sort_idx] = sort(track_time);
        track_jstruct         = track_jstruct(sort_idx);
        %extract newest timestamp (+ radar_id) from track and the newest timestamp from vol_struct for the same radar_id (to check if a new cell has been added) 
        end_track_radar_id   = storm_radar_id_list(track_idx(end));
        end_track_timestamp  = track_time(end);
        newest_vol_timestamp = max(vol_timestamp(vol_radar_id==end_track_radar_id));
        %% track objects
        if options(5)==1
            stat_kml  = vis_storm_stat_kml(stat_kml,track_jstruct,track_id);
        end
        if options(6)==1
            track_kml = vis_storm_track_kml(track_kml,track_jstruct,track_id);
        end
        if options(7)==1
            swath_kml = vis_storm_meshswath_kml(swath_kml,track_jstruct,track_id);
        end
        %% objects for new data, check if a new cell has been added
        if end_track_timestamp == newest_vol_timestamp
            %nowcast
            if options(8)==1
                nowcast_kml = kml_storm_nowcast(nowcast_kml,storm_jstruct,tracking_id_list,track_id);
            end
        end
    end
end
%generate mesh impact map for unprocessed storm_jstructs
impact_generate_mesh(vol_struct,storm_jstruct(proced_idx),tracking_id_list(proced_idx),transform_path);

%cell stats
if options(5)==1
    ge_kml_out(stats_ffn,'Cell Stats',stat_kml);
end
%track
if options(6)==1
    ge_kml_out(track_ffn,'Tracks',track_kml);
end
%swath
if options(7)==1
    ge_kml_out(swath_ffn,'Swaths',swath_kml);
end
%nowcast
if options(8)==1
    ge_kml_out(nowcast_ffn,'Nowcasts',nowcast_kml);
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
