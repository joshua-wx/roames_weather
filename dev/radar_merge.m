function radar_merge



%load data
%this is a big loop that keeps constantly loading and replacing data
h5_ffn                              = 'data/66_20161203_043000.h5';
tic
grid_obj66 = process_vol_regrid(h5_ffn);
toc
keyboard


h5_ffn                              = 'data/28_20161203_043200.h5';
tic
grid_obj28 = process_vol_regrid(h5_ffn);
toc
keyboard