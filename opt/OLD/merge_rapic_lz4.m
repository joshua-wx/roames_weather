function merge_rapic_lz4

source_folder='/media/meso/radar_data2/QLD_Archive_Processed/temp/'; %all in one folder

log={};
log_fn=['merge_rapic_lz4_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

source_ffn=getAllFiles(source_folder);
%source_size=[temp_dir.bytes]';
for i=1:length(source_ffn)
    disp(['processing ',num2str(i),' of ',num2str(length(source_ffn))]);
    target_source_ffn=source_ffn{i};
    target_source_info=dir(target_source_ffn); target_source_size=target_source_info.bytes; target_source_fn=target_source_info.name;
    target_year=target_source_ffn(end-15:end-12);

    if ~isreal(str2num(target_year))
        keyboard
    end
        
    if ~strcmp(target_source_ffn(end-2:end),'lz4')
        disp('NOT LZ4, skipped')
        continue
    end
    
    if str2num(target_year)>2010
        destination_folder='/media/meso/radar_data3/'; %must be in yearly folders less than 2010
    else
        destination_folder='/media/meso/radar_data1/'; %must be in yearly folders less than 2010
    end
    
    destination_path=[destination_folder,target_year,'/vol/',target_source_fn];
    
    if exist(destination_path,'file')==2
        temp_dir=dir(destination_path);
        dest_size=temp_dir.bytes;
        if target_source_size>=dest_size
            %source is larger than dest. New source file is needed
            movefile(target_source_ffn,destination_path);
            log=[log;{target_source_ffn,'overwritten'}];
            disp([target_source_ffn,'........overwritten']);
        else
            %source is smaller than dest. Remove source as it's not
            %needed
            delete([target_source_ffn]);
            log=[log;{target_source_ffn,'deleted'}];
            disp([target_source_ffn,'........deleted']);
        end
    else
        %source is unique, movefile
        movefile(target_source_ffn,destination_path);
        log=[log;{target_source_ffn,'unique'}];
        disp([target_source_ffn,'........unique']);
    end
    save(log_fn,'log')
end
