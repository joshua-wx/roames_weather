function batch_reprocess
%WHAT: using a list of files, break apart into tilts, rebuild into vols and
%convert to odimh5 -> upload to odim archive is success or unbroken vol

%add paths
if ~isdeployed
    addpath('../../lib/m_lib')
end

mkdir('tmp')

%read config
config_fn = 'corrupt.config';
read_config(config_fn)
load(['tmp/',config_fn,'.mat'])

%load rapic file list
load(rapic_list_fn)

%parse file listing to dates
date_list     = zeros(length(restore_ffn_list),1);
for j=1:length(date_list)
    [~,rapic_fn,ext] = fileparts(restore_ffn_list{j});
    str_date = textscan([rapic_fn,ext],'%*s %*s %s %*s %*s','Delimiter','.'); str_date = str_date{1};
    date_list(j) = datenum(str_date,'yyyymmdd');
end

%init temp dir
daily_path = [tempname,'_rapic_daily/'];
tilt_path  = [tempname,'_rapic_tilt/'];
vol_path   = [tempname,'_rapic_vol/'];

%loop through unique list of days
uniq_date_list = unique(date_list);
%remove entries before start date
start_date     = datenum(num2str(start_date),'yyyymmdd');
uniq_date_list = uniq_date_list(uniq_date_list>=start_date);

try
    for i=1:length(uniq_date_list)
         
         %clean folders
         clear_dir(daily_path);
         clear_dir(tilt_path);
         clear_dir(vol_path);
        
         %index files for target date
         day_idx = find(uniq_date_list(i) == date_list);
         %download files for target day
         for j=1:length(day_idx)
             [~,rapic_fn,ext] = fileparts(restore_ffn_list{day_idx(j)});
             local_daily_ffn = [daily_path,rapic_fn,ext]
             file_cp(restore_ffn_list{day_idx(j)},local_daily_ffn,0,0);
         end

         %wait for aws jobs to finish
         %utility_aws_wait
         %uncompress files
         lz4_to_vol(daily_path)
         %process into tilts
         daily_to_tilt(daily_path,tilt_path)
         %process tilts into volumes
         tilt_to_volume(tilt_path,vol_path)
    end
catch err
    utility_pushover('batch_reprocess','crashed!!!! ')
    rethrow(err)
end
utility_pushover('batch_reprocess','finished :)')

function clear_dir(folder)
%WHAT: deletes folder if it exists and mkdirs again
%daily paths
if exist(folder,'file') == 7
    rmdir(folder,'s');
end
mkdir(folder);

function lz4_to_vol(daily_path)
%WHAT: unlz4 vols and remove compressed files
prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
%index path
dir_out = dir(daily_path); dir_out(1:2) = [];
fn_list = {dir_out.name};
for i=1:length(fn_list)
    %split into parts
    target_fn = fn_list{i};
    [~,name,ext] = fileparts(target_fn);
    if strcmp(ext,'.lz4')
        %uncompress
        cmd = [prefix_cmd,'lz4c -d ',daily_path,target_fn,' ',daily_path,name];
        [sout,uout] = unix(cmd);
        %delete original
        delete([daily_path,target_fn])
    end
end