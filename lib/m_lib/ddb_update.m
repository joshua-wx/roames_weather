function ddb_update(part_name,part_type,part_value,sort_name,sort_type,sort_value,update_name,update_type,update_value,ddb_table)
%queries ddb for items from radar_id between start and stop
%datestr. p_exp is a string of attriutes to return.

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end

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
