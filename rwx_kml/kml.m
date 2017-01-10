function kml
try
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
restart_vars_fn   = 'tmp/kml_restart_vars.mat';
tmp_config_path   = 'tmp/';
pushover_flag     = 1;

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
    addpath('/home/meso/dev/roames_weather/lib/m_lib');
    addpath('/home/meso/dev/roames_weather/lib/ge_lib');
    addpath('/home/meso/dev/shared_lib/jsonlab');
    addpath('/home/meso/dev/roames_weather/etc')
    addpath('/home/meso/dev/roames_weather/bin/json_read');
    addpath('/home/meso/dev/roames_weather/rwx_kml/etc')
    addpath('/home/meso/dev/roames_weather/rwx_kml/tmp')
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
    src_odimh5_root  = local_odimh5_src_root;
    src_stormh5_root = local_stormh5_src_root;
else
    src_odimh5_root  = s3_odimh5_src_root;
    src_stormh5_root = s3_stormh5_src_root;
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

%init vars
% check for restart or first start
if exist(restart_vars_fn,'file')==2
    %silent restart detected, load vars from reset and remove file
    try
        %attempt to load restart vars
        load(restart_vars_fn);
        delete(restart_vars_fn);
    catch
        %corrupt file
        delete(restart_vars_fn);
        kml_build_root(dest_root,radar_id_list,local_dest_flag);
        object_struct = [];
    end
else
    %build root kml
    kml_build_root(dest_root,radar_id_list,local_dest_flag);
    %new start
    object_struct = [];
end


%% Primary code
%cat daily databases for times between oldest and newest time,
%allows for mulitple days to be joined
while exist('tmp/kill_kml','file')==2
    
    % Calculate time limits from time options
    if realtime_kml == 1
        oldest_time = addtodate(utc_time,realtime_length,'hour');
        newest_time = utc_time;
    else
        oldest_time = datenum(hist_oldest,ddb_tfmt);
        newest_time = datenum(hist_newest,ddb_tfmt);
    end
    
    %% download realtime data
    %empty download path
    delete([download_path,'*'])
    %read staging index
    if realtime_kml == 1
        download_odimh5_ffn_list   = ddb_filter_staging(staging_ddb_table,oldest_time,newest_time,radar_id_list,'process_odimh5');
        download_stormh5_ffn_list  = ddb_filter_staging(staging_ddb_table,oldest_time,newest_time,radar_id_list,'stormh5');
    else
        date_id_list               = round(oldest_time):1:round(newest_time);
        download_odimh5_ffn_list   = ddb_filter_index(odimh5_ddb_table,'radar_id',radar_id_list,'start_timestamp',oldest_time,newest_time);
        download_stormh5_ffn_list  = ddb_filter_index(storm_ddb_table,'date_id',date_id_list,'sort_id',oldest_time,newest_time);
    end
    download_ffn_list = [download_odimh5_ffn_list;download_stormh5_ffn_list];
    for i=1:length(download_ffn_list)
        %download data file and untar into download_path
        display(['s3 cp of ',download_ffn_list{i}])
        file_cp(download_ffn_list{i},download_path,0,1);
    end 
    %wait for aws processes to finish
    wait_aws_finish
    %untar stormh5 files and create list
    download_r_id_list = [];
    for i=1:length(download_stormh5_ffn_list)
        [~,storm_name,ext] = fileparts(download_stormh5_ffn_list{i});
        download_ffn       = [download_path,storm_name,ext];
        if exist(download_ffn,'file') == 2
            download_r_id_list = [download_r_id_list;str2num(storm_name(1:2))];
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
    
    %% run tracking
    %perhaps run it within the kml_storm_obj script
    
    
    %% process volumes to kml objects
    %merge removed radar_id list and download list for updating in
    %storm_to_kml (ie removing old data from the kml)
    kml_radar_list = unique([download_r_id_list;remove_radar_id]);
    %loop through radar id list
    for i=1:length(kml_radar_list)
        radar_id      = kml_radar_list(i);
        object_struct = kml_storm_obj(object_struct,radar_id,oldest_time,newest_time,download_path,dest_root,options);
        object_struct = kml_odimh5_obj(object_struct,radar_id,download_path,dest_root,options);
    end
    
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
    unix(['tail -c 200kB  tmp/log.qa > tmp/log.qa']);
    unix(['tail -c 200kB  tmp/log.ddb > tmp/log.ddb']);
    unix(['tail -c 200kB  tmp/log.cp > tmp/log.cp']);
    unix(['tail -c 200kB  tmp/log.rm > tmp/log.rm']);
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
    message = [err.identifier,10,10,getReport(err,'extended','hyperlinks','off')];
    log_cmd_write('tmp/log.crash','',['crash error at ',datestr(now)],[err.identifier,' ',err.message]);
    save(['tmp/crash_',datestr(now,'yyyymmdd_HHMMSS'),'.mat'],'err')
    %push notification
    if pushover_flag == 1
        pushover('kml',message)
    end
    rethrow(err)
end

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(kill_timer),' @@@@@@@@@'])