function jstruct = ddb_query(part_name,part_value,sort_name,sort_start,sort_stop,p_exp,ddb_table)
%queries ddb for items from radar_id between start and stop
%datestr. p_exp is a string of attriutes to return.

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end


exp_json = ['{":r_id": {"N":"',part_value,'"},',...
    '":startTs": {"S":"',sort_start,'"},',...
    '":stopTs": {"S":"',sort_stop,'"}}'];
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id AND ',sort_name,' BETWEEN :startTs AND :stopTs"',' ',...
    '--expression-attribute-values ''',exp_json,'''',' ',...
    '--projection-expression "',p_exp,'"'];
[sout,eout]       = unix([cmd,' | tee /tmp/eout.json']);
if sout~=0 || isempty(eout)
    log_cmd_write('tmp/log.ddb','',cmd,eout)
    jstruct = '';
    return
end
%convert json to struct
%jstruct    = loadjson('tmp/eout.json','SimplifyCell',1,'FastArrayParser',1);
try
jstruct    = json_read('/tmp/eout.json');
if ~isempty(jstruct)
    jstruct = jstruct.Items;
end
catch
    keyboard
end
