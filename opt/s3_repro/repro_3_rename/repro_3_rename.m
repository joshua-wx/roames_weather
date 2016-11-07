function repro_3_rename

if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib')
    addpath('/home/meso/Dropbox/dev/wv/etc')
end

%type3: VOL (but no ext) or .gz
%processes for one folder
prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
restart_vars_fn  = 'restart_vars.mat';
config_fn        = 'config';
%read config
read_config(config_fn,[config_fn,'.mat']);
load([config_fn,'.mat']);
%read site info
read_site_info('site_info.txt');
load('tmp/site_info.txt.mat');

mkdir('tmp')

%convert dates
dnum_start = datenum(date_start,'yyyymmdd');
dnum_stop  = datenum(date_stop,'yyyymmdd');

for i=1:length(site_id_list)
    radar_id    = site_id_list(i);
    s3_path     = [s3_in,num2str(radar_id,'%02.0f'),'/',num2str(s3_year),'/'];
    cmd         = [prefix_cmd,'aws s3 ls ',s3_path,' --recursive'];
    [sout,eout] = unix(cmd);
    %read text
    if sout ~= 0
        msg = [cmd,' returned ',eout];
        write_log('log.ls','s3 listing',msg)
    end
    if isempty(eout)
        display(['no files for ',s3_path]);
        continue
    end
    C              = textscan(eout,'%*s %*s %u %s');
    h5_list        = C{2};
    for j = 1:length(h5_list)
        h5_ffn     = [s3_bucket,h5_list{j}];
        h5_fn_idx  = strfind(h5_ffn,'/');
        h5_path    = h5_ffn(1:h5_fn_idx(end));
        h5_fn      = h5_ffn(h5_fn_idx(end)+1:end);
        if strcmp(h5_fn(3),'_')
            display('file already renamed, skipping')
            continue
        end
        h5_date    = datenum(h5_fn(1:12),'yyyymmddHHMM');
        if h5_date<dnum_start || h5_date>dnum_stop
            msg = ['skipping ',h5_fn,' r_date outside stop/start dates'];
            continue
        end
        new_tag    = [num2str(radar_id,'%02.0f'),'_',datestr(h5_date,'yyyymmdd'),'_',datestr(h5_date,'HHMMSS'),'.h5'];
        new_ffn    = [h5_path,new_tag];
        cmd        = [prefix_cmd,'aws s3 mv ',h5_ffn,' ',new_ffn,' >> log.mv 2>&1 &']
        pause(0.3)
        [sout,eout] = unix(cmd);
%         if sout~= 0
%             msg = [cmd,' returned ',eout];
%             write_log('log.mv','file rename',msg)
%         end
    end
end

display('processing finished!')

%log each error and pass file to brokenVOL archive
function write_log(log_fn,type,msg)
log_fid = fopen(log_fn,'a');
display(msg)
fprintf(log_fid,'%s %s %s\n',datestr(now),type,msg);
fclose(log_fid);
