function nowcast2arhive
%Description:
%downloads individual volumes from a full dir structure and tar's them up
mkdir('tmp')
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')

kill_fn = 'flurry2archive.kill';
[~,~] = system(['touch ',kill_fn]);

%create date list
datelist       = datenum([2016,07,01]):datenum([2016,07,07]);
start_radar_id = 15;
%archive path
local_root = '/run/media/meso/JSODERHOLM/radarfill2016/';

%flurry archive root
remote_root = 'http://wxdigicor2.bom.gov.au/nowcast/data/rapic/';

%log setup
log={};
log_fn=['flurry2archive_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%setup kill files
[~,~]=unix('touch kill_flurry2archive');

%radar_id list
read_site_info('site_info.txt');
load('tmp/site_info.txt.mat')

%tmp dl dir path
dl_tmp_path='/tmp/rapic_flurry/';
%clean/make tmp dir
if exist(dl_tmp_path,'file')==7
    system(['rm -R ',dl_tmp_path]);
end
mkdir(dl_tmp_path);
display('late start')

%start loop
for i=1:length(siteinfo_name_list)
    %create flurry url
    remote_radar_name = siteinfo_name_list{i};
    for j=1:length(datelist)
        %create flurry path
        curr_day   = num2str(day(datelist(j)), '%02.0f');
        curr_month = num2str(month(datelist(j)), '%02.0f');
        curr_year  = num2str(year(datelist(j)));
        curr_id    = num2str(siteinfo_id_list(i), '%02.0f');
        if siteinfo_id_list(i) < start_radar_id
            continue
        end
        remote_path=[remote_root,remote_radar_name,'/',curr_year,'/',curr_month,'/',curr_day,'/'];
        %create output filename
        out_name = [curr_id,'_',datestr(datelist(j),'yyyymmdd')];
        %create wget cmd string and pass to system
        disp(['Downloading: ',remote_path]);

        cmd_string=['export LD_LIBRARY_PATH=/usr/lib; wget -r -np -nH -nd -A "*.rapic" -P ',dl_tmp_path,' ',remote_path];
        [sout,eout]=unix(cmd_string);
        %get file list of dl'ed files
        dl_fileList = getAllFiles(dl_tmp_path);
        %skip if no files present
        if isempty(dl_fileList)
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',remote_path]];
            continue
        end
        %create archive folder
        archive_folder = [local_root,curr_year,'/',curr_id,'/'];
        if exist(archive_folder,'file')~=7
            mkdir(archive_folder)
        end
        %tar
        try
            tar_ffn = [archive_folder,out_name,'.tar'];
            tar(tar_ffn,dl_fileList);
        catch
            disp('TAR creation failed');
            log=[log;['TAR creation failed ',flurry_ffn]];
            continue
        end
        %success
        system(['rm -R ',dl_tmp_path,'*']);
        save(log_fn,'log')
        if exist('kill_flurry2archive','file')~=2
            return
        end

    end
end
