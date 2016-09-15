function monash_era_temp_interp


%read csv file
root='/media/meso/storage/wv_monash_proced_arch/';
C = dlmread([root,'monash_datelist_270814.csv'],',',1,0);
event_id  = C(:,1);
event_dt  = x2mdate(C(:,2));
event_lat = C(:,3);
event_lon = C(:,4);

%preallocated
event_fz_level      = nan(length(event_id),1);
event_minus20_level = nan(length(event_id),1);

%tempt dataset
tempt_nc_ffn    = '/media/meso/storage/PhD_2013-2014_Big_Data/era-interim/01071997-31032014_ERAinteriM_06Z_pl_temp.nc';
tempt_nc_data   = ncread(tempt_nc_ffn,'t'); %note scale factor and add offset are applied by matlab and data converted to double

tempt_nc_data   = tempt_nc_data-272.150; %convert to C

nc_lon    = double(ncread(tempt_nc_ffn,'longitude'));
nc_lat    = double(ncread(tempt_nc_ffn,'latitude'));
nc_hrs    = double(ncread(tempt_nc_ffn,'time'));
nc_plevel = double(ncread(tempt_nc_ffn,'level'));

%geopt dataset
geopt_nc_ffn    = '/media/meso/storage/PhD_2013-2014_Big_Data/era-interim/01071997-31032014_ERAinteriM_06Z_pl_geopot.nc';
geopt_nc_data   = ncread(geopt_nc_ffn,'z'); %note scale factor and add offset are applied by matlab and data converted to double

geopt_nc_data  = geopt_nc_data./9.80665; %convert from geopot to geopotH

%create datenum
offset_dt = datenum('1900-01-01','yyyy-mm-dd');
nc_dt     = offset_dt + nc_hrs./24;

for i=1:length(event_id)
    %extract target dim values
    target_lat = event_lat(i);
    target_lon = event_lon(i);
    target_dt  = event_dt(i);
    
    %find closest profile coordinates
    [~,nc_lat_ind] = min(abs(nc_lat-target_lat));
    [~,nc_lon_ind] = min(abs(nc_lon-target_lon));
    [~,nc_dt_ind]  = min(abs(nc_dt-target_dt));
    
    %extract profile
    t_profile = tempt_nc_data(nc_lon_ind,nc_lat_ind,:,nc_dt_ind);
    z_profile = geopt_nc_data(nc_lon_ind,nc_lat_ind,:,nc_dt_ind);
    
    %reshape profile
    t_profile = flipud(reshape(t_profile,length(t_profile),1));
    z_profile = flipud(reshape(z_profile,length(z_profile),1));
    
    %interpolate
    target_fz_level = sounding_interp(t_profile,z_profile,0);
    target_minus20_level = sounding_interp(t_profile,z_profile,-20);
    
    %insert if not empty
    if ~isempty(target_fz_level)
        event_fz_level(i) = target_fz_level;
    end
    if ~isempty(target_minus20_level)
        event_minus20_level(i) = target_minus20_level;
    end
    
end

dlmwrite([root,'era_shs_levels_',datestr(now,'ddmmyyyy'),'.csv'],[event_fz_level,event_minus20_level]);

function intp_h = sounding_interp(snd_temp,snd_height,target_temp)
%WHAT: Provides an interpolated height for a target temperature using a
%sounding vertical profile

intp_h=[];
%subset data to above and below freezing level
below_ind = find(snd_temp>target_temp,1,'last');
above_ind = below_ind+1;
%check indices exist
if isempty(below_ind) || above_ind>length(snd_temp)
    return
end
%attempt to interpolate
intp_h   = interp1(snd_temp(below_ind:above_ind),snd_height(below_ind:above_ind),target_temp);



