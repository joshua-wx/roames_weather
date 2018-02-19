function broken_vol_stat

%WHAT: for a radar id, run the odimh5 conversion utility on broken volumes
%and lists the error codes, grouping by most common error.

%init vars
radar_id       = 50;
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
s3_odimh5_root = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';
s3_bucket      = 's3://roames-weather-odimh5/';
s3_odimh5_path = [s3_odimh5_root,num2str(radar_id,'%02.0f'),'/'];
log_fn         = ['broken_vol.',num2str(radar_id,'%02.0f'),'.mat'];

%ls s3 path
% display(['s3 ls for broken_vols radar_id: ',num2str(radar_id,'%02.0f')])
% cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path];
% [sout,eout] = unix(cmd);
% %read text
% C             = textscan(eout,'%*s %*s %*u %s');
% rapic_fn_list = C{1};

listing = dir('/home/meso/radar_temp'); listing(1:2) = [];
rapic_fn_list = {listing.name};
    
%download group to tmp folder
len     = length(rapic_fn_list);
log_rfn = cell(len,1);
log_msg = cell(len,1);
log_err = cell(len,1);
parfor i = 1:len
        rapic_fn = rapic_fn_list{i};
        %update user
        display(['processing ',num2str(i),' of ',num2str(len)])
        %download file
        %s3_ffn  = [s3_odimh5_path,rapic_fn];
        %local_rapic_ffn = [tempdir,rapic_fn];
        
        local_rapic_ffn = ['/home/meso/radar_temp/',rapic_fn];
        local_odim_ffn  = [tempdir,rapic_fn,'.h5'];
        %cmd = [prefix_cmd,'aws s3 cp ',s3_ffn,' ',local_rapic_ffn];
        %[sout,eout] = unix(cmd);
        %run convert and log
        [sout,eout] = unix([prefix_cmd,'rapic_to_odim ',local_rapic_ffn,' ',local_odim_ffn]); %note, reset lD path from matlab to system default
        tmp_idx     = strfind(eout,'->');
        error_part1 = eout(1:tmp_idx-4);
        error_path2 = eout(tmp_idx+3:end-1);
        log_rfn{i}   = rapic_fn;
        log_msg{i}  = error_part1;
        log_err{i}  = error_path2;
        %delete local files
        %delete(local_rapic_ffn)
        if exist(local_odim_ffn,'file') == 2
            delete(local_odim_ffn)
        end
end

save(log_fn,'log_rfn','log_msg','log_err')
uniq_err     = unique(log_err);
uniq_err_sum = zeros(length(uniq_err),1);

for i=1:length(uniq_err_sum)
    err_idx         = find(strcmp(log_err,uniq_err{i}));
    uniq_err_sum(i) = length(err_idx);
end


%write to log file
keyboard
fid = fopen(log_fn,'at');
fprintf(fid,'%s',log_str);
fclose(fid);