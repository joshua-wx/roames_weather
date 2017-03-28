function ddb_rm_item(ddb_struct,ddb_table)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: removes a single item from ddb described in ddb_struct
% INPUTS
% ddb_struct:  struct containing part and sort values for item to remove
% from ddb
% ddb_table: ddb table name (str)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%write json struct data file string in file
json        = savejson('',ddb_struct);
%run remove command
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb delete-item --table-name ',ddb_table,' --key ''',json,''''];
[sout,eout] = unix([cmd,' >> tmp/log.ddb 2>&1 &']);

