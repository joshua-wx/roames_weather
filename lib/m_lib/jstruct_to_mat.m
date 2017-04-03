function out = jstruct_to_mat(jstruct,type)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: converts jstruct item into a matlab cell array (strings) or double array (numbers)
% INPUTS
% jstruct: struct item name.type.data (struct)
% type:    type, either 'S' for string or 'N' for number
% RETURNS
% out: matlab cell array (cell) for type 'S' or matlab double array
% (double) for type 'N'
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(type,'S')
    out = {jstruct.S}';
else
    out = cellfun(@str2num,{jstruct.N})';
end