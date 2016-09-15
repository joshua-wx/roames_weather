function wv_prep
% WHAT
%BoM volumetric lftp download manager. Downloads complete volumes (all files
%which make up one volume scan), rather than just new files, elimating the
%problem with delayed uploads to the ftp server. previously downloaded
%filenames are saved. Once a volume has been downloaded, the IMAGE header is
%removed, files are cat'ed and then moved to the correct archive directory.

%scan_fn: list of downloaded individual scan files
%vol_fn: list of cated scan_fn files
%add function path if not deployed
if ~isdeployed
    addpath('../lib/m_lib');
end
addpath('../etc');

%load global config file
config_input_path = 'wv_prep.config';
read_config(config_input_path)
load([config_input_path,'.mat'])

%kill function is dest is missing (config broken)
if isempty(dest)
    msgbox('prep config broken')
    return
end

%Create script termination file
if exist('kill_wv_prep','file')~=2
    fid = fopen('kill_wv_prep', 'w'); fprintf(fid, '%s', ''); fclose(fid);
end

%init local mirror folder
local_mirror_path = [tempdir,'rapic_mirror'];
if exist(local_mirror_path,'file')~=7
    %create as needed
    mkdir(local_mirror_path);
end

tic
while exist('kill_wv_prep','file')==2 %run loop while script termination control still exists
        %open ftp and create nlist
        ftp_timer = tic;

		%create lftp script to mirror remote server
        lftp_mirror_coder(ftp_address,ftp_un,ftp_pass,ftp_path,local_mirror_path);
        
        %run ftp script, usually brings in 27k files
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
		
        %Convert nlist char matrix to cell array
        disp(['ftp mirror download took  ',num2str(toc(ftp_timer)),' seconds',10])
        
        %only process files of the correction fn length (remove others fns)
        clean_rapic_list = {};
        for i = 1:length(local_mirror_list)
            if strcmp(local_mirror_list{i}(end-2:end),'txt')
                clean_rapic_list = [clean_rapic_list;local_mirror_list{i}];
            end
        end
        
        %Run volume sorter...
        [fetch_volumes,fetch_datetime,fetch_r_id] = filter_ftp_list(clean_rapic_list,ftp_oldest);
        filt_fetch_volumes = {};
        
        %filter using h5 archive index
        for i = 1:length(fetch_volumes)
            [index_h5_fn,~] = index_read(dest,fetch_r_id(i),fetch_datetime(i));
            temp_h5_fn   = [num2str(fetch_r_id(i),'%02.0f'),'_',datestr(fetch_datetime(i),'yyyymmdd'),'_',datestr(fetch_datetime(i),'HHMMSS'),'.h5'];
            if ~any(strcmp(index_h5_fn,temp_h5_fn))
                filt_fetch_volumes = [filt_fetch_volumes,fetch_volumes(i)];
            end
        end
        
        %Loop through sorted_volumes
        no_vols = length(filt_fetch_volumes);
        disp(['########Passing ',num2str(no_vols),' volumes to rapic_convert'])

        for i=1:no_vols
            %cat rapic scans into volumes and convert to hdf5
            rapic_convert(filt_fetch_volumes{i},local_mirror_path,dest);
            disp(['Volume ',num2str(i),' processed of ',num2str(no_vols),' ',filt_fetch_volumes{i}{1}])
        end
        %output ftp open time and number of files downloaded
        disp(['######Script Runtime ',num2str(roundn(toc/60/60,-2)),'hrs with ',num2str(no_vols),' volumes preprocessed',10]);
        
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


function rapic_convert(file_list,local_mirror_path,dest)
%WHAT
%Takes a list of ftp_rapic (individual elevation scan files) and cat's them
%with grep into a single txt file. It then converts to odimh5
%moves this text file to the appropriate directory.

%INPUT
%file_list: cell array of strings of file names in the tmp dir
%dest: path to destination dir for h5 file

%create full path filenames
dled_files=strcat( repmat({[' ',local_mirror_path,'/']},length(file_list),1),file_list);

%extract datetag
date_vec = datevec(file_list{1}(10:21),'yyyymmddHHMM');
date_num = datenum(file_list{1}(10:21),'yyyymmddHHMM');
radar_id = str2num(file_list{1}(4:5));

%create correct archive folder
archive_dest=[dest,num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
if ~isdir(archive_dest)
    mkdir(archive_dest);
end

%create new h5 volume ffn
h5_fn  = [num2str(radar_id,'%02.0f'),'_',datestr(date_num,'yyyymmdd'),'_',datestr(date_num,'HHMMSS'),'.h5'];
h5_ffn = [archive_dest,h5_fn];

%cat scans into temp rapic volume 
tmp_rapic_ffn = [tempdir,'ftp_cat.rapic'];
if exist(tmp_rapic_ffn,'file') == 2; delete(tmp_rapic_ffn); end;
cmd = ['cat ',cell2mat(dled_files'),' > ',tmp_rapic_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    log_cmd_write('prep_cat.log',h5_fn,cmd,eout)
end

%convert to odim and save in correct archive folder
cmd = ['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',tmp_rapic_ffn,' ',h5_ffn];
[sout,eout]=unix(cmd);
if sout ~= 0
    log_cmd_write('prep_convert.log',h5_fn,'','')
end

%check file exist
if exist(h5_ffn,'file') ~= 2
    display(eout);
else
    %write to index file in the rapic archive
    index_write(dest,radar_id,date_num,h5_fn);
end

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
