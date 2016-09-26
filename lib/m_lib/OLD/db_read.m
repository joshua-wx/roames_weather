function db_struct = db_read(db_fn,db_path)
%WHAT: reads a wv database files in a struct array from db_ffn text file
%db_ffn header contains field names (1 line)

%build ffn
db_ffn = [db_path,db_fn];

%return empty struct if missing
if exist(db_ffn,'file')~=2
    display(['database file missing: ',db_ffn])
    db_struct  = struct;
    return
end

%lock file
lock_ffn = lock_file(db_fn);

%open file
db_read_fid = fopen(db_ffn,'r');

%read database header
header_line = fgetl(db_read_fid);
field_names = textscan(header_line,'%s','Delimiter',','); field_names = field_names{1};

%read database
fmt_spec = repmat('%f',1,length(field_names));
db_raw   = textscan(db_read_fid,fmt_spec,'Delimiter',',','HeaderLines',1);

%build struct
db_struct = struct;
for i=1:length(field_names)
    db_struct.(field_names{i}) = db_raw{i};
end

%delete lockfile
delete(lock_ffn)


