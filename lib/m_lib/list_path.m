function [index_h5_fn,index_h5_ffn] = list_path(dest_path,r_id,datetime)

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';
index_h5_fn  = {};
index_h5_ffn = {};

%full path
date_vec = datevec(datetime);
sub_path  = [num2str(r_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
full_path = [dest_path,sub_path];

%switch s3/local
if strcmp(dest_path(1:2),'s3')
    %s3 command
    cmd         = [prefix_cmd,'aws s3 ls ',full_path];
    [sout,eout] = unix(cmd);
    if isempty(eout)
        return
    end
     %clean list
    C = textscan(eout,'%*s %*s %*f %s'); file_list = C{1};
else
    %local command
    dir_out = dir(full_path); dir_out(1:2) = [];
    file_list = dir_out.name;
    if isempty(file_list)
        return
    end
end

%build h5_fn
for i=1:length(file_list)
    if strcmp(file_list{i}(end-1:end),'h5') && length(file_list{i})==21
        index_h5_fn = [index_h5_fn;file_list{i}];
    end
end

%build ffn
rep_path     = repmat({full_path},length(index_h5_fn),1);
index_h5_ffn = strcat(rep_path,index_h5_fn);


    

