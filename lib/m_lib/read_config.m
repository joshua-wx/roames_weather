function read_config(config_input_path)
%WHAT
%Imports a config file of a standard format and saves the varibles it
%describes in a mat file. Varbles which contain no '_' are converted to
%numbers. % is the comment character, multiple spaces are the delimiters

%INPUT
%config_path: path to config ASCII file.
%mat_output_path: path to write config file to
    
%OUTPUT
%config mat file

mat_output_path = [config_input_path,'.mat'];

%% SOFTWARE CONFIG FILE    

%reomve existing mat file
if exist(mat_output_path,'file')
    delete(mat_output_path)
end

%Create file ID    
fid=fopen(config_input_path);
%Read ASCII file into cell array columns
config_out = textscan(fid, '%s %s','CommentStyle','%','MultipleDelimsAsOne',true);
%Close file
fclose(fid);

%Loop through each row
for i=1:length(config_out{1})
    %read variable name and value
    var_name=config_out{1}{i};
    var_value=config_out{2}{i};
    %check variable type and convert if number
    if and(isempty(strfind(var_value,'_')),sum(isletter(var_value))==0) || strcmp(var_value,'NaN') %convert string to number/NaN
        var_value=str2num(var_value);
    end
    %set string to be the variable name for that variable
    [~] = evalc([var_name '= var_value']);
    %save and append to mat file using append command if i~=1
    if i==1
        save(mat_output_path,var_name);
    else
        save(mat_output_path,var_name, '-append');
    end
end
