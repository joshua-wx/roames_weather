function clean_s3
%WHAT: Removes duplicate files (same minute)

%load global config file
config_input_path = 'config';
read_config(config_input_path);
load(['tmp/',config_input_path,'.mat'])

%check if is deployed
if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
end

%init vars
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
ddb_table      = 'wxradar_odimh5_index';
s3_odimh5_root = 's3://roames-wxradar-archive/odimh5_archive/';
s3_bucket      = 's3://roames-wxradar-archive/';
s3_odimh5_path = [s3_odimh5_root,num2str(radar_id)];

%ensure temp directory exists
mkdir('tmp')

% REMOVE DUPLICATE FILES (WITHIN THE SAME MINUTE)
%run an aws ls -r
display(['s3 ls for radar_id: ',num2str(radar_id)])
cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path,' --recursive'];
[sout,eout] = unix(cmd);
%read text
C           = textscan(eout,'%*s %*s %u %s');
h5_name     = C{2};
h5_size     = C{1};
%create file name with seconds to check for unique files
display('removing duplicates')
h5_name_custom = {};
for j=1:length(h5_name)
    h5_name_custom   = [h5_name_custom;h5_name{j}(1:end-5)];
end
[uniq_h5_name,ia,ic] = unique(h5_name_custom);
for j=1:length(uniq_h5_name);
    display(['Checking ',uniq_h5_name])
    duplicate_idx           = find(ic==j);
    %find size and sort
    [duplicate_sz,sort_idx] = sort(h5_size(duplicate_idx),'descend');
    duplicate_idx           = duplicate_idx(sort_idx);
    %remove files less than the largest
    for k = 2:length(duplicate_sz)
        cmd         = [prefix_cmd,'aws s3 rm ',s3_bucket,h5_name{duplicate_idx(k)},' &'];
        [sout,eout] = unix(cmd)
        display(['removing ',h5_name{duplicate_idx(k)}])
    end
end
display('complete')
