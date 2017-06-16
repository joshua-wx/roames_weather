function vol_datetime = read_odimh5_time(h5_ffn)

%WHAT: reads volume time and date from /what

%init
vol_datetime = 0;
try
	h5_vol_date  = deblank(h5readatt(h5_ffn,'/what/','date'));
    h5_vol_time  = deblank(h5readatt(h5_ffn,'/what/','time'));
	vol_datetime = datenum([h5_vol_date,h5_vol_time],'yyyymmddHHMMSS');
catch err
    disp([h5_ffn,' is broken']);
    utility_log_write('tmp/log.ppi_vol_time','',[h5_ffn,' for vol time is broken ',datestr(now)],[err.identifier,' ',err.message]);
end  
