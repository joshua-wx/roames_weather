function out = mat_wrapper2(archive_flag,mat_path,struct_name,struct_data,append_flag)
%WHAT:
%Reads or writes the mat file on mat_path containing variable struct_name.
%If struct_data is supplied, a write operation is performed. lockfile
%ensure mat_wrapper2 has to wait until previous calls have been completed.

%INPUT:
%archive_flag: to set the class of lockfile
%mat_path: path to mat file
%struct_name: name of variable in struct file
%struct_data: data to write to struct file
%append_flag: turn on write append

%OUTPUT
%out: if reading, struct variable

if nargin<5
    append_flag=0;
end

%create file flag in tempdir
task_name      = tempname;
task_ext       = ['.',archive_flag,'.wv_lockfile'];
task_fn        = [task_name(6:end),task_ext];
task_path      = [task_name,task_ext];
system(['touch ',task_path]);
%list tempdir wv_lockfile
dir_out        = dir([tempdir,'*',task_ext]);
task_list      = {dir_out.name};
%remove ltask_name from task_list
ind            = ismember(task_list,task_fn);
wait_task_list = task_list(~ind);
%wait until previous tasks have cleared
while ~isempty(wait_task_list)
    pause(.1);
    %check temp dir lockfiles
    dir_out        = dir([tempdir,'*',task_ext]);
    task_list      = {dir_out.name};
    ind            = ismember(wait_task_list,task_list);
    %update wait list
    wait_task_list = wait_task_list(ind);
    disp(['lockfile in que of length ',num2str(sum(ind))])
end

%perform task now clearance has been given

%read operation
if nargin==3
    try
        load(mat_path,struct_name);
        eval(['out=',struct_name,';']);
    catch err
        disp(['file read error for ',mat_path]);
        out = [];
    end
    %write operation
elseif nargin>3
    try
        eval([struct_name,'=struct_data;']);
        if append_flag==0
            save(mat_path,struct_name);
        else
            save(mat_path,struct_name,'-append');
        end
    catch err
        disp(['file write error for ',mat_path]);
        out = [];
    end
end
%delete flag path if operation is completed
while true
    delete(task_path);
    if exist(task_path,'file')~=2
        break
    end
    disp(['task file file not removing for ',mat_path]);
    pause(.1)
end



