function vol_to_odimh5(local_rapic_ffn)

%init
brokenvol_s3_path = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';
odim_s3_path      = 's3://roames-weather-odimh5/odimh5_archive/';
prefix_cmd        = 'export LD_LIBRARY_PATH=/usr/lib; ';

%convert to odimh5 and remove
[~,rapic_fn,ext]   = fileparts(local_rapic_ffn);
local_odimh5_ffn   = [tempdir,rapic_fn,'.h5'];
cmd                = [prefix_cmd,' rapic_to_odim ',local_rapic_ffn,' ',local_odimh5_ffn];
[sout,eout]        = unix(cmd);

if sout ~= 0 || exist(local_odimh5_ffn,'file') ~= 2
    %if conversion fails, then move to broken vols
    disp('failed to convert to odim, moving to broken_vols')
    %move rapic vol to broken vols
    radar_id_str    = rapic_fn(1:2);
    s3_broken_ffn   = [brokenvol_s3_path,radar_id_str,'/',rapic_fn,ext];
    file_mv(local_rapic_ffn,s3_broken_ffn);
else
    %conversion success
    %read odimh5 vol time and radar id
    disp('conversion successful')
    source_att   = h5readatt(local_odimh5_ffn,'/what','source');
    h5_radar_id  = str2num(source_att(7:8));
    h5_vol_date  = deblank(h5readatt(local_odimh5_ffn,'/dataset1/what/','startdate'));
    h5_vol_time  = deblank(h5readatt(local_odimh5_ffn,'/dataset1/what/','starttime'));
    h5_datetime  = datenum([h5_vol_date,h5_vol_time],'yyyymmddHHMMSS');
    h5_datevec   = datevec(h5_datetime);
    %move to s3
    odimh5_fn     = [num2str(h5_radar_id,'%02.0f'),'_',datestr(h5_datetime,'yyyymmdd_HHMMSS'),'.h5'];
    s3_odimh5_ffn = [odim_s3_path,num2str(h5_radar_id,'%02.0f'),'/',num2str(h5_datevec(1)),'/',...
        num2str(h5_datevec(2),'%02.0f'),'/',num2str(h5_datevec(3),'%02.0f'),'/',odimh5_fn];
    file_mv(local_odimh5_ffn,s3_odimh5_ffn);
end


