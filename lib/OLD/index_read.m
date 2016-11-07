function [index_h5_fn,index_h5_ffn] = index_read(dest_path,r_id,datetime)

%file path
date_vec = datevec(datetime);

index_fn   = [num2str(r_id,'%02.0f'),'_',datestr(datetime,'yyyymmdd'),'.index'];
index_path = [dest_path,num2str(r_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
index_ffn  = [index_path,index_fn];

%abort if file is missing
if exist(index_ffn,'file')~=2
    display(['odimh5 index file missing: ',index_ffn])
    index_h5_fn  = {};
    index_h5_ffn = {};
    return
end

%lock file
lock_ffn = lock_file(index_fn);

%open/create file and read size
fid_read = fopen(index_ffn,'r');

%read index
index_h5_fn = textscan(fid_read,'%s'); index_h5_fn=index_h5_fn{1};
fclose(fid_read);

%build ffn
tmp_path  = repmat({index_path},length(index_h5_fn),1);
index_h5_ffn = strcat(tmp_path,index_h5_fn);

%release lock
delete(lock_ffn);


    

