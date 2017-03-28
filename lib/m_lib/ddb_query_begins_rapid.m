function temp_fn = ddb_query_begins_rapid(part_name,part_value,sort_name,sort_value,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: runs a ddb query using part and sort value (using begins with
% expression), returning ALL attributes
% INPUTS
% part_name:  name of partition key (str)
% part_value: value of partition key (str)
% sort_name:  name of sort key (str)
% sort_value: begins with expression (Str)
% p_exp: list of attributes to extract (str)
% ddb_table: ddb table name (str)
% RETURNS
% temp_fn: full file name containing json containing extract ddb items (str)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
temp_fn  = tempname;
exp_json = ['{":r_id": {"N":"',part_value,'"},',...
    '":sortVal": {"S":"',sort_value,'"}}'];
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id AND begins_with ( ',sort_name,', :sortVal )"',' ',...
    '--expression-attribute-values ''',exp_json,''''];
[sout,eout] = unix([cmd,' | tee ',temp_fn,' &']);
