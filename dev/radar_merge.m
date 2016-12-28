function radar_merge

radar_66 = [];
radar_28 = [];

%load data
h5_ffn    = 'data/66_20161203_043000.h5';
radar_66 = vol_regrid(h5_ffn);
h5_ffn    = 'data/28_20161203_043200.h5';
radar_28 = vol_regrid(h5_ffn);


%merge
merge_radars                 = [radar_66;radar_28];
[uniq_count,uniq_global_idx] = hist(merge_radars(:,1),unique(merge_radars(:,1)));
rep_idx                      = find(uniq_count>1);
for i=1:length(rep_idx)
    target_global_idx = uniq_global_idx(rep_idx(i));
    merge_idx         = find(merge_radars(:,1)==target_global_idx);
    merge_weights     = merge_radars(merge_idx,6);
    %use highest merge weight to merge radars (but this may create some
    %artifacts?)
    %advection needs to be done first within each radar domain to readjust
    %global index before merge. Perhaps use simple cross corr method?
    %perhaps test first without advection? -> next step is to 
end

keyboard
