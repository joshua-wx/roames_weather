function [ddb_struct,tmp_sz] = utility_addtostruct(ddb_struct,data_struct)

%init
data_name_list  = fieldnames(data_struct);
%name
item_name = ['item',num2str(length(fieldnames(ddb_struct))+1)];
for i = 1:length(data_name_list)
    %read from data_struct
    data_name  = data_name_list{i};
    data_type  = fieldnames(data_struct.(data_name)); data_type = data_type{1};
    data_value = data_struct.(data_name).(data_type);
    %add to ddb master struct
    ddb_struct.(item_name).(data_name).(data_type) = data_value;
end
%check size
tmp_sz    = length(fieldnames(ddb_struct));