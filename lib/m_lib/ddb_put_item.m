function ddb_put_item(ddb_struct,ddb_table)
%writes a ddb_struct to dynamodb

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end

json        = savejson('',ddb_struct);
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb put-item --table-name ',ddb_table,' --item ''',json,''''];
[sout,eout] = unix([cmd,' >> log.ddb 2>&1 &']);
% if sout ~=0
%     log_cmd_write('log.ddb','',cmd,eout)
% end
