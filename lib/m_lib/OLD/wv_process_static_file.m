%write data/atts
scaled_llb  = round(vol_obj.llb*1000);
att_struct  = struct('img_max_lat',scaled_llb(1),'img_min_lat',scaled_llb(2),'img_max_lon',scaled_llb(3),'img_min_lon',scaled_llb(4));
data_struct = struct('tilt1_refl',vol_obj.scan1_refl,'tilt1_vel',vol_obj.scan1_vel,'tilt2_refl',vol_obj.scan2_refl,'tilt2_vel',vol_obj.scan2_vel);
h5_data_write(vol_data_fn,archive_path,vol_id,data_struct,att_struct)

%% Update prc_db and prc_data

%skip if storm_obj is empty
if isempty(storm_obj)
    return
end

%create paths
prc_data_fn = [arch_tag,'_prc_data.h5'];

%load db
if exist([archive_path,prc_db_fn],'file')==2 %file exists
    %read from file
    prc_db     = db_read(prc_db_fn,archive_path);
    %find any repeated times
    delete_idx = find([prc_db.start_time] == start_time);
    %remove data from same timestep
    if ~isempty(ind)
        disp(['duplicate prc_db objects exist for ',datestr(storm_obj.start_timedate),' IDR ',num2str(storm_obj.radar_id)]);
        prc_db = db_delete(prc_db,delete_idx);
        disp('old data removed')
    end
    subset_id = max(prc_db.subset_id)+1;
else
    %create a new vol_db
    prc_db    = struct;
    subset_id = 1;
end


track_id = 0;
for i=1:length(storm_obj)
    
    cell_llb   = round(storm_obj(i).subset_latlonbox*1000);
    cell_dcent = round(storm_obj(i).dbz_latloncent*1000);
    cell_stats = round(storm_obj(i).stats*10);
    %append and write db
    prc_db(end+1).subset_id     = subset_id;
    prc_db(end+1).track_id      = storm_obj.track_id;
    prc_db(end+1).start_time    = vol_obj.start_time;
    prc_db(end+1).stop_time     = vol_obj.stop_time;
    prc_db(end+1).cell_max_lat  = cell_llb(1);
    prc_db(end+1).cell_min_lat  = cell_llb(2); 
    prc_db(end+1).cell_max_lon  = cell_llb(3);
    prc_db(end+1).cell_min_lon  = cell_llb(4);
    prc_db(end+1).dbz_cent_lat  = cell_dcent(1);
    prc_db(end+1).dbz_cent_lon  = cell_dcent(2);
    %append stats
    for j=1:length(cell_stats)
        prc_db(end+1).(storm_obj(i).stats_labels{j}) = cell_stats(j);
    end
    db_write(prc_db_fn,archive_path,prc_db);

    %write data
    att_struct  = struct('h_grid',h_grid,'v_grid',v_grid);
    data_struct = struct('refl_vol',storm_obj(i).subset_refl,'vel_vol',storm_obj(i).subset_vel,...
                        'top_h_grid',storm_obj(i).top_h_grid,'sts_h_grid',storm_obj(i).sts_h_grid,...
                        'MESH_grid',storm_obj(i).MESH_grid,'POSH_grid',storm_obj(i).sts_h_grid,...
                        'max_dbz_grid',storm_obj(i).max_dbz_grid,'vil_grid',storm_obj(i).vil_grid);      
    h5_data_write(vol_data_fn,archive_path,vol_id,data_struct,att_struct)

    %move to next subset if
    subset_id = subset_id + 1;
    
end