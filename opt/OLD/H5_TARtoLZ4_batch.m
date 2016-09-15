function H5_TARtoLZ4_batch

source_folder='/media/meso/radar_data3_QLD/proced_fill_QLD/1998/'; %all in one folder
%list all files in source_folder
source_ffn = getAllFiles(source_folder);
log={};

for i=1:length(source_ffn)
    disp(['processing ',num2str(i),' of ',num2str(length(source_ffn))]);
    target_fn_path=source_ffn{i};
    
    if ~strcmp(target_fn_path(end-5:end),{'h5.tar'})
       disp(['NOT A h5.tar: ',source_ffn{i}])
       log=[log;{source_ffn{i},'NOT A h5.tar'}];
       continue
    end
    
    cmd_text=['lz4c -hc -y ',target_fn_path,' ',target_fn_path,'.lz4'];
    [status,cmdout]=system(cmd_text);
    if exist([target_fn_path,'.lz4'],'file')==2
        delete(target_fn_path)
        log=[log;{source_ffn{i},'Success'}];
        disp('Success')
    else
        disp(['LZ4 fail: ',source_ffn{i}])
        log=[log;{source_ffn{i},'LZ$ Failed'}];
    end
end

%date_str=datestr(now,'yymmdd_HHMM');
%save(['log_file_VOLtoLZ4_',date_str,'.mat'],'log')