function restore_rapic
%WHAT: triggers s3 glacier restore for all files between the start and end
%date. ffn are output in mat file


rapic_yr_folders = {'2007','2008'};
start_date       = datenum('01072007','ddmmyyyy');
end_date         = datenum('31032008','ddmmyyyy');
prefix_cmd       = 'export LD_LIBRARY_PATH=/usr/lib; ';
rapic_root       = 's3://roames-weather-rapic/rapic_archive/';

restore_ffn_list = {};

for i=1:length(rapic_yr_folders)
    
    %read in rapic folder file listing
    rapic_path    = [rapic_root,rapic_yr_folders{i},'/vol/'];
    rapic_fn_list = s3_listing(prefix_cmd,rapic_path)
    
    %parse file listing to dates
    date_list     = zeros(length(rapic_fn_list),1);
    for j=1:length(date_list)
        str_date = textscan(rapic_fn_list{j},'%*s %*s %s %*s %*s','Delimiter','.'); str_date = str_date{1};
        date_list(j) = datenum(str_date,'yyyymmdd');
    end
    
    %mask dates
    date_idx = find(date_list >= start_date & date_list <= end_date);
    
    %loop through dates and trigger restore
    for j=1:length(date_idx)
        s3_ffn = [rapic_path,rapic_fn_list{date_idx(j)}]
        cmd = [prefix_cmd, 's3cmd --restore-days=7 --restore-priority=standard restore ',s3_ffn];
        [sout,uout] = unix(cmd);
        restore_ffn_list = [restore_ffn_list,s3_ffn];
    end

end

%save list to file
save('restore_rapic_fflist.mat','restore_ffn_list')

function rapic_fn_list = s3_listing(prefix_cmd,s3_odimh5_path)
    rapic_fn_list = {};
    %ls s3 path
    cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path];
    [sout,uout] = unix(cmd);
    %read text
    if ~isempty(uout)
        C             = textscan(uout,'%*s %*s %*u %s');
        rapic_fn_list = C{1};
    end