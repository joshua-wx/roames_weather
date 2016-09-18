function repro_1

%type1: 1999->2014 .VOL.lz4
%processes for only one year

prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
restart_vars_fn  = 'restart_vars_1.mat';
config_fn        = 'config';
%read config
read_config(config_fn,[config_fn,'.mat']);
load([config_fn,'.mat']);

% dnum_start = datenum(date_start,'yyyy_mm_dd');
% dnum_stop  = datenum(date_stop,'yyyy_mm_dd');

s3_in = [s3_in,s3_year,'/vol/'];

if exist(restart_vars_fn,'file') ~= 2
    %generate file listing
    cmd          = [prefix_cmd,'aws s3 ls ',s3_in]
    [sout,eout]  = unix(cmd);
    if sout ~= 0
        msg = [cmd,' returned ',eout];
        write_log(s3_log_fn,'s3 list',msg)
        return
    end
    %clean list
    C = textscan(eout,'%*s %*s %*f %s'); rapic_list = C{1};
    %loop through list
    display([num2str(length(rapic_list)),' files in s3 folder ',s3_in]);
else
    %load rapic_list from file
    load(restart_vars_fn)
    rapic_list = pending_rapic_list;
    %loop through list
    display(['restart detected, downloading',num2str(length(rapic_list)),' files in s3 folder ',s3_in]);
end
if exist('restart.flag','file') == 2
    delete('restart.flag')
end
kill_timer = tic;
kill_wait  = 60*60; %kill time in seconds

for j=1:length(rapic_list)
    %update pending list
    pending_rapic_list = rapic_list(j:end);
    %Kill function
    if toc(kill_timer)>kill_wait    
        %save restart list
        save(restart_vars_fn,'pending_rapic_list')
        %update user
        disp(['@@@@@@@@@ s3_repro restarted at ',datestr(now)])
        %restart
        if ~isdeployed
            %not deployed method: trigger background restart command before
            %kill
            [~,~] = unix(['matlab -desktop -r "run ',pwd,'/s3_rapic_to_odimh5_type1.m" &'])
        else
            %deployed method: restart controlled by run_wv_process sh
            %script
            disp('is deployed - passing restart to run script kill existance')
            [sout,eout]=unix('touch restart.flag');
        end
        quit force
    end
    
    %filter files
    if length(rapic_list{j})~=28
        msg = ['skipping ',rapic_list{j},' short filename'];
        write_log(local_log_fn,'file filter',msg);
        continue
    end
    r_id_str = rapic_list{j}(10:11);
    r_id     = str2num(r_id_str);
%     r_date = datenum(rapic_list{j}(13:20),'yyyymmdd');
    if r_id<str2num(r_id_start)
        msg = ['skipping ',rapic_list{j},' r_id less than r_id_start']
        %write_log(local_log_fn,'file filter',msg);
        continue
    end
%     if r_date<dnum_start || r_date>dnum_stop
%         msg = ['skipping ',rapic_list{j},' r_date outside stop/start dates'];
%         write_log(local_log_fn,'file filter',msg);
%         continue
%     end
    %check if file is lz4
    if ~strcmp(rapic_list{j}(end-6:end),'VOL.lz4')
        msg = [rapic_list{j},' not lz4'];
        write_log(local_log_fn,'VOL.lz4 check',msg);
        continue
    end
    %copy locally
    local_lz4rapic_ffn = [tempdir,rapic_list{j}];
    cmd                = [prefix_cmd,'aws s3 cp ',s3_in,rapic_list{j},' ',local_lz4rapic_ffn]
    [sout,eout]        = unix(cmd);
    if exist(local_lz4rapic_ffn,'file') ~= 2
        msg = [cmd,' returned ',eout];
        write_log(s3_log_fn,'cp_s3->local',msg)
        delete(local_lz4rapic_ffn)
        continue
    end
    %lz4c -d
    local_rapic_ffn = local_lz4rapic_ffn(1:end-4);
    cmd             = [prefix_cmd, 'lz4c -df ',local_lz4rapic_ffn,' ',local_rapic_ffn]
    [sout,eout]     = unix(cmd);
    if sout ~= 0
        msg = [cmd,' returned ',eout];
        write_log(local_log_fn,'lz4c -df',msg)
        broken_file(local_lz4rapic_ffn,[s3_bvol,r_id_str,'/'])
        continue
    else
        delete(local_lz4rapic_ffn)
    end
    %break up VOL
    svol_path = tempdir;
    display('starting VOL breakup')
    svol_list = dailyVOL_to_VOL(local_rapic_ffn,svol_path,local_log_fn);
    %check break up VOLs
    if isempty(svol_list)
        msg = [local_rapic_ffn,' returned no single volumes'];
        write_log(local_log_fn,'DailyVol_to_Single_VOL',msg)
        delete(local_rapic_ffn)
    else
        delete(local_rapic_ffn)
    end
    %loop through single volume list
    display('looping through single vols')
    for k=1:length(svol_list)
        rapic_ffn = [svol_path,svol_list{k}];
        %check file exists
        if exist(rapic_ffn,'file')~=2
            msg = [rapic_ffn,' is missing, skipping'];
            write_log(local_log_fn,'CAPPI check',msg)
            continue
        end
        %check if file contains volume data
        svol_ffn_dir  = dir(rapic_ffn);
        svol_ffn_size = svol_ffn_dir.bytes/1000;
        if svol_ffn_size<20
            msg = [rapic_ffn,' is a CAPPI, skipping'];
            write_log(local_log_fn,'CAPPI check',msg)
            delete(rapic_ffn)
            continue
        end
        %convert to h5
        [~, h5_tag, ~] = fileparts(rapic_ffn);
        h5_fn  = [h5_tag,'.h5'];
        h5_ffn = [svol_path,h5_fn];
        eout   = rapic_to_odim_wrapper(rapic_ffn,svol_path,h5_fn);
        %conversion failure, copy to broken vol
        if exist(h5_ffn,'file') ~= 2
            write_log(local_log_fn,'odimh5 conversion failure',eout)
            broken_file(rapic_ffn,[s3_bvol,r_id_str,'/'])
            delete(rapic_ffn)
            continue
        end
        %create archive_path
        radar_id   = h5_tag(1:2);
        date_vec   = datevec(h5_tag(4:11),'yyyymmdd');
        s3_h5_path = [s3_out,radar_id,'/',num2str(date_vec(1)),'/',...
            num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
        %             %check if file exists on s3, if so, size
        %             cmd             = [prefix_cmd,'aws s3 ls ',s3_h5_path,h5_fn]
        %             [sout,eout]     = unix(cmd);
        %file does not exist
        %             if sout == 1
        cmd             = [prefix_cmd,'aws s3 cp ',h5_ffn,' ',s3_h5_path,h5_fn]
        [sout,eout]     = unix(cmd);
        if sout ~= 0
            msg = [cmd,' returned ',eout];
            write_log(s3_log_fn,'final cp to s3',msg)
            delete(rapic_ffn)
            delete(h5_ffn)
        else
            delete(rapic_ffn)
            delete(h5_ffn)
        end
        %             %compare file sizes
        %             elseif sout == 0
        %                 C = textscan(eout,'%*s %*s %f %s');
        %                 s3_size    = C{1};
        %                 local_size = dir(h5_ffn); local_size = local_size.bytes;
        %                 if local_size > s3_size
        %                     cmd             = [prefix_cmd,'aws s3 cp ',h5_ffn,' ',s3_h5_path,h5_fn]
        %                     [sout,eout]     = unix(cmd);
        %                     if sout ~= 0
        %                         msg = [cmd,' returned ',eout];
        %                         write_log(s3_log_fn,'final cp to s3',msg)
        %                     end
        %                 else
        %                     write_log(s3_log_fn,'same file size on s3','same file size on s3')
        %                 end
        %             end
    end
end
delete(restart_vars_fn)
display('processing finished!')

%log each error and pass file to brokenVOL archive
function write_log(log_fn,type,msg)
log_fid = fopen(log_fn,'a');
display(msg)
fprintf(log_fid,'%s %s %s\n',datestr(now),type,msg);
fclose(log_fid);

%move broken file
function broken_file(ffn,target_s3_path)
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

cmd = [prefix_cmd,'aws s3 cp ',ffn,' ',target_s3_path]
[sout,eout]        = unix(cmd);
if sout ~= 0
    msg = [cmd,' returned ',eout];
    write_log(s3_log_fn,'broken vol cp to s3',msg)
end
