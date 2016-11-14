function [vol_obj,vol_refl_out,vol_vel_out]=vol_regrid(h5_ffn,aazi_grid,sl_rrange_grid,eelv_grid,no_datasets,vel_flag)
%WHAT
%Regrids 3D polarmetic data into cartesian coordinates using a max library

%INPUT
%h5_ffn: h5 h5_ffn
%aazi_grid: azi coord for regridding into
%sl_range_grid: slant range coord for regridding into
%eelv_grid: elv coord for regridding into
%no_datasets: number of datasets in h5 file, output of QA

%OUTPUT:
%intp_struct: contains fields of lon_vev (regridded lon coordinates), lat_vec (regridded lat coordinates, z_vec_asml (regridded z coord),
    %region_latlonbox (sscan latlongbox), start_timedate, stop_timedate,
    %radar_id, sig_refl (sig_refl_count_thresh threshold), sscan (surface scan
    %image)
%v: regridded volume with coordinates lat,lon,z vec.

%Load config file
load('tmp/global.config.mat');
load('tmp/site_info.txt.mat');

%% SETUP STANDARD GRID FOR SPH->POL->CART TRANFORMS

%pol grid constants
r_width     = 360/double(h5readatt(h5_ffn,'/dataset1/where','nrays'));                 %deg, beam width
a_vec       = 0:r_width:360;                                                             %deg, azimuth vector
r_bin       =  double(h5readatt(h5_ffn,'/dataset1/where','rscale'));                   %m, range bin size (range res)
r_start     = double(h5readatt(h5_ffn,'/dataset1/where','rstart'))*1000;               %m, range of radar
r_range     = double(h5readatt(h5_ffn,'/dataset1/where','nbins'))*r_bin+r_start-r_bin; %m, range of radar
slant_r_vec = r_start:r_bin:r_range;                                                     %m,   slant range (along ray)

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

%% EXTRACT SURFACE SCAN
% Interpolate a surface scane image into carteisan coord
[scan1_elv,scan1_refl,refl_vars,scan1_vel,vel_vars] = read_radar_scan(h5_ffn,1,slant_r_vec,a_vec,vel_flag);
[scan2_elv,scan2_refl,~,scan2_vel,~]                = read_radar_scan(h5_ffn,2,slant_r_vec,a_vec,vel_flag);

%setup interpolation grid
[imgrid_a,imgrid_sr]           = meshgrid(a_vec,slant_r_vec);   %coordinate for surface image
[imgrid_x,imgrid_y]            = meshgrid(x_vec,y_vec);         %coordinates for regridded image
[imgrid_intp_a,imgrid_intp_sr] = cart2pol(imgrid_x,imgrid_y);   %convert regridd coord into polar

%interpolate refl scans
scan1_refl_out = interp2(imgrid_a,imgrid_sr,scan1_refl,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan1 into convereted regridded coord
scan1_refl_out = rot90(scan1_refl_out,3); %orientate
tilt1          = scan1_elv;
scan2_refl_out = interp2(imgrid_a,imgrid_sr,scan2_refl,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan2 into convereted regridded coord
scan2_refl_out = rot90(scan2_refl_out,3); %orientate
tilt2          = scan2_elv;
%interpolate vel scans
if vel_flag == 1
    scan1_vel_out = interp2(imgrid_a,imgrid_sr,scan1_vel,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan1 into convereted regridded coord
    scan1_vel_out = rot90(scan1_vel_out,3); %orientate
    scan2_vel_out = interp2(imgrid_a,imgrid_sr,scan2_vel,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan2 into convereted regridded coord
    scan2_vel_out = rot90(scan2_vel_out,3); %orientate
else
    scan1_vel_out=[];
    scan2_vel_out=[];
end

%% Generate mapping coordinates
%mapping coordinates, working in ij coordinates
mstruct        = defaultm('mercator');
mstruct.origin = [r_lat r_lon];
mstruct.geoid  = almanac('earth','wgs84','meters');
mstruct        = defaultm(mstruct);
%transfore x,y into lat long using centroid
[lat_vec, lon_vec]     = minvtran(mstruct, x_vec, x_vec);
[r_lat_vec, r_lon_vec] = minvtran(mstruct, [0,0,x_vec(1),x_vec(end)], [y_vec(1),y_vec(end),0,0]);
region_latlonbox       = [max(r_lat_vec);min(r_lat_vec);max(r_lon_vec);min(r_lon_vec)];

%% INTERPOLATE
%WHAT: Check for significant convection by masking to ewt_a and checking saliency
%criteria

%mask scan
try
    temp_scan       = double(scan2_refl_out).*refl_vars(1)+refl_vars(2);
catch
    vol_obj      = [];
    vol_refl_out = [];
    vol_vel_out  = [];
    return
end    
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

%for sig_refl, load all radar data and regrid into cartesian coordinates
if sig_refl == 1

    %preallocate matrices to build HDF5 coordinates and dump scan1 and
    %scan2 data to improve performance
    refl_vol        = zeros(length(slant_r_vec),length(a_vec),no_datasets);    %dBZ, HDF5 radar data
    refl_vol(:,:,1) = scan1_refl; refl_vol(:,:,2) = scan2_refl;
    elv_vec         = zeros(no_datasets,1);                                    %deg, ray elevation data
    elv_vec(1)      = scan1_elv; elv_vec(2) = scan2_elv;
    if vel_flag == 1
        vel_vol        = zeros(length(slant_r_vec),length(a_vec),no_datasets); %m/s, HDF5 radar data
        vel_vol(:,:,1) = scan1_vel; vel_vol(:,:,2) = scan2_vel;
    end
    %load data frm h5 datasets into matrices
    for i=3:no_datasets
        [temp_elv,temp_refl,~,temp_vel,~] = read_radar_scan(h5_ffn,i,slant_r_vec,a_vec,vel_flag);
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
    [~,uniq_elv_idx] = unique(elv_vec);
    if length(elv_vec)~=length(uniq_elv_idx)
        log_cmd_write('tmp/process_regrid.log',h5_ffn,'duplicate scan in h5 file','');
        %exit interpolation and return blank entires
        elv_vec  = elv_vec(uniq_elv_idx);
        refl_vol = refl_vol(:,:,uniq_elv_idx);
        if vel_flag == 1
            vel_vol = vel_vol(:,:,uniq_elv_idx);
        end 
    end
    
    %% start regrid process
    %vectorise range, azi and elv
    eval = [aazi_grid(:),sl_rrange_grid(:),eelv_grid(:)];
    eval_length = length(eval);
    %filter out boundaries
    [inside_ind,filt_eval] = boundary_filter(eval,elv_vec,slant_r_vec(2)-slant_r_vec(1),slant_r_vec(end));
    %convert to pixel coordinates for interpolation
    [pix_a,pix_r,pix_e] = vec2pix(a_vec,slant_r_vec,elv_vec,filt_eval);
    
    %regrid refl into cartesian
    %run interp C function
    refl_vol(refl_vol==0)=NaN;
    intp_refl = mirt3D_mexinterp(refl_vol,pix_a,pix_r,pix_e);
    intp_refl = uint8(intp_refl);
    %resize to 3D array
    vol_refl_out = zeros(eval_length,1,'uint8');
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
        intp_vel = uint8(intp_vel);
        %resize to 3D array
        vol_vel_out = zeros(eval_length,1,'uint8');
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
    vol_refl_out = double(vol_refl_out).*refl_vars(1)+refl_vars(2);
end
if ~isempty(vol_vel_out)
    vol_vel_out  = double(vol_vel_out).*vel_vars(1)+vel_vars(2);
    vel_ni       = vel_vars(3);
else
    vel_ni       = 0;
end

%output into struct vol_obj
vol_obj = struct('lon_vec',lon_vec,'lat_vec',lat_vec,'z_vec_amsl',z_vec+r_elv,...
    'llb',region_latlonbox,'start_timedate',start_timedate,...
    'r_lat',r_lat,'r_lon',r_lon,...
    'radar_id',radar_id,'sig_refl',sig_refl,...
    'scan1_refl',scan1_refl_out,'scan2_refl',scan2_refl_out,...
    'scan1_vel',scan1_vel_out,'scan2_vel',scan2_vel_out,'vel_ni',vel_ni,...
    'tilt1',tilt1,'tilt2',tilt2,'refl_vars',refl_vars,'vel_vars',vel_vars);


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

function [elv,refl_data,refl_vars,vel_data,vel_vars]=read_radar_scan(h5_ffn,dataset_no,slant_r_vec,a_vec,vel_flag)
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
    %extract constants from what group for the dataset
    elv      = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/where/'],'elangle');
    vel_data = [];
    vel_vars = [];
    %read reflectivity data from hdf5 file, and scaling formula parameters, apply the forumla
    refl_data   = h5read(h5_ffn,['/dataset',num2str(dataset_no),'/data1/data']);
    refl_gain   = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data1/what/'],'gain');
    refl_offset = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data1/what/'],'offset');
    %keep transformation variables
    refl_vars   = [refl_gain,refl_offset];
    %ensure continuity
    refl_data   = cat(2,refl_data,refl_data(:,1));

    %pad refl range dim with zeros if scan is cut short (repair data) or too
    %long
    range_padding = length(slant_r_vec)-size(refl_data,1);
    if range_padding>0
        refl_data = [refl_data;zeros(range_padding,length(a_vec),'uint8')];
    elseif range_padding<0
        refl_data = refl_data(1:end+range_padding,:);
    end
    %vel data
    if vel_flag == 1
        vel_data   = h5read(h5_ffn,strcat('/dataset',num2str(dataset_no),'/data2/data'));
        vel_gain   = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data2/what/'],'gain');
        vel_offset = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/data2/what/'],'offset');
        vel_ni     = hdf5read(h5_ffn,['/dataset',num2str(dataset_no),'/how/'],'NI');
        %keep transformation variables
        vel_vars   = [vel_gain,vel_offset,vel_ni];
        %ensure continuity
        vel_data   = cat(2,vel_data,vel_data(:,1));
        %pad refl range dim with zeros if scan is cut short (repair data) or too
        %long
        range_padding = length(slant_r_vec)-size(vel_data,1);
        if range_padding>0
            vel_data = [vel_data;zeros(range_padding,length(a_vec),'uint8')];
        elseif range_padding<0
            vel_data = vel_data(1:end+range_padding,:);
        end
    end
catch
    disp(['/dataset',num2str(dataset_no),' is broken']);
    elv       = 0;
    vel_data  = zeros(length(slant_r_vec),length(a_vec),'uint8');
    vel_vars  = [];
    refl_data = zeros(length(slant_r_vec),length(a_vec),'uint8');
    refl_vars = [];
end
