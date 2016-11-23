function [vol_obj,vol_refl_out,vol_vel_out] = process_vol_regrid(h5_ffn,aazi_grid,sl_rrange_grid,eelv_grid,no_datasets,vel_flag)
%WHAT
%Regrids 3D polarmetic data into cartesian coordinates using a max library

%INPUT
%h5_ffn: h5 h5_ffn
%aazi_grid: azi coord for regridding into
%sl_range_grid: slant range coord for regridding into
%eelv_grid: elv coord for regridding into
%no_datasets: number of datasets in h5 file, output of QA

%OUTPUT:
%vol_obj: struct containing attributes for radar data volume
%vol_refl_out: regridded reflectivity
%vol_vel_out:  regridded doppler velocity

%Load config file
load('tmp/global.config.mat');
load('tmp/site_info.txt.mat');
%% SETUP STANDARD GRID FOR SPH->POL->CART TRANFORMS

%pol grid constants
n_rays      = double(h5readatt(h5_ffn,'/dataset1/where','nrays'));                     %deg, beam width
a_vec       = linspace(0,360,n_rays+1);                                                %deg, azimuth vector, duplicating 0 ray to 360
r_bin       = double(h5readatt(h5_ffn,'/dataset1/where','rscale'));                    %m, range bin size (range res)
r_start     = double(h5readatt(h5_ffn,'/dataset1/where','rstart'))*1000;               %m, range of radar
r_range     = double(h5readatt(h5_ffn,'/dataset1/where','nbins'))*r_bin+r_start-r_bin; %m, range of radar
slant_r_vec = r_start:r_bin:r_range;                                                   %m,   slant range (along ray)

%load radar id
source   = h5readatt(h5_ffn,'/what','source');                                         %source text tag (contains radar id)
radar_id = str2num(source(7:8));

%use radar id to load radar centroid from site_info matrix
site_ind = find(radar_id==site_id_list);
r_lat    = double(site_centroid(site_ind,1)); %negated
r_lon    = double(site_centroid(site_ind,2));
r_elv    = double(site_centroid(site_ind,3));

%read the following paraters
start_date = deblank(h5readatt(h5_ffn,['/dataset',num2str(1),'/what/'],'startdate'));
start_time = deblank(h5readatt(h5_ffn,['/dataset',num2str(1),'/what/'],'starttime'));

%collate time values
start_timedate  = datenum([start_date,start_time(1:4)],'yyyymmddHHMM');

%cartesian grid setup
x_vec = -h_range:h_grid:h_range;                              %m, X domain vector
y_vec = -h_range:h_grid:h_range;                              %m, Y domain vector
z_vec = [v_grid:v_grid:v_range]';                             %m, Z domain vector, adjusted for radar height

%% Generate mapping coordinates
%mapping coordinates, working in ij coordinates
mstruct        = defaultm('mercator');
mstruct.origin = [r_lat r_lon];
mstruct.geoid  = almanac('earth','wgs84','meters');
mstruct        = defaultm(mstruct);
%transfore x,y into lat long using centroid
[lat_vec, lon_vec]     = minvtran(mstruct, x_vec, x_vec);

%% EXTRACT SURFACE SCAN FOR SIG_REFL CHECK
% Interpolate a surface scane image into carteisan coord
[~,sig_refl_data,sig_refl_vars,~,~,~] = read_radar_scan(h5_ffn,sig_refl_sweep,slant_r_vec,a_vec,0);

%setup interpolation grid
[imgrid_a,imgrid_sr]           = meshgrid(a_vec,slant_r_vec);   %coordinate for surface image
[imgrid_x,imgrid_y]            = meshgrid(x_vec,y_vec);         %coordinates for regridded image
[imgrid_intp_a,imgrid_intp_sr] = cart2pol(imgrid_x,imgrid_y);   %convert regridd coord into polar

%extract ppi sweep 2 to check sig_refl
sig_refl_intp = interp2(imgrid_a,imgrid_sr,sig_refl_data,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan2 into convereted regridded coord
sig_refl_intp = rot90(sig_refl_intp,3); %orientate

%transform to radar coords
temp_scan       = sig_refl_intp.*sig_refl_vars(1)+sig_refl_vars(2);

%mask using ewt_a value
temp_mask       = temp_scan>=ewt_a;
%calc number of pixels required for saliency
saliency_pixels = floor(ewt_saliency/h_grid*h_grid);
%remove regions smaller than saliency_pixels
temp_mask       = bwareaopen(temp_mask, saliency_pixels-1);
%set sig refl flag if any regions remain
if any(temp_mask(:))
    sig_refl = 1;
else
    sig_refl = 0;
end

%% INTERPOLATION
%for sig_refl, load all radar data and regrid into cartesian coordinates
if sig_refl == 1

    %preallocate matrices to build HDF5 coordinates and dump scan1 and
    %scan2 data to improve performance
    refl_vol        = zeros(length(slant_r_vec),length(a_vec),no_datasets);    %dBZ, HDF5 radar data
    elv_vec         = zeros(no_datasets,1);                                    %deg, ray elevation data
    if vel_flag == 1
        vel_vol     = zeros(length(slant_r_vec),length(a_vec),no_datasets); %m/s, HDF5 radar data
    end
    %load data frm h5 datasets into matrices
    for i=1:no_datasets
        [temp_elv,temp_refl,~,temp_vel,~,~] = read_radar_scan(h5_ffn,i,slant_r_vec,a_vec,vel_flag);
        if temp_elv == 0
            log_cmd_write('tmp/process_regrid.log',h5_ffn,'corrupt scan in h5 file in tilt: ',num2str(i));
            continue
        end
        elv_vec(i)         = temp_elv;
        refl_vol(:,:,i)    = temp_refl;
        if vel_flag == 1
            vel_vol(:,:,i) = temp_vel;
        end
    end
    %remove empty corrupt scans from vols
    zero_mask = elv_vec == 0;
    elv_vec(zero_mask) = [];
    refl_vol(:,:,zero_mask) = [];
    if vel_flag == 1
        vel_vol(:,:,zero_mask)=[];
    end
    %check for duplicate elevations
    [~,uniq_elv_idx]   = unique(elv_vec);
    if length(elv_vec)~=length(uniq_elv_idx)
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'duplicate scan in h5 file','');
        %exit interpolation and return blank entires
        elv_vec     = elv_vec(uniq_elv_idx);
        refl_vol    = refl_vol(:,:,uniq_elv_idx);
        if vel_flag == 1
            vel_vol = vel_vol(:,:,uniq_elv_idx);
        end 
    end
    
    %% start regrid process
    %vectorise range, azi and elv
    eval        = [aazi_grid(:),sl_rrange_grid(:),eelv_grid(:)];
    eval_length = length(eval);
    %filter out boundaries
    [inside_ind,filt_eval] = boundary_filter(eval,elv_vec,slant_r_vec(2)-slant_r_vec(1),slant_r_vec(end));
    %convert to pixel coordinates for interpolation
    [pix_a,pix_r,pix_e]    = vec2pix(a_vec,slant_r_vec,elv_vec,filt_eval);
    
    %regrid refl into cartesian
    %run interp C function
    refl_vol(refl_vol==0)=NaN;
    intp_refl = mirt3D_mexinterp(refl_vol,pix_a,pix_r,pix_e);
    %resize to 3D array
    vol_refl_out = zeros(eval_length,1);
    vol_refl_out(inside_ind) = intp_refl;
    sizev        = size(aazi_grid);
    vol_refl_out = reshape(vol_refl_out,sizev(1),sizev(2),sizev(3));
    %rotate in the from x-y to i-j
    vol_refl_out = permute(vol_refl_out,[2,1,3]);
    vol_refl_out = flip(vol_refl_out,1);
    vol_refl_out = flip(vol_refl_out,2);
    
    %regrid vel into cartesian
    if vel_flag == 1
        %run interp C function
        vel_vol(vel_vol==0) = NaN;
        intp_vel = mirt3D_mexinterp(vel_vol,pix_a,pix_r,pix_e);
        %resize to 3D array
        vol_vel_out = zeros(eval_length,1);
        vol_vel_out(inside_ind) = intp_vel;
        sizev       = size(aazi_grid);
        vol_vel_out = reshape(vol_vel_out,sizev(1),sizev(2),sizev(3));
        
        %rotate in the from x-y to i-j
        vol_vel_out = permute(vol_vel_out,[2,1,3]);
        vol_vel_out = flip(vol_vel_out,1);
        vol_vel_out = flip(vol_vel_out,2);
    else
        vol_vel_out = [];
    end
    
else
    vol_refl_out = [];
    vol_vel_out  = [];
end

%rescale/offset data
if ~isempty(vol_refl_out)
    vol_refl_out = vol_refl_out.*refl_vars(1)+refl_vars(2);
end
if ~isempty(vol_vel_out)
    vol_vel_out  = vol_vel_out.*vel_vars(1)+vel_vars(2);
    vel_ni       = vel_vars(3);
else
    vel_ni       = 0;
end

%output into struct vol_obj
vol_obj = struct('lon_vec',lon_vec,'lat_vec',lat_vec,'z_vec_amsl',z_vec+r_elv,...
    'start_timedate',start_timedate,...
    'r_lat',r_lat,'r_lon',r_lon,...
    'radar_id',radar_id,'sig_refl',sig_refl,'vel_ni',vel_ni,...
    'refl_vars',refl_vars,'vel_vars',vel_vars);


function [inside_ind,filt_eval] = boundary_filter(eval,elv_vec,r_min,r_max)
%Inputs r_min=r_bin, r_max=r_range, elv_vector, and the eval coordinates
%Function: identifies the indicies of bins outsite the natural radar domain
%and also selects the inside values
%Outputs: inside_ind: linear index marix of values of eval inside bounds,
%filter_eval: values inside the bounds
elv_min = min(elv_vec);
elv_max = max(elv_vec);
%find ind of data points inside bounds (eval(1) is elevation, eval(2) is
%range)
inside_ind = find(eval(:,3)>= elv_min & eval(:,3)<=elv_max...
    & eval(:,2)>=r_min & eval(:,2)<=r_max);
filt_eval  = eval(inside_ind,:);

function [pix_a,pix_r,pix_e]=vec2pix(a_vec,slant_r_vec,elv_vec,eval)
%Inputs: a_vec=1xn vector of azimuth values, slant_r_vec=1xn value of ray
%distance value, elv_vec=1xn matrix of scan elevation of raw data volue,
%eval: The interpolation points
%Function: Converts the intperolation points from radar units into pixel
%units using linear approaches
%Output: azimuth, range and elevation from eval in pixel coordinates

%y=mx+c approach (monotonic azi and range)
azi_m = (2-1)/(a_vec(2)-a_vec(1));
azi_c = 1-azi_m*a_vec(1);
pix_a = eval(:,1).*azi_m+azi_c;

rang_m = (2-1)/(slant_r_vec(2)-slant_r_vec(1));
rang_c = 1-rang_m*slant_r_vec(1);
pix_r  = eval(:,2).*rang_m+rang_c;

%elevation vector is non-monotonic, use a 1D inteprolation method.
pix_e = interp1(elv_vec',1:length(elv_vec),eval(:,3),'pchip');

function [elv,refl_data,refl_vars,vel_data,vel_vars,vel_ni]=read_radar_scan(h5_ffn,dataset_no,vol_slant_r_vec,vol_a_vec,vel_flag)
%WHAT: reads scan and elv data from dataset_no from h5_ffn.
%INPUTS:
%h5_ffn: path to h5 file
%dataset_no: dataset number in h file
%slant_r_vec: slant_r coordinate vector
%a_vec: azimuth coordinates vector
%OUTPUTS:
%elv: elevation angle of radar beam
%pol_data: polarmetric data
try
    %extract data dims
    data_n_rays      = double(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/where'],'nrays'));                       %number of rays
    data_a_vec       = linspace(0,360,data_n_rays+1);                                                                   %wrap to 360 by duplicating first ray
    data_r_bin       = double(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/where'],'rscale'));                      %m, range bin size (range res)
    data_r_start     = double(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/where'],'rstart'))*1000;                 %m, range of radar
    data_r_range     = double(h5readatt(h5_ffn,['/dataset',num2str(dataset_no),'/where'],'nbins'))*data_r_bin+data_r_start-data_r_bin; %m, range of radar
    data_slant_r_vec = data_r_start:data_r_bin:data_r_range;                                                            %m,   slant range (along ray)
    %extract constants from what group for the dataset
    elv      = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/where/'],'elangle');
    %refl data (data no 1)
    [refl_data,refl_vars,~] = extract_odimh5_ppi(h5_ffn,dataset_no,1,data_a_vec,data_slant_r_vec,vol_a_vec,vol_slant_r_vec);
    %vel data (data no 2)
    if vel_flag == 1
        [vel_data,vel_vars,vel_ni] = extract_odimh5_ppi(h5_ffn,dataset_no,2,data_a_vec,data_slant_r_vec,vol_a_vec,vol_slant_r_vec);
    else
        vel_data = [];
        vel_vars = [];
        vel_ni   = [];
    end
catch
    disp(['/dataset',num2str(dataset_no),' is broken']);
    elv       = 0;
    vel_data  = zeros(length(slant_r_vec),length(a_vec));
    vel_vars  = []; vel_ni = [];
    refl_data = zeros(length(slant_r_vec),length(a_vec));
    refl_vars = [];
end

function [ppi_data,ppi_vars,vel_ni] = extract_odimh5_ppi(h5_ffn,dataset_no,data_no,data_a_vec,data_slant_r_vec,vol_a_vec,vol_slant_r_vec)

%extract data and vars
ppi_data   = double(h5read(h5_ffn,strcat('/dataset',num2str(dataset_no),'/data',num2str(data_no),'/data')));
ppi_gain   = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data',num2str(data_no),'/what/'],'gain');
ppi_offset = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data',num2str(data_no),'/what/'],'offset');
%collate variables
ppi_vars = [ppi_gain,ppi_offset];
%vel ni
if data_no == 2
    vel_ni = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/how/'],'NI');
else
    vel_ni = [];
end
%wrap 0deg to 360deg ray
ppi_data   = cat(2,ppi_data,ppi_data(:,1));
%interpolate if dataset dims are different size from vol dim vecs
if length(data_slant_r_vec)~=length(slant_r_vec) || length(data_a_vec)~=length(a_vec)
    [data_az_grid,data_sl_grid] = meshgrid(data_a_vec,data_slant_r_vec);   %grid for dataset
    [vol_az_grid, vol_sl_grid]  = meshgrid(vol_a_vec,vol_slant_r_vec);             %grid for volume
    ppi_data                    = interp2(data_az_grid,data_sl_grid,ppi_data,vol_az_grid,vol_sl_grid,'linear',0); %interpolate and extrap to 0
end
        
