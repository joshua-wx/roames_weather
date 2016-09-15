function QLDarchive2DailyVOL

%This program cats qld rapic data into daily files. Once this daily archive
%has been built it can be ingested into the main archive using
%merge_rapic.m then compress these new vols using lz4tovol.m

%only works on data from 2000 onwards as rapic files are different prior

%read site_info
[site_id_list,site_s_name_list]=old_read_site_info;

%set path
target_year=1999;
qld_archive_path=['/media/meso/radar_data2/QLD_ARCHIVE/',num2str(target_year),'/'];
%qld_archive_path=['/media/meso/radar_data2/QLD_ARCHIVE/2005_12_30-2006_01_5/'];
%qld_archive_path='/home/meso/Desktop/test/';
processed_archive_path='/media/meso/radar_data2/QLD_Archive_Processed/';
%get file list
filelist = getAllFiles(qld_archive_path);

%tmp dir path
tmp_dir='/tmp/qld_convert/';
%clean/make tmp dir
if exist(tmp_dir,'file')==7
    system(['rm -R ',tmp_dir]);
end
mkdir(tmp_dir);

corrupt_file_list={};

%remove index files from list to leave only data files and zip files
idx_ind=strfind(filelist, '.idx');
dat_ind=strfind(filelist, '.dat');
arch_ind=strfind(filelist, '.arch');
txt_ind=strfind(filelist, '.txt');
filter_mask=false(1,length(idx_ind));
for i=1:length(idx_ind)
    if isempty(idx_ind{i}) & isempty(dat_ind{i}) & isempty(arch_ind{i}) & isempty(txt_ind{i})
        filter_mask(i)=true; 
    end
end
filt_filelist=filelist(filter_mask);

%convert to daily VOL
for i=length(filt_filelist)-1:length(filt_filelist)
    temp_file=false;
    target_ffn = filt_filelist{i};
    disp(['Processing file ',num2str(i),' of ',num2str(length(filt_filelist)),' : ',target_ffn])
    %fileparts
    [target_path, target_fn, target_ext] = fileparts(target_ffn);
    %check zip type and unzip if required
    try
        if strcmp(target_ext,'.gz')
            gunzip(target_ffn);
            %rebuild target ffn without ext
            target_ffn = [target_path,'/',target_fn];
            temp_file=true;
        elseif strcmp(target_ext,'.bz2')
            system(['bzip2 -dk ',target_ffn]);
            target_ffn = [target_path,'/',target_fn];
            temp_file=true;
        end
    catch
        display(['Broken zip file ',target_ffn])
        corrupt_file_list = [corrupt_file_list;target_ffn];
        continue
    end
    
    %check if decompression was sucessful
    if exist(target_ffn,'file')~=2
        corrupt_file_list = [corrupt_file_list;target_ffn];
        continue
    end
    
    %preview file
%     fid = fopen(target_ffn);
%     tline = fgets(fid);
%     for i=1:600
%                 disp(tline)
%         tline = fgets(fid);
%     end
%     keyboard
    %read file
    fid1 = fopen(target_ffn);
    tline = ['temp'];
    while ischar(tline)
        tline = fgets(fid1);
        if isempty(tline) || length(tline)<7
            continue
        end
        try
            if strcmp(tline(1:7),'COUNTRY')
                %read date and radar if from last tline
                k = strfind(tline, 'STNID'); if isempty(k); continue; end; radar_id = str2num(tline(k+7:k+8));
                k = strfind(tline, 'TIMESTAMP'); if isempty(k); continue; end; scan_date = datenum(tline(k+10:k+18),'yyyymmdd');
                %skip bad dates
                %if year(scan_date)~=target_year; continue; end                
                %match radar s_name
                tf = site_id_list==radar_id; radar_s_name=site_s_name_list(tf);
                %daily vol fn
                daily_vol_fn=['radar.',radar_s_name{1},'.',datestr(scan_date,'yyyymmdd'),'.VOL'];
                %daily vol ffn
                daily_vol_ffn=[processed_archive_path,num2str(year(scan_date)),'/',daily_vol_fn];
                %open text file
                fid2=fopen(daily_vol_ffn,'a');
                %write data to text file
                fprintf(fid2,'%s',tline);
                fclose(fid2);
            end
        catch err
            disp('Failed process')
            disp(tline)
        end
    end
    fclose(fid1);
    %remove unzipped files to prevent duplication during later rerunss...
    if temp_file==true
        delete(target_ffn);
    end
end

disp('daily converison and archiving complete')
save('corrupt_file_list.mat','corrupt_file_list')
