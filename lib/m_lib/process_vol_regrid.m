function grid_obj = process_vol_regrid(h5_ffn,transform_path,clim_radar_coords)
%WHAT:
%load radar volume
%load output transform
%interpolate into output grid
%create sparse storm objects in national grid

%init paths and vars
global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';

%read configs
load([tmp_config_path,site_info_fn,'.mat'])
load([tmp_config_path,global_config_fn,'.mat']);

%% SETUP RADAR GRID

%load radar id
source_att   = h5readatt(h5_ffn,'/what','source');                                    
radar_id     = str2num(source_att(7:8));

%init transform
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];
load(transform_fn,'img_azi','img_rng','grid_size','geo_coords');
empty_grid    = nan(grid_size);
dbzh_grid     = empty_grid;
vradh_grid    = empty_grid;

%read number of groups
h5_info       = h5info(h5_ffn);
dataset_list  = {h5_info.Groups(1:end-3).Name};
dataset_count = length(dataset_list);

%preallocate matrices to build HDF5 coordinates and dump scan1 and
%scan2 data to improve performance
[vol_azi_vec,vol_rng_vec]   = process_read_ppi_dims(h5_ffn,1,true);
[vol_azi_grid,vol_rng_grid] = meshgrid(vol_azi_vec,vol_rng_vec); %grid for dataset
empty_vol  = nan(length(vol_rng_vec),length(vol_azi_vec),dataset_count);
empty_vec  = nan(dataset_count,1);
dbzh_vol   = empty_vol;
vradh_vol  = empty_vol;
elv_vec    = empty_vec;
start_dt   = [];


%load data frm h5 datasets into matrices
for i=1:dataset_count
    %load ppi attributes
    [ppi_elv,vol_time] = process_read_ppi_atts(h5_ffn,i);
    %skip ppi when error exists (indicated by zero elv angle)
    if isempty(ppi_elv)
        sig_flag = false;
        break %abort loop and set sig flag to false
    end
    elv_vec(i)         = ppi_elv;
    %assign start_dt for first ppi
    if i == 1
        start_dt = vol_time;
    end

    %read ppi data from file
    dataset_struct = process_read_ppi_data(h5_ffn,i);
	if isempty(dataset_struct)
		sig_flag = false;
		break %abort loop and set sig flag to false
	end
    ppi_dbzh       = dataset_struct.data1.data;
    ppi_vradh      = dataset_struct.data2.data;
    %if ppi data size does not matach volume size, interpolate to volume
    %coords
    if any(size(ppi_dbzh)~=size(empty_vol(:,:,1)))
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(dataset_struct.atts.azi_vec,dataset_struct.atts.rng_vec); %grid for ppi
        [vol_azi_grid,vol_rng_grid] = meshgrid(vol_azi_vec,vol_rng_vec);                                 %grid for volume
        ppi_dbzh                    = interp2(ppi_azi_grid,ppi_rng_grid,ppi_dbzh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
        ppi_vradh                   = interp2(ppi_azi_grid,ppi_rng_grid,ppi_vradh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
    end
    %allocate to radar volume
    dbzh_vol(:,:,i)  = ppi_dbzh;
    vradh_vol(:,:,i) = ppi_vradh;
    %check for signficant reflectivity in second ppi tilt
    if i == sig_refl_ppi_no
        sig_flag      = check_sig_refl(ppi_dbzh,vol_azi_grid,vol_rng_grid,img_azi,img_rng,ewt_a,ewt_saliency,h_grid);
        if ~sig_flag
            elv_vec   = elv_vec(1:2);
            dbzh_vol  = dbzh_vol(:,:,1:2);
            vradh_vol = vradh_vol(:,:,1:2);
            break
        end
    end
end

%data type flags
vradh_flag   = any(~isnan(vradh_vol(:)));
dualpol_flag = false;


%regrid if sig_refl
if sig_flag
    %load transformation coords
    if isempty(clim_radar_coords)
        load(transform_fn,'radar_coords');
    else
        radar_coords = clim_radar_coords;
    end
    radar_coords     = double(radar_coords)./100;

    %remove duplicate elevation entries
    [elv_vec,ia,~] = unique(elv_vec);
    dbzh_vol       = dbzh_vol(:,:,ia);
    vradh_vol      = vradh_vol(:,:,ia);
    
    %apply boundary filter
    filter_ind       = boundary_filter(radar_coords,min(elv_vec),max(elv_vec),min(vol_rng_vec),max(vol_rng_vec));
    radar_coords     = radar_coords(filter_ind,:);
    
    %convert to pixel coords
    [pix_azi,pix_rng,pix_elv] = vec2pix(vol_azi_vec,vol_rng_vec,elv_vec,radar_coords);

    %regrid dbzh
    dbzh_intp_vec               = run_mirt3D(dbzh_vol,pix_azi,pix_rng,pix_elv);
    dbzh_grid(filter_ind)       = dbzh_intp_vec;
    dbzh_grid(isnan(dbzh_grid)) = min_dbzh;

    %regrid vradh
    if vradh_flag
        %>>>>>>>>>>>>>Correct NI here!!!
        vradh_intp_vec              = run_mirt3D(vradh_vol,pix_azi,pix_rng,pix_elv);
        vradh_grid(filter_ind)      = vradh_intp_vec;
        dbzh_grid(isnan(dbzh_grid)) = min_vradh;
    else
        vradh_grid = [];
    end

    %regrid dualpol
    if dualpol_flag
    end
end

%output
grid_obj = struct('dbzh_grid',dbzh_grid,'vradh_grid',vradh_grid,...
    'lon_vec',geo_coords.radar_lon_vec,'lat_vec',geo_coords.radar_lat_vec,'alt_vec',geo_coords.radar_alt_vec,...
    'radar_id',radar_id,'start_dt',start_dt,...
    'radar_lat',geo_coords.radar_lat,'radar_lon',geo_coords.radar_lon,'radar_alt',geo_coords.radar_alt,...
    'sig_refl',sig_flag);

function out_flag = check_sig_refl(ppi_dbzh,ppi_azi_grid,ppi_rng_grid,img_azi,img_rng,ewt_a,ewt_saliency,h_grid)
%WHAT: takes a ppi volume and checks for significant reflectivity using
%ewt_a (lower refl) and ewt_salency thresholds (area)

%calc sig refl
dbzh_img        = interp2(ppi_azi_grid,ppi_rng_grid,ppi_dbzh,img_azi,img_rng,'nearest'); %interpolate scan into regridded coord%mask using ewt_a value
%apply ewt lower threshold
sigrefl_mask    = dbzh_img>=ewt_a;
%calc number of pixels required for saliency
h_grid          = deg2km(h_grid);
saliency_pixels = floor(ewt_saliency/(h_grid^2));
%remove regions smaller than saliency_pixels
sigrefl_mask    = bwareaopen(sigrefl_mask, saliency_pixels-1);
%set sig refl flag if any regions remain
if any(sigrefl_mask(:))
    out_flag = true;
else
    out_flag = false;
end

function [pix_azi,pix_rng,pix_elv]=vec2pix(azi_vec,rng_vec,elv_vec,r_coords)
%Inputs: a_vec=1xn vector of azimuth values, slant_r_vec=1xn value of ray
%distance value, elv_vec=1xn matrix of scan elevation of raw data volue,
%eval: The interpolation points
%Function: Converts the intperolation points from radar units into pixel
%units using linear approaches
%Output: azimuth, range and elevation from eval in pixel coordinates

%y=mx+c approach (monotonic azi and range)
azi_m   = (2-1)/(azi_vec(2)-azi_vec(1));
azi_c   = 1-azi_m*azi_vec(1);
pix_azi = r_coords(:,1).*azi_m+azi_c;

rng_m   = (2-1)/(rng_vec(2)-rng_vec(1));
rng_c   = 1-rng_m*rng_vec(1);
pix_rng = r_coords(:,2).*rng_m+rng_c;

%elevation vector is non-monotonic, use a 1D inteprolation method.
pix_elv = interp1(elv_vec',1:length(elv_vec),r_coords(:,3),'linear');

function intp_out = run_mirt3D(dbzh_vol,pix_azi,pix_rng,pix_elv)
%WHAT: run linear interpolation
intp_out = mirt3D_mexinterp(dbzh_vol,pix_azi,pix_rng,pix_elv);

function filter_ind = boundary_filter(radar_coords,elv_min,elv_max,rng_min,rng_max)
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filteradar_eval: values inside the bounds
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
filter_ind = find(radar_coords(:,3)>= elv_min & radar_coords(:,3)<=elv_max...
    & radar_coords(:,2)>=rng_min & radar_coords(:,2)<=rng_max);
