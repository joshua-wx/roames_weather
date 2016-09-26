function out = jstruct_to_mat(jstruct,type)
%WHAT: converts jstruct to a matlab cell array (Strings) or array (numbers)

if strcmp(type,'S')
    out = {jstruct.S}';
else
    out = str2num(vertcat(jstruct.N));
end