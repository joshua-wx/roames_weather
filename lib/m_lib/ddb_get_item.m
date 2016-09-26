function jstruct_out = ddb_get_item(ddb_table,radar_id,start_timestamp)

if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
end

ddb_struct                      = struct;
ddb_struct.radar_id.N           = num2str(radar_id);
ddb_struct.start_timestamp.S    = datestr(start_timestamp,'yyyy-mm-ddTHH:MM:SS');
json                            = savejson('',ddb_struct);
cmd                             = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb get-item --table-name ',ddb_table,' --key ''',json,''''];
[sout,eout]                     = unix(cmd);
if sout ==0 && ~isempty(eout)
    jstruct_out = loadjson(eout,'SimplifyCell',1);
elseif sout ==0 && isempty(eout)
    jstruct_out = [];
else
    log_cmd_write('log.ddb',test_h5_fn,cmd,eout)
    jstruct_out = [];
end
    

