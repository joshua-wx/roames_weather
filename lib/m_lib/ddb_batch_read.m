function json_ffn = ddb_batch_read(ddb_tmp_struct,ddb_table,temp_path,p_exp)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: batch read for ddb using a list of index entries from ddb_tmp_struct
% INPUTS
% ddb_tmp_struct: structure contraining up to 25 items. each item has a key
% and sort index for extraction from dynamodb (struct)
% ddb_table: ddb table name (str)
% temp_path: directory to use for temp json file (str)
% p_exp: projected expression for fields to extract from ddb (str)
% RETURNS
% json_ffn: full filename of file which contains ddb extract json (cell
% array)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%init filenames
temp_ffn       = tempname;
[~,temp_fn,~]  = fileparts(temp_ffn);
json_ffn       = [temp_path,temp_fn];
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
[sout,eout] = unix([cmd,' | tee ',json_ffn,' &']);
%error catching
if sout ~= 0
    utility_log_write('log.ddb','',cmd,eout)
    json_ffn = '';
end
