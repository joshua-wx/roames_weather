function h5_ffn_list=rapic2h5(target_file,file_fmt)
%WHAT: attempts to convert rapic file into hdf5 file

%INPUT: target file path
%OUTPUT: h5 temp file path

%create temp dir and remove old h5 files
temp_path=[tempdir,'rapic2h5/'];
if exist(temp_path,'file')==7
    delete([temp_path,'*']);
else
    mkdir(temp_path);
end

if strcmp(file_fmt,'historical')
    output_ffn=[temp_path,'temp.VOL'];
    command=['lz4c -d ',target_file,' ',output_ffn];
    [~,~]=system(command);
    target_file=output_ffn;
end
    

%Convert rapic to h5 using utilit
[~, fname, ~] = fileparts(target_file);
command=['export LD_LIBRARY_PATH=/usr/lib; cd ',temp_path,' && rapic_to_odim ',target_file,' ',fname,'.h5'];
[sout,eout]=unix(command);
if sout==1
    display(eout)
end

%remove temp files
delete([temp_path,'*.VOL']);
delete([temp_path,'*.log']);

%get list of h5 ffn
h5_ffn_list=getAllFiles(temp_path);

