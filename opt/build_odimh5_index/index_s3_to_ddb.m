function index_s3_to_ddb
%WHAT: builds an index for the odimh5 s3 archive.

%check if is deployed
if ~isdeployed
    addpath('/home/meso/dev/roames_weather/lib/m_lib');
    addpath('/home/meso/dev/shared_lib/jsonlab');
end

%load global config file
config_input_path = 'config';
read_config(config_input_path);
load(['tmp/',config_input_path,'.mat'])


%init vars
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
ddb_table      = 'wxradar_odimh5_index_2';
s3_odimh5_root = 's3://roames-wxradar-archive/odimh5_archive/';
s3_bucket      = 's3://roames-wxradar-archive/';
s3_odimh5_path = [s3_odimh5_root,num2str(radar_id,'%02.0f')];
year_list      = [year_start:1:year_stop];

%ensure temp directory exists
mkdir('tmp')
display('CHECK WRITE CAPACITY, PAUSED')
pause
% BUILD INDEX
%run an aws ls -r
for i=1:length(year_list)
    display(['s3 ls for radar_id: ',num2str(radar_id,'%02.0f'),'/',num2str(year_list(i)),'/'])
    cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path,'/',num2str(year_list(i)),'/',' --recursive'];
    [sout,eout] = unix(cmd);
    %read text
    C           = textscan(eout,'%*s %*s %u %s');
    h5_name     = C{2};
    h5_size     = C{1};

    %add to archive
    display('indexing s3 file list')
    ddb_tmp_struct  = struct;
    for k=1:length(h5_name)
        %skip if not a h5 file
        if ~strcmp(h5_name{k}(end-1:end),'h5')
            continue
        end
        %add to ddb struct
        h5_ffn                  = [s3_bucket,h5_name{k}];
        [ddb_tmp_struct,tmp_sz] = addtostruct(ddb_tmp_struct,h5_ffn,h5_size(k));
        %write to ddb
        if tmp_sz==25 || k == length(h5_name)
            display(['write to ddb ',h5_name{k}]);
            ddb_batch_write(ddb_tmp_struct,ddb_table,0);
            %clear ddb_tmp_struct
            ddb_tmp_struct  = struct;
            %display('written_to ddb')
        end
    end
end
display('complete')
        
        
function [ddb_struct,tmp_sz] = addtostruct(ddb_struct,h5_ffn,h5_size)

%init
h5_fn              = h5_ffn(end-20:end);
radar_id           = h5_fn(1:2);

radar_timestamp    = datenum(h5_fn(4:end-5),'yyyymmdd_HHMM');

item_id            = ['item_',radar_id,'_',datestr(radar_timestamp,'yyyymmddHHMMSS')];

%build ddb struct
ddb_struct.(item_id).radar_id.N             = radar_id;
ddb_struct.(item_id).start_timestamp.S      = datestr(radar_timestamp,'yyyy-mm-ddTHH:MM:SS');
ddb_struct.(item_id).data_size.N            = num2str(h5_size);
ddb_struct.(item_id).data_ffn.S             = h5_ffn;
ddb_struct.(item_id).data_rng.S             = '250';
ddb_struct.(item_id).storm_flag.N           = '-1';

tmp_sz =  length(fieldnames(ddb_struct));
