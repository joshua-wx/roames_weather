function temp_repro_2

%type1: 2015_201606 .tar.lz4 single vols
%processes for only one year

prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
restart_vars_fn  = 'restart_vars.mat';
config_fn        = 'config';
%read config
read_config(config_fn,[config_fn,'.mat']);
load([config_fn,'.mat']);

mkdir('tmp')
local_path = '/home/meso/Downloads/20090207/';
svol_dir   = dir(local_path); svol_dir(1:2) = [];
svol_list  = {svol_dir.name};
r_id_str   = '02';

    display('looping through single vols')
    for k=1:length(svol_list)
        rapic_ffn = [local_path,svol_list{k}];
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
        h5_date = h5_tag(1:8);
        h5_time = [h5_tag(9:12),'00'];
        
        h5_fn  = [r_id_str,'_',h5_date,'_',h5_time,'.h5'];
        h5_ffn = [tempdir,h5_fn];
        eout   = rapic_to_odim_wrapper(rapic_ffn,tempdir,h5_fn);
        %conversion failure, copy to broken vol
        if exist(h5_ffn,'file') ~= 2
            write_log(local_log_fn,'odimh5 conversion failure',eout)
            broken_file(rapic_ffn,[s3_bvol,r_id_str,'/'])
            continue
        end
        %create archive_path
        date_vec   = datevec(h5_tag(1:8),'yyyymmdd');
        s3_h5_path = [s3_out,r_id_str,'/',num2str(date_vec(1)),'/',...
            num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
        cmd             = [prefix_cmd,'aws s3 mv ',h5_ffn,' ',s3_h5_path,h5_fn,' >> tmp/log.mv 2>&1 &']
        [sout,eout]     = unix(cmd);
        delete(rapic_ffn)
    end
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

cmd = [prefix_cmd,'aws s3 mv ',ffn,' ',target_s3_path,' >> tmp/log.mv 2>&1 &']
[sout,eout]        = unix(cmd);

