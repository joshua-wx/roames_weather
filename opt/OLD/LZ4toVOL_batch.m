function LZ4toVOL_batch

source_folder='/media/meso/radar_data1/2000/vol/'; %all in one folder
%list all files in source_folder
temp_dir=dir(source_folder); temp_dir(1)=[]; temp_dir(1)=[];
source_fn={temp_dir.name};
log={};

for i=1:length(source_fn)
    disp(['processing ',num2str(i),' of ',num2str(length(source_fn))]);
    target_fn_path=[source_folder,source_fn{i}];
    
    if ~strcmp(target_fn_path(end-2:end),'lz4')
       disp(['NOT A lz4: ',source_fn{i}])
       log=[log;{source_fn{i},'NOT A lz4'}];
       continue
    end
    
    cmd_text=['lz4c -d ',target_fn_path,' ',target_fn_path(1:end-4)];
    [status,cmdout]=system(cmd_text);
    if exist([target_fn_path(1:end-4)],'file')==2
        delete(target_fn_path)
        log=[log;{source_fn{i},'Success'}];
        disp('Success')
    else
        disp(['VOL fail: ',source_fn{i}])
        log=[log;{source_fn{i},'decompression Failed'}];
    end
end

date_str=datestr(now,'yymmdd_HHMM');
save(['log_file_LZ4toVOL_',date_str,'.mat'],'log')
