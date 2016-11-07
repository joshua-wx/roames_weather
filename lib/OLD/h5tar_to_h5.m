function h5_ffn_list=h5tar_to_h5(h5tar_ffn)
%WHAT: attempts to convert rapic file into hdf5 file

%INPUT: target file path
%OUTPUT: h5 temp file path

%create temp dir and remove old h5 files
temp_path=[tempdir,'tarh52h5/'];
if exist(temp_path,'file')==7
    delete([temp_path,'*']);
else
    mkdir(temp_path);
end

%untar
untar(h5tar_ffn,temp_path)

%remove temp files
delete([temp_path,'*.tar']);
delete([temp_path,'*.log']);

%get list of h5 ffn
h5_ffn_list=getAllFiles(temp_path);

