function jstruct_out = ddb_get_item(ddb_table,part_name,part_type,part_value,sort_name,sort_type,sort_value,att_list)
%WHAT: gets an items from a ddb table which has partition and sort key. The
%name, type and value of these two keys can be specified. Output is
%returned as a struct. Att_list can be specified to only retrived specific
%attributes

% if ~isdeployed
%     addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
%     addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
% end

%build struct to item key
ddb_struct                         = struct;
ddb_struct.(part_name).(part_type) = part_value;
ddb_struct.(sort_name).(sort_type) = sort_value;
%convert to strut
json                               = savejson('',ddb_struct);
%build command
cmd                                = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb get-item --table-name ',ddb_table,' --key ''',json,''''];
%add att_list if present
if ~isempty(att_list)
    cmd = [cmd,' --projection-expression ','"',att_list,'"'];
end
%run script
[sout,eout]                        = unix([cmd,' | tee /tmp/eout.json']);
%catch errors and convert out json to struct
if sout ==0 && ~isempty(eout)
    %jstruct_out = loadjson(eout,'SimplifyCell',1,'FastArrayParser',1);
    jstruct_out = json_read('/tmp/eout.json');
elseif sout ==0 && isempty(eout)
    jstruct_out = [];
else
    log_cmd_write('tmp/log.ddb','',cmd,eout)
    jstruct_out = [];
end
    

