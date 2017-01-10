function file_s3sync(src_root,dest_folder,timestamp,radar_id)

%init vars
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';
date_vec     = datevec(timestamp);

%build command
src_path     = [src_root,num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f')];
cmd          = ['export LD_LIBRARY_PATH=/usr/lib; aws s3 sync ',src_path,' ',dest_folder];

%run command
[sout,eout] = unix(cmd);
%write error as needed
if isempty(eout)
    log_cmd_write('tmp/log.sync',src_path,cmd,eout)
end