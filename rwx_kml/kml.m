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
transform_path    = [tmp_config_path,'transforms/'];

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
if exist(download_path,'file')~=7
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
        kmlobj_struct = [];
        vol_struct    = [];
    end
else
    %build root kml
    kml_build_root(dest_root,radar_id_list,local_dest_flag);
    %new start
    kmlobj_struct = [];
    vol_struct    = [];
end

% Preallocate regridding coordinates
if radar_id_list==99
    preallocate_mobile_grid(transform_path,force_transform_update)
else
    preallocate_radar_grid(radar_id_list,transform_path,force_transform_update)
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
    
    %% download odimh5/storm data
    %empty download path
    delete([download_path,'*'])
    %read staging index
    if realtime_kml == 1
        download_odimh5_list   = ddb_filter_staging(staging_ddb_table,oldest_time,newest_time,radar_id_list,'process_odimh5');
        download_stormh5_list  = ddb_filter_staging(staging_ddb_table,oldest_time,newest_time,radar_id_list,'stormh5');
    else
        date_id_list           = round(oldest_time):1:round(newest_time);
        download_odimh5_list   = ddb_filter_index(odimh5_ddb_table,'radar_id',radar_id_list,'start_timestamp',oldest_time,newest_time,[]);
        download_stormh5_list  = ddb_filter_index(storm_ddb_table,'date_id',date_id_list,'sort_id',oldest_time,newest_time,radar_id_list);
    end
    download_list = [download_odimh5_list;download_stormh5_list];
    for i=1:length(download_list)
        %download data file and untar into download_path
        display(['s3 cp of ',download_list{i}])
        file_cp(download_list{i},download_path,0,1);
    end 
    %wait for aws processes to finish
    wait_aws_finish
    
    %% extract storm data
    %untar stormh5 files and create list
    for i=1:length(download_stormh5_list)
        if exist(download_stormh5_list{i},'file') == 2
            untar(download_ffn,download_path);
        end
    end
    
    %% update vol object
    %add new volumes to vol_struct
    for i=1:length(download_list)
        [~,storm_name,ext] = fileparts(download_list{i});
        download_ffn       = [download_path,storm_name,ext];
        download_rid       = str2num(storm_name(1:2));
        download_start_td  = datenum(storm_name(4:18),r_tfmt);
        %add to vol_struct (VOL_STRUCT IS UPDATED FROM THE CURRENT DATA
        %BEFORE KMLOBJ_STRUCT
        tmp_struct        = struct('radar_id',download_rid,'start_timestamp',download_start_td);
        vol_struct        = [vol_struct,tmp_struct];
    end
 
    %% clean kmlobj_struct and remove kml old files
    remove_radar_id = [];
    remove_idx      = [];
    if ~isempty(kmlobj_struct)
        %find old files
        remove_idx      = find([kmlobj_struct.start_timestamp]<oldest_time);
        if ~isempty(remove_idx)
            remove_ffn_list = {kmlobj_struct(remove_idx).ffn};
            %clean out files
            for i=1:length(remove_ffn_list)
                 file_rm(remove_ffn_list{i},0,1);
            end
            %preserve removed radar_ids
            remove_radar_id           = [kmlobj_struct(remove_idx).radar_id]';
            %remove entries
            kmlobj_struct(remove_idx) = [];
        end
    end
    
    %% clean vol_struct
    if ~isempty(vol_struct) && ~isempty(remove_idx)
        %find old entries
        remove_idx      = find([vol_struct.start_timestamp]<oldest_time);
        if ~isempty(remove_idx)
            vol_struct(remove_idx) = [];
        end
    end
    
    %% query storm ddb
    %query storm ddb
    date_list         = floor(oldest_time):floor(newest_time);
    storm_atts        = 'radar_id,start_timestamp,subset_id,storm_latlonbox,storm_dbz_centlat,storm_dbz_centlon,storm_edge_lat,storm_edge_lon,area,cell_vil,max_tops,max_mesh,orient,maj_axis,min_axis';
    storm_jstruct     = [];
    %collate multiple date_id's (these must be unique in query request)
    for i=1:length(date_list)
        date_id       = datestr(date_list(i),ddb_dateid_tfmt);
        temp_jstruct  = ddb_query('date_id',date_id,'sort_id',datestr(oldest_time,ddb_tfmt),datestr(newest_time,ddb_tfmt),storm_atts,storm_ddb_table);
        storm_jstruct = [storm_jstruct,temp_jstruct];
    end
    
    %% process volumes to kml objects
    %merge removed radar_id list and download list for updating in
    %storm_to_kml (ie removing old data from the kml)
    kml_radar_list    = unique([[vol_struct.radar_id],remove_radar_id]);
    %loop through radar id list
    for i=1:length(kml_radar_list)
        radar_id       = kml_radar_list(i);
        [~,radar_step] = ddb_filter_odimh5_kml(odimh5_ddb_table,radar_id,oldest_time,newest_time);
        kmlobj_struct  = kml_odimh5(kmlobj_struct,vol_struct,radar_id,radar_step,download_odimh5_list,dest_root,transform_path,options);
        %kmlobj_struct = kml_stormh5(kmlobj_struct,vol_struct,storm_jstruct,radar_id,radar_step,download_stormh5_list,dest_root,options);
    end
    %kmlobj_struct     = kml_stormddb(kmlobj_struct,storm_jstruct,vol_struct,kml_radar_list,oldest_time,newest_time,dest_root,options);
    
    keyboard
    %% ending loop
    %Update user
    disp([10,'kml pass complete. ',num2str(length(kml_radar_list)),' radars updated at ',datestr(now),10]);
    
    %break loop for not realtime
    if realtime_kml == 0
        delete('tmp/kill_kml')
        break
    elseif ~isempty(kml_radar_list) && save_object_struct == 1
        %update restart_vars_fn on kml update for realtime processing
        try
            save(restart_vars_fn,'kmlobj_struct')
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