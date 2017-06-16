function sync_database(radar_id_list_in)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Syncs the s3 stormh5 and stormddb data for a single radar id to a
%local database structure. ddb data is cut from jstructs into daily
%structs.
% INPUTS
% out_ffn: sync.config
% radar_id_list_in: vector of radar ids
% RETURNS: database on disk
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%setup config names
database_config_fn = 'sync.config';
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

% Load site info
[~] = read_site_info(site_info_fn);
load([local_tmp_path,site_info_fn,'.mat']);

%read local archive path folders for 'all'
if strcmp(radar_id_list,'all')
    radar_id_list = siteinfo_id_list;
end
%override with input var if present
if nargin==1
    radar_id_list = radar_id_list_in;
end

for m = 1:length(radar_id_list)
    %set radar_id
    radar_id = radar_id_list(m);
    disp(['sync for ',num2str(radar_id,'%02.0f')]);
    
    %create archive root
    if exist([db_root,num2str(radar_id,'%02.0f')],'file') == 7
        disp('db_root exists')
    else
        mkdir([db_root,num2str(radar_id,'%02.0f')])
    end

    %create archive file name
    archive_ffn  = [db_root,'/',num2str(radar_id,'%02.0f'),'/database.csv'];
    %delete if required
    if rebuild_ddb == 1 && exist(archive_ffn,'file') == 2
        delete(archive_ffn)
    end

    %% sync s3 data
    if resync_h5 == 1
        s3_timer = tic;
        display(['storm_s3 sync of ',num2str(radar_id,'%02.0f')])
        s3_sync(storm_s3,[db_root,num2str(radar_id,'%02.0f'),'/'],radar_id,'','','');
        disp(['storm_s3 sync complete in ',num2str(round(toc(s3_timer)/60)),'min'])
    end

    %% sync ddb for s3 data
    %build stormh5 file name list and dates  
    archive_ffn_list = utility_getAllFiles([db_root,num2str(radar_id,'%02.0f'),'/']);
    stormh5_dt_list  = [];
    stormh5_ffn_list = {};
    %extract file dates and locations of stormh5
    for i=1:length(archive_ffn_list)
        [~,stormh5_fn,~] = fileparts(archive_ffn_list{i});
        %skip database file
        if strcmp(stormh5_fn,'database')
            continue
        end
        stormh5_dt_list  = [stormh5_dt_list;datenum(stormh5_fn(4:18),r_tfmt)];
        stormh5_ffn_list = [stormh5_ffn_list;archive_ffn_list{i}];
    end
    
    %apply rebuild ddb settings (skip transfered data)
    if exist(archive_ffn,'file') == 2
        %read database
        fid = fopen(archive_ffn);
        C   = textscan(fid,['%*d %f %f %f %f %f %f',repmat(' %*f',1,27)],'HeaderLines',1,'Delimiter',',');
        %skip if file only contains header
        if ~isempty(C{1})
            fclose(fid);
            %convert to dates
            database_dt = datenum(C{1},C{2},C{3},C{4},C{5},C{6});
            uniq_date   = unique(floor(database_dt));
            %crop database.csv to remove the end date (this will be replaced
            %with refreshed ddb entries)
            crop_date   = uniq_date(end-1);
            crop_idx    = find(floor(database_dt)==crop_date,1,'last');
            cmd = ['sed -n ''1,',num2str(crop_idx),' p'' ',archive_ffn];
            [sout,eout] = unix(cmd);
            %keep stormh5_dt_list >= end date
            filt_mask        = floor(stormh5_dt_list)>=uniq_date(end);
            stormh5_ffn_list = stormh5_ffn_list(filt_mask);
            stormh5_dt_list  = stormh5_dt_list(filt_mask);
        end
    else
        %init database
        table_header = {'radar_id,','year,','month,','day,','hour,','minute,','second,','track_id,',... %1-8
            'subset_id,','v_grid(km),','h_grid(km),',... %9-11
            'storm_z_centlat,','storm_z_centlon,',... %12-13
            'storm_min_i,','storm_max_i,','storm_min_j,','storm_max_j,',... %14-17
            'storm_max_lat,','storm_min_lat,','storm_max_lon,','storm_min_lon,',... %18-21
            'area(km2),','area_ewt(km2),','max_cell_vil(kg/m2),','max_dbz(dbz),',... %22-25
            'max_dbz_h(km),','max_g_vil(kg/m2),','max_mesh(mm),',... %26-28
            'max_posh(%),','max_sts_dbz_h(km),','max_tops(km),',... %29-31
            'mean_dbz(dbz),','mass(kt),','vol(km3),'}; %32-34
        %write header to file
        fid = fopen(archive_ffn,'a+'); %discard contents
        fprintf(fid,'%s\n',cell2mat(table_header));
        fclose(fid);
    end
    
    
    %run ddb begins query for each datetime for each date
    ddb_timer         = tic;
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
                [ddb_read_struct,tmp_sz] = utility_addtostruct(ddb_read_struct,tmp_jstruct);
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
    utility_aws_wait
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
                    clean_struct.(field_name) = utility_jstruct_to_mat(field_struct,field_type);
                end
                %append clean_struct to storm_struct
                storm_struct = [storm_struct,clean_struct];
            end
        end
        %calc tracks
        track_vec   = nowcast_wdss_tracking(storm_struct,false,'');
        %create date vec
        date_vec    = datevec(vertcat(storm_struct.start_timestamp),ddb_tfmt);
        %collate storm_ij_box and storm latlon box
        storm_ijbox      = zeros(length(storm_struct),4);
        storm_latlonbox = zeros(length(storm_struct),4);
        for k=1:length(storm_struct)
            storm_ijbox(k,:)     = str2num(cell2mat(storm_struct(k).storm_ijbox));
            storm_latlonbox(k,:) = str2num(cell2mat(storm_struct(k).storm_latlonbox));
        end
        %extract storm_struct to table
        table_data   = [vertcat(storm_struct.radar_id),date_vec,track_vec,...
            vertcat(storm_struct.subset_id),vertcat(storm_struct.v_grid),vertcat(storm_struct.h_grid),...
            vertcat(storm_struct.storm_z_centlat),vertcat(storm_struct.storm_z_centlon),storm_ijbox,storm_latlonbox,...
            vertcat(storm_struct.area),vertcat(storm_struct.area_ext),vertcat(storm_struct.cell_vil),vertcat(storm_struct.max_dbz),...
            vertcat(storm_struct.max_dbz_h),vertcat(storm_struct.max_g_vil),vertcat(storm_struct.max_mesh),...
            vertcat(storm_struct.max_posh),vertcat(storm_struct.max_sts_dbz_h),vertcat(storm_struct.max_tops),...
            vertcat(storm_struct.mean_dbz),vertcat(storm_struct.mass),vertcat(storm_struct.vol)];
        %write data to end of file
        dlmwrite(archive_ffn,table_data,'-append');
    end

    disp(['ddb sync complete in ',num2str(round(toc(ddb_timer)/60)),'min'])
    rmdir([tempdir,root_tmp_folder],'s')
end
