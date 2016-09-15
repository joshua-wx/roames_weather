function era_rsite_temps()
%WHAT: processes an era-interim dataset of pressure level temps into
%freezing and -20C heights for each radar site across the country

%OUT:
%era_t_struct.time                 matlab datenum
%            .(site_id)
%                   .fz_z           %fz level above msl (m)
%                   .minus20_z     

%add paths for lib/etc
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib/')
addpath('/home/meso/Dropbox/dev/wv/etc/')

%read site
read_site_info('site_info.txt');
load('site_info.txt.mat');

era_tz_struct   = struct('time',[]);
for i=1:100;
    site_id                           = ['r',num2str(i)];
    era_tz_struct.(site_id).fz_z      = [];
    era_tz_struct.(site_id).minus20_z = [];
end
    
    
year_list       = 1997:2016;

for i=1:length(year_list)
    target_year = num2str(year_list(i));
    era_ffn     = ['/run/media/meso/DATA/project_data/era-int_wv/era_wv_',target_year,'.nc'];
    era_lon     = ncread(era_ffn,'longitude');
    era_lat     = ncread(era_ffn,'latitude');
    era_hour    = ncread(era_ffn,'time');
    era_t       = double(ncread(era_ffn,'t'))-273.15;   %K -> C
    era_z       = double(ncread(era_ffn,'z'))./9.80665; %geopot to geopotH
    
    %convert time from hours past 1900-01-01 to matlab time number
    offset_dt = datenum('1900-01-01','yyyy-mm-dd');
    era_dt    = offset_dt + era_hour./24;
    
    era_tz_struct.time = [era_tz_struct.time;era_dt];
    
    %loop through radar sites
    for j=1:length(site_id_list)
        site_lat     = site_lat_list(j);
        site_lon     = site_lon_list(j);
        site_id      = site_id_list(j);
        site_id_str  = ['r',num2str(site_id)];
        
        [~,lat_ind]  = min(abs(era_lat-site_lat));
        [~,lon_ind]  = min(abs(era_lon-site_lon));
        fz_z         = zeros(length(era_dt),1);
        minus20_z    = zeros(length(era_dt),1);
        for k=1:length(era_dt)
            %extract profile for single time
            t_profile = era_t(lon_ind,lat_ind,:,k);
            z_profile = era_z(lon_ind,lat_ind,:,k);
            %reshape profile
            t_profile = flipud(reshape(t_profile,length(t_profile),1));
            z_profile = flipud(reshape(z_profile,length(z_profile),1));
            %interpolate
            fz_level      = sounding_interp(t_profile,z_profile,0);
            minus20_level = sounding_interp(t_profile,z_profile,-20);
            %cat
            fz_z(k)       = fz_level;
            minus20_z(k)  = minus20_level;
        end
        era_tz_struct.(site_id_str).fz_z       = [era_tz_struct.(site_id_str).fz_z;fz_z];
        era_tz_struct.(site_id_str).minus20_z  = [era_tz_struct.(site_id_str).minus20_z;minus20_z];
        disp(['finished site ',site_id_str,' for year ',num2str(target_year)]);
    end
    disp(['finished year ',num2str(target_year)]);
end
disp(['finished all']);
save('era_tz_1999-201606.mat','era_tz_struct')
keyboard

function intp_h = sounding_interp(snd_temp,snd_height,target_temp)
%WHAT: Provides an interpolated height for a target temperature using a
%sounding vertical profile

intp_h=[];
%find index above and below freezing level
above_ind = find(snd_temp<target_temp,1,'first');
if above_ind > 1  
    below_ind = above_ind-1;
else
    %above ind is either 1 or 0, cannot provide interpolation
    return
end

%attempt to interpolate
intp_h   = interp1(snd_temp(below_ind:above_ind),snd_height(below_ind:above_ind),target_temp);
