function impact_generate_mesh(vol_struct,storm_jstruct,tracking_id_list,transform_path)

%WHAT: for tracks with a cell in the latest volume for a radar, generate a
%raster. Raster is the convex hull if a pair exists, or just a mask. Can't
%be integrated with swath_kml due to radar centric requirement of impact
%maps


%load radar colormap and global config
load('global.config.mat')
load([site_info_fn,'.mat'])
load('vis.config.mat')

%generate unique list of radar ids and their index for remapping
[uniq_storm_rid_list,~,rid_idx]  = unique(utility_jstruct_to_mat([storm_jstruct.radar_id],'N'));
storm_timestamp_list             = datenum(utility_jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
storm_mesh_list                  = utility_jstruct_to_mat([storm_jstruct.max_mesh],'N');

%for each unique radar id
for i = 1:length(uniq_storm_rid_list)
    
    %extract radar storm times
    target_rid          = uniq_storm_rid_list(i);
    rid_track_list      = tracking_id_list(rid_idx==i);
    uniq_rid_track_list = unique(rid_track_list);
    radar_step          = utility_radar_step(vol_struct,target_rid);
    
    %skip if no high mesh
    rid_mesh_list       = storm_mesh_list(rid_idx==i);
    if ~any(rid_mesh_list>=swath_mesh_threshold(1))
        continue
    end
    
    %init blank grid
    transform_fn = [transform_path,'regrid_transform_',num2str(target_rid,'%02.0f'),'.mat'];
    load(transform_fn,'grid_size')
    impact_grid  =  zeros(grid_size(1),grid_size(2));
    
    %for each unique track for the radar
    for j = 1:length(uniq_rid_track_list)
        
        %skip 0th track
        track_id = uniq_rid_track_list(j);
        if track_id == 0
            continue
        end
        
        %extract track idx
        track_idx  = find(tracking_id_list == track_id);
        track_mesh = storm_mesh_list(track_idx);
        track_time = storm_timestamp_list(track_idx);
        
        %sort track by time
        [track_time,sort_idx] = sort(track_time);
        track_idx             = track_idx(sort_idx);
        track_mesh            = track_mesh(sort_idx);
        
        %prep for swath processing
        track_jstruct    = storm_jstruct(track_idx);
        track_latloncent = utility_jstruct_to_mat([track_jstruct.storm_latlonbox],'S');
        track_latloncent = str2num(cell2mat(track_latloncent));
        track_ijbox      = utility_jstruct_to_mat([track_jstruct.storm_ijbox],'S');
        track_ijbox      = str2num(cell2mat(track_ijbox));
        
        %generate swath
        for k = 1:length(swath_mesh_threshold)
            %generate swath grid
            mesh_threshold   = swath_mesh_threshold(k);
            %check for mesh threshold
            check_mask = track_idx(track_mesh>=mesh_threshold);
            if isempty(check_mask)
                continue
            end
            out_struct       = process_swath(track_latloncent,track_ijbox,track_time,{track_jstruct.mesh_grid},mesh_threshold,radar_step,grid_size);
            %collate convex density grid using max function
            mesh_grid        = (out_struct.density_grid > 0).*mesh_threshold;
            impact_grid      = max(cat(3,impact_grid,mesh_grid),[],3);
        end
    end
        
    %write out
    %note, file name represents newest volume in impact
    %grid. Can contains many volumes if vis is restarted (up to 2hours)
    if ~any(impact_grid(:))
        continue
    end
    out_fn   = [datestr(max(storm_timestamp_list(rid_idx==i)),r_tfmt),'.mat'];
    out_path = [impact_tmp_root,'hail/',num2str(target_rid,'%02.0f'),'/'];
    out_ffn  = [out_path,out_fn];
    if exist(out_path) ~= 7
        mkdir(out_path);
    end
    save(out_ffn,'impact_grid')

end