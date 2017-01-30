function radar_step = calc_radar_step(vol_struct,radar_id)
%init
radar_id_list   = [vol_struct.radar_id];
radar_time_list = [vol_struct.start_timestamp];
%filter my radar id
filter_mask     = radar_id_list==radar_id;
radar_time_list = radar_time_list(filter_mask);
%sort time
radar_time_list = sort(radar_time_list);
%calc time step
if length(radar_time_list) > 1
    all_steps  = round((radar_time_list(2:end)-radar_time_list(1:end-1))*24*60);
    radar_step = mode(all_steps);
else
    radar_step = 10; %minutes
end
