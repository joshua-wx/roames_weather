function h5_data_write(h5_fn,h5_path,group_number,data_struct,r_scale)
%WHAT: Writes data_struct under group_name to h5_fn

%build ffn
h5_ffn = [h5_path,h5_fn];

%lock file
%lock_ffn = lock_file(h5_fn);

%check if it exists
if exist(h5_ffn,'file')~=2
    %create new h5 file
    h5_fid = H5F.create(h5_ffn, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
    %create root group labels
    root_id = H5G.open(h5_fid, '/', 'H5P_DEFAULT');
    H5Acreatestring(root_id, 'Owner', 'Fugro Roames (c)');
    H5Acreatestring(root_id, 'Creation Date', datestr(now));
else
    h5_fid = H5F.open(h5_ffn,'H5F_ACC_RDWR','H5P_DEFAULT');
end

%create group
group_name = num2str(group_number);
root_id    = H5G.open(h5_fid, '/', 'H5P_DEFAULT');
group_id   = H5G.create(root_id,group_name, 0, 0, 0);
%add data to group
data_names = fieldnames(data_struct);
for i=1:length(data_names)
    dataset = int16(round(data_struct.(data_names{i}).*r_scale));
    write_data(group_id,data_names{i},dataset);
end

%close h5 file
H5F.close(h5_fid);

%remove lock file
%delete(lock_ffn);


function H5Acreatestring(root_id, a_name, a_val)
%converts a matlab string into a C sting and writes to a H5 file as an att

a_val(length(a_val)+1)=setstr(0);
type_id  = H5T.copy('H5T_C_S1');
H5T.set_size(type_id, length(a_val));

space_id = H5S.create('H5S_SCALAR');
attr_id  = H5A.create(root_id, a_name, type_id, space_id, 'H5P_DEFAULT', 'H5P_DEFAULT');
H5A.write(attr_id, type_id, a_val);

function write_data(group_id,data_name,data)

%set compression
h5_size      = fliplr(size(data));
chunk_size   = h5_size;
deflate_scal = 9;

%setup data variable
dataspace_id = H5S.create_simple(length(h5_size), h5_size, h5_size);
plist        = H5P.create('H5P_DATASET_CREATE');
H5P.set_chunk(plist, chunk_size);
H5P.set_deflate(plist, deflate_scal);

%create data variable
dataset_id = H5D.create(group_id,data_name,'H5T_STD_I16LE',dataspace_id, 'H5P_DEFAULT', plist, 'H5P_DEFAULT');

%write data variable
H5D.write(dataset_id, 'H5T_STD_I16LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', data);
