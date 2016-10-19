function broken_vol_stat

%WHAT: for a radar id, run the odimh5 conversion utility on broken volumes
%and lists the error codes, grouping by most common error.

%init vars
radar_id       = 50;
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
s3_odimh5_root = 's3://roames-wxradar-archive/odimh5_archive/broken_vols/';
s3_bucket      = 's3://roames-wxradar-archive/';
s3_odimh5_path = [s3_odimh5_root,num2str(radar_id,'%02.0f'),'/'];
log_fn         = ['broken_vol.',num2str(radar_id,'%02.0f'),'.log'];

%ls s3 path
display(['s3 ls for broken_vols radar_id: ',num2str(radar_id,'%02.0f')])
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
for i = 1:length(rapic_fn_groups)
    tmp_fn_list = rapic_fn_groups{i};
    for j = 1:length(tmp_fn_list)
        %update user
        display(['processing ',tmp_fn_list{j},' from group ',num2str(i),' of ',num2str(length(rapic_fn_groups))])
        %download file
        s3_ffn  = [s3_odimh5_path,tmp_fn_list{j}];
        tmp_ffn = [tempdir,tmp_fn_list{j}];
        cmd = [prefix_cmd,'aws s3 cp ',s3_ffn,' ',tmp_ffn];
        [sout,eout] = unix(cmd);
        %run convert and log
        [sout,eout] = unix([prefix_cmd,'rapic_to_odim ',tmp_ffn,' ',tempdir,'tmp.h5']); %note, reset lD path from matlab to system default
        tmp_idx     = strfind(eout,'->');
        error_part1 = eout(1:tmp_idx-4);
        error_path2 = eout(tmp_idx+3:end-1);
        log_str     = [tmp_fn_list{j},',',error_part1,',',error_path2,10];
        %write to log file
        fid = fopen(log_fn,'at');
        fprintf(fid,'%s',log_str);
        fclose(fid);
        %delete file
        delete(tmp_ffn)
    end
end
