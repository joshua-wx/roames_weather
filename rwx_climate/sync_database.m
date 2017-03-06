function sync_database

%WHAT: Syncs the s3 stormh5 and stormddb data for a single radar id to a
%local database structure. ddb data is cut from jstructs into daily
%structs.

%setup config names
database_config_fn = 'database.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';
root_tmp_folder    = 'sync_database/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end
if exist([tempdir,root_tmp_folder],'file') ~= 7
    mkdir([tempdir,root_tmp_folder])
else
    rmdir([tempdir,root_tmp_folder],'s')
    mkdir([tempdir,root_tmp_folder])
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('/home/meso/dev/shared_lib/jsonlab')
addpath('/home/meso/dev/roames_weather/bin/json_read')
addpath('etc/')

% load database config
read_config(database_config_fn);
load([local_tmp_path,database_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

%create archive root
if exist([db_root,num2str(radar_id,'%02.0f')],'file') == 7
    str = input('db_root exists, type "rm" to remove, otherwise s3 data will be merged and ddb data will be replaced: ','s');
    if strcmp(str,'rm')
        disp('removing db_root')
        rmdir([db_root,num2str(radar_id,'%02.0f')],'s')
        mkdir([db_root,num2str(radar_id,'%02.0f')])
    end
else
    mkdir([db_root,num2str(radar_id,'%02.0f')])
end

%% sync s3 data
display(['storm_s3 sync of ',num2str(radar_id,'%02.0f')])
s3_timer = tic;
if resync_h5 == 1
    file_s3sync(storm_s3,[db_root,num2str(radar_id,'%02.0f'),'/'],'',radar_id);
end
disp(['storm_s3 sync complete in ',num2str(round(toc(s3_timer)/60)),'min'])

%% sync ddb for s3 data
%build stormh5 file name list and dates
ddb_timer        = tic;
archive_ffn_list = getAllFiles([db_root,num2str(radar_id,'%02.0f'),'/']);
stormh5_dt_list  = [];
stormh5_ffn_list = {};
for i=1:length(archive_ffn_list)
    %check if this is a database file
    [~,stormh5_fn,~] = fileparts(archive_ffn_list{i});
    if strcmp(stormh5_fn,'database')
        delete(archive_ffn_list{i})
        continue
    end
    stormh5_dt_list  = [stormh5_dt_list;datenum(stormh5_fn(4:18),r_tfmt)];
    stormh5_ffn_list = [stormh5_ffn_list;archive_ffn_list{i}];
end
%run ddb begins query for each datetime for each date
uniq_stormh5_date = unique(floor(stormh5_dt_list));
temp_ffn_list     = {};
temp_date_list    = [];
for i=1:length(uniq_stormh5_date)
    %create list of entries for target_date
    target_date   = uniq_stormh5_date(i);
    disp(['ddb batch get for ',datestr(target_date)]);
    target_idx    = find(floor(stormh5_dt_list) == target_date);
    %loop through entries
    %init read struct
    ddb_read_struct  = struct;
    for j=1:length(target_idx)
        %extract storm cell entries for datetime
        target_datetime = stormh5_dt_list(target_idx(j));
        target_stormh5  = stormh5_ffn_list{target_idx(j)};
        %check number of cells
        stormh5_info    = h5info(target_stormh5);
        stormh5_group_no= length(stormh5_info.Groups);
        %loop through storm groups
        for k=1:stormh5_group_no
            tmp_jstruct              = struct;
            tmp_jstruct.date_id.N    = datestr(target_datetime,ddb_dateid_tfmt);
            tmp_jstruct.sort_id.S    = [datestr(target_datetime,ddb_tfmt),'_',num2str(radar_id,'%02.0f'),'_',num2str(k,'%03.0f')];
            %create entry for batch read for current storm
            [ddb_read_struct,tmp_sz] = addtostruct(ddb_read_struct,tmp_jstruct);
            %parse batch read if size is 25 or last cell of last file for
            %current day
            if tmp_sz==25 || (j == length(target_idx) && k == stormh5_group_no)
                %temp path
                temp_path        = [tempdir,root_tmp_folder,datestr(target_date,'yyyymmdd'),'/'];
                if exist(temp_path,'file')~=7
                    mkdir(temp_path)
                end
                %batch read
                temp_ffn         = ddb_batch_read(ddb_read_struct,storm_ddb,temp_path,'');
                pause(0.1)
                %add read filename to list
                temp_ffn_list    = [temp_ffn_list;temp_ffn];
                temp_date_list   = [temp_date_list;target_date];
                %clear ddb_put_struct
                ddb_read_struct  = struct;
            end
        end
    end
end

%wait for aws batch read to finish
wait_aws_finish
%generate unique date list
uniq_temp_date_list = unique(temp_date_list);

%loop through each unique date for the ddb read file list
for i=1:length(uniq_temp_date_list)
    %create target_ffn_list for target_date
    target_date     = uniq_temp_date_list(i);
    target_ffn_list = temp_ffn_list(temp_date_list==target_date);
    disp(['json parse for ',datestr(target_date)]);
    %read temp files into matlab
    storm_struct = [];
    %loop through file list
    for j=1:length(target_ffn_list)
        %read json in temp file
        jstruct_out = json_read(target_ffn_list{j});
        %delete temp file
        delete(target_ffn_list{j})
        %abort file if it contains unprocessed keys
        if ~isempty(fieldnames(jstruct_out.UnprocessedKeys))
            disp('UnprocessedKeys present')
            keyboard
        end
        %loop through entries
        for k=1:length(jstruct_out.Responses.(storm_ddb))
            %extract names for entry k
            jnames      = fieldnames(jstruct_out.Responses.(storm_ddb)(k));
            %abort if field names are not equal to ddb_fields
            if length(jnames) ~= ddb_fields
                disp(['jnames not correct length for ',datestr(target_date(i))])
                continue
            end
            %remove field types from struct and append to storm_struct
            clean_struct = struct;
            %loop though fields and add to clean_struct
            for m=1:length(jnames)
                field_name                = jnames{m};
                field_struct              = jstruct_out.Responses.(storm_ddb)(k).(field_name);
                field_type                = fieldnames(field_struct); field_type = field_type{1};
                clean_struct.(field_name) = jstruct_to_mat(field_struct,field_type);
            end
            %append clean_struct to storm_struct
            storm_struct = [storm_struct,clean_struct];
        end
    end
    %save to archive path
    date_vec     = datevec(target_date);
    archive_path = [num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',...
        num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
    %save storm_jstruct
    save([db_root,archive_path,'database.mat'],'storm_struct')
end

disp(['ddb sync complete in ',num2str(round(toc(ddb_timer)/60)),'min'])
rmdir([tempdir,root_tmp_folder],'s')


function [ddb_struct,tmp_sz] = addtostruct(ddb_struct,data_struct)

%init
data_name_list  = fieldnames(data_struct);
%check size
tmp_sz    = length(fieldnames(ddb_struct));
item_name = ['item',num2str(tmp_sz+1)];
for i = 1:length(data_name_list)
    %read from data_struct
    data_name  = data_name_list{i};
    data_type  = fieldnames(data_struct.(data_name)); data_type = data_type{1};
    data_value = data_struct.(data_name).(data_type);
    %add to ddb master struct
    ddb_struct.(item_name).(data_name).(data_type) = data_value;
end

