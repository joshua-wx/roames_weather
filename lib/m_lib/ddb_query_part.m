function jstruct = ddb_query_part(part_name,part_value,part_type,p_exp,ddb_table)
%queries ddb for items from radar_id between start and stop
%datestr. p_exp is a string of attriutes to return.

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end

temp_fn  = tempname;
exp_json = ['{":r_id": {"',part_type,'":"',part_value,'"}}'];
cmd      = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id"',' ',...
    '--expression-attribute-values ''',exp_json,'''',' ',...
    '--projection-expression "',p_exp,'"'];
[sout,eout]       = unix([cmd,' | tee ',temp_fn]);
if sout~=0 || isempty(eout)
    log_cmd_write('tmp/log.ddb','',cmd,eout)
    jstruct = '';
    return
end
%convert json to struct
try
    jstruct    = json_read(temp_fn);
catch %catch for corrupt file
    jstruct = '';
end
if ~isempty(jstruct)
    jstruct = jstruct.Items;
end
if exist(temp_fn,'file')==2
    delete(temp_fn)
end
