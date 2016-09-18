function flurry2archive
%Description:
%downloads all rapic data for a selected year from the flurry archive. it
%then untars and cats this data. Followed by lz4 compression and move to
%the correct local archive

%create date list
datelist=datenum([2013,11,11]):datenum([2015,01,15]);

%load date list
% date_list_fn = 'IDR70_days.txt';
% fileID       = fopen(date_list_fn);
% datelist     = textscan(fileID,'%s'); datelist = datelist{1};
% datelist     = datenum(datelist,'yyyymmdd');

%archive path
archive_path='/media/meso/DATA/phd/bom_obs/MtStapyOdim/';

%flurry archive root
flurry_archive='http://flurry-bm.bom.gov.au/nowcast/nowcast_data/rapic/';

%log setup
log={};
log_fn=['flurry2archive_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%radar_id list
%[site_id_list,site_s_name_list]=read_site_info;
site_id_list     = 66;
site_s_name_list = {'MtStapl'};


%tmp dl dir path
dl_tmp_dir='/tmp/flurry_convert/';
%clean/make tmp dir
if exist(dl_tmp_dir,'file')==7
    system(['rm -R ',dl_tmp_dir]);
end
mkdir(dl_tmp_dir);

%tmp untar dir path
untar_tmp_dir='/tmp/untar_convert/';
%clean/make tmp dir
if exist(untar_tmp_dir,'file')==7
    system(['rm -R ',untar_tmp_dir]);
end
mkdir(untar_tmp_dir);

%start loop

for i=1:length(site_s_name_list)
    %create flurry url
    fluury_radar_name=site_s_name_list{i};    
    for j=1:length(datelist)
        %create flurry path
        curr_day=num2str(day(datelist(j)), '%02.0f');
        curr_month=num2str(month(datelist(j)), '%02.0f');
        curr_year=num2str(year(datelist(j)));
        temp_flurry_path=[flurry_archive,fluury_radar_name,'/',curr_year,'/',curr_month,'/',curr_day,'/'];
        %create wget cmd string and pass to system
        disp(['Downloading: ',temp_flurry_path]);
        cmd_string=['wget -r -np -nH -A .tar -P ',dl_tmp_dir,' ',temp_flurry_path];
        [~,~]=system(cmd_string);
        %get file list of dl'ed files
        dl_fileList = getAllFiles(dl_tmp_dir);
        %skip if no files present
        if isempty(dl_fileList)
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',temp_flurry_path]];
            continue
        end
        %more than one tar file
        if length(dl_fileList) > 1
            keyboard
        end
        %extract file name
        temp_fn=dl_fileList{1};
        %untar
        try
        untar(temp_fn,untar_tmp_dir);
        catch
            disp('TAR corrupt');
            log=[log;['TAR corrupt ',temp_flurry_path]];
            continue
        end
        %create cat cmd and pass to system
        vol_name=['radar.IDR',num2str(site_id_list(i), '%02.0f'),'.',datestr(datelist(j),'yyyymmdd'),'.VOL'];
        cmd_string=['cat ',untar_tmp_dir,'*.rapic > ',untar_tmp_dir,vol_name];
        [~,~]=system(cmd_string);
        %compress file and move to archive
        target_folder = [archive_path,num2str(year(datelist(j))),'/vol/'];
        %create target folder is needed
        if exist(target_folder,'file')~=7
            mkdir(target_folder)
        end
        cmd_text=['lz4c -hc -y ',untar_tmp_dir,vol_name,' ',target_folder,vol_name,'.lz4'];
        [~,~]=system(cmd_text);
        %success
        disp('Success!')
        log=[log;['Success ',temp_flurry_path]];
        %clean dl and untar dirs
        system(['rm -R ',dl_tmp_dir,'*']);
        system(['rm -R ',untar_tmp_dir,'*']);
        save(log_fn,'log')
    end
end
