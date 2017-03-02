function build_database

%setup config names
database_config_fn = 'database.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('/home/meso/dev/shared_lib/jsonlab')
addpath('/home/meso/dev/roames_weather/bin/json_read')

% load database config
read_config(database_config_fn);
load([local_tmp_path,database_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

%create archive root
if exist([db_root,num2str(radar_id,'%02.0f')],'file') == 7
    str = input('db_root exists, type "rm" to remove, otherwise it will be merged');
    if strcmp(str,'rm')
        disp('removing db_root')
        rmdir([db_root,num2str(radar_id,'%02.0f')],'s')
        mkdir([db_root,num2str(radar_id,'%02.0f')])
    end
else
    mkdir([db_root,num2str(radar_id,'%02.0f')])
end

% date list
start_datenum = datenum(start_date,'yyyy_mm_dd');
end_datenum   = datenum(end_date,'yyyy_mm_dd');
date_list     = start_datenum:end_datenum;

%% sync s3 data
display(['storm_s3 sync of ',num2str(radar_id,'%02.0f')])
s3_timer = tic;
file_s3sync(storm_s3,[db_root,num2str(radar_id,'%02.0f'),'/'],'',radar_id)
disp(['storm_s3 sync complete in ',num2str(round(toc(s3_timer)/60)),'min'])

%% sync ddb for s3 data
%build stormh5 file name list and dates
stormh5_ffn_list = getAllFiles([db_root,num2str(radar_id,'%02.0f'),'/']);
stormh5_dt       = zeros(length(stormh5_ffn_list),1);
for i=1:length(stormh5_dt)
    [~,stormh5_fn,~] = fileparts(stormh5_ffn_list{i});
    stormh5_dt(i)    = datenum(stormh5_fn(4:18),r_tfmt);
end
%extract ddb for each date
uniq_stormh5_date = unique(floor(stormh5_dt));
for i=1:length(uniq_stormh5_date)
    target_date   = uniq_stormh5_date(i);
    disp(['processing ',datestr(target_date)]);
    target_idx    = find(floor(stormh5_dt) == target_date);
    temp_fn_list  = cell(length(target_idx),1);
    for j=1:length(target_idx)
        target_datetime = stormh5_dt(target_idx(j));
        date_id = datestr(target_datetime,ddb_dateid_tfmt);
        sort_id = [datestr(target_datetime,ddb_tfmt),'_',num2str(radar_id,'%02.0f')];
        temp_fn = ddb_query_begins_rapid('date_id',date_id,'sort_id',sort_id,'',storm_ddb);
        temp_fn_list{j} = temp_fn;
        %init get requires for target_date
    end
    wait_aws_finish
    %read temp files into matlab
    storm_jstruct = [];
    for j=1:length(temp_fn_list)
        jstruct_out = json_read(temp_fn_list{j});
        jnames      = fieldnames(jstruct_out.Items);
        if length(jnames) ~= ddb_fields
            disp(['jnames not correct length for ',datestr(stormh5_dt(target_idx(j)))])
            continue
        end
        storm_jstruct = [storm_jstruct,jstruct_out.Items];
    end
    %save to archive path
    date_vec     = datevec(target_date(i));
    archive_path = [num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',...
        num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
    %save storm_jstruct
    save([db_root,archive_path,'database.mat'],'storm_jstruct')
end
display('build_database complete')

for i=1:length(date_list)
    %make archive_path
    date_vec     = datevec(date_list(i));
    archive_path = [num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',...
        num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
    %create archive paths
    if exist([db_root,archive_path],'file') ~= 7
        mkdir([db_root,archive_path])
    end
end
