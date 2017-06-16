function jstruct = clean_jstruct(jstruct,n_fields)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: removed entries from a jstruct which do not have the correct number
% of fields (jstruct.item.fields). This issue is caused by corrupt writes
% to ddb or old data with extra fields.
% INPUTS
% jstruct: json represented as a struct containing n items with i
% fields (struct)
% n_fields: number of fields expected for each item (int)
% RETURNS
% jstruct: json struct with items removed that contained more than
% n_fields entries (Struct)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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