function monash_process2excel

format long

%create output directory
root='/media/meso/storage/wv_monash_proced_arch/';
output_dir=[root,datestr(now,'yyyymmddHHMM'),'_simple_stats_run/'];
mkdir(output_dir)  
log_fn=[output_dir,'log_file.mat'];

%proced_dir
dest_dir=[root,'proced/'];
if exist(dest_dir,'file')~=7
    mkdir(dest_dir)
end
    
%load date list
C = dlmread([root,'monash_datelist_270814.csv'],',',1,0);
event_id=C(:,1);
event_date=x2mdate(C(:,2));
%lat 3
%lon 4
radar_id_1=C(:,5);
radar_id_2=C(:,6);
radar_id_3=C(:,7);

%load snd level list
C = dlmread([root,'era_shs_levels_27082014.csv'],',');
snd_fz_level      = C(:,1);
snd_minus20_level = C(:,2);

if length(snd_fz_level)~=length(event_id)
    msgbox('length of snd_fz_level not equal to event_id')
    return
end

%create blank log list
data_log_list=cell(length(event_id),1);
process_log_list=cell(length(event_id),1);

for i=1:length(event_date)
    
    display(['Processing date ',num2str(i),' of ',num2str(length(event_date))]);
    display(datestr(event_date(i)));
    
    cur_year=year(event_date(i));
    date_tag=datevec(event_date(i));
	
    %load primary and alternative dataset paths
    vol_path=['/media/meso/radar_data1/',num2str(cur_year),'/vol/'];
    vol_fn_1=['radar.IDR',num2str(radar_id_1(i), '%02.0f'),'.',datestr(event_date(i),'yyyymmdd'),'.VOL.lz4'];
    vol_fn_2=['radar.IDR',num2str(radar_id_2(i), '%02.0f'),'.',datestr(event_date(i),'yyyymmdd'),'.VOL.lz4'];
    vol_fn_3=['radar.IDR',num2str(radar_id_3(i), '%02.0f'),'.',datestr(event_date(i),'yyyymmdd'),'.VOL.lz4'];
    
    %select best dataset
    if exist([vol_path,vol_fn_1],'file')==2
        vol_ffn=[vol_path,vol_fn_1];
        data_log_list{i}='ID1 data coverage exists';
        target_radar_id=radar_id_1(i);
    elseif exist([vol_path,vol_fn_2],'file')==2 && ~isnan(radar_id_2(i))
        vol_ffn=[vol_path,vol_fn_2];
        data_log_list{i}='ID2 data coverage exists';
        target_radar_id=radar_id_2(i);
    elseif exist([vol_path,vol_fn_3],'file')==2 && ~isnan(radar_id_3(i))
        vol_ffn=[vol_path,vol_fn_3];
        data_log_list{i}='ID3 data coverage exists';
        target_radar_id=radar_id_3(i);
    else
        data_log_list{i}='NO data form any radar';
        continue
    end
    

    %process
    ident_dest=[dest_dir,'IDR',num2str(target_radar_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/','ident_db_',datestr(event_date(i),'dd-mm-yyyy'),'.mat'];
    %only process if it's hasn't been done.
    
%     profile clear
%     profile on
    if exist(ident_dest,'file')~=2
        wv_process(vol_path,dest_dir,'historical',floor(event_date(i)),floor(event_date(i)),0,'AUS',target_radar_id,'',[snd_fz_level(i),snd_minus20_level(i)]);
    end
%     profile off
%     profile viewer
%     keyboard
    
    %check to see if processing worked
    if exist(ident_dest,'file')~=2
        process_log_list{i}='wv_process failed: corrupt data or only CAPPI data';
        continue
    end
    
    %extract simple archive and write to xls
    load(ident_dest)
    csv_fn=[output_dir,'IDR',num2str(target_radar_id),'_',datestr(event_date(i),'yyyy-mm-dd'),'.csv'];
    stats=cell2mat({ident_db.stats}');
    
    
%     stats                         = [volume,area_wdss,area,maj_axis,min_axis,... %1 to 5
%                                     orient,max_tops,max_dbz,max_dbz_h,mean_dbz,... %6 to 10
%                                     max_g_vil,mass,max_sts_dbz_h,cell_vil,max_mesh,... %11 to 15
%                                     max_posh]; %16
    if ~isempty(stats)
        %volume (km3), 35dbz area (km2), max_tops(m), max_dbz, max_dbz_h
        %(m), mean_dbz, max_grid_vil (kg/m2), mass (kt), max_50dbz_h (m),
        %cell_vil (kg/m2), max_mesh (mm), max_posh (%)
        stats=[stats(:,1),stats(:,3),stats(:,7:16)];
        raw_td=[ident_db.stop_timedate]';
        xdate=floor(m2xdate(raw_td));
        xtime=raw_td-floor(raw_td);
        radar_id=[ident_db.radar_id]';
        latloncent=cell2mat({ident_db.dbz_latloncent}');
        csv_data=[xdate,xtime,radar_id,latloncent,stats];
        dlmwrite(csv_fn, csv_data, 'precision', '%i');
        process_log_list{i}='Processing completed and data extracted to csv';
    else
        process_log_list{i}='Processing Completed but NOT STORM DATA PRESENT';
    end

    display('Processing Sucessful')
end

%save log file
[event_id, sort_ind] = sort(event_id);
event_date           = event_date(sort_ind);
data_log_list        = data_log_list(sort_ind);
process_log_list     = process_log_list(sort_ind);
radar_id_1           = radar_id_1(sort_ind);
radar_id_2           = radar_id_2(sort_ind);
radar_id_3           = radar_id_3(sort_ind);

save(log_fn,'event_id','event_date','data_log_list','process_log_list','radar_id_1','radar_id_2','radar_id_3')

keyboard