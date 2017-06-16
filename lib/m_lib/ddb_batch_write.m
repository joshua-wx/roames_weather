function ddb_batch_write(ddb_tmp_struct,ddb_table,background)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: batch write for ddb using a structure of items in ddb_tmp_struct
% INPUTS
% ddb_tmp_struct: structure contraining up to 25 items. each item has a key
% and sort index and attributed
% ddb_table: ddb table name (str)
% background: flag for running process in background (binary)
% RETURNS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%init items list and json
batch_json  = '';
ddb_items_list = fieldnames(ddb_tmp_struct);

if background==1
    back_cmd = ' &';
else
    back_cmd = '';
end
%loop through items list and generate request json
for i=1:length(ddb_items_list)
    tmp_struct                 = struct;
    tmp_struct.PutRequest.Item = ddb_tmp_struct.(ddb_items_list{i});
    batch_json                 = [batch_json,savejson('',tmp_struct)];
    if i~=length(ddb_items_list)
        batch_json = [batch_json,','];
    end
end
%run ddb write request
batch_json  = ['{"',ddb_table,'": [',batch_json,']}'];
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb batch-write-item --request-items ''',batch_json,''''];
[sout,eout] = unix([cmd,' >> tmp/log.ddb 2>&1',back_cmd]);
%write to log
if eout ~= 0
    utility_log_write('log.ddb','',cmd,eout)
end