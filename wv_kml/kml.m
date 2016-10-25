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
object_struct     = [];

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

%create path as required
if exist(download_path,'file')~=7;
    mkdir(download_path);
end
if local_dest_flag==1
    if exist(dest_root,'file')~=7;  mkdir(dest_root); end
    if exist([dest_root,overlays_path],'file')~=7;  mkdir([dest_root,overlays_path]); end
    if exist([dest_root,scan_obj_path],'file')~=7;  mkdir([dest_root,scan_obj_path]); end
    if exist([dest_root,track_obj_path],'file')~=7; mkdir([dest_root,track_obj_path]); end
    if exist([dest_root,cell_obj_path],'file')~=7;  mkdir([dest_root,cell_obj_path]); end
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
    
    %% download realtime data
    %empty download path
    delete([download_path,'*'])
    vol_updated   = 0;
    odim_jstruct  = '';
    download_list = {};
    %read staging index
    [download_ffn_list,download_fn_list] = staging_ddb_filter(staging_ddb_table,oldest_time,newest_time,radar_id_list,'storm');
    for j=1:length(download_fn_list)
        tmp_radar_id   = str2num(download_fn_list{j}(1:2));
        tmp_time_stamp = datenum(download_fn_list{j}(4:end-3),'yyyymmdd_HHMMSS'); 
        if any(tmp_time_stamp == complete_h5_dt & tmp_radar_id == complete_h5_rid)
            %skip file download, already processed
            continue
        else
            %add to index
            complete_h5_dt  = [complete_h5_dt;tmp_time_stamp];
            complete_h5_rid = [complete_h5_rid;tmp_radar_id];
            vol_updated     = vol_updated+1;
        end
        %download data file and untar into download_path
        display(['s3 cp of ',download_fn_list{j}])
        file_cp(download_ffn_list{j},download_path,0,1);
        download_list   = [download_list;download_fn_list{j}];
    end 
    %wait for aws processes to finish
    wait_aws_finish
    %untar files and create radar_id list
    radar_id_list = [];
    for i=1:length(download_list)
        radar_id_list = [radar_id_list;str2num(download_list{i}(1:2))];
        untar([download_path,download_list{i}],download_path)
    end
    
    %% process volumes to kml objects
    uniq_radar_id_list = unique(radar_id_list);
    for i=1:length(uniq_radar_id_list)
        radar_id      = uniq_radar_id_list(i);
        tmp_fn_list   = download_list(radar_id_list==radar_id);
        object_struct = storms_to_kml(object_struct,radar_id,oldest_time,newest_time,tmp_fn_list,dest_root,options);
    end
    %% clean object_struct
    
    %% generate kml nl layers
    
    %% query odimh5 and storm ddb for required storm ids
    odimh5_atts       = 'radar_id,start_timestamp,sig_refl_flag,img_latlonbox,tilt1,tilt2,vel_ni';
odimh5_atts_n     = 7; %change to suit odimh5_atts
storm_atts        = 'subset_id,start_timestamp,track_id,storm_dbz_centlat,storm_dbz_centlon,area,cell_vil,max_tops,max_mesh,orient,maj_axis,min_axis';
storm_atts_n      = 12; %change to suit odimh5_atts


    uniq_radar_id_list = unique(radar_id_list);
    odim_jstruct  = [];
    storm_jstruct = [];
    for i=1:length(uniq_radar_id_list)
        radar_id_str    = num2str(uniq_radar_id_list(i));
        %odimh5 ddb
        display(['query ',odimh5_ddb_table,' for ',radar_id_str])
        tmp_odim_jstruct = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
        if isempty(tmp_odim_jstruct)
            continue
        end
        if iscell(tmp_odim_jstruct)
            display('unprocessed objects removed from odim_jstruct')
            tmp_odim_jstruct = clean_jstruct(tmp_odim_jstruct,odimh5_atts_n);
        end
        %storm ddb
        sig_refl_flag = jstruct_to_mat([tmp_odim_jstruct.sig_refl_flag],'N');
        if any(sig_refl_flag)
            display(['query ',storm_ddb_table,' for ',radar_id_str])
            tmp_storm_jstruct = ddb_query('radar_id',radar_id_str,'subset_id',oldest_time_str,newest_time_str,storm_atts,storm_ddb_table);
            if isempty(tmp_odim_jstruct)
                continue
            end
            if iscell(tmp_storm_jstruct)
                display('unprocessed objects removed from storm_jstruct')
                tmp_storm_jstruct = clean_jstruct(tmp_storm_jstruct,odimh5_atts_n);
            end
        else
            tmp_storm_jstruct = [];
        end
        %append
        odim_jstruct  = [odim_jstruct,tmp_odim_jstruct];
        storm_jstruct = [storm_jstruct,tmp_storm_jstruct];
    end
        
    %todo:
    %pass jstructs to objects scripts. These files loop through listing and
    %create new kml objects
    %need a way of keeping kml object lists and cleaning them with time
    %cell array of time + list of file objects? pretty easy
    
    %generate ppi objects
    %kml_ppi_objects(download_path,odim_jstruct,dest_root,options);
    
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