function OLD_QLDarchive2sortedhdf5

%this program is written specifically for the messy rapic archive kept by
%brisbane. It removes the index files and converts the rapic files to hdf5
%scan files which are moved to a folder archive.

%set path
bad_archive_path='/media/meso/radar_data2/QLD_Archive/Finished_processing/2011_2012/';
good_archive_path='/media/meso/radar_data2/QLD_Archive/h5_archive/';
%get file list
filelist = getAllFiles(bad_archive_path);

%tmp dir path
tmp_dir='/tmp/qld_convert/';
%clean/make tmp dir
if exist(tmp_dir,'file')==7
    system(['rm -R ',tmp_dir]);
end
mkdir(tmp_dir);
%remove local h5 files
delete('*.h5');

corrupt_file_list={};

%check for index files
idx_ind=strfind(filelist, '.idx');
dat_ind=strfind(filelist, '.dat');
arch_ind=strfind(filelist, '.arch');
txt_ind=strfind(filelist, '.txt');

%remove index files from list
filter_mask=false(1,length(idx_ind));
for i=1:length(idx_ind)
    if isempty(idx_ind{i}) & isempty(dat_ind{i}) & isempty(arch_ind{i}) & isempty(txt_ind{i})
        filter_mask(i)=true; 
    end
end
filt_filelist=filelist(filter_mask);

%convert to hdf5
for i=1:length(filt_filelist)
    target_ffn=filt_filelist{i};
    disp(['Processing file ',num2str(i),' of ',num2str(length(filt_filelist)),' : ',target_ffn])
    %fileparts
    [~, target_fn, target_ext] = fileparts(target_ffn);
    %copy to temp directory
    copyfile(target_ffn,tmp_dir);
    %check zip type and unzip if required
    if strcmp(target_ext,'.gz')
        try
            gunzip([tmp_dir,target_fn,target_ext]);
        catch
            display(['Broken zip file ',target_ffn])
            continue
        end
        delete([tmp_dir,target_fn,target_ext]);   
    elseif strcmp(target_ext,'.bz2')
        try
            system(['bzip2 -d ',tmp_dir,target_fn,target_ext]);
        catch
            display(['Broken zip file ',target_ffn])
            continue
        end
    end
    %Convert rapic to h5 using utility
    command=['./rapic2ODIMH5 -rapicdb ',tmp_dir,target_fn];
    [~,~]=system(command);
    delete([tmp_dir,target_fn]);
    %read radar and date from filename
    struct = dir('*.h5');
    if isempty(struct)
        display('$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$conversion error')
    end
    h5_fn_list={struct.name};
    for j=1:length(h5_fn_list)
        target_h5_fn=h5_fn_list{j};
        h5_radar=target_h5_fn(13:end-3);
        h5_datevec=datevec(target_h5_fn,'yyyymmddHHMM');
        archive_dest=[good_archive_path,h5_radar,'/',num2str(h5_datevec(3)),'-',num2str(h5_datevec(2)),'-',num2str(h5_datevec(1)),'/'];
        if ~isdir(archive_dest)
            mkdir(archive_dest);
        end
        %copyfile(target_h5_fn,[archive_dest,target_h5_fn]);
        system(['cp ',target_h5_fn,' ',archive_dest,target_h5_fn]);
         if exist([archive_dest,target_h5_fn],'file')~=2
             corrupt_file_list=[corrupt_file_list;target_h5_fn];
         end
    end
    delete('*.h5')
end

disp('h5 converison and archiving complete')
save('corrupt_file_list.mat','corrupt_file_list')



function fileList = getAllFiles(dirName)
%WHAT:
%recursively loops through the directories below dirName and outputs all
%files in a list

%INPUT:
%dirname: directory path

%OUTPUT
%filelist: filename of all files below the directory path.

dirData = dir(dirName);      %# Get the data for the current directory
dirIndex = [dirData.isdir];  %# Find the index for directories
fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files
if ~isempty(fileList)
    fileList = cellfun(@(x) fullfile(dirName,x),...  %# Prepend path to files
        fileList,'UniformOutput',false);
end
subDirs = {dirData(dirIndex).name};  %# Get a list of the subdirectories
validIndex = ~ismember(subDirs,{'.','..'});  %# Find index of subdirectories
%#   that are not '.' or '..'
for iDir = find(validIndex)                  %# Loop over valid subdirectories
    nextDir = fullfile(dirName,subDirs{iDir});    %# Get the subdirectory path
    fileList = [fileList; getAllFiles(nextDir)];  %# Recursively call getAllFiles
end
