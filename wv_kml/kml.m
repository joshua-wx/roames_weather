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
site_info_hide_fn = 'site_info_hide.txt';
restart_vars_fn   = 'tmp/kml_restart_vars.mat';
tmp_config_path   = 'tmp/';
%init tmp path
if exist(tmp_config_path,'file') ~= 7
    mkdir(tmp_config_path)
end
    
% setup kill time (restart program to prevent memory fragmentation)
kill_wait  = 60*60*2; %kill time in seconds
kill_timer = tic; %create timer object
unix('touch tmp/kill_kml');

% Add folders to path and read config files
if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
    addpath('/home/meso/Dropbox/dev/wv/lib/ge_lib');
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
    addpath('/home/meso/Dropbox/dev/wv/wv_process/bin/json_read')
    addpath('/home/meso/Dropbox/dev/wv/etc')
    addpath('/home/meso/Dropbox/dev/wv/wv_kml/etc')
    addpath('/home/meso/Dropbox/dev/wv/wv_kml/tmp')
else
    addpath('etc')
    addpath('tmp')
end

% load kml_config
read_config(kml_config_fn);
load([tmp_config_path,kml_config_fn,'.mat'])

%init download path
if exist(download_path,'file')~=7;
    mkdir(download_path);
end

%build paths strings
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

%load colourmaps for png generation
colormap_interp('refl24bit.txt','vel24bit.txt');

% Load global config files
read_config(global_config_fn);
load([tmp_config_path,global_config_fn,'.mat'])

% site_info.txt
read_site_info(site_info_fn); load([tmp_config_path,site_info_fn,'.mat']);
% check if all sites are needed
if strcmp(radar_id_list,'all')
    radar_id_list = site_id_list;
end

% site_info_mask.txt
radar_id_hide = dlmread(site_info_hide_fn); save([tmp_config_path,site_info_hide_fn,'.mat']);

%init vars
% check for restart or first start
if exist(restart_vars_fn,'file')==2
    %silent restart detected, load vars from reset and remove file
    load(restart_vars_fn);
else
    %build root kml
    build_kml_root(dest_root,radar_id_list,local_dest_flag)
    %new start
    object_struct = [];
end


%% Primary code
%cat daily databases for times between oldest and newest time,
%allows for mulitple days to be joined
try
while exist('tmp/kill_kml','file')==2
    
    % Calculate time limits from time options
    if realtime_kml == 1
        oldest_time = addtodate(utc_time,realtime_length,'hour');
        newest_time = utc_time;
    else
        oldest_time = datenum(hist_oldest,ddb_tfmt);
        newest_time = datenum(hist_newest,ddb_tfmt);
    end
    oldest_time_str = datestr(oldest_time,ddb_tfmt);
    newest_time_str = datestr(newest_time,ddb_tfmt);
    
    %% download realtime data
    %empty download path
    delete([download_path,'*'])
    download_list = {};
    %read staging index
    if realtime_kml == 1
        [download_ffn_list,download_fn_list] = ddb_filter_staging(staging_ddb_table,oldest_time,newest_time,radar_id_list,'storm');
    else
        [download_ffn_list,download_fn_list] = ddb_filter_odimh5(odimh5_ddb_table,src_root,oldest_time_str,newest_time_str,radar_id_list);
    end
    for i=1:length(download_fn_list)
        %download data file and untar into download_path
        display(['s3 cp of ',download_fn_list{i}])
        file_cp(download_ffn_list{i},download_path,0,1);
    end 
    %wait for aws processes to finish
    wait_aws_finish
    %untar files and create radar_id list
    download_r_id_list = [];
    for i=1:length(download_fn_list)
        download_ffn = [download_path,download_fn_list{i}];
        if exist(download_ffn,'file') == 2
            download_r_id_list = [download_r_id_list;str2num(download_fn_list{i}(1:2))];
            download_list      = [download_list;download_fn_list{i}];
            untar(download_ffn,download_path);
        end
    end
    
    %% clean object_struct and remove old files
    remove_radar_id = [];
    if ~isempty(object_struct)
        %find old files
        remove_idx      = find([object_struct.start_timestamp]<oldest_time);
        if ~isempty(remove_idx)
            remove_ffn_list = {object_struct(remove_idx).ffn};
            %clean out files
            for i=1:length(remove_ffn_list)
                 file_rm(remove_ffn_list{i},0,1);
            end
            %preserve removed radar_ids
            remove_radar_id           = [object_struct(remove_idx).radar_id]';
            %remove entries
            object_struct(remove_idx) = [];
        end
    end
    
    %% process volumes to kml objects
    %merge removed radar_id list and download list for updating in
    %storm_to_kml
    kml_radar_list = unique([download_r_id_list;remove_radar_id]);
    %loop through radar id list
    for i=1:length(kml_radar_list)
        radar_id      = kml_radar_list(i);
        tmp_fn_list   = download_list(download_r_id_list==radar_id);
        object_struct = storm_to_kml(object_struct,radar_id,oldest_time,newest_time,tmp_fn_list,dest_root,options);
    end
    
    %% generate kml nl layer
    
    %Update user
    disp([10,'kml pass complete. ',num2str(length(kml_radar_list)),' radars updated at ',datestr(now),10]);
    
    %break loop for not realtime
    if realtime_kml == 0
        delete('tmp/kill_kml')
        break
    elseif ~isempty(kml_radar_list) && save_object_struct == 1
        %update restart_vars_fn on kml update for realtime processing
        try
            save(restart_vars_fn,'object_struct')
        catch err
            display(err)
        end
    end
    
    %rotate ddb, cp_file, and qa logs to 200kB
    unix(['tail -c 200kB  etc/log.qa > etc/log.qa']);
    unix(['tail -c 200kB  etc/log.ddb > etc/log.ddb']);
    unix(['tail -c 200kB  etc/log.cp > etc/log.cp']);
    unix(['tail -c 200kB  etc/log.rm > etc/log.rm']);
    %Kill function
    if toc(kill_timer)>kill_wait
        %update user
        disp(['@@@@@@@@@ wv_kml restarted at ',datestr(now)])
        %restart
        if ~isdeployed
            %not deployed method: trigger background restart command before
            %kill
            [~,~] = system(['matlab -desktop -r "run ',pwd,'/kml.m" &'])
        else
            %deployed method: restart controlled by run_wv_process sh
            %script
            disp('is deployed - passing restart to run script via temp_kml_vars.mat existance')
        end
        quit force
    end

    %pause
    disp('pausing for 5s')
    pause(5)
    
end
catch err
    %display and log error
    display(err)
    log_cmd_write('tmp/log.crash','',['crash error at ',datestr(now)],[err.identifier,' ',err.message]);
    rethrow(err)
end

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(kill_timer),' @@@@@@@@@'])