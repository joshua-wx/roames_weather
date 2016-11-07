function db_struct = db_delete(db_struct,row_idx)
%WHAT: removes a specified row from each field of db_struct

%list struct names
struct_fields = fieldnames(db_struct);

%loop through fields and delete the specified row
for i=1:length(struct_fields)
    db_struct.(struct_fields(i))(row_idx) = [];
end