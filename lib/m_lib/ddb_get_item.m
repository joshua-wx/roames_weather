function jstruct_out = ddb_get_item(ddb_table,part_name,part_type,part_value,sort_name,sort_type,sort_value,p_exp)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: filters volumes in ddb and generates a list of their respective
% h5 ffn's (either storm or odim).
% INPUTS
% ddb_table: ddb table name (str)
% part_name: name of partition key (str)
% part_type: variable type of parition key (1x char)
% part_value: value of partition key (str)
% sort_name: name of sort key (str)
% sort_type: variable type of sort key (1x char)
% sort_value: value of sort key (str)
% p_exp: list of attributes to extract (str)
% RETURNS
% jstruct_out: json struct containing extract ddb items (struct)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%build struct to item key
ddb_struct                         = struct;
ddb_struct.(part_name).(part_type) = part_value;
ddb_struct.(sort_name).(sort_type) = sort_value;
temp_fn                            = tempname;

%convert to strut
json                               = savejson('',ddb_struct);
%build command
cmd                                = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb get-item --table-name ',ddb_table,' --key ''',json,''''];
%add att_list if present
if ~isempty(p_exp)
    cmd = [cmd,' --projection-expression ','"',p_exp,'"'];
end
%run script
[sout,eout]                        = unix([cmd,' | tee ',temp_fn]);
%catch errors and convert out json to struct
if sout ==0 && ~isempty(eout)
    %jstruct_out = loadjson(eout,'SimplifyCell',1,'FastArrayParser',1);
    jstruct_out = json_read(temp_fn);
elseif sout ==0 && isempty(eout)
    jstruct_out = [];
else
    utility_log_write('tmp/log.ddb','',cmd,eout)
    jstruct_out = [];
end
if exist(temp_fn,'file')==2
    delete(temp_fn)
end
    

