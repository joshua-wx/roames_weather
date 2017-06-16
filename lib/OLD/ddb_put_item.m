function ddb_put_item(ddb_struct,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: writes single item in ddb_struct to dynamodb
% INPUTS
% ddb_struct: struct containing a single json item (struct)
% ddb_table: ddb table name (str)
% RETURNS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%writes a ddb_struct to dynamodb
json        = savejson('',ddb_struct);
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb put-item --table-name ',ddb_table,' --item ''',json,''''];
[sout,eout] = unix([cmd,' >> tmp/log.ddb 2>&1 &']);

