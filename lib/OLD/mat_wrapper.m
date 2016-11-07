function out = mat_wrapper(mat_path,struct_name,struct_data,append_flag)
%WHAT:
%Reads or writes the mat file on mat_path containing variable struct_name.
%If struct_data is supplied, a write operation is performed. write flag
%files protect parallel processes

%INPUT:
%mat_path: path to mat file
%struct_name: name of variable in struct file
%struct_data: data to write to struct file

%OUTPUT
%out: if reading, struct variable

if nargin<4
    append_flag=0;
end


complete=0;
%loop until operation is performed
while complete==0
    %set flag file path
    flag_path=[mat_path,'.flag'];
    %if flag file doesn't exist
    if exist(flag_path,'file')~=2
        %create flag file confirm flag file exists
        while true
            %create flag file
            fid = fopen(flag_path, 'w'); fprintf(fid, '%s', ''); fclose(fid);
            if exist(flag_path,'file')==2
               break
            end
            disp(['Flag file not creating for ',mat_path]);
            pause(.1)
        end
        %read operation
        if nargin==2
            try
                load(mat_path,struct_name);
                eval(['out=',struct_name,';']);
                complete=1;
            catch
                 disp(['file read error for ',mat_path]);
                 delete(flag_path);
            end
        %write operation
        elseif nargin>2
            try
                eval([struct_name,'=struct_data;']);
                if append_flag==0
                    save(mat_path,struct_name);
                else
                    save(mat_path,struct_name,'-append');
                end
                out=[];
                complete=1;
            catch
                disp(['file write error for ',mat_path]);
                delete(flag_path);
            end
        end
        %delete flag path if operation is completed
        while true && complete==1
            delete(flag_path);
            if exist(flag_path,'file')~=2
                break
            end
            disp(['Flag file not removing for ',mat_path]);
            pause(.1)
        end
    else
        disp(['Flag file still exists for ',mat_path]);
        pause(.1)
    end
    if complete==0
     disp('looping')
    end
end

