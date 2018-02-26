function file_cp(src_ffn,dest_ffn,recursive_flag,background_flag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: copies a local/s3 files to a local/s3 location. Can recursively
% copy folder and run in the background. Note won't copy from s3 to s3
% INPUTS
% src_ffn: source full file path and name (str)
% dest_ffn: destination full file path and name (str)
% recursive_flag: flag for recursive copy (binary)
% background_flag: flag for background execution (binary)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%setup flags
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';
if recursive_flag == 1
    recur_str = '--recursive ';
else
    recur_str = '';
end
if background_flag == 1
    back_str = ' &';
else
    back_str = '';
end

%copy from s3 to local
if strcmp(src_ffn(1:2),'s3')
    %s3 command in foreground
    cmd         = [prefix_cmd,'aws s3 cp ',recur_str,src_ffn,' ',dest_ffn,back_str];
    [sout,eout] = unix(cmd);
    %log
    if sout~=0
        utility_log_write('tmp/log.cp',src_ffn,cmd,eout)
    end
elseif strcmp(dest_ffn(1:2),'s3') %copy from local to s3
    %s3 command in background
    cmd         = [prefix_cmd,'aws s3 cp --quiet ',recur_str,src_ffn,' ',dest_ffn,' >> tmp/log.cp 2>&1',back_str];
    [sout,eout] = unix(cmd);
else %copy local to local
    copyfile(src_ffn,dest_ffn)
end

    
