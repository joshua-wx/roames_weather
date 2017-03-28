function ddb_update(part_name,part_type,part_value,sort_name,sort_type,sort_value,update_name,update_type,update_value,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: updates a entry in ddb described by part and sort keys with update
% values
% INPUTS
% part_name:  name of partition key (str)
% part_type: variable type of parition key (1x char)
% part_value: value of partition key (str)
% sort_name:  name of sort key (str)
% sort_type: variable type of sort key (1x char)
% sort_value: value of sort key (str)
% update_name: name of attribute to update (str)
% update_type: type of attribute to update (str)
% update_value: values of attribute to update
% ddb_table: ddb table name (str)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%build expression
exp_json = ['{":update_att": {"',update_type,'":"',update_value,'"}}'];

%build struct to item key
ddb_struct                         = struct;
ddb_struct.(part_name).(part_type) = part_value;
ddb_struct.(sort_name).(sort_type) = sort_value;
%convert to strut
json                               = savejson('',ddb_struct);
%build command
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb update-item --table-name ',ddb_table,...
    ' --key ''',json,''' --update-expression "SET ',update_name,' = :update_att" --expression-attribute-values ''',exp_json,''''];

[sout,eout]       = unix([cmd,' >> tmp/log.ddb 2>&1 &']);
% if sout~=0
%     log_cmd_write('log.ddb','',cmd,eout)
% end
