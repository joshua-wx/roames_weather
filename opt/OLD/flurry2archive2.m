function flurry2archive2
%Description:
%downloads all rapic data for a selected year from the flurry archive. it
%then untars and cats this data. Followed by lz4 compression and move to
%the correct local archive

kill_fn = 'flurry2archive2.kill';
[~,~] = system(['touch ',kill_fn]);


%create date list
datelist=datenum([2015,01,01]):datenum([2016,06,30]);
%datelist=datenum([2013,11,11]):datenum([2015,01,15]);

%load date list
% date_list_fn = 'IDR70_days.txt';
% fileID       = fopen(date_list_fn);
% datelist     = textscan(fileID,'%s'); datelist = datelist{1};
% datelist     = datenum(datelist,'yyyymmdd');

%archive path
archive_path='/media/meso/storage/2015_rapic/';

%flurry archive root
flurry_archive='http://flurry-bm.bom.gov.au/nowcast/nowcast_data/rapic/';

%log setup
log={};
log_fn=['flurry2archive_log_',datestr(now,'yymmdd_HHMM'),'.mat'];

%radar_id list
[site_id_list,site_s_name_list]=read_site_info;

%tmp dl dir path
dl_tmp_path='/tmp/flurry_convert/';
%clean/make tmp dir
if exist(dl_tmp_path,'file')==7
    system(['rm -R ',dl_tmp_path]);
end
mkdir(dl_tmp_path);

%tmp untar dir path
untar_tmp_path='/tmp/untar_convert/';
%clean/make tmp dir
if exist(untar_tmp_path,'file')==7
    system(['rm -R ',untar_tmp_path]);
end
mkdir(untar_tmp_path);

%start loop

for i=1:length(site_s_name_list)
    %create flurry url
    flurry_radar_name=site_s_name_list{i};    
    for j=1:length(datelist)
        %create flurry path
        curr_year   = num2str(year(datelist(j)));
        flurry_fn   = ['rapic_',flurry_radar_name,'_',datestr(datelist(j),'yyyymmdd'),'.rapic'];
        flurry_path = [flurry_archive,flurry_radar_name,'/',curr_year,'/'];
        flurry_ffn  = [flurry_path,flurry_fn];
        %create wget cmd string and pass to system
        disp(['Downloading: ',flurry_ffn]);
        
        cmd_string=['wget -r -P ',dl_tmp_path,' ',flurry_ffn];
        [~,~]=system(cmd_string);
        %skip if no files present
        dl_tmp_ffn = [dl_tmp_path,flurry_fn];
        if exist(dl_tmp_ffn,'file') ~= 2
            disp('NO DATA COLLECTED')
            log=[log;['NO DATA DLED ',flurry_ffn]];
            continue
        end
        %untar
        try
        untar(dl_tmp_ffn,untar_tmp_path);
        catch
            disp('TAR corrupt');
            log=[log;['TAR corrupt ',flurry_ffn]];
            continue
        end
        untar_tmp_dir          = dir(untar_tmp_path);
        untar_tmp_fnlist       = {untar_tmp_dir.name}; untar_tmp_fnlist(1:2)=[];
        untar_tmp_rapic_fnlist = {};
        %check for rapic files
        for k=1:length(untar_tmp_fnlist)
            temp_fn = untar_tmp_fnlist{k};
            if strcmp(temp_fn(end-4:end),'rapic')
                untar_tmp_rapic_fnlist = [untar_tmp_rapic_fnlist;temp_fn];
            end
        end
        if isempty(untar_tmp_rapic_fnlist)
            disp('TAR EMPTY')
            log=[log;['TAR EMPTY ',flurry_ffn]];
            continue
        end
        
        %create archive folder
        archive_folder = [archive_path,flurry_radar_name,'/',num2str(year(datelist(j))),'/',num2str(month(datelist(j)), '%02.0f'),'/',num2str(day(datelist(j)), '%02.0f'),'/'];
        if exist(archive_folder,'file')~=7
            mkdir(archive_folder)
        end
        %convert to untared files to odim
        for k=1:length(untar_tmp_rapic_fnlist)
            untar_fn      = untar_tmp_rapic_fnlist{k};
            fn_datestr    = untar_fn(1:12);
            untar_tmp_ffn = [untar_tmp_path,untar_fn];
            h5_name       = ['radar.IDR',num2str(site_id_list(i), '%02.0f'),'.',fn_datestr,'.h5'];
            cmd_string    = ['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',untar_tmp_ffn,' ',archive_folder,h5_name];
            [~,~] = system(cmd_string); %note, reset lD path from matlab to system default
            if exist([archive_folder,h5_name],'file')==2
                display(['converting ',untar_fn])
            else
                display('Conversion failure')
                log=[log;['Failed on rapid_to_odim ',flurry_ffn]];
            end
            if exist(kill_fn,'file') ~= 2
                return
            end
        end
        %success
        system(['rm -R ',dl_tmp_path,'*']);
        system(['rm -R ',untar_tmp_path,'*']);
        save(log_fn,'log')
    end
end
