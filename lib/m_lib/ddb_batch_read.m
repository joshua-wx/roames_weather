function json_fn = ddb_batch_read(ddb_tmp_struct,ddb_table,p_exp)
%WHAT: batch read for ddb using a list of index entried from temp_struct

%init filenames
json_fn        = tempname;
batch_json     = '';
ddb_items_list = fieldnames(ddb_tmp_struct);
%generate proection expression as required
if ~isempty(p_exp)
    p_exp = [',"ProjectionExpression":"',p_exp,'"',10];
end


%build read query string
for i=1:length(ddb_items_list)
    tmp_struct                 = ddb_tmp_struct.(ddb_items_list{i});
    batch_json                 = [batch_json,savejson('',tmp_struct)];
    if i~=length(ddb_items_list)
        batch_json = [batch_json,','];
    end
end
%wrap with necessary syntax
batch_json = ['{',10,...
    '"',ddb_table,'": {',10,...
    '"Keys": [',10,...
    batch_json,...
    ']',10,...
    p_exp,...
    '}',10,...
    '}'];
%pass command
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb batch-get-item --request-items ''',batch_json,''''];
%run extract
[sout,eout] = unix([cmd,' | tee ',json_fn,' &']);
%error catching
if sout ~= 0
    log_cmd_write('log.ddb','',cmd,eout)
    json_fn = '';
end
