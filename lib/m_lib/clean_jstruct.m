function jstruct = clean_jstruct(jstruct,n_fields)       
%WHAT: removed entries from a jstruct which do not have the corrupt number
%of field

if ~iscell(jstruct)
    return
end

for j=1:length(jstruct)
    if length(fieldnames(jstruct{j})) ~= n_fields
        jstruct{j}=[];
    end
end
jstruct = [jstruct{:}];