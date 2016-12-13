function rw_merger

%load radar volume
%load output transform
%interpolate into output grid
%create sparse storm objects in national grid

read_site_info('site_info.txt')
load([tempdir,'site_info.txt','.mat'])

h5_ffn = '28_20161203_043200.h5';

%% SETUP RADAR GRID

%generate volume grid from dataset1
[vol_azi_vec,vol_rng_vec] = read_ppi_dims(h5_ffn,1);

%load radar id
source_att = h5readatt(h5_ffn,'/what','source');                                    
r_id       = str2num(source_att(7:8));

%read number of groups
h5_info       = h5info(h5_ffn);
dataset_list  = {h5_info.Groups(1:end-3).Name};
dataset_count = length(dataset_list);

%preallocate matrices to build HDF5 coordinates and dump scan1 and
%scan2 data to improve performance
empty_vol = zeros(length(vol_rng_vec),length(vol_azi_vec),dataset_count);
empty_vec = zeros(dataset_count,1);
dbzh_vol  = empty_vol;
vradh_vol = empty_vol;        
elv_vec   = empty_vec;
time_vec  = empty_vec;

%load data frm h5 datasets into matrices
for i=1:dataset_count
    [ppi_elv,ppi_time]       = read_dataset_atts(h5_ffn,i);
    if temp_elv == 0
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'corrupt scan in h5 file in tilt: ',num2str(i));
        continue
    end
    [ppi_dbzh,ppi_dbzh_vars] = read_data(h5_ffn,i,1,vol_rng_vec,vol_azi_vec);
    
    
    elv_vec(i)         = ppi_elv;
    time_vec(i)        = ppi_time;
    dbzh_vol(:,:,i)    = ppi_dbzh;
    if vel_flag == 1
        [~,~,ppi_vradh,ppi_vradh_vars] = read_radar_scan(h5_ffn,i,2,vol_rng_vec,vol_azi_vec);
        vradh_vol(:,:,i) = ppi_vradh;
    end
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



function [ppi_data,ppi_vars]=read_odimh5_data(h5_ffn,dataset_no,data_no,vol_rng_vec,vol_azi_vec)
%WHAT: reads scan and elv data from dataset_no from h5_ffn.
%INPUTS:
%h5_ffn: path to h5 file
%dataset_no: dataset number in h file
%slant_r_vec: slant_r coordinate vector
%a_vec: azimuth coordinates vector
%OUTPUTS:
%elv: elevation angle of radar beam
%pol_data: polarmetric data

ppi_data = [];
ppi_vars = [];

try
    %extract ppi dims
    [ppi_azi_vec,ppi_rng_vec] = read_ppi_dims(h5_ffn,dataset_no);
    %refl data (data no 1)
    [ppi_data,ppi_vars] = extract_odimh5_ppi(h5_ffn,dataset_no,1,ppi_azi_vec,ppi_rng_vec,vol_azi_vec,vol_rng_vec);
catch
    disp(['/dataset',num2str(dataset_no),' is broken']);
end




function [ppi_data,ppi_vars] = extract_odimh5_ppi(h5_ffn,dataset_no,data_no,ppi_azi_vec,ppi_rng_vec,vol_azi_vec,vol_rng_vec)

%TO FINISH

%extract data and vars
ppi_data   = double(h5read(h5_ffn,strcat('/dataset',num2str(dataset_no),'/data',num2str(data_no),'/data')));
ppi_gain   = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data',num2str(data_no),'/what/'],'gain');
ppi_offset = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data',num2str(data_no),'/what/'],'offset');
%collate variables
ppi_vars = [ppi_gain,ppi_offset];
%vel ni
if data_no == 2
    vel_ni = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/how/'],'NI');
    ppi_vars = [ppi_vars,vel_ni];
end
%wrap 0deg to 360deg ray
ppi_data   = cat(2,ppi_data,ppi_data(:,1));
%interpolate if dataset dims are different size from vol dim vecs
if length(ppi_rng_vec)~=length(vol_rng_vec) || length(ppi_rng_vec)~=length(vol_azi_vec)
    [data_az_grid,data_sl_grid] = meshgrid(data_a_vec,data_slant_r_vec);   %grid for dataset
    [vol_az_grid, vol_sl_grid]  = meshgrid(vol_a_vec,vol_slant_r_vec);             %grid for volume
    ppi_data                    = interp2(data_az_grid,data_sl_grid,ppi_data,vol_az_grid,vol_sl_grid,'nearest',0); %interpolate and extrap to 0
end
      

function [azi_vec,rng_vec] = read_ppi_dims(h5_ffn,dataset_no)
dataset_no_str = num2str(dataset_no);
%azimuth (deg)
n_rays   = double(h5readatt(h5_ffn,'/dataset',dataset_no_str,'/where','nrays'));                     %number of rays
azi_vec  = linspace(0,360,n_rays+1); azi_vec = azi_vec(1:end-1);                    %azimuth vector, without end point
%slant range (km)
r_bin    = double(h5readatt(h5_ffn,'/dataset',dataset_no_str,'/where','rscale'))./1000;              %range bin size
r_start  = double(h5readatt(h5_ffn,'/dataset',dataset_no_str,'/where','rstart'));                    %starting range of radar
r_range  = double(h5readatt(h5_ffn,'/dataset',dataset_no_str,'/where','nbins'))*r_bin+r_start-r_bin; %number of range bins
rng_vec  = r_start:r_bin:r_range; 