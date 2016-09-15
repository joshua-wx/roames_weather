function index_write(dest_path,r_id,datetime,h5_fn)

%file path
date_vec   = datevec(datetime);
index_fn   = [num2str(r_id,'%02.0f'),'_',datestr(datetime,'yyyymmdd'),'.index'];
index_path = [dest_path,num2str(r_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
index_ffn  = [index_path,index_fn];

%lock file
lock_ffn = lock_file(index_fn);

%open/create file and read size
fid_write = fopen(index_ffn, 'at');

%write output
fprintf(fid_write,'%s\n',h5_fn);
fclose(fid_write);

%release lock
delete(lock_ffn);


    

