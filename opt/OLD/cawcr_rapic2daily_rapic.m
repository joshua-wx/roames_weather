function cawcr_rapic2daily_rapic
%WHAT: converts the individual scan files from the cawcr rapic archive into
%daily files by looping through the directories (arranged into daily
%folder) and cat'ing the files.

%requires wxdigicor2 nowcast server data downloaded and placed in the root
%folder with server header folders removed. use wget syntax: wget -r -np -nH -A.rapic http://wxdigicor2.bom.gov.au/nowcast/data/rapic/Melb/2012/

root_path='/media/meso/storage/marburg_radar_data/2015/';

start_date=datenum('01/01/2015','dd/mm/yyyy');
end_date=datenum('09/06/2015','dd/mm/yyyy');
radar_id=50;

date_list=start_date:end_date;

for i=1:length(date_list)
    temp_datevec=datevec(date_list(i));
    raw_dir=[root_path,num2str(temp_datevec(1),'%04.0f'),'/',num2str(temp_datevec(2),'%02.0f'),'/',num2str(temp_datevec(3),'%02.0f')];
    output_ffn=[root_path,'radar.IDR',num2str(radar_id,'%02.0f'),'.',datestr(date_list(i),'yyyymmdd'),'.VOL'];
   
    if exist(raw_dir,'file')
        %join all scan files in that folder into a daily rapic file
        [status, result] = system(['cat ',raw_dir,'/*.rapic > ',output_ffn])
        %remove the scan rapic folder
        system(['rm -rf ',raw_dir])
    end
end
    
keyboard


