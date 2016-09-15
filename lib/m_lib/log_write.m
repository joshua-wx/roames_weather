function log_write(file_name,path,td,radar_id,source_module,message)

%formatting of timedate string
td_format='HH:MM_dd-mm-yy';

%file path
file_path=[path,file_name];

%open/create file and read size
fid = fopen(file_path, 'at');

%write output
fprintf(fid,'%s\n',[datestr(now,td_format),' ',num2str(radar_id),' ',datestr(td,td_format),' ',source_module,' ',message]);
fclose(fid);

    

