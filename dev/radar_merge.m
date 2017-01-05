function radar_merge

addpath('bin')
addpath('../lib/m_lib')
addpath('../etc')

global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';


read_site_info(site_info_fn)
read_config(global_config_fn);


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