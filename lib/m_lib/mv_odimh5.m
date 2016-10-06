function mv_odimh5(src_ffn,dest_ffn)

prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

if strcmp(src_ffn(1:2),'s3')
    %s3 command
    cmd         = [prefix_cmd,'aws s3 mv --quiet ',src_ffn,' ',dest_ffn];
    [sout,eout] = unix(cmd);
    if isempty(eout)
        log_cmd_write('log.cp',src_ffn,cmd,eout)
    end
elseif strcmp(dest_ffn(1:2),'s3')
    %s3 command
    cmd         = [prefix_cmd,'aws s3 mv --quiet ',src_ffn,' ',dest_ffn,' >> log.cp 2>&1 &'];
    [sout,eout] = unix(cmd);
%     if isempty(eout)
%         log_cmd_write('log.cp_file',src_ffn,cmd,eout)
%     end
else
    movefile(src_ffn,dest_ffn)
end