function data_struct = h5_data_read(h5_fn,h5_path,group_number)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: reads group_number from h5_fn and returns the associated data as
% data_struct. Designed for storm.h5 files
% INPUTS
% h5_fn:   storm.h5 file names (str)
% h5_path: path to storm.h5 file (str)
% group_number: group number for object to extract from stormh5 (double)
% RETURNS
% data_struct: struct containing data objects from storm.h5 file (Struct)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%build ffn
h5_ffn = [h5_path,h5_fn];

%return empty struct if missing
if exist(h5_ffn,'file')~=2
    display(['h5 file missing: ',h5_ffn])
    data_struct = struct;
    return
end

%read data group object list
group_name   = num2str(group_number);
group_h5data = h5info(h5_ffn,['/',group_name]);

group_h5data = group_h5data.Datasets;
data_struct  = [];
for i = 1:length(group_h5data)
    dataset_name = group_h5data(i).Name;
    dataset_path = ['/',group_name,'/',dataset_name];
    data_struct.(dataset_name) = h5read(h5_ffn,dataset_path);
end
