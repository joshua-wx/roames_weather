function cp_odimh5(src_h5_ffn,dest_h5_ffn)

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

if strcmp(src_h5_ffn(1:2),'s3')
    %s3 command
    cmd         = [prefix_cmd,'aws s3 cp ',src_h5_ffn,' ',dest_h5_ffn];
    [sout,eout] = unix(cmd);
    if isempty(eout)
        log_cmd_write('log.cp_odimh5',src_h5_ffn,cmd,eout)
    end
else
    copyfile(src_h5_ffn,dest_h5_ffn)
end

