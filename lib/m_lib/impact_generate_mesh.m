function impact_generate_mesh(vol_struct,storm_jstruct,tracking_id_list,transform_path)

%WHAT: for tracks with a cell in the latest volume for a radar, generate a
%raster. Raster is the convex hull if a pair exists, or just a mask. Can't
%be integrated with swath_kml due to radar centric requirement of impact
%maps


%load radar colormap and global config
load('global.config.mat')
load([site_info_fn,'.mat']);
load('vis.config.mat')

%generate unique list of radar ids and their index for remapping
[uniq_storm_rid_list,~,rid_idx]  = unique(utility_jstruct_to_mat([storm_jstruct.radar_id],'N'));
storm_timestamp_list             = datenum(utility_jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
vol_radar_id                     = [vol_struct.radar_id];
vol_timestamp                    = [vol_struct.start_timestamp];

%for each radar id
for i = 1:length(uniq_storm_rid_list)
    %extract track list
    target_rid                        = uniq_storm_rid_list(i);
    radar_step                        = utility_radar_step(vol_struct,target_rid);    
    %init blank grid
    transform_fn = [transform_path,'regrid_transform_',num2str(target_rid,'%02.0f'),'.mat'];
    load(transform_fn,'grid_size')
    impact_grid  =  zeros(grid_size(1),grid_size(2));
    %extract radar volume times from strom
    
    %filter by first mesh threshold??? earlier???
    
    %loop track id
    %pass each pair to gridding
    %should gridding be a linear interpolation??!?!
    %collate and save... want a file for each volume.
    
    
    rid_track_list                    = tracking_id_list(rid_idx==i);
    uniq_rid_track_list               = unique(rid_track_list);
    
    
    %extract newest for vol time for target_rid
    for j = 1:length(uniq_rid_track_list)
        target_track          = uniq_rid_track_list(j);
        track_idx             = tracking_id_list==target_track;
        %sort track by time
        track_time            = storm_timestamp_list(track_idx);
        [track_time,sort_idx] = sort(track_time);
        track_idx             = track_idx(sort_idx);
        %extract track jstruct
        if length(track_idx)>1
            offset = 1;
        else
            offset = 0;
        end
        track_jstruct    = storm_jstruct(track_idx(end-offset:end));
        %generate swath
        track_latloncent = utility_jstruct_to_mat([track_jstruct.storm_latlonbox],'S');
        track_ijbox      = utility_jstruct_to_mat([track_jstruct.storm_ijbox],'S');
        track_struct     = struct('track_data',track_jstruct.mesh_grid,'track_latloncent',track_latloncent,...
            'track_ijbox',track_ijbox,'track_date_list',track_time);
        %for each mesh threshold
        for k = 1:length(swath_mesh_threshold)
            %generate swath grid
            mesh_threshold   = swath_mesh_threshold(i);
            out_struct       = process_swath(track_struct,mesh_threshold,radar_step,grid_size);
            %collate convex density grid using max function
            mesh_grid        = (out_struct.density_grid > 0).*mesh_threshold;
            impact_grid      = max(cat(3,impact_grid,mesh_grid),[],3);
        end
    end
    %save impact grid to file
    data_tag      = ['mesh_',datestr(newest_vol_timestamp,'yyyymmdd_HHMMSS')];
    sd_impact_ffn = [impact_tmp_root,num2str(target_rid,'%02.0f'),'/',data_tag,'.mat'];
    save(sd_impact_ffn,'impact_grid');
end