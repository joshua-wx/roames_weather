function repro_3

%type3: VOL (but no ext) or .gz
%processes for one folder

prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
restart_vars_fn  = 'restart_vars.mat';
config_fn        = 'config';
odimh5_ddb_table = 'wxradar-odimh5-index';
%read config
read_config(config_fn,[config_fn,'.mat']);
load([config_fn,'.mat']);

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
    
    %copy locally
    local_rapic_ffn = [tempdir,rapic_list{j}];
    if isempty(rapic_list{j})
        continue
    end
    cmd                = [prefix_cmd,'aws s3 cp ',s3_in,rapic_list{j},' ',local_rapic_ffn]
    [sout,eout]        = unix(cmd);
    if exist(local_rapic_ffn,'file') ~= 2
        msg = [cmd,' returned ',eout];
        write_log('log.s3','cp_s3->local',msg)
        delete(local_rapic_ffn)
        continue
    end
    
   %check if file is gz
    if strcmp(rapic_list{j}(end-1:end),'gz')
        %run gunzip
        display('gunzip running on file')
        try
            gunzip(local_rapic_ffn,tempdir)
        catch
            msg = [local_rapic_ffn,' zip if broken'];
            write_log(local_log_fn,'gunzip',msg)
            continue
        end
        delete(local_rapic_ffn)
        local_rapic_ffn = local_rapic_ffn(1:end-3);
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
        %convert to h5
        [~, h5_tag, ~] = fileparts(rapic_ffn);
        radar_id       = h5_tag(1:2);
        date_num       = datenum(h5_tag(4:18),'yyyymmdd_HHMMSS');
        date_vec       = datevec(date_num);
        h5_fn  = [h5_tag,'.h5'];
        h5_ffn = [svol_path,h5_fn];
        eout   = rapic_to_odim_wrapper(rapic_ffn,svol_path,h5_fn);
        %conversion failure, copy to broken vol
        if exist(h5_ffn,'file') ~= 2
            write_log(local_log_fn,'odimh5 conversion failure',eout)
            broken_file(rapic_ffn,[s3_bvol,num2str(radar_id),'/'])
            delete(rapic_ffn)
            continue
        end
        %create archive_path
        s3_h5_path = [s3_out,radar_id,'/',num2str(date_vec(1)),'/',...
            num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
        
            cmd             = [prefix_cmd,'aws s3 cp ',h5_ffn,' ',s3_h5_path,h5_fn]
            [sout,eout]     = unix(cmd);
            if sout ~= 0
                msg = [cmd,' returned ',eout];
                write_log(s3_log_fn,'final cp to s3',msg)
            else
                display('h5 moved to s3 completed')
            end

        delete(rapic_ffn)
        delete(h5_ffn)
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
