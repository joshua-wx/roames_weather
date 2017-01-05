function grid_obj = process_vol_regrid(h5_ffn)
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
transform_fn = ['transforms/regrid_transform_',num2str(radar_id),'.mat'];
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
[vol_azi_vec,vol_rng_vec] = read_ppi_dims(h5_ffn,1);
empty_vol  = nan(length(vol_rng_vec),length(vol_azi_vec),dataset_count);
empty_vec  = nan(dataset_count,1);
dbzh_vol   = empty_vol;
vradh_vol  = empty_vol;
elv_vec    = empty_vec;
start_dt   = [];

%load data frm h5 datasets into matrices
for i=1:dataset_count
    %load ppi attributes
    [ppi_elv,ppi_time] = read_dataset_atts(h5_ffn,i);
    elv_vec(i)         = ppi_elv;
    %assign start_dt for first ppi
    if i == 1
        start_dt       = ppi_time;
    end
    %skip ppi when error exists (indicated by zero elv angle)
    if ppi_elv == 0
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'corrupt scan in h5 file in tilt: ',num2str(i));
        continue
    end
    %read ppi data from file
    dataset_struct = read_ppi_data(h5_ffn,i);
    ppi_dbzh       = dataset_struct.data1.data;
    ppi_vradh      = dataset_struct.data2.data;
    %if ppi data size does not matach volume size, interpolate to volume
    %coords
    if any(size(ppi_dbzh)~=size(empty_vol(:,:,1)))
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(dataset_struct.atts.azi_vec,dataset_struct.atts.rng_vec); %grid for dataset
        [vol_azi_grid,vol_rng_grid] = meshgrid(vol_azi_vec,vol_rng_vec);                                 %grid for volume
        ppi_dbzh                    = interp2(ppi_azi_grid,ppi_rng_grid,ppi_dbzh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
        ppi_vradh                   = interp2(ppi_azi_grid,ppi_rng_grid,ppi_vradh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
    end
    %allocate to radar volume
    dbzh_vol(:,:,i)  = ppi_dbzh;
    vradh_vol(:,:,i) = ppi_vradh;
    %check for signficant reflectivity in second ppi tilt
    if i == sig_refl_ppi_no
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(dataset_struct.atts.azi_vec,dataset_struct.atts.rng_vec); %grid for dataset
        sig_flag                    = check_sig_refl(ppi_dbzh,ppi_azi_grid,ppi_rng_grid,img_azi,img_rng,ewt_a,ewt_saliency,h_grid);
        if ~sig_flag
            elv_vec   = elv_vec(1:2);
            dbzh_vol  = dbzh_vol(:,:,1:2);
            vradh_vol = vradh_vol(:,:,1:2);
            break
        end
    end
end

%regrid if sig_refl
if sig_flag
    %load transformation coords
    load(transform_fn,'radar_coords','filter_ind');
    radar_coords     = double(radar_coords)./100;

    %convert to pixel coords
    [pix_azi,pix_rng,pix_elv] = vec2pix(vol_azi_vec,vol_rng_vec,elv_vec,radar_coords);

    %regrid dbzh
    dbzh_intp_vec  = run_mirt3D(dbzh_vol,pix_azi,pix_rng,pix_elv);%,r_size,filter_ind);
    %regrid vradh
    vradh_intp_vec = run_mirt3D(vradh_vol,pix_azi,pix_rng,pix_elv);%,r_size,filter_ind);

    %>>>>>>>>>>>>>Correct NI here!!!

    %index, time, dbzh, vradh, weight
    dbzh_grid(filter_ind)  = dbzh_intp_vec;
    vradh_grid(filter_ind) = vradh_intp_vec;
end

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
saliency_pixels = floor(ewt_saliency/h_grid*h_grid);
%remove regions smaller than saliency_pixels
sigrefl_mask    = bwareaopen(sigrefl_mask, saliency_pixels-1);
%set sig refl flag if any regions remain
if any(sigrefl_mask(:))
    out_flag = true;
else
    out_flag = false;
end

function [ppi_elv,ppi_time]=read_dataset_atts(h5_ffn,dataset_no)
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
ppi_time = [];

try
    %extract constants from what group for the dataset
    ppi_elv      = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/where/'],'elangle');
    start_date   = deblank(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/what/'],'startdate'));
    start_time   = deblank(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/what/'],'starttime'));
    ppi_time     = datenum([start_date,start_time],'yyyymmddHHMMSS');
catch
    disp(['/dataset',num2str(dataset_no),' is broken']);
end


function dataset_struct = read_ppi_data(h5_ffn,dataset_no)

%WHAT: reads ppi from odimh5 volumes into a struct included the required
%variables

%init
dataset_struct = [];
try
    %set dataset name
    dataset_name = ['dataset',num2str(dataset_no)];
    %index data groups
    data_info = h5info(h5_ffn,['/',dataset_name,'/']);
    num_data = length(data_info.Groups)-3; %remove index for what/where/how groups
    %loop through all data sets
    for i=1:num_data
        %read data
        data_name = ['data',num2str(i)];
        data      = double(h5read(h5_ffn,['/',dataset_name,'/',data_name,'/data']));
        quantity  = deblank(h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'quantity'));
        offset    = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'offset');
        gain      = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'gain');
        nodata    = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'nodata');
        undetect  = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'undetect');
        %unpack data
        data(data == nodata | data == undetect) = nan;
        data = (data.*gain) + offset;
        %add to struct
        dataset_struct.(data_name) = struct('data',data,'quantity',quantity);
    end
    %save nquist data
    if i>=2
        NI     = h5readatt(h5_ffn,['/',dataset_name,'/how'],'NI');
    else
        %dummy nyquist data
        NI     = '';
        dataset_struct.data2.data = nan(size(data));
    end
    %read dimensions
    [azi_vec,rng_vec] = read_ppi_dims(h5_ffn,dataset_no);
    dataset_struct.atts = struct('NI',NI,'azi_vec',azi_vec,'rng_vec',rng_vec);
catch err
    disp(['/dataset',num2str(dataset_no),' is broken']);
end  
        

function [azi_vec,rng_vec] = read_ppi_dims(h5_ffn,dataset_no)

%WHAT: reads dims variables from dataset and generates azimuth and rng
%vectors

dataset_no_str = num2str(dataset_no);
%azimuth (deg)
n_rays   = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'nrays'));                     %number of rays
azi_vec  = linspace(0,360,n_rays+1); azi_vec = azi_vec(1:end-1);                    %azimuth vector, without end point
%slant range (km)
r_bin    = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'rscale'))./1000;              %range bin size
r_start  = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'rstart'));                    %starting range of radar
r_range  = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'nbins'))*r_bin+r_start-r_bin; %number of range bins
rng_vec  = r_start:r_bin:r_range;

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
