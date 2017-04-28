function qc_odimh5
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: applies several qc processed to odimh5-archive on s3
%(1) remove_cappi, uses min_vol_size to remove files
%(2) nowcasting_rename_flag, renames files in nowcasting format
%(3) timestamp_rename_flag, renames files missing seconds (old error)
%(4) duplicate_flag, removes duplicated using largest file
%(5) vol_count_flag, generates log containing number of volumes + step
%
% INPUT 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check if is deployed
if ~isdeployed
    addpath('/home/meso/dev/roames_weather/lib/m_lib');
    addpath('/home/meso/dev/roames_weather/etc');
    addpath('/home/meso/dev/shared_lib/jsonlab');
end
addpath('etc')

%configs
local_tmp_path   = 'tmp';
local_log_path   = 'log';
config_input_fn  = 'qc.config';
site_info_fn     = 'site_info.txt';

%ensure temp directory exists
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%ensure log directory exists
if exist(local_log_path,'file') == 7
    disp('old log folder renamed')
    movefile(local_log_path,[local_log_path,'_',datestr(now,'yyyymmdd_HHMMSS')]);
end
mkdir(local_log_path)

%load global config file
read_config(config_input_fn);
load([local_tmp_path,'/',config_input_fn,'.mat'])

%load sites
site_info_fn      = 'site_info.txt';
read_site_info(site_info_fn); load([local_tmp_path,'/',site_info_fn,'.mat']);
if strcmp(radar_id,'all')
    radar_id_list = siteinfo_id_list;
else
    radar_id_list = radar_id;
end

%init vars
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
year_list      = [year_start:1:year_stop];

%loop through each year
for i=1:length(year_list)
    %loop through each radar
    for j=1:length(radar_id_list)
        %set path to odimh5 data (id/year)
        s3_odimh5_path = [s3_odimh5_root,num2str(radar_id_list(j),'%02.0f'),'/',num2str(year_list(i))];
        %get listing
        display(['s3 ls for: ',s3_odimh5_path])
        cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path,' --recursive'];
        [sout,eout] = unix(cmd);
        if isempty(eout)
            display(['no files for ',s3_odimh5_path]);
            continue
        end
        %read s3 listing
        C           = textscan(eout,'%*s %*s %u %s');
        h5_name     = C{2};
        h5_size     = C{1};
        
        %% (1) remove empty files (smaller than 10kB)
        if remove_cappi == 1
            disp('removing cappi files')
            remove_idx = [];
            for k = 1:length(h5_name)
                %check for cappi files using size
                if h5_size(k) < empty_vol_size
                    %remove these files
                    disp([h5_name{k},' of size ',num2str(h5_size(k)),' removed'])
                    file_rm([s3_bucket,h5_name{k}],0,1)
                    pause(0.1)
                    remove_idx = [remove_idx,k];
                end
            end
            %remove deleted files
            h5_name(remove_idx)  = [];
            h5_size(remove_idx)  = [];
        end

        %% (2) remove seconds to create volume time
        if timestamp_rename_flag == 1
            disp('renaming filenames to remove seconds')
            %rename volumes to remove seconds
            for k = 1:length(h5_name)
                h5_ffn = [s3_bucket,h5_name{k}];
                [h5_path,h5_fn,h5_ext] = fileparts(h5_ffn);
                %skip files with 00 seconds
                if strcmp(h5_fn(end-1:end),'00')
                    %display('file already renamed, skipping')
                    continue
                end
                new_fn      = [h5_fn(1:end-2),'00',h5_ext];
                new_ffn     = [h5_path,'/',new_fn];
                %if new ffn is different, mv to rename
                disp(['renaming ',h5_ffn,' to remove seconds'])
                cmd         = [prefix_cmd,'aws s3 mv ',h5_ffn,' ',new_ffn,' >> log.mv 2>&1 &'];
                [sout,eout] = unix(cmd);
                h5_name{k}  = [h5_path,'/',new_fn];
                pause(0.1)
            end
        end

        %% (3) rename incorrect (nowcast filenames in yyyymmddHHMMSS)
        if nowcasting_rename_flag == 1
            disp('renaming nowcast server files')
            for k = 1:length(h5_name)
                h5_ffn = [s3_bucket,h5_name{k}];
                [h5_path,h5_fn,~] = fileparts(h5_ffn);
                if strcmp(h5_fn(3),'_')
                    %display('file already renamed, skipping')
                    continue
                end
                h5_date     = datenum(h5_fn(1:14),'yyyymmddHHMMSS');
                new_tag     = [num2str(radar_id_list(j),'%02.0f'),'_',datestr(h5_date,'yyyymmdd'),'_',datestr(h5_date,'HHMMSS'),'.h5'];
                new_ffn     = [s3_bucket,h5_path,'/',new_tag];
                cmd         = [prefix_cmd,'aws s3 mv ',h5_ffn,' ',new_ffn,' >> log.mv 2>&1 &'];
                pause(0.3)
                [sout,eout] = unix(cmd);
                h5_name(k)  = [h5_path,'/',new_tag];
            end
        end
        %% (4) remove duplicates by removing seconds and comparing size
        if duplicate_flag == 1
            %create file name without seconds to check for unique files
            disp('removing duplicates')
            h5_name_custom = cell(length(h5_name),1);
            for k=1:length(h5_name)
                h5_name_custom{k} = [h5_name{k}(1:end-5)]; %remove seconds
            end
            [uniq_h5_name,~,ic] = unique(h5_name_custom);
            out_h5_name        = cell(length(uniq_h5_name),1);
            out_h5_size        = zeros(length(uniq_h5_name),1);
            for k=1:length(uniq_h5_name)
                duplicate_idx           = find(ic==k);
                %skip is no duplicates
                if length(duplicate_idx)<2
                    out_h5_size(k) = h5_size(duplicate_idx);
                    out_h5_name(k) = h5_name(duplicate_idx);
                    continue
                end
                %find size and sort
                [duplicate_sz,sort_idx] = sort(h5_size(duplicate_idx),'descend');
                duplicate_idx           = duplicate_idx(sort_idx);
                %write largest size to matrix
                out_h5_size(k) = h5_size(duplicate_idx(1));
                out_h5_name(k) = h5_name(duplicate_idx(1));
                %remove files less than the largest
                for l = 2:length(duplicate_sz)
                    cmd             = [prefix_cmd,'aws s3 rm ',s3_bucket,h5_name{duplicate_idx(l)},' &'];
                    [sout,eout]     = unix(cmd);
                    pause(0.1)
                    display(['removing ',h5_name{duplicate_idx(l)}])
                end
            end
            h5_name = out_h5_name;
            h5_size = out_h5_size;
        end
           
        %% (5) generate vol_count log
        if vol_count_flag == 1
            %generate a log file that contains three columns,
            %[yyyymmdd,vol_count,vol_count_with_size_threshold,mode_step];
            %build h5_Date
            disp('running vol count log')
            date_list = zeros(length(h5_name),1);
            for k = 1:length(h5_name)
                h5_ffn       = [s3_bucket,h5_name{k}];
                [~,h5_fn,~]  = fileparts(h5_ffn);
                date_list(k) = datenum(h5_fn(4:end),'yyyymmdd_HHMMSS');
            end
            %generate dateonly and uniq lists
            dateonly_list       = floor(date_list);
            index_date_list     = datenum(year_list(i),1,1):datenum(year_list(i),12,31);
            vol_count_list      = zeros(length(index_date_list),1);
            vol_size_count_list = zeros(length(index_date_list),1);
            vol_step_list       = zeros(length(index_date_list),1);
            %for each unique date, count the number of volumes ang the
            %number of steps
            for k = 1:length(index_date_list)
                %count number of volumes
                date_subset            = date_list(dateonly_list == index_date_list(k));
                size_subset            = h5_size(dateonly_list == index_date_list(k));
                vol_count_list(k)      = length(date_subset);
                vol_size_count_list(k) = sum(size_subset>=thresh_vol_size);
                %calc radar step
                if length(date_subset) > 1
                    vol_diff          = round((date_subset(2:end)-date_subset(1:end-1))*24*60);
                    vol_step          = mode(vol_diff);
                    if vol_step > 10
                        vol_step = 10;
                    end
                else
                    vol_step = 10; %default
                end
                vol_step_list(k) = vol_step;
            end
            %write to log file
            log_fn = [local_log_path,'/vol_count_',num2str(radar_id_list(j),'%02.0f'),'.log'];
            fid = fopen(log_fn,'at');
            for k = 1:length(index_date_list)
                fprintf(fid,'%s %d %d %d \n',datestr(index_date_list(k),'yyyymmdd'),vol_count_list(k),vol_size_count_list(k),vol_step_list(k));
            end
        end
    end
end
display('complete')
pushover('qc_odimh5','qc complete!')

function [ddb_struct,tmp_sz] = addtostruct(ddb_struct,h5_ffn,h5_size)

%init
h5_fn              = h5_ffn(end-20:end);
radar_id           = h5_fn(1:2);

radar_timestamp    = datenum(h5_fn(4:end-3),'yyyymmdd_HHMMSS');

item_id            = ['item_',radar_id,'_',datestr(radar_timestamp,'yyyymmddHHMMSS')];

%build ddb struct
ddb_struct.(item_id).radar_id.N             = radar_id;
ddb_struct.(item_id).start_timestamp.S      = datestr(radar_timestamp,'yyyy-mm-ddTHH:MM:SS');
ddb_struct.(item_id).data_size.N            = num2str(h5_size);
ddb_struct.(item_id).data_ffn.S             = h5_ffn;

tmp_sz =  length(fieldnames(ddb_struct));
