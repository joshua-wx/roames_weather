function prep
% prep data class
%
% BoM volumetric lftp download manager. Downloads complete volumes (all files
% which make up one volume scan), rather than just new files, elimating the
% problem with delayed uploads to the ftp server. FTP server is first synced
% to a folder in tmp before applying time/site filters as required. Complete
% volumes which pass are cat'ed,converted to odim_h5 and moved to the
% correct s3 or local directory. directory ls provides indexing (perhaps
% move to dynamodb for remote?)

try

%add paths if not deployed
if ~isdeployed
    addpath('/home/meso/dev/roames_weather/etc');
    addpath('/home/meso/dev/roames_weather/bin/json_read');
    addpath('/home/meso/dev/roames_weather/lib/m_lib');
    addpath('/home/meso/dev/shared_lib/jsonlab');
    unix('touch tmp/kill_prep');
end

%create temp dir
if exist('tmp/','file')~=7
    mkdir('tmp');
end

%add local paths
addpath('etc/');
addpath('tmp/');

%clear tmp
delete('/tmp/*rapic')

%load ftp config file
config_input_path = 'prep.config';
read_config(config_input_path);
load(['tmp/',config_input_path,'.mat'])

% Load global config files
global_config_fn = 'global.config';
read_config(global_config_fn);
load(['tmp/',global_config_fn,'.mat']);

% site_info.txt
site_info_fn = 'site_info.txt';
read_site_info(site_info_fn);
load(['tmp/',site_info_fn,'.mat']);

%init local mirror folder
local_mirror_path = [tempdir,'rapic_mirror'];
if exist(local_mirror_path,'file')~=7
    %create as needed
    mkdir(local_mirror_path);
end

%local and remote switch
if local_flag == 1
    dest_path = local_path;
else
    dest_path = s3_path;
end

%setup kill timer
kill_timer         = tic;
kill_wait          = 60*60*2; %kill time in seconds
fetch_h5_fn        = {};

while exist('tmp/kill_prep','file')==2 %run loop while script termination control still exists
    %be nice to server
    disp('pausing for 5s')
    pause(5)
    
    %Kill function
    if toc(kill_timer)>kill_wait
        %update user
        disp(['@@@@@@@@@ wv_prep restarted at ',datestr(now)])
        %restart
        if ~isdeployed
            %not deployed method: trigger background restart command before
            %kill
            [~,~] = unix(['matlab -desktop -r "run ',pwd,'/prep.m" &'])
        else
            %deployed method: restart controlled by run_wv_process sh
            %script
            disp('is deployed - passing restart to run script kill existance')
        end
        quit force
    end
    
    %create lftp script to mirror remote server
    disp('starting lftp sync')
    lftp_mirror_coder(ftp_address,ftp_un,ftp_pass,ftp_path,local_mirror_path);
    
    %run ftp script, usually brings in 27k files
    ftp_timer   = tic;
    cmd         = 'export LD_LIBRARY_PATH=/usr/lib; ./tmp/lftp_mirror_scipt';
    [sout,eout] = unix(cmd);
    if sout ~= 0
        log_cmd_write('tmp/log.lftp',' ',cmd,eout)
    end
    %reate dir listing
    local_mirror_dir = dir(local_mirror_path); local_mirror_list = {local_mirror_dir.name}; local_mirror_list(1:2)=[];
    
    %check files exist in tempdir mirror
    if isempty(local_mirror_list)
        display('local mirror is empty')
        continue
    end
    
    %update on lftp time
    disp(['ftp mirror download took  ',num2str(toc(ftp_timer)),' seconds',10])
    
    %only process files of the correction fn length (remove others fns)
    clean_rapic_list = {};
    for i = 1:length(local_mirror_list)
        if length(local_mirror_list{i})<3
            continue
        end
        if strcmp(local_mirror_list{i}(end-2:end),'txt')
            clean_rapic_list = [clean_rapic_list;local_mirror_list{i}];
        end
    end
    
    %check files exist in tempdir mirror
    if isempty(clean_rapic_list)
        display('clean_rapic_list is empty')
        continue
    end   
    
    %Run volume sorter while preserving previous output (as these have all
    %been processed)
    vol_timer = tic;
    prev_fetch_h5_fn = fetch_h5_fn;
    [fetch_volumes,fetch_datetime,fetch_r_id,fetch_h5_fn] = lftp_to_volumes(clean_rapic_list,ftp_oldest);
    disp(['lftp to vol filter took ',num2str(toc(vol_timer)),' seconds for ',num2str(length(clean_rapic_list)),' files'])
    
    %check files exist in tempdir mirror
    if isempty(fetch_h5_fn)
        display('fetch_h5_fn is empty')
        continue
    end   

    %remove volumes processed in last run
    [~,rm_idx]   = ismember(fetch_h5_fn,prev_fetch_h5_fn);
    new_h5_fn    = fetch_h5_fn(~rm_idx);
    new_volumes  = fetch_volumes(~rm_idx);
    new_datetime = fetch_datetime(~rm_idx);
    new_r_id     = fetch_r_id(~rm_idx);
    
    %check files exist in tempdir mirror
    if isempty(new_h5_fn)
        display('new_h5_fn is empty')
        continue
    end   
    
    %filter using h5 archive , only for init loop run (otherwise
    %prev_fetch_hf_fn is sufficent)
    if isempty(prev_fetch_h5_fn)
        index_timer  = tic;
        filt_volumes = {};
        filt_h5_fn   = {};
        filt_r_id    = [];
        for i = 1:size(new_h5_fn,1)
            test_h5_fn      = new_h5_fn{i};
            test_volumes    = new_volumes(i);
            test_r_id       = new_r_id(i);
            test_datetime   = new_datetime(i);
            %pull index from dynamodb
            jstruct_out = ddb_get_item(odimh5_ddb_table,...
                'radar_id','N',num2str(test_r_id,'%02.0f'),...
                'start_timestamp','S',[datestr(test_datetime,'yyyy-mm-ddTHH:MM'),':00'],''); %remove seconds because rapic filename may not match h5 time
            if isempty(jstruct_out)
                filt_h5_fn   = [filt_h5_fn;test_h5_fn];
                filt_volumes = [filt_volumes;test_volumes];
                filt_r_id    = [filt_r_id;test_r_id];
            else
                continue
            end
        end
        disp(['index filter took  ',num2str(toc(index_timer)),' seconds for ',num2str(length(new_datetime)),' volumes'])
    else
        filt_r_id    = new_r_id;
        filt_h5_fn   = new_h5_fn;
        filt_volumes = new_volumes;
    end
    
    %check files exist in tempdir mirror
    if isempty(filt_h5_fn)
        display('filt_h5_fn is empty')
        continue
    end  
    
    %Loop through sorted_volumes
    no_vols = length(filt_volumes);
    disp(['########Passing ',num2str(no_vols),' volumes to rapic_convert'])
    
    for i=1:no_vols
        %cat rapic scans into volumes and convert to hdf5
        rapic_convert(filt_volumes{i},filt_r_id(i),local_mirror_path,dest_path,staging_ddb_table,odimh5_ddb_table);
        disp(['Volume ',num2str(i),' processed of ',num2str(no_vols),' ',filt_volumes{i}{1}])
    end
    %output ftp open time and number of files downloaded
    disp(['###### ',num2str(no_vols),' volumes preprocessed',10]);
    
    %rotate ddb, cp_file, and qa logs to 200kB
    unix(['tail -c 200kB  tmp/log.lftp > tmp/log.lftp']);
    unix(['tail -c 200kB  tmp/log.ddb > tmp/log.ddb']);
    unix(['tail -c 200kB  tmp/log.convert > tmp/log.convert']);
    unix(['tail -c 200kB  tmp/log.mv > tmp/log.mv']);
end

disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(kill_timer),' @@@@@@@@@'])

catch err
    display(err)
    %save error to file and log
    message = [err.identifier,10,10,getReport(err,'extended','hyperlinks','off')];
    log_cmd_write('tmp/log.crash','',['crash error at ',datestr(now)],[err.identifier,' ',err.message]);
    save(['tmp/crash_',datestr(now,'yyyymmdd_HHMMSS'),'.mat'],'err')
    %send push notification
    if pushover_flag == 1
        pushover('prep',message)
    end
    rethrow(err)
end

function [fetch_volumes,fetch_h5_datetime,fetch_h5_r_id,fetch_h5_fn] = lftp_to_volumes(scan_filenames,min_offset)
%WHAT
%Takes the dir listing from the ftp server and returns complete volumes
%which as less than min_offset old and in cell arrays of complete volumes

%INPUT
%scan_filenames: ftp scan filenames
%min_offset: now-min_offset gives the oldest gave of data to pass (minutes)

%OUTPUT
%fetch_volumes: a cell array where each element contains a list of
%filenames from a complete volume
%fetch_h5_fn:   h5 filenames of each volume (not implemented)

fetch_volumes     = {};
fetch_h5_datetime = [];
fetch_h5_r_id     = [];
fetch_h5_fn       = {};
oldest_date_num   = addtodate(utc_time,min_offset,'minute');

%extract parameters from scan_filenames
if ~isempty(scan_filenames)
    %write filename strings to datestrings, convert to datenums and sort
    %'IDR' r_id 'VOL.' yyyymmddHHMM '.' scan_no '_' total_num_scans '.txt'
    cell_out = textscan([scan_filenames{:}],'%*3s %2f %*4s %12s %*1s %2f %*1s %2f %*4s');

    %sort and extract parts
    [date_num,IX]  = sort(datenum(cell_out{2},'yyyymmddHHMM')); %remove seconds because rapic filename may not match h5 time
    r_id           = cell_out{1}(IX);
    scan_no        = cell_out{3}(IX);
    total_scans    = cell_out{4}(IX);
    scan_filenames = scan_filenames(IX);
    
    %generate the oldest date num and create filter for this cutoff
    flt=find(date_num>=oldest_date_num);
    if isempty(flt)
        return
    end
    %apply filter to datasets    
    date_num=date_num(flt); r_id=r_id(flt); scan_no=scan_no(flt); total_scans=total_scans(flt); scan_filenames=scan_filenames(flt);
    
    %Loop by unique radar ID
    uniq_r_id_list = unique(r_id);
     for i=1:length(uniq_r_id_list)
         
        %Find indicies of filenames of uniq_r_id
        uniq_r_id = uniq_r_id_list(i);
        r_idx     = find(r_id==uniq_r_id);
        %Collate filenames from the same volume into one cell
        temp_vol      = {};
        temp_dt       = [];
        r_total_scans = total_scans(r_idx(1));
        
        for j=1:length(r_idx)
            %start building volume
            temp_vol = [temp_vol;scan_filenames{r_idx(j)}];
            temp_dt  = [temp_dt;date_num(r_idx(j))];
            %extract next scan number
            if j < length(r_idx)
                next_scan_no = scan_no(r_idx(j+1));
            else
                next_scan_no = 2; %at the end, set to two to skip and update next ftp fetch
            end
            %append if next scan is a new volume
            if next_scan_no==1
                if length(temp_vol)==r_total_scans
                    %length and end of scan number correct, volume complete
                    fetch_volumes     = [fetch_volumes;{temp_vol}];
                    fetch_h5_datetime = [fetch_h5_datetime;temp_dt(1)];
                    fetch_h5_r_id     = [fetch_h5_r_id;uniq_r_id];
                    temp_h5_fn        = [num2str(uniq_r_id,'%02.0f'),'_',datestr(temp_dt(1),'yyyymmdd'),'_',datestr(temp_dt(1),'HHMMSS'),'.h5'];
                    fetch_h5_fn       = [fetch_h5_fn;temp_h5_fn];
                %elseif str2num(temp_vol{1}(23:24))==1 && length(temp_vol)>=8
                    %volume missing end/middle scans, 1st scan is still there.
                    %sorted_volumes=[sorted_volumes,{temp_vol}];
                end
                temp_vol = {};
                temp_dt  = [];
            end
        end
    end
end


function rapic_convert(file_list,radar_id,local_mirror_path,arch_path,staging_ddb_table,odimh5_ddb_table)
%WHAT
%Takes a list of ftp_rapic (individual elevation scan files) and cat's them
%with grep into a single txt file. It then converts to odimh5
%moves this text file to the appropriate directory.

%INPUT
%file_list: cell array of strings of file names in the tmp dir
%dest_path: path to destination dir for h5 file

%read site_info
load(['tmp/site_info.txt.mat']);
load(['tmp/global.config.mat']);
%find radar lat lon
site_idx  = find(radar_id==siteinfo_id_list);
radar_lat = siteinfo_lat_list(site_idx);
radar_lon = siteinfo_lon_list(site_idx);
radar_h   = siteinfo_alt_list(site_idx);

%create full path filenames
dled_files = strcat( repmat({[' ',local_mirror_path,'/']},length(file_list),1),file_list);

%create local folder
if ~isdir(arch_path) && ~strcmp(arch_path(1:2),'s3')
    mkdir(arch_path);
end
broken_dest     = [arch_path,'broken_vols/',num2str(radar_id,'%02.0f'),'/'];
broken_dt       = datenum(file_list{1}(10:21),'yyyymmddHHMM');
broken_rapic_fn = [num2str(radar_id,'%02.0f'),'_',datestr(broken_dt,r_tfmt),'.rapic'];
%temp h5
tmp_h5_ffn = [tempname,'.h5'];
if exist(tmp_h5_ffn,'file') == 2
    delete(tmp_h5_ffn)
end

%cat scans into temp rapic volume 
tmp_rapic_ffn = [tempname,'.rapic'];
cmd = ['cat ',cell2mat(dled_files'),' > ',tmp_rapic_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    log_cmd_write('tmp/log.cat',broken_rapic_fn,cmd,eout)
end

%filter for error messages
error_1 = 'MSSG: 30 Status information following - 3D-Rapic TxDevice';
error_2 = 'MSSG: 6 \*\** Radar completed automatic update \*\**';
error_3 = 'MSSG: 5 \*\** Radar performing automatic update \*\**'; %escaped * chars
cmd     = ['sed -i -e ''s/\(',error_1,'\|',error_2,'\|',error_3,'\)//g'' ',tmp_rapic_ffn];
[sout,eout] = unix(cmd);

%convert to odim and save in correct archive folder
cmd = ['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',tmp_rapic_ffn,' ',tmp_h5_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    eout
    log_cmd_write('tmp/log.convert',broken_rapic_fn,'',eout)
end

%write missing latlonheight data as required
if any(strfind(eout,'LATITUDE'))
    h5writeatt(tmp_h5_ffn,'/where','height',radar_h);
    h5writeatt(tmp_h5_ffn,'/where','lat',radar_lat);
    h5writeatt(tmp_h5_ffn,'/where','lon',radar_lon);
end

%if h5 file does not exist, move rapic file to broken rapic vol
if exist(tmp_h5_ffn,'file')~=2
    display('conversion failure, moving rapic file to broken_vols')
    broken_file(tmp_rapic_ffn,broken_rapic_fn,broken_dest)
    return
else
    %extract h5 start date number 
    h5_start_date = deblank(h5readatt(tmp_h5_ffn,'/dataset1/what/','startdate'));
    h5_start_time = deblank(h5readatt(tmp_h5_ffn,'/dataset1/what/','starttime'));
    %remove seconds for BoM radar volumes becuase of issues with the
    %starttime in some rapic volumes
    h5_start_dt   = datenum([h5_start_date,h5_start_time(1:6)],'yyyymmddHHMMSS');
    h5_dir        = dir(tmp_h5_ffn);
    h5_size       = round(h5_dir.bytes/1000);
end
%create correct archive folder
h5_start_dt_vec  = datevec(h5_start_dt);
archive_dest     = [arch_path,num2str(radar_id,'%02.0f'),'/',num2str(h5_start_dt_vec(1)),'/',num2str(h5_start_dt_vec(2),'%02.0f'),'/',num2str(h5_start_dt_vec(3),'%02.0f'),'/'];
h5_fn            = [num2str(radar_id,'%02.0f'),'_',datestr(h5_start_dt,r_tfmt),'.h5'];
h5_ffn           = [archive_dest,h5_fn];

%move to required directory
file_mv(tmp_h5_ffn,h5_ffn);

%write to staging dynamo db
data_id                         = [datestr(h5_start_dt,ddb_tfmt),'_',num2str(radar_id,'%02.0f')];
ddb_struct                      = struct;
ddb_struct.data_type.S          = 'prep_odimh5';
ddb_struct.data_id.S            = data_id;
ddb_struct.data_ffn.S           = h5_ffn;
ddb_put_item(ddb_struct,staging_ddb_table)

%write to odimh5 dynamo db
ddb_struct                      = struct;
ddb_struct.radar_id.N           = num2str(radar_id,'%02.0f');
ddb_struct.start_timestamp.S    = datestr(h5_start_dt,ddb_tfmt);
ddb_struct.data_size.N          = num2str(h5_size);
ddb_struct.data_ffn.S           = h5_ffn;
ddb_struct.data_rng.N           = num2str(radar_mask_rng);
ddb_struct.storm_flag.N         = num2str(-1);
ddb_put_item(ddb_struct,odimh5_ddb_table)

%remove tmp rapic file
delete(tmp_rapic_ffn)

function lftp_mirror_coder(ftp_address,ftp_un,ftp_pass,ftp_path,local_mirror_path)
% WHAT
% creates an lftp bash script to mirror the rapic ftp server into
% local_mirror_path

%INPUT
% ftp_address: string of ftp site
% ftp_un: string of ftp username
% ftp_pass: string of ftp password
% ftp_path: string of ftp folder
% local_mirror_path: 

%          'set ftp:use-mlsd on;',...
%          'set net:timeout 5;',...
%          'set net:max-retries 10;',...
%          'set net:reconnect-interval-base 6;',...

%creat standard header and footer of code
script = ['#!/bin/bash',10,...
          'lftp -e ',...
          '''set ftp:sync-mode off;',...
          'mirror --delete --parallel=10 ',...
          ftp_path,' ',...
          local_mirror_path,'; ',...
          'bye''',' ',...
          '-u',' ',ftp_un,',',ftp_pass,...
          ' ',ftp_address];

%write to file
fid = fopen('tmp/lftp_mirror_scipt', 'wt');
fprintf(fid,'%s',script);
fclose(fid);
%set permission!
[~,~]=system('chmod +xw tmp/lftp_mirror_scipt');

function broken_file(in_ffn,out_fn,target_path)
%WHAT: move broken rapic volume

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

if strcmp(target_path(1:2),'s3')
    %s3 cmd
    cmd = [prefix_cmd,'aws s3 cp ',in_ffn,' ',target_path,out_fn];
    [sout,eout]        = unix(cmd);
    if sout ~= 0
        msg = [cmd,' returned ',eout]
    end
else
    %local cmd
    if exist(target_path,'file')~=7
        mkdir(target_path)
    end
    copyfile(in_ffn,[target_path,out_fn])
end
