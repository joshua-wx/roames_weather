function rw_merger

%load radar volume
%load output transform
%interpolate into output grid
%create sparse storm objects in national grid

read_site_info('site_info.txt')
load([tempdir,'site_info.txt','.mat'])

h5_ffn = 'data/28_20161203_043200.h5';

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
empty_vol = zeros(length(vol_rng_vec),length(vol_azi_vec),dataset_count,'uint8');
empty_vec = zeros(dataset_count,1);
dbzh_vol  = empty_vol;
vradh_vol = empty_vol;
elv_vec   = empty_vec;
time_vec  = empty_vec;

%load data frm h5 datasets into matrices
for i=1:dataset_count
    [ppi_elv,ppi_time] = read_dataset_atts(h5_ffn,i);
    elv_vec(i)         = ppi_elv;
    time_vec(i)        = ppi_time;
    
    if ppi_elv == 0
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'corrupt scan in h5 file in tilt: ',num2str(i));
        continue
    end
    dataset_struct = read_ppi_data(h5_ffn,i);
    ppi_dbzh       = dataset_struct.data1.data;
    ppi_vradh      = dataset_struct.data2.data;
    if ~any(size(ppi_dbzh)~=size(empty_vol(:,:,1)))
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(dataset_struct.atts.azi_vec,dataset_struct.atts.rng_vec); %grid for dataset
        [vol_azi_grid,vol_rng_grid] = meshgrid(vol_azi_vec,vol_rng_vec);                                 %grid for volume
        ppi_dbzh                    = interp2(ppi_azi_grid,ppi_rng_grid,ppi_dbzh,vol_azi_grid,vol_rng_grid,'nearest',0); %interpolate and extrap to 0
        ppi_vradh                   = interp2(ppi_azi_grid,ppi_rng_grid,ppi_vradh,vol_azi_grid,vol_rng_grid,'nearest',0); %interpolate and extrap to 0
    end
    dbzh_vol(:,:,i)  = ppi_dbzh;
    vradh_vol(:,:,i) = ppi_vradh;
end

keyboard
    
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
        data      = h5read(h5_ffn,['/',dataset_name,'/',data_name,'/data']);
        quantity  = deblank(h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'quantity'));
        offset    = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'offset');
        gain      = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'gain');
        nodata    = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'nodata');
        undetect  = h5readatt(h5_ffn,['/',dataset_name,'/',data_name,'/what'],'undetect');
        %add to struct
        dataset_struct.(data_name) = struct('data',data,'quantity',quantity,'offset',offset,'gain',gain,'nodata',nodata,'undetect',undetect);
    end
    %save nquist data
    if i>=2
        NI     = h5readatt(h5_ffn,['/',dataset_name,'/how'],'NI');
    else
        %dummy nyquist data
        NI     = '';
        dataset_struct.data2.data = zeros(size(data),'uint8');
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