function [ppi_elv,vol_time] = read_odimh5_ppi_atts(h5_ffn,dataset_no)
%WHAT: reads scan and elv data from dataset_no from h5_ffn.
%INPUTS:
%h5_ffn: path to h5 file
%dataset_no: dataset number in h file
%slant_r_vec: slant_r coordinate vector
%a_vec: azimuth coordinates vector
%OUTPUTS:
%elv: elevation angle of radar beam
%pol_data: polarmetric data
ppi_elv  = [];
vol_time = [];

try
    %extract constants from what group for the dataset
    ppi_elv      = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/where/'],'elangle');
    start_date   = deblank(h5readatt(h5_ffn,['/dataset',num2str(1),'/what/'],'startdate'));
    start_time   = deblank(h5readatt(h5_ffn,['/dataset',num2str(1),'/what/'],'starttime'));
    vol_time     = datenum([start_date,start_time],'yyyymmddHHMMSS');
catch err
    disp(['/dataset',num2str(dataset_no),' is broken']);
	utility_log_write('tmp/log.ppi_att_read','',[h5_ffn,' for ','/dataset',num2str(dataset_no),' is broken ',datestr(now)],[err.identifier,' ',err.message]);
end
