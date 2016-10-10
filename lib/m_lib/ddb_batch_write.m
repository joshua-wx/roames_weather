function ddb_batch_write(ddb_tmp_struct,ddb_table,background)

batch_json  = '';
ddb_items_list = fieldnames(ddb_tmp_struct);

if background==1
    back_cmd = ' &';
else
    back_cmd = '';
end

for i=1:length(ddb_items_list)
    tmp_struct                 = struct;
    tmp_struct.PutRequest.Item = ddb_tmp_struct.(ddb_items_list{i});
    batch_json                 = [batch_json,savejson('',tmp_struct)];
    if i~=length(ddb_items_list)
        batch_json = [batch_json,','];
    end
end
batch_json  = ['{"',ddb_table,'": [',batch_json,']}'];
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb batch-write-item --request-items ''',batch_json,''''];
[sout,eout] = unix([cmd,' >> tmp/log.ddb 2>&1',back_cmd]);
% if sout ~=0
%     log_cmd_write('log.ddb','',cmd,eout)
% end