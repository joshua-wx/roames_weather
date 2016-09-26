function flurry2archive_type1
%Description:
%downloads individual volumes from a full dir structure and tar's them up

addpath('../lib/m_lib')

kill_fn = 'flurry2archive.kill';
[~,~] = system(['touch ',kill_fn]);

%create date list
datelist=datenum([2016,07,01]):datenum([2016,09,20]);
%archive path
archive_path='/run/media/meso/DATA/201607-201609/';

%flurry archive root
flurry_archive='http://wxdigicor2.bom.gov.au/nowcast/data/rapic/';
%flurry_archive='http://flurry-bm.bom.gov.au/nowcast/data/rapic/';

%log setup
log={};
log_fn=['flurry2archive_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%setup kill files
[~,~]=unix('touch kill_flurry2archive');

%radar_id list
read_site_info;
load('site_info.mat')

%site_s_name_list = {'PrthA_P','BrisA_P','R_hmptn','K_grlie','T_Hills'};
%site_id_list = [26,43,47,48,71];


%tmp dl dir path
dl_tmp_path='/tmp/rapic_flurry/';
%clean/make tmp dir
if exist(dl_tmp_path,'file')==7
    system(['rm -R ',dl_tmp_path]);
end
mkdir(dl_tmp_path);

%tmp untar dir path
tar_tmp_path='/tmp/rapic_flurry_tar/';
%clean/make tmp dir
if exist(tar_tmp_path,'file')==7
    system(['rm -R ',tar_tmp_path]);
end
mkdir(tar_tmp_path);

display('late start')



%start loop
for i=1:length(site_s_name_list)
    %create flurry url
    flurry_radar_name=site_s_name_list{i};
    for j=1:length(datelist)
        %create flurry path
        curr_day   = num2str(day(datelist(j)), '%02.0f');
        curr_month = num2str(month(datelist(j)), '%02.0f');
        curr_year  = num2str(year(datelist(j)));
        curr_id    = num2str(site_id_list(i), '%02.0f');
        flurry_path=[flurry_archive,flurry_radar_name,'/',curr_year,'/',curr_month,'/',curr_day,'/'];
        %create output filename
        out_name = ['radar.IDR',curr_id,'.',datestr(datelist(j),'yyyymmdd')];
        %create wget cmd string and pass to system
        disp(['Downloading: ',flurry_path]);

        cmd_string=['export LD_LIBRARY_PATH=/usr/lib; wget -r -np -nH -nd -A "*.rapic" -P ',dl_tmp_path,' ',flurry_path];
        [sout,eout]=unix(cmd_string);
        %get file list of dl'ed files
        dl_fileList = getAllFiles(dl_tmp_path);
        %skip if no files present
        if isempty(dl_fileList)
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',flurry_path]];
            continue
        end
        %tar
        try
            tar_ffn = [tar_tmp_path,out_name,'.tar'];
            tar(tar_ffn,dl_fileList);
        catch
            disp('TAR creation failed');
            log=[log;['TAR creation failed ',flurry_ffn]];
            continue
        end

        %create archive folder
        archive_folder = [archive_path,curr_year,'/',curr_id,'/'];
        if exist(archive_folder,'file')~=7
            mkdir(archive_folder)
        end
        cmd_text=['lz4c -hc -y ',tar_ffn,' ',archive_folder,out_name,'.lz4'];
        [sout,eout]=system(cmd_text);
        if sout==1
            log=[log;['lz4 creation failed ',cmd_text]];
            continue
        end
        %success
        system(['rm -R ',dl_tmp_path,'*']);
        system(['rm -R ',tar_tmp_path,'*']);
        save(log_fn,'log')
        if exist('kill_flurry2archive','file')~=2
            return
        end

    end
end
