function flurry2archive_type2
%Description:
%downloads tar'ed daily files from flurry archive, renames, lz4's and moved
%to correct directory

addpath('../lib/m_lib')

kill_fn = 'flurry2archive.kill';
[~,~] = system(['touch ',kill_fn]);

%create date list
datelist=datenum([2011,01,01]):datenum([2014,12,31]);
%archive path
archive_path='/media/meso/DATA/2010-2014_missing_sites_fill/';

%flurry archive root
flurry_archive='http://flurry-bm.bom.gov.au/nowcast/data/rapic/';

%log setup
log={};
log_fn=['flurry2archive_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%setup kill files
[~,~]=unix('touch kill_flurry2archive');

%radar_id list
%read_site_info;
%load('site_info.mat')

site_s_name_list = {'PrthA_P','BrisA_P','R_hmptn','K_grlie','T_Hills'};
site_id_list = [26,43,47,48,71];


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
        flurry_path=[flurry_archive,flurry_radar_name,'/',curr_year,'/'];
        flurry_fn  =['rapic_',flurry_radar_name,'_',datestr(datelist(j),'yyyymmdd'),'.tar'];
        %create output filename
        out_name = ['radar.IDR',curr_id,'.',datestr(datelist(j),'yyyymmdd')];
        %create wget cmd string and pass to system
        disp(['Downloading: ',flurry_path,flurry_fn]);

        cmd_string=['export LD_LIBRARY_PATH=/usr/lib; wget -r -np -nH -nd -P ',dl_tmp_path,' ',flurry_path,flurry_fn];
        [sout,eout]=unix(cmd_string);
        %skip if no files present
        if exist([dl_tmp_path,flurry_fn])~=2
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',flurry_path]];
            continue
        end
        %rename
        try
            tar_ffn = [dl_tmp_path,out_name,'.tar'];
            movefile([dl_tmp_path,flurry_fn],tar_ffn);
        catch
            disp('rename failed');
            log=[log;['rename failed ',flurry_ffn]];
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
        save(log_fn,'log')
        if exist('kill_flurry2archive','file')~=2
            return
        end

    end
end
