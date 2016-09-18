function wv_prep
% WHAT
%BoM volumetric lftp download manager. Downloads complete volumes (all files
%which make up one volume scan), rather than just new files, elimating the
%problem with delayed uploads to the ftp server. FTP server is first synced
%to a folder in tmp before applying time/site filters as required. Complete
%volumes which pass are cat'ed,converted to odim_h5 and moved to the
%correct s3 or local directory. directory ls provides indexing (perhaps
%move to dynamodb for remote?)

if ~isdeployed
    addpath('../lib/m_lib');
end

%load global config file
config_input_path = 'config';
read_config(config_input_path)
load([config_input_path,'.mat'])

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

kill_timer = tic;
kill_wait  = 60*60; %kill time in seconds

while exist('kill_wv_prep','file')==2 %run loop while script termination control still exists
    
    %Kill function
    if toc(kill_timer)>kill_wait
        %update user
        disp(['@@@@@@@@@ wv_prep restarted at ',datestr(now)])
        %restart
        if ~isdeployed
            %not deployed method: trigger background restart command before
            %kill
            [~,~] = unix(['matlab -desktop -r "run ',pwd,'/wv_prep.m" &'])
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
    cmd         = 'export LD_LIBRARY_PATH=/usr/lib; ./lftp_mirror_scipt';
    [sout,eout] = unix(cmd);
    if sout ~= 0
        log_cmd_write('prep_lftp.log',' ',cmd,eout)
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
        if strcmp(local_mirror_list{i}(end-2:end),'txt')
            clean_rapic_list = [clean_rapic_list;local_mirror_list{i}];
        end
    end
    
    %Run volume sorter...
    volume_timer = tic;
    [fetch_volumes,fetch_datetime,fetch_r_id] = filter_ftp_list(clean_rapic_list,ftp_oldest);
    filt_fetch_volumes = {};
    disp(['volume sorter took  ',num2str(toc(volume_timer)),' seconds',10])
    
    %filter using h5 archive index
    index_timer = tic;
    for i = 1:length(fetch_volumes)
        
        [index_h5_fn,~] = list_path(dest_path,fetch_r_id(i),fetch_datetime(i));
        %[index_h5_fn,~] = index_read(dest_path,fetch_r_id(i),fetch_datetime(i));
        temp_h5_fn   = [num2str(fetch_r_id(i),'%02.0f'),'_',datestr(fetch_datetime(i),'yyyymmdd'),'_',datestr(fetch_datetime(i),'HHMMSS'),'.h5'];
        if ~any(strcmp(index_h5_fn,temp_h5_fn))
            filt_fetch_volumes = [filt_fetch_volumes,fetch_volumes(i)];
        end
    end
    disp(['index filter took  ',num2str(toc(index_timer)),' seconds',10])
    
    %Loop through sorted_volumes
    no_vols = length(filt_fetch_volumes);
    disp(['########Passing ',num2str(no_vols),' volumes to rapic_convert'])
    
    for i=1:no_vols
        %cat rapic scans into volumes and convert to hdf5
        rapic_convert(filt_fetch_volumes{i},local_mirror_path,dest_path);
        disp(['Volume ',num2str(i),' processed of ',num2str(no_vols),' ',filt_fetch_volumes{i}{1}])
    end
    %output ftp open time and number of files downloaded
    disp(['###### ',num2str(no_vols),' volumes preprocessed',10]);
    
    %be nice to server
    pause(10)
end

disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc),' @@@@@@@@@'])

function [fetch_volumes,fetch_h5_datetime,fetch_h5_r_id] = filter_ftp_list(scan_filenames,min_offset)
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
oldest_date_num   = addtodate(utc_time,min_offset,'minute');

%extract parameters from scan_filenames
if ~isempty(scan_filenames)
    %write filename strings to datestrings, convert to datenums and sort
    %'IDR' r_id 'VOL.' yyyymmddHHMM '.' scan_no '_' total_num_scans '.txt'
    cell_out = textscan([scan_filenames{:}],'%*3s %2f %*4s %12s %*1s %2f %*1s %2f %*4s');

    %sort and extract parts
    [date_num,IX]  = sort(datenum(cell_out{2},'yyyymmddHHMM'));
    r_id           = cell_out{1}(IX);
    scan_no        = cell_out{3}(IX);
    total_scans    = cell_out{4}(IX);
    scan_filenames = scan_filenames(IX);
    
    %generate the oldest date num and create filter for this cutoff
    flt=find(date_num>=oldest_date_num);        
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
                    fetch_volumes     = [fetch_volumes,{temp_vol}];
                    fetch_h5_datetime = [fetch_h5_datetime;temp_dt(1)];
                    fetch_h5_r_id     = [fetch_h5_r_id;uniq_r_id];
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


function rapic_convert(file_list,local_mirror_path,dest_path)
%WHAT
%Takes a list of ftp_rapic (individual elevation scan files) and cat's them
%with grep into a single txt file. It then converts to odimh5
%moves this text file to the appropriate directory.

%INPUT
%file_list: cell array of strings of file names in the tmp dir
%dest_path: path to destination dir for h5 file

%create full path filenames
dled_files=strcat( repmat({[' ',local_mirror_path,'/']},length(file_list),1),file_list);

%extract datetag
date_vec = datevec(file_list{1}(10:21),'yyyymmddHHMM');
date_num = datenum(file_list{1}(10:21),'yyyymmddHHMM');
radar_id = str2num(file_list{1}(4:5));

%create correct archive folder
archive_dest=[dest_path,num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
%create local folder
if ~isdir(archive_dest) && ~strcmp(dest_path(1:2),'s3')
    mkdir(archive_dest);
end

%create new h5 volume ffn
h5_fn      = [num2str(radar_id,'%02.0f'),'_',datestr(date_num,'yyyymmdd'),'_',datestr(date_num,'HHMMSS'),'.h5'];
tmp_h5_ffn = [tempdir,h5_fn];
h5_ffn     = [archive_dest,h5_fn];

%cat scans into temp rapic volume 
tmp_rapic_ffn = [tempdir,'ftp_cat.rapic'];
if exist(tmp_rapic_ffn,'file') == 2; delete(tmp_rapic_ffn); end;
cmd = ['cat ',cell2mat(dled_files'),' > ',tmp_rapic_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    log_cmd_write('prep_cat.log',h5_fn,cmd,eout)
end

%convert to odim and save in correct archive folder
cmd = ['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',tmp_rapic_ffn,' ',tmp_h5_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    log_cmd_write('prep_convert.log',h5_fn,'','')
end

%if h5 file does not exist, move rapic file to broken vol
if exist(tmp_h5_ffn,'file')~=2
    display('conversion failure, moving rapic file to broken_vols')
    broken_file(tmp_rapic_ffn,[archive_dest,'broken_vols/'])
    return
end


%move to required directory
if strcmp(dest_path(1:2),'s3')
    cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws s3 cp ',tmp_h5_ffn,' ',h5_ffn];
    [sout,eout] = unix(cmd);
    if sout ~= 0
        log_cmd_write('pre_s3.log',h5_fn,cmd,eout)
    end
else
    copyfile(tmp_h5_ffn,h5_ffn)
end

% %check file exist
% if exist(h5_ffn,'file') ~= 2
%     display(eout);
% else
%     %write to index file in the rapic archive
%     index_write(dest_path,radar_id,date_num,h5_fn);
% end

%remove tmp files
delete(tmp_rapic_ffn)
delete(tmp_h5_ffn)

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
fid = fopen('lftp_mirror_scipt', 'wt');
fprintf(fid,'%s',script);
fclose(fid);
%set permission!
[~,~]=system('chmod +xw lftp_mirror_scipt');



%move broken file
function broken_file(ffn,target_path)
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

if strcmp(target_path(1:2),'s3')
    %s3 cmd
    cmd = [prefix_cmd,'aws s3 cp ',ffn,' ',target_path]
    [sout,eout]        = unix(cmd);
    if sout ~= 0
        msg = [cmd,' returned ',eout]
    end
else
    %local cmd
    if exist(target_path,'file')~=7
        mkdir(target_path)
    end
    copyfile(ffn,target_path)
end
