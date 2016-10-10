function lock_ffn = lock_file(in_fn)

%create file flag in tempdir
lock_part1      = tempname; lock_part1 = lock_part1(6:end);
lock_part2      = ['.',in_fn,'.wv_lockfile'];
lock_fn         = [lock_part1,lock_part2];
lock_ffn        = [tempdir,lock_fn];
system(['touch ',lock_ffn]);
%list tempdir wv_lockfile
dir_out         = dir([tempdir,'*',lock_part2]);
lock_list       = {dir_out.name};
%remove ltask_name from task_list
ind             = ismember(lock_list,lock_fn);
wait_list       = lock_list(~ind);

%wait until previous tasks have cleared
lock_check_out = 0;

while ~isempty(wait_list)
    disp(['lockfile in queue of length ',num2str(length(wait_list))])
    %hold loop
    pause(0.1)
    %clear lock list if past certain time
    if lock_check_out > 30
        disp('removing old lockfiles')
        for i=1:length(wait_list)
            delete([tempdir,wait_list{i}])
        end
    end
    lock_check_out = lock_check_out + 1;
    %check temp dir lockfiles
    dir_out   = dir([tempdir,'*',lock_part2]);
    tmp_list  = {dir_out.name};
    ind       = ismember(wait_list,tmp_list);
    %remove missing items from wait list
    wait_list = wait_list(ind);
end
