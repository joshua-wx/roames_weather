function file_rm(delete_ffn,recursive_flag,background_flag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: deletes a local/s3 file. Can recursively
% delete folder and run in the background.
% INPUTS
% delete_ffn: source full file path and name (str)
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
    back_str = '&';
else
    back_str = '';
end

if strcmp(delete_ffn(1:2),'s3') %delete from s3
    %s3 command in background
    cmd         = [prefix_cmd,'aws s3 rm --quiet ',recur_str,delete_ffn,' >> tmp/log.rm 2>&1 ',back_str];
    [sout,eout] = unix(cmd);
else %delete from local
    if exist(delete_ffn,'file')==2 %delete file
        delete(delete_ffn)
    elseif exist(delete_ffn,'file')==7 %delete folder
        rmdir(delete_ffn,'s')
    end
end

    
