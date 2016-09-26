function ind=find_db_ind(id,uniq_id_list,mode)
%WHAT: Mode(1): find the ind of each id element in uniq_id_list
%Mode(2): finds the ind(s) of each uniq_id_list element in id (COLLATED
%INTO A SINGLE LIST)

%INPUTS:
%ID: non-unique cell array of id strings
%LIST: unique cell array of id strings

%OUTPUTS:
%IND: depends on mode

%check for memebership of id in uniq_id_list
temp_ind=ismembc(id,uniq_id_list);


if mode==1
    %mode1: find ind of each id element in uniq_id_list
    
    %remove entries from input list (track) which are missing from uniq list
    %(ident) CAUSE OF THIS PROBLEM IS UNKNOWN.
    temp_ind=temp_ind(temp_ind>0);
    
    ind=temp_ind;
elseif mode==2
    %mode2: find ind(s) of each uniq_id_list element in id (COLLATES INTO A
    %SINGLE LIST (ind)
    ind=[];
    for i=1:length(uniq_id_list)
        ind=[ind;find(temp_ind==i)];
    end
end
    