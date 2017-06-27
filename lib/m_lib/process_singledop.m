function [error,png_ffn,sd_impact_ffn] = process_singledop(odimh5_ffn,sdppi_struct,data_tag,vol_start_time,radar_id)

load('tmp/vis.config.mat')
load('global.config.mat')

%build impact map variables
if ismember(radar_id,impact_radar_id)
    impact_sd_flag = 1;
    tmp_path       = [impact_tmp_root,'wind/',num2str(radar_id,'%02.0f'),'/'];
    if exist(tmp_path,'file') ~= 7
        mkdir(tmp_path);
    end
    nc_fn = ['sd_',datestr(vol_start_time,r_tfmt),'.nc'];
    sd_impact_ffn = [tmp_path,nc_fn];
else
    impact_sd_flag = 0;
    sd_impact_ffn  = '';
end

%build command to run python single doppler script
png_ffn      = [tempdir,data_tag,'.png'];
cmd          = ['python py_lib/sd_winds.py',' ',odimh5_ffn,' ',png_ffn,' ',...
 		num2str(sdppi_struct.atts.NI),' ',num2str(sd_l),' ',num2str(sd_min_rng),' ',...
		num2str(sd_max_rng),' ',num2str(sd_sweep),' ',num2str(sd_thin_azi),' ',...
		num2str(sd_thin_rng),' ',num2str(sd_plt_thin),' ',num2str(impact_sd_flag),' ',...
        sd_impact_ffn];
[sout,eout] = unix(cmd);

%halt on exception
if sout ~= 0
    error = eout;
else
    error         = [];
    png_ffn       = [];
    sd_impact_ffn = [];
end
    
