function qc_odimh5
%WHAT:
%1: builds an odimh5 ddb for the odimh5 s3 archive.

%check if is deployed
if ~isdeployed
    addpath('/home/meso/dev/roames_weather/lib/m_lib');
    addpath('/home/meso/dev/shared_lib/jsonlab');
end
%ensure temp directory exists
mkdir('tmp')

%load global config file
config_input_path = 'config';
read_config(config_input_path);
load(['tmp/',config_input_path,'.mat'])

%init vars
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
ddb_table      = 'wxradar_odimh5_index';
s3_odimh5_root = 's3://roames-weather-odimh5/odimh5_archive/';
s3_bucket      = 's3://roames-weather-odimh5/';
year_list      = [year_start:1:year_stop];
if strcmp(radar_id,'all')
    radar_id_list = [1:1:80];
else
    radar_id_list = radar_id;
end

custom_date   = '/10/27/';


%confirm ddb has capacity
display('CHECK WRITE CAPACITY, PAUSED')
pause
% QC odimh5 ddb
for i=1:length(year_list)
    for j=1:length(radar_id_list)
        %set path to odimh5 data (id/year)
        s3_odimh5_path = [s3_odimh5_root,num2str(radar_id_list(j),'%02.0f'),'/',num2str(year_list(i)),custom_date];
        %get listing
        display(['s3 ls for: ',s3_odimh5_path])
        cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path,' --recursive'];
        [sout,eout] = unix(cmd);
        if isempty(eout)
            display(['no files for ',s3_odimh5_path]);
            continue
        end
        %read listing
        C           = textscan(eout,'%*s %*s %u %s');
        h5_name     = C{2};
        h5_size     = C{1};
        
        %% rename incorrect (nowcast filenames)
        if rename_flag == 1
            for k = 1:length(h5_name)
                [h5_path,h5_fn,~] = fileparts(h5_name{k});
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
                h5_name{k}  = [h5_path,'/',new_tag];
            end
        end
        
        %% duplicate
        if duplicate_flag == 1
            %create file name without seconds to check for unique files
            display('removing duplicates')
            h5_name_custom = cell(length(h5_name),1);
            for k=1:length(h5_name)
                h5_name_custom{k} = [h5_name{k}(1:end-5)];
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
                    pause(0.3)
                    display(['removing ',h5_name{duplicate_idx(l)}])
                end
            end
            h5_name = out_h5_name;
            h5_size = out_h5_size;
        end
        
        %% write to ddb
        if ddb_flag == 1
            %write to ddb
            display('write to ddb')
            ddb_tmp_struct  = struct;
            for k=1:length(h5_name)
                %skip if not a h5 file
                if ~strcmp(h5_name{k}(end-1:end),'h5')
                    continue
                end
                %rename
                %add to ddb struct
                if ddb_flag == 1
                    h5_ffn                  = [s3_bucket,h5_name{k}];
                    [ddb_tmp_struct,tmp_sz] = addtostruct(ddb_tmp_struct,h5_ffn,h5_size(k));
                    %write to ddb
                    if tmp_sz == 25 || k == length(h5_name)
                        display(['write to ddb ',h5_name{k}]);
                        ddb_batch_write(ddb_tmp_struct,ddb_table,0);
                        %clear ddb_tmp_struct
                        ddb_tmp_struct  = struct;
                        %display('written_to ddb')
                    end
                end
            end            
        end
    end
end
display('complete')


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
ddb_struct.(item_id).data_rng.S             = '300';
ddb_struct.(item_id).storm_flag.N           = '-1';

tmp_sz =  length(fieldnames(ddb_struct));
