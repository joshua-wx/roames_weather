function jstruct = ddb_query(part_name,part_value,sort_name,sort_start,sort_stop,p_exp,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: runs a ddb query using part and sort values (equality), returning p_exp
% INPUTS
% part_name:  name of partition key (str)
% part_value: value of partition key (str)
% sort_name:  name of sort key (str)
% sort_start: start time for sort var (ddb tfmt str)
% sort_stop:  stop time for sort var (ddb tfmt str)
% p_exp: list of attributes to extract (str)
% ddb_table: ddb table name (str)
% RETURNS
% jstruct: json struct containing extract ddb items (struct)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%build ddb query expression
temp_fn  = tempname;
exp_json = ['{":r_id": {"N":"',part_value,'"},',...
    '":startTs": {"S":"',sort_start,'"},',...
    '":stopTs": {"S":"',sort_stop,'"}}'];
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id AND ',sort_name,' BETWEEN :startTs AND :stopTs"',' ',...
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
%read json str from file
jstruct    = json_read(temp_fn);
if ~isempty(jstruct)
    jstruct = jstruct.Items;
end
if exist(temp_fn,'file')==2
    delete(temp_fn)
end
