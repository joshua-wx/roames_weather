function broken_vol_convert

%WHAT: for a radar id, run the odimh5 conversion utility on broken volumes
%and lists the error codes, grouping by most common error.

%init config
config_fn = 'convert.config';
read_config(config_fn,[config_fn,'.mat'])
load([config_fn,'.mat'])

%init vars
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
s3_odimh5_root = 's3://roames-wxradar-archive/odimh5_archive/broken_vols/';
s3_bucket      = 's3://roames-wxradar-archive/';
radar_id_str   = num2str(radar_id,'%02.0f');
s3_odimh5_path = [s3_odimh5_root,radar_id_str,'/'];
log_err_fn     = ['log.broken_convert_err_',num2str(radar_id,'%02.0f')];
log_stats_fn   = ['log.broken_convert_stats_',num2str(radar_id,'%02.0f')];

mkdir('tmp')
if ~isdeployed
    addpath('bin')
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
end

%ls s3 path
display(['s3 ls for broken_vols radar_id: ',radar_id_str])
cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path];
[sout,eout] = unix(cmd);
%read text
C             = textscan(eout,'%*s %*s %*u %s');
rapic_fn_list = C{1};

%bin into groups of 500
bin_count       = 0;
rapic_fn_groups = {};
tmp_group       = {};
for i=1:length(rapic_fn_list);
    tmp_group = [tmp_group;rapic_fn_list{i}];
    bin_count = bin_count+1;
    if bin_count == 500
        rapic_fn_groups = [rapic_fn_groups,{tmp_group}];
        bin_count       = 0;
        tmp_group       = {};
    elseif i==length(rapic_fn_list)
        rapic_fn_groups = [rapic_fn_groups,{tmp_group}];
    end
end
    
%download group to tmp folder
success_count = 0;
for i = 1:length(rapic_fn_groups)
    tmp_fn_list = rapic_fn_groups{i};
    for j = 1:length(tmp_fn_list)
        %update user
        display(['processing ',tmp_fn_list{j},' from group ',num2str(i),' of ',num2str(length(rapic_fn_groups))])
        %download file
        s3_rapic_ffn  = [s3_odimh5_path,tmp_fn_list{j}];
        tmp_rapic_ffn = [tempdir,tmp_fn_list{j}];
        cmd = [prefix_cmd,'aws s3 cp ',s3_rapic_ffn,' ',tmp_rapic_ffn];
        [~,~]   = unix(cmd);
        %run convert and log
        tmp_h5_ffn    = [tempname,'.h5'];
        [sout,eout]         = unix(['bin/rapic2ODIMH5_64bit ',tmp_rapic_ffn,' ',tmp_h5_ffn]);
        if exist(tmp_h5_ffn,'file') == 2
            try
                %read start timestamp from file
                start_date      = deblank(h5readatt(tmp_h5_ffn,['/dataset',num2str(1),'/what/'],'startdate'));
                start_time      = deblank(h5readatt(tmp_h5_ffn,['/dataset',num2str(1),'/what/'],'starttime'));
                start_timedate  = datenum([start_date,start_time(1:4)],'yyyymmddHHMM');
                %write legacy converter flag
                h5writeatt(tmp_h5_ffn,'/what','legacy','1');
                %transfer to odimh5_archive
                date_vec      = datevec(start_timedate);
                s3_odimh5_ffn = [s3_bucket,'odimh5_archive/',radar_id_str,'/',...
                    num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',...
                    num2str(date_vec(3),'%02.0f'),'/',radar_id_str,'_',datestr(start_timedate,'yyyymmdd_HHMMSS'),'.h5'];
                cmd     = [prefix_cmd,'aws s3 mv ',tmp_h5_ffn,' ',s3_odimh5_ffn,' &'];
                [~,~]   = unix(cmd);
                %success
                success_count = success_count + 1;
            catch err
                %write log
                write_log(log_err_fn,[tmp_fn_list{j},', corrupt file after legacy conversion ',err.identifier,' ',err.message]);
                continue
            end
            
        else
            write_log(log_err_fn,[tmp_fn_list{j},', failed legacy conversion']);
        end
        %delete file
        delete(tmp_rapic_ffn)
    end
end

%write stats log
write_log(log_stats_fn,['total number of files: ',num2str(length(rapic_fn_list))]);
write_log(log_stats_fn,['successful conversions: ',num2str(success_count)]);

display('finished')

function write_log(log_fn,log_str)
%write to log file
display(log_str)
fid = fopen(log_fn,'at');
fprintf(fid,'%s',log_str);
fclose(fid);


    
