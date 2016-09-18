function RemoveVOLHeaders



%set path
%archive_path='/media/meso/radar_data2/QLD_Archive/QLD_ARCHIVE/2000/';
archive_path='/home/meso/Desktop/test/';
%get file list
filelist = getAllFiles(archive_path);

%convert to daily VOL
for i=1:length(filelist)
    target_ffn = filelist{i};
    disp(['Processing file ',num2str(i),' of ',num2str(length(filelist)),' : ',target_ffn])
    %fileparts
    [target_path, target_fn, target_ext] = fileparts(target_ffn);
    if ~strcmp(target_ext,'.VOL')
        continue
        %not a vol file
    end
    
    fid = fopen(target_ffn);
    tline = fgets(fid);
    temp_text=[];
    while ischar(tline)
        if strcmp(tline(1:7),'COUNTRY')
            temp_text=[temp_text,tline];
        end
        tline = fgets(fid);
    end
    fclose(fid);
    fid = fopen(target_ffn,'w');
    fprintf(fid,'%s',temp_text);
    fclose(fid);
end

disp('daily converison and archiving complete')
