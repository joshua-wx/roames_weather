function db_write(db_fn,db_path,db_struct)
%WHAT: Writes a database struct to db_fn where the fieldnames are the
%headers. All entries are signed int32

%build ffn
db_ffn = [db_path,db_fn];

%lock file
lock_ffn = lock_file(db_fn);

%open file
db_read_fid = fopen(db_ffn,'w'); %open to write and discard

%list struct fields
header = fieldnames(db_struct);

%create database text
tmp_db = struct2cell(db_struct)';
tmp_db = int32(cell2mat(tmp_db));

%write to file
h_fmt  = repmat('%s,',1,length(header)); h_fmt(end)  = []; h_fmt  = [h_fmt,'\n'];
db_fmt = repmat('%d,',1,length(header)); db_fmt(end) = []; db_fmt = [db_fmt,'\n'];
fprintf(db_read_fid,h_fmt,header{:});
fprintf(db_read_fid,db_fmt,tmp_db);

%delete lockfile
delete(lock_ffn)

