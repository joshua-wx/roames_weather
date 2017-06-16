function impact_generate_mesh(vol_struct,storm_jstruct,tracking_id_list)

%WHAT: for tracks with a cell in the latest volume for a radar, generate a
%raster. Raster is the convex hull if a pair exists, or just a mask.


%load radar colormap and gobal config
load('global.config.mat')
load([site_info_fn,'.mat']);
load('vis.config.mat')

%generate uniqu list of radar ids and their index for remapping
[uniq_storm_rid_list,~,rid_idx]  = unique(utility_jstruct_to_mat([storm_jstruct.radar_id],'N'));

%for each radar id
for i = 1:length(uniq_storm_rid_list)
    %init blank grid
    
    %extract track list
    target_rid                        = uniq_storm_rid_list(i);
    rid_track_list                    = tracking_id_list(rid_idx==i);
    uniq_rid_track_list               = unique(rid_track_list);
    %extract newest for vol time for target_rid
    for j = 1:length(uniq_rid_track_list)
        target_track    = uniq_rid_track_list(j);
        track_idx       = find(tracking_id_list==target_track);
        %sort track by time
        track_time_list = 
        %check if last cell in track is the same as newest vol time
            %check if previous cell exists and at the correct step
            %apply hull and add to master grid
    end
end

%uniq_track_id_list   = unique(tracking_id_list);

%build impact map variables
if ismember(radar_id,impact_radar_id)
    impact_sd_flag = 1;
    tmp_path       = [impact_tmp_root,num2str(radar_id,'%02.0f')];
    if exist(tmp_path,'file') ~= 7
        mkdir(tmp_path);
    end
    sd_impact_ffn = [impact_tmp_root,num2str(radar_id,'%02.0f'),'/',data_tag,'.nc'];
else
    impact_sd_flag = 0;
    sd_impact_ffn  = '';
end