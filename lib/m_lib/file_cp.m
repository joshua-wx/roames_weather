function file_cp(src_ffn,dest_ffn,recursive_flag,background_flag)

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';
if recursive_flag == 1
    recur_str = '--recursive ';
else
    recur_str = '';
end
if background_flag == 1
    back_str = ' &';
else
    recur_str = '';
end
if strcmp(src_ffn(1:2),'s3')
    %s3 command in foreground
    cmd         = [prefix_cmd,'aws s3 cp ',recur_str,src_ffn,' ',dest_ffn,back_str];
    [sout,eout] = unix(cmd);
    if ~isempty(eout)
        log_cmd_write('tmp/log.cp',src_ffn,cmd,eout)
    end
elseif strcmp(dest_ffn(1:2),'s3')
    %s3 command in background
    cmd         = [prefix_cmd,'aws s3 cp --quiet ',recur_str,src_ffn,' ',dest_ffn,' >> tmp/log.cp 2>&1',back_str];
    [sout,eout] = unix(cmd);
else
    copyfile(src_ffn,dest_ffn)
end

    
