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
complete_h5_dt    = [];
complete_h5_rid   = [];
download_path     = [tempdir,'h5_download/'];
if exist(download_path,'file')~=7
    mkdir(download_path)
end

% Add folders to path and read config files
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/wv/lib/ge_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
addpath('/home/meso/Dropbox/dev/wv/wv_process/bin/json_read')
addpath('/home/meso/Dropbox/dev/wv/etc')
addpath('/home/meso/Dropbox/dev/wv/wv_kml/etc')
addpath('/home/meso/Dropbox/dev/wv/wv_kml/tmp')

% load kml_config
read_config(kml_config_fn);
load([tmp_config_path,kml_config_fn,'.mat'])

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

%build root kml
build_kml_root(dest_root,radar_id_list)

%% Primary code
tic
%cat daily databases for times between oldest and newest time,
%allows for mulitple days to be joined

while true
    
    % Calculate time limits from time options
    if realtime_kml == 0
        oldest_time = datenum(hist_oldest,ddb_tfmt);
        newest_time = datenum(hist_newest,ddb_tfmt);
    else
        oldest_time = addtodate(utc_time,realtime_length,'hour');
        newest_time = utc_time;
    end
    oldest_time_str = datestr(oldest_time,ddb_tfmt);
    newest_time_str = datestr(newest_time,ddb_tfmt);
    
    %empty download path
    delete([download_path,'*'])
    vol_updated   = 0;
    odim_jstruct  = '';
    download_list = {};
    %check index for new files and download
    for i=1:length(radar_id_list);
        
        %init query vars
        radar_id        = radar_id_list(i);
        radar_id_str    = num2str(radar_id,'%02.0f');
        oldest_time_str = datestr(oldest_time,ddb_tfmt);
        newest_time_str = datestr(newest_time,ddb_tfmt);
        odimh5_atts     = 'radar_id,start_timestamp,sig_refl_flag,img_latlonbox,tilt1,tilt2,vel_ni';
        odimh5_atts_n   = 7; %change to suit odimh5_atts
        %query databases
        display(['ddb query for radar ',radar_id_str])
        tic
        tmp_odim_jstruct  = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
        toc
        %continue to next radar_id if empty
        if isempty(tmp_odim_jstruct)
            continue
        end
        %removed unprocessed odimh5 entries if returned as cell
        if iscell(tmp_odim_jstruct)
            display('unprocessed objects removed from odim_jstruct')
            tmp_odim_jstruct = clean_jstruct(tmp_odim_jstruct,odimh5_atts_n);
        end
        
        %download storm data files for each timestamp
        start_timestamp_str = jstruct_to_mat([tmp_odim_jstruct.start_timestamp],'S');
        start_timestamp     = datenum(start_timestamp_str,ddb_tfmt);
        for j=1:length(start_timestamp)
            if any(start_timestamp(j) == complete_h5_dt & radar_id == complete_h5_rid)
                %skip file download, already processed
                continue
            else
                %add to index
                complete_h5_dt  = [complete_h5_dt;start_timestamp(j)];
                complete_h5_rid = [complete_h5_rid;radar_id];
                vol_updated     = vol_updated+1;
            end
            %download data file and untar into download_path
            date_vec        = datevec(start_timestamp(j));
            data_fn         = [radar_id_str,'_',datestr(start_timestamp(j),r_tfmt),'.wv.tar'];
            storm_arch_path = [src_root,radar_id_str,'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/',data_fn];
            display(['s3 cp of ',data_fn])
            file_cp(storm_arch_path,download_path,0,1);
            download_list   = [download_list;data_fn];
        end
        
        %append odim_jstruct
        if isempty(odim_jstruct)
            odim_jstruct  = tmp_odim_jstruct;
        else
            odim_jstruct  = [odim_jstruct,tmp_odim_jstruct];
        end
    end
    %wait for aws processes to finish
    wait_aws_finish
    
    %untar files
    for i=1:length(download_list)
        untar([download_path,download_list{i}])
    end

    %generate scan objects
    %kml_scan_objects(download_path,odim_jstruct,dest_root,options);
    
    %generate track objects
    %kml_track_objects(download_path,odim_jstruct,storm_jstruct,dest_root,options);

    %generate cell objects
    %kml_cell_objects(download_path,odim_jstruct,storm_jstruct,dest_root,options);
    
    %clean out complete_h5_dt and complete_h5_rid
    keep_mask       = complete_h5_dt>=oldest_time;
    delete_h5_dt    = complete_h5_dt(~keep_mask);
    complete_h5_dt  = complete_h5_dt(keep_mask);
    complete_h5_rid = complete_h5_rid(keep_mask);

    %clean out kml objects
    scan_path  = [dest_root,'scan_objects/'];
    track_path = [dest_root,'track_objects/'];
    cell_path  = [dest_root,'cell_objects/'];
    for j = 1:length(delete_h5_dt)
        rm_folder = [radar_id_str,'_',datestr(delete_h5_dt(j),r_tfmt)];
        file_rm([scan_path,rm_folder],1)
        file_rm([track_path,rm_folder],1)
        file_rm([cell_path,rm_folder],1)
    end
    
    %Update user
    disp([10,'kml pass complete. ',num2str(length(odim_jstruct)),' volumes updated',10]);
    
    %break loop for not realtime
    if realtime_kml == 0
        break
    end
    
end
%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc),' @@@@@@@@@'])

%         storm_atts      = 'radar_id,start_timestamp,subset_id,track_id,storm_latlonbox,storm_dbz_centlat,storm_dbz_centlon,storm_edge_lat,storm_edge_lon,orient,maj_axis,min_axis,max_tops,max_mesh,cell_vil';
%         storm_atts_n    = 15;