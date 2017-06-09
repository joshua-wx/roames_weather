function nowcast2local
%Description:
%downloads all rapic data for a selected date range to local disk

%addtopaths
addpath('../../etc')
addpath('../../lib/m_lib')
mkdir('tmp')

%set up kill switch
kill_fn = 'nowcast2local.kill';
[~,~]   = system(['touch ',kill_fn]);

%create date list
date_list = datenum([2016,06,25]):datenum([2016,09,19]);

%paths
local_root  = '/run/media/meso/radar_archive/radar/';
remote_root = 'http://wxdigicor2.bom.gov.au/nowcast/data/rapic/';

%log setup
log={};
log_fn=['nowcast2local_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%radar_id list
[~] = read_site_info('site_info.txt');
load(['tmp/','site_info.txt','.mat']);

%start loop
for i = 3:length(siteinfo_name_list)
    %create flurry url
    site_name = siteinfo_name_list{i};
    site_id   = num2str(siteinfo_id_list(i), '%02.0f');
    for j=1:length(date_list)
        %create paths
        curr_day    = num2str(day(date_list(j)), '%02.0f');
        curr_month  = num2str(month(date_list(j)), '%02.0f');
        curr_year   = num2str(year(date_list(j)));
        remote_path = [remote_root,site_name,'/',curr_year,'/',curr_month,'/',curr_day,'/'];
        local_path  = [local_root,site_id,'/',curr_year,'/',curr_month,'/',curr_day,'/'];

        %run fetch --limit-rate=1024k
        disp(['Downloading: ',remote_path]);
        cmd_string  = ['export LD_LIBRARY_PATH=/usr/lib; wget -r -np -nH -nd -A "*.rapic" -P ',local_path,' ',remote_path];
        [sout,eout] = unix(cmd_string);
        
        %get file list of dl'ed files
        dl_fileList = getAllFiles(local_path);
        %skip if no files present
        if isempty(dl_fileList)
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',remote_path]];
            save(log_fn,'log')
        end
    end
    %send pushover notification
    pushover('nowcast2local',['finished radar ',site_id]);
end
