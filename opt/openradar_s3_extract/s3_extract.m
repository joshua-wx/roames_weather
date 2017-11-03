function s3_extract

%%WHAT: extract odimh5 volumes from s3 using a date/time/radar list file
%%to provide Rob Warren with a TRIMM/GPM calibration dataset

radar_id   = 04;
list_fn    = 'IDR04_cpa.txt';
s3_root    = 's3://roames-weather-odimh5/odimh5_archive/';
out_root   = '/home/meso/radar_temp/';
prefix_cmd = 'export LD_LIBRARY_PATH=/usr/lib; ';
max_t_diff = 1/24/60*15; %max 15minute difference

%read config
fid = fopen(list_fn);
list_raw = textscan(fid,'%s %s');
fclose(fid);
date_raw = list_raw{1};
time_raw = list_raw{2};
%convert to matlab date list
dt_list  = zeros(size(date_raw));
for i = 1:length(dt_list)
    dt_list(i) = datenum([date_raw{i},' ',time_raw{i}],'yyyy-mm-dd HH:MM:SS');
end

%extract nearest volume from s3
%list s3 folder for target date
for i=1:length(dt_list)
    target_dt =  dt_list(i);
    dt_vec     = datevec(target_dt);
    s3_path    = [s3_root,num2str(radar_id,'%02.0f'),'/',num2str(dt_vec(1)),'/',...
        num2str(dt_vec(2),'%02.0f'),'/',num2str(dt_vec(3),'%02.0f'),'/'];
    cmd        = [prefix_cmd,'aws s3 ls ',s3_path];
    [sout,out] = unix(cmd);
    %parse ls out
    if isempty(out)
        display(['s3 ls is empty for ',s3_path])
        continue
    end
    ls_raw       = textscan(out,'%*s %*s %*f %s');
    h5_name_list = ls_raw{1};
    %loop through each h5 file to extract date
    h5_time_list = zeros(size(h5_name_list));
    for k = 1:length(h5_time_list)
        h5_fn           = h5_name_list{k};
        h5_time_list(k) = datenum(h5_fn(4:end),'yyyymmdd_HHMMSS');
    end
    %find index of nearest time to target time/date
    [diff_value,min_idx] = min(abs(target_dt-h5_time_list));
    if diff_value > max_t_diff
        disp(['maximum t diff of ',num2str(minute(diff_value)),' minutes is greater max for ',datestr(target_dt)]);
        continue
    else
        disp(['time diff of ',num2str(minute(diff_value)),' min'])
    end
    %fetch s3 file
    s3_ffn   = [s3_path,h5_name_list{min_idx}];
    dest_ffn = [out_root,h5_name_list{min_idx}];
    cmd = [prefix_cmd,'aws s3 cp ',s3_ffn,' ',dest_ffn];
    [sout,eout] = unix(cmd);
    if exist(dest_ffn,'file')==2
        disp(['Download of ',s3_ffn,' was a success'])
    else
        disp(['Download of ',s3_ffn,' failed'])
    end
end