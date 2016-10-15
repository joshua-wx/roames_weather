function kml

%WHAT: This module pulls data from storm_archive and create kml objects for
%GE

%INPUT:
%see wv_kml.config

%OUTPUT: kml visualisation of selected mat file archive

%%Load VARS
% general vars
kml_config_fn     = 'kml.config';
global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';
download_path     = [tmp_config_path,'h5_download/'];


% Add folders to path and read config files
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/wv/lib/ge_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
addpath('/home/meso/Dropbox/dev/wv/etc')
addpath('/home/meso/Dropbox/dev/wv/wv_kml/etc')
addpath('/home/meso/Dropbox/dev/wv/wv_kml/tmp')

% load kml_config
read_config(kml_config_fn);
load([tmp_config_path,kml_config_fn,'.mat'])
date_list           = [];
complete_h5_dt      = [];
complete_h5_list    = {};
gfs_extract_list    = [];
hist_oldest_restart = [];

% Load global config files
read_config(global_config_fn);
load([tmp_config_path,global_config_fn,'.mat'])

%load colourmaps for png generation
colormap_interp('refl24bit.txt','vel24bit.txt');

% site_info.txt
read_site_info(site_info_fn); load([tmp_config_path,site_info_fn,'.mat']);
% check if all sites are needed
if strcmp(radar_id_list,'all')
    radar_id_list = site_id_list;
end

% Calculate time limits from time options
oldest_time = datenum(hist_oldest,ddb_tfmt);
newest_time = datenum(hist_newest,ddb_tfmt);

%build paths
if local_src_flag==1
    src_root = local_src_root;
else
    src_root = s3_src_root;
end
if local_dest_flag==1
    dest_root = local_dest_root;
else
    dest_root = s3_dest_root;
end

%% Primary code
tic
%cat daily databases for times between oldest and newest time,
%allows for mulitple days to be joined

for i=1:length(radar_id_list);
    %init query vars
    radar_id        = radar_id_list(i);
    radar_id_str    = num2str(radar_id,'%02.0f');
    oldest_time_str = datestr(oldest_time,ddb_tfmt);
    newest_time_str = datestr(newest_time,ddb_tfmt);
    odimh5_atts     = 'radar_id,start_timestamp,sig_refl_flag,img_latlonbox,tilt1,tilt2,vel_ni';
    odimh5_atts_n   = 7; %change to suit odimh5_atts
    storm_atts      = 'radar_id,start_timestamp,subset_id,track_id,storm_latlonbox,storm_dbz_centlat,storm_dbz_centlon,storm_edge_lat,storm_edge_lon,orient,maj_axis,min_axis,max_tops,max_mesh,cell_vil';
    storm_atts_n    = 15;
    %query databases
    odim_jstruct  = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
    storm_jstruct = ddb_query('radar_id',radar_id_str,'subset_id',oldest_time_str,newest_time_str,storm_atts,storm_ddb_table);
    
    %removed unprocessed odimh5 entries if returned as cell
    if iscell(odim_jstruct)
        display('odim_jstruct returned as cell')
        odim_jstruct = clean_jstruct(odim_jstruct,odimh5_atts_n);
    end
    if iscell(storm_jstruct)
        display('storm_jstruct returned as cell')
        storm_jstruct = clean_jstruct(storm_jstruct,storm_atts_n);
    end    
    %download data files
    start_timestamp_str = jstruct_to_mat([odim_jstruct.start_timestamp],'S');
    start_timestamp     = datenum(start_timestamp_str,ddb_tfmt);
    for j=1:length(start_timestamp)
        date_vec        = datevec(start_timestamp(j));
        data_fn         = [radar_id_str,'_',datestr(start_timestamp(j),r_tfmt),'.wv.tar'];
        storm_arch_path = [src_root,radar_id_str,'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/',data_fn];
        file_cp(storm_arch_path,download_path,0);
        untar([download_path,data_fn],download_path);
    end
end

%Rebuild kml hierarchy
build_kml_hierarchy_2(true,dest_root,radar_id_list);

%build kml from intp and their associated ident entires
cloud_objects3(download_path,odim_jstruct,storm_jstruct,dest_root,options);

%Build kml network links and generate tracked kml objects
update_kml_4(odim_jstruct,storm_jstruct,dest_root,options,oldest_time,newest_time);

%Update user
disp([10,'kml pass complete. ',num2str(length(odim_jstruct)),' volumes updated',10]);

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc),' @@@@@@@@@'])