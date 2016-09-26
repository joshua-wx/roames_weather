function merge_rapic

source_folder='/media/meso/radar_data3/additional/'; %all in one folder
destination_folder='/media/meso/radar_data1/'; %must be in yearly folders less than 2010
log={};
%list all files in source_folder
temp_dir=dir(source_folder); temp_dir(1)=[]; temp_dir(1)=[];

source_fn={temp_dir.name};
source_size=[temp_dir.bytes]';
for i=1:length(source_fn)
    disp(['processing ',num2str(i),' of ',num2str(length(source_fn))]);
    target_source_fn=source_fn{i};
    target_source_size=source_size(i);
    target_year=target_source_fn(end-11:end-8);
    
    if ~isreal(str2num(target_year))
        keyboard
    end
            
    if ~strcmp(target_source_fn(end-2:end),'VOL')
        disp('NOT VOL, skipped')
        continue
    end
    
    if str2num(target_year)>2010
        continue
        log=[log;{target_source_fn,'skipped... >2010'}];
        keyboard
    end
    
    destination_path=[destination_folder,target_year,'/vol/',target_source_fn];
    
    if exist(destination_path,'file')==2
        temp_dir=dir(destination_path);
        dest_size=temp_dir.bytes;
        if target_source_size>=dest_size
            %source is larger than dest. New source file is needed
            movefile([source_folder,target_source_fn],destination_path);
            log=[log;{target_source_fn,'overwritten'}];
            disp([target_source_fn,'........overwritten']);
        else
            %source is smaller than dest. Remove source as it's not
            %needed
            delete([source_folder,target_source_fn]);
            log=[log;{target_source_fn,'deleted'}];
            disp([target_source_fn,'........deleted']);
        end
    else
        %source is unique, movefile
        movefile([source_folder,target_source_fn],destination_path);
        log=[log;{target_source_fn,'unique'}];
        disp([target_source_fn,'........unique']);
    end
end

save('log_file_merge_rapic','log')
