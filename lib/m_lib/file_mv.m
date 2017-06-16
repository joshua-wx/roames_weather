function file_mv(src_ffn,dest_ffn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: moves a local/s3 files to a local/s3 location. Note won't copy from
% s3 to s3 and will not run in background
% INPUTS
% src_ffn: source full file path and name (str)
% dest_ffn: destination full file path and name (str)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%setup prefilx
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

if strcmp(src_ffn(1:2),'s3') %move from s3 to local
    %s3 command
    cmd         = [prefix_cmd,'aws s3 mv --quiet ',src_ffn,' ',dest_ffn];
    [sout,eout] = unix(cmd);
    if isempty(eout)
        utility_log_write('tmp/log.mv',src_ffn,cmd,eout)
    end
elseif strcmp(dest_ffn(1:2),'s3') %move local to s3
    %s3 command
    cmd         = [prefix_cmd,'aws s3 mv --quiet ',src_ffn,' ',dest_ffn,' >> tmp/log.mv 2>&1 &'];
    [sout,eout] = unix(cmd);
%     if isempty(eout)
%         utility_log_write('log.cp_file',src_ffn,cmd,eout)
%     end
else %move local to local
    movefile(src_ffn,dest_ffn)
end