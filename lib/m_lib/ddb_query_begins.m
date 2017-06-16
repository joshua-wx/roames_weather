function jstruct = ddb_query_begins(part_name,part_value,sort_name,sort_value,p_exp,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: runs a ddb query using part and sort value (using begins with expression), returning p_exp
% INPUTS
% part_name:  name of partition key (str)
% part_value: value of partition key (str)
% sort_name:  name of sort key (str)
% sort_value: begins with expression (Str)
% p_exp: list of attributes to extract (str)
% ddb_table: ddb table name (str)
% RETURNS
% jstruct: json struct containing extract ddb items (struct)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%build ddb query expression
temp_fn  = tempname;
exp_json = ['{":r_id": {"N":"',part_value,'"},',...
    '":sortVal": {"S":"',sort_value,'"}}'];
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id AND begins_with ( ',sort_name,', :sortVal )"',' ',...
    '--expression-attribute-values ''',exp_json,'''',' ',...
    '--projection-expression "',p_exp,'"'];
%run query
[sout,eout]       = unix([cmd,' | tee ',temp_fn]);
%output to logs
if sout~=0 || isempty(eout)
    utility_log_write('tmp/log.ddb','',cmd,eout)
    jstruct = '';
    return
end
%convert json to struct
%jstruct    = loadjson('tmp/eout.json','SimplifyCell',1,'FastArrayParser',1);
jstruct    = json_read(temp_fn);
if ~isempty(jstruct)
    jstruct = jstruct.Items;
end
if exist(temp_fn,'file')==2
    delete(temp_fn)
end
