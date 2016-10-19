function file_rm(delete_ffn,recursive_flag)

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';
if recursive_flag == 1
    recur_str = '--recursive ';
else
    recur_str = '';
end

if strcmp(delete_ffn(1:2),'s3')
    %s3 command in background
    cmd         = [prefix_cmd,'aws s3 rm --quiet ',recur_str,delete_ffn,' >> tmp/log.rm 2>&1 &'];
    [sout,eout] = unix(cmd);
else
    delete(delete_ffn)
end

    
