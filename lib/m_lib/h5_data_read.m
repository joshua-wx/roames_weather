function data_struct = h5_data_read(h5_fn,h5_path,group_number)
%WHAT: reads group_name from h5_fn and returns the associated data struct
%and the global attributes as att_struct

%build ffn
h5_ffn = [h5_path,h5_fn];

%return empty struct if missing
if exist(h5_ffn,'file')~=2
    display(['h5 file missing: ',h5_ffn])
    data_struct = struct;
    return
end

%lock file
%lock_ffn = lock_file(h5_fn);

%read data group
group_name   = num2str(group_number);
group_h5data = h5info(h5_ffn,['/',group_name]);
group_h5data = group_h5data.Datasets;
data_struct  = [];
for i = 1:length(group_h5data)
    dataset_name = group_h5data(i).Name;
    dataset_path = ['/',group_name,'/',dataset_name];
    data_struct.(dataset_name) = h5read(h5_ffn,dataset_path);
end

%remove lock file
%delete(lock_ffn);
