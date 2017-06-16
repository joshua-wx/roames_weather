function radar_step = utility_radar_step(vol_struct,radar_id)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: using vol_struct, previous radar start_timestamps for radar_id are
% extracted and used to calculate the interval. A default interval is used
% of 10 min
% INPUTS
% vol_struct: contains struct of volumes information (see variable docs)
% radar_id: radar id to filter vol_struct (int)
% RETURNS
% radar_step: radar interval in minutes (int)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%init output struct
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
	if radar_step > 10
		radar_step = 10;
	end
else
    radar_step = 10; %minutes
end
