function temp_fn = ddb_query_begins_rapid(part_name,part_value,sort_name,sort_value,p_exp,ddb_table)
%queries ddb for items from radar_id begins with sort value
%p_exp is a string of attriutes to return all fields to temp_fn

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end

temp_fn  = tempname;
exp_json = ['{":r_id": {"N":"',part_value,'"},',...
    '":sortVal": {"S":"',sort_value,'"}}'];
cmd = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb query --table-name ',ddb_table,' ',...
    '--key-condition-expression "',part_name,' = :r_id AND begins_with ( ',sort_name,', :sortVal )"',' ',...
    '--expression-attribute-values ''',exp_json,''''];
[sout,eout] = unix([cmd,' | tee ',temp_fn,' &']);
