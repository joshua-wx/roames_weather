function radar_merge

%% setup national latlon grid
%setup grid
min_lat    = -10;
min_lon    = 112;
dist_y_km  = 3900;
dist_x_km  = 4740;
alt_vec    = [[0.5:0.5:15.5],[16:1:20]];
dbz_thresh = 0;

[max_lat,~] = reckon(min_lat,min_lon,km2deg(dist_y_km),180);
[~,max_lon] = reckon(min_lat,min_lon,km2deg(dist_x_km),90);
lat_vec     = linspace(min_lat,max_lat,dist_y_km);
lon_vec     = linspace(min_lon,max_lon,dist_x_km);
empty_vec   = zeros(length(lat_vec)*length(lon_vec)*length(alt_vec),1,'uint16');
dbzh_vec    = empty_vec;
vradh_vec   = empty_vec;
weight_vec  = empty_vec;

%load data
%this is a big loop that keeps constantly loading and replacing data
h5_ffn                              = 'data/66_20161203_043000.h5';
[out66_dbzh,out66_vradh,out66_atts] = vol_regrid(h5_ffn,dbz_thresh);

h5_ffn                              = 'data/28_20161203_043200.h5';
[out28_dbzh,out28_vradh,out28_atts] = vol_regrid(h5_ffn,dbz_thresh);

%merge data

global_weights                        = weight_vec(out66_atts(:,1));
weight_mask                           = out66_atts(:,3) > global_weights;
dbzh_vec(out66_atts(weight_mask,1))   = out66_dbzh(weight_mask);
vradh_vec(out66_atts(weight_mask,1))  = out66_vradh(weight_mask);
weight_vec(out66_atts(weight_mask,1)) = out66_atts(weight_mask,3);

global_weights                        = weight_vec(out28_atts(:,1));
weight_mask                           = out28_atts(:,3) > global_weights;
dbzh_vec(out28_atts(weight_mask,1))   = out28_dbzh(weight_mask);
weight_vec(out28_atts(weight_mask,1)) = out28_atts(weight_mask,3);

%once merge is finished....
dbzh_vol         = reshape(dbzh_vec,length(lat_vec),length(lon_vec),length(alt_vec));
ewt_refl_image   = max(dbzh_vol./10,[],3); %allows the assumption only shrinking is needed.
ewt_refl_image   = medfilt2(ewt_refl_image, [9,9]);
addpath('../etc')
addpath('../lib/m_lib')
[ewtBasinExtend] = process_wdss_ewt(ewt_refl_image);
keyboard

%then ready to run through the usual identification and tracking, just a
%little slower than usual.
%problems: need to remove regions which have not been updated from the
%identification and tracking.
keyboard

%% merge
tic
merge_radars                 = [radar_66;radar_28];
[uniq_count,uniq_global_idx] = hist(merge_radars(:,1),unique(merge_radars(:,1)));
rep_idx                      = find(uniq_count>1);
toc
%loop and merge voxels
for i=1:length(rep_idx)
    target_global_idx = uniq_global_idx(rep_idx(i));
    merge_mask        = merge_radars(:,1)==target_global_idx;
    merge_weights     = merge_radars(merge_mask,6);
    [~,max_idx]       = max(merge_weights);
    merge_row         = merge_radars(merge_idx(max_idx),:);
    merge_radars(merge_idx,:) = repmat(merge_row,length(merge_idx),1);
end

%insert into global array


dbzh_vec(fill_data(:,1))  = fill_data(:,3);
vradh_vec(fill_data(:,1)) = fill_data(:,4);

keyboard
