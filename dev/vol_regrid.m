function out_mat = vol_regrid(h5_ffn)

%load radar volume
%load output transform
%interpolate into output grid
%create sparse storm objects in national grid

addpath('bin')
read_site_info('site_info.txt')
load([tempdir,'site_info.txt','.mat'])

dbz_mask = 20;
%% SETUP RADAR GRID

%load radar id
source_att = h5readatt(h5_ffn,'/what','source');                                    
r_id       = str2num(source_att(7:8));

%read number of groups
h5_info       = h5info(h5_ffn);
dataset_list  = {h5_info.Groups(1:end-3).Name};
dataset_count = length(dataset_list);

%preallocate matrices to build HDF5 coordinates and dump scan1 and
%scan2 data to improve performance
[vol_azi_vec,vol_rng_vec] = read_ppi_dims(h5_ffn,1);
empty_vol = nan(length(vol_rng_vec),length(vol_azi_vec),dataset_count);
empty_vec = nan(dataset_count,1);
dbzh_vol  = empty_vol;
vradh_vol = empty_vol;
time_vol  = empty_vol;
elv_vec   = empty_vec;

%load data frm h5 datasets into matrices
for i=1:dataset_count
    [ppi_elv,ppi_time] = read_dataset_atts(h5_ffn,i);
    elv_vec(i)         = ppi_elv;
    time_vol(:,:,i)    = ones(length(vol_rng_vec),length(vol_azi_vec)).*ppi_time;
    
    if ppi_elv == 0
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'corrupt scan in h5 file in tilt: ',num2str(i));
        continue
    end
    dataset_struct = read_ppi_data(h5_ffn,i);
    ppi_dbzh       = dataset_struct.data1.data;
    ppi_vradh      = dataset_struct.data2.data;
    if any(size(ppi_dbzh)~=size(empty_vol(:,:,1)))
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(dataset_struct.atts.azi_vec,dataset_struct.atts.rng_vec); %grid for dataset
        [vol_azi_grid,vol_rng_grid] = meshgrid(vol_azi_vec,vol_rng_vec);                                 %grid for volume
        ppi_dbzh                    = interp2(ppi_azi_grid,ppi_rng_grid,ppi_dbzh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
        ppi_vradh                   = interp2(ppi_azi_grid,ppi_rng_grid,ppi_vradh,vol_azi_grid,vol_rng_grid,'nearest',NaN); %interpolate and extrap to 0
    end
    dbzh_vol(:,:,i)  = ppi_dbzh;
    vradh_vol(:,:,i) = ppi_vradh;
end

%load transformation coords
transform_fn = ['transforms/mosiac_transform_',num2str(r_id),'.mat'];
load(transform_fn);
r_coords     = double(r_coords)./100;
%convert to pixel coords
[pix_azi,pix_rng,pix_elv] = vec2pix(vol_azi_vec,vol_rng_vec,elv_vec,r_coords);

%regrid dbzh
dbzh_intp_vol  = run_mirt3D(dbzh_vol,pix_azi,pix_rng,pix_elv);%,r_size,filter_ind);
%regrid vradh
vradh_intp_vol = run_mirt3D(vradh_vol,pix_azi,pix_rng,pix_elv);%,r_size,filter_ind);
%regrid time
time_intp_vol  = interp3(time_vol,pix_azi,pix_rng,pix_elv,'nearest');
%apply dbzh filter
vol_filter     = dbzh_intp_vol>=dbz_mask;

%calculating weights
if isempty(dataset_struct.atts.NI) %nonDoppler radars
    weight1  = 3500;
    weight2  = 4;
else %Doppler Radars
    weight1  = 7000;
    weight2  = 1;  
end
r_weight = exp(-(r_coords(:,2).^2)./weight1)./weight2;
%For Doppler radars use weight1 = 3500, weight2 = 4
%this gives 0.25 @ 0km, 0.1 @ 55km, 0 @ 105km
%For nonDoppler radars, use weight1 = 7000, weight2 = 1
%this gives 1.0 @ 0 km, 0.25 @ 100km, 0.1 @ 125km, 0 @ 180km

%index, time, dbzh, vradh, weight
out_dbzh       = dbzh_intp_vol(vol_filter);
out_vradh      = vradh_intp_vol(vol_filter);
out_global_idx = double(global_index(vol_filter));
out_local_idx  = find(vol_filter);
out_time       = time_intp_vol(vol_filter);
out_weight     = r_weight(vol_filter);

out_mat        = [out_global_idx,out_local_idx,out_dbzh,out_vradh,out_time,out_weight];

%generate 3D grid ->
%merge same index using weighting ->
%allocate to grid
%reassemble 3D grid (looks like it'll have to sit in memory...

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

function intp_out = run_mirt3D(dbzh_vol,pix_azi,pix_rng,pix_elv)%,r_size,filter_ind)
%WHAT: run linear interpolation
intp_out = mirt3D_mexinterp(dbzh_vol,pix_azi,pix_rng,pix_elv);
%intp_vol = zeros(r_size(1)*r_size(2)*r_size(3),1);
%intp_vol(filter_ind) = intp_out;
%intp_vol = reshape(intp_vol,r_size(1),r_size(2),r_size(3));