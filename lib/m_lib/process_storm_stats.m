function ident_obj = process_storm_stats(grid_obj,refl_img,ewtBasinExtend,snd_fz_h,snd_minus20_h)

%Load config file
load('tmp/global.config.mat');

%extract data
refl_vol = grid_obj.dbzh_grid;
vel_vol  = grid_obj.vradh_grid;

%create blank ident_obj
ident_obj = struct ('subset_refl',[],'subset_vel',[],'subset_id',[],...
    'dbz_latloncent',[],'subset_latlonbox',[],'subset_ijbox',[],'subset_lat_edge',[],...
    'subset_lon_edge',[],'stats',[],'sts_h_grid',[],'tops_h_grid',[],...
    'MESH_grid',[],'POSH_grid',[],'max_dbz_grid',[],'vil_grid',[],'stats_labels',{});

%extract z vec
radar_alt_vec        = grid_obj.alt_vec;

%2D regionation
extended_basin_stats = regionprops(ewtBasinExtend,refl_img,'MajorAxisLength',...
    'MinorAxisLength','Orientation','Area','BoundingBox','WeightedCentroid');

%Shrink to region2d min intensity. Expansion is not needed because ewt
%method is applied to an image of max dbz in z.
for i=1:length(extended_basin_stats)
    
    %mask region
    ext_region_mask = ewtBasinExtend==i;
    
    %extract bounding box
    bb = extended_basin_stats(i).BoundingBox;
    %round upper and lower limits on bounding towards +-inf
    lower_b = floor([bb(2),bb(1)])-1; lower_b(lower_b<=0)=1;
    upper_b = ceil([bb(2)+bb(4),bb(1)+bb(3)])+1;
    %limit upper bounds to length of dimensions
    if upper_b(1)>length(grid_obj.lat_vec); upper_b(1)=length(grid_obj.lat_vec); end
    if upper_b(2)>length(grid_obj.lon_vec); upper_b(2)=length(grid_obj.lon_vec); end
    %create pixel list
    i_subset = lower_b(1):upper_b(1);
    j_subset = lower_b(2):upper_b(2);

    storm_mask      = ext_region_mask(i_subset,j_subset);
    storm_edge_mask = bwboundaries(storm_mask,4); storm_edge_mask = storm_edge_mask{1};
    
    %subset subset_refl to ext_region_mask bounding region and smooth
    subset_refl     = refl_vol(i_subset,j_subset,:);
    if ~isempty(vel_vol)
        subset_vel      = vel_vol(i_subset,j_subset,:);
    else
        subset_vel      = [];
    end
    
    %create masks
    ss_region_mask  = repmat(storm_mask,[1,1,size(refl_vol,3)]);
    
    %set outside region to min_dbz
    subset_refl(~ss_region_mask) = min_dbzh;
    if ~isempty(subset_vel)
        subset_vel(~ss_region_mask)  = min_dbzh;
    end
    %create max_dbz_grid for extraction
    max_dbz_grid        = max(subset_refl,[],3);
    
    %calc lakshamanan_tops
    %creat h_ind_vol for region (height index volume)
    len_z_vec             = length(radar_alt_vec);
    size_vol              = size(subset_refl);
    rot_h_vec             = reshape(radar_alt_vec,1,1,len_z_vec);
    h_vol                 = repmat(rot_h_vec,[size_vol(1:2),1]);
    tops_h_grid           = lakshamanan_tops3(subset_refl,h_vol,tops_thresh);
    
    %calc 50dbz surface
    sts_h_grid            = lakshamanan_tops3(subset_refl,h_vol,severe_dbz_thresh);
    
    %calc wdss-ii hail grids
    [MESH_grid,POSH_grid] = mesh_algorthim(subset_refl,h_vol,snd_fz_h,snd_minus20_h,v_grid);
    
    %calc grid vil
    z_v             = 10.^(subset_refl(:,:,1:end)./10); 
    subset_vil      = 3.44*10^-6.*v_grid.*1000.*sum(((z_v(:,:,1:end-1)+z_v(:,:,2:end))./2).^(4/7),3);
    max_ij_z_v      = max(max(z_v,[],1),[],2); 
    cell_vil        = 3.44*10^-6*v_grid.*1000*sum(((max_ij_z_v(1:end-1)+max_ij_z_v(2:end))./2).^(4/7));
    
    %Shrink to ewt_a for volume calc
    shink_mask      = subset_refl>=ewt_a;
    %apply ewt_a threshold for max and mean calculations.
    subset_refl_vec = subset_refl(:); subset_refl_vec(subset_refl_vec<ewt_a)=[];
    
    %compile stats
    %note all stats are from extended basin except for area_wdss
    volume          =   sum(shink_mask(:))*h_grid^2*v_grid;
    area            =   extended_basin_stats(i).Area*h_grid^2;
    maj_axis        =   extended_basin_stats(i).MajorAxisLength;
    min_axis        =   extended_basin_stats(i).MinorAxisLength;
    orient          =   extended_basin_stats(i).Orientation;
    max_tops        =   max(tops_h_grid(:));
    max_dbz         =   max(subset_refl_vec);
    [~,md_idx]      =   max(subset_refl(:)); [~,~,md_k] = ind2sub(size(subset_refl),md_idx);
    max_dbz_h       =   radar_alt_vec(md_k);
    mean_dbz        =   mean(subset_refl_vec);
    max_g_vil       =   max(subset_vil(:)); %units of kg/m2
    mass            =   sum(subset_vil(:))*area; %units of kt
    max_sts_dbz_h   =   max(sts_h_grid(:));
    cell_vil        =   cell_vil;
    max_mesh        =   max(MESH_grid(:));
    max_posh        =   max(POSH_grid(:));
    %
    if isempty(max_sts_dbz_h); max_sts_dbz_h=-999; end
    
    %dbz_latloncent
    dbz_cent        = round(extended_basin_stats(i).WeightedCentroid);
    dbz_latloncent  = [grid_obj.lat_vec(dbz_cent(2)),grid_obj.lon_vec(dbz_cent(1))];
    radarmask_id    = double(grid_obj.radar_weight_id(dbz_cent(2),dbz_cent(1)));
    %calculate geometry
    subset_lat_vec   = grid_obj.lat_vec(i_subset);
    subset_lon_vec   = grid_obj.lon_vec(j_subset);
    subset_lat_edge  = subset_lat_vec(storm_edge_mask(:,1));
    subset_lon_edge  = subset_lon_vec(storm_edge_mask(:,2));
    subset_latlonbox = [max(subset_lat_vec);min(subset_lat_vec);max(subset_lon_vec);min(subset_lon_vec)];
    subset_ijbox     = [min(i_subset),max(i_subset),min(j_subset),max(j_subset)];

    %Collate into ident_db object
    stats                         = [volume,area,maj_axis,min_axis,orient,...           %1 to 5
                                    max_tops,max_dbz,max_dbz_h,mean_dbz,max_g_vil,...   %6 to 10
                                    mass,max_sts_dbz_h,cell_vil,max_mesh,max_posh];     %11 to 15
    stats_labels                  = {'vol','area','maj_axis','min_axis','orient',...
                                    'max_tops','max_dbz','max_dbz_h','mean_dbz','max_g_vil',...
                                    'mass','max_sts_dbz_h','cell_vil','max_mesh','max_posh'};                                  
    ident_obj(i).subset_refl      = subset_refl;
    ident_obj(i).subset_vel       = subset_vel;
    ident_obj(i).subset_id        = i;
    ident_obj(i).radarmask_id     = radarmask_id;
    ident_obj(i).dbz_latloncent   = dbz_latloncent;
    ident_obj(i).subset_latlonbox = subset_latlonbox;
    ident_obj(i).subset_lat_edge  = subset_lat_edge;
    ident_obj(i).subset_lon_edge  = subset_lon_edge;
    ident_obj(i).subset_ijbox     = subset_ijbox;
    ident_obj(i).stats            = stats;
    ident_obj(i).stats_labels     = stats_labels;
    ident_obj(i).sts_h_grid       = sts_h_grid;
    ident_obj(i).tops_h_grid      = tops_h_grid;
    ident_obj(i).MESH_grid        = MESH_grid;
    ident_obj(i).POSH_grid        = POSH_grid;
    ident_obj(i).max_dbz_grid     = max_dbz_grid; %note: max dbz grid smoothed by kernel filter in wv_process
    ident_obj(i).vil_grid         = subset_vil;
end

function [intp_h]=lakshamanan_tops3(z_vol,h_vol,z_thresh)
%WHAT: Lakshmanan tops function recoded for speed. Replaces for loops with
%array manipulation. Lakshmanan, Valliappa, Kurt Hondl, Corey K. Potvin, 
%David Preignitz, 2013: An Improved Method for Estimating Radar Echo-Top Height. Wea. Forecasting, 28, 481–488.
%estimates true echo top height from above and below heights/dbz using linear interpolation

%INPUTS:
%z_vol: subset reflectivity volume (dbz)
%h_vol: voxel height volume (m)
%z_thresh: dbz threshold for analysis (dbz)

%OUTPUTS:
%intp_h: interpolated height of z_thresh surface above cloud (m)

%size variables
size_z_vol = size(z_vol);

%create grid of i and j index for indexing
[i_grid,j_grid] = ndgrid(1:size_z_vol(1),1:size_z_vol(2));

%remove regions below threshold
h_vol_mask = h_vol;
h_vol_mask(z_vol<z_thresh) = -999;
%find maximum h_ind for every x,y grid point
[~,b_k_ind]   = max(h_vol_mask,[],3);
%enforce z limits
b_k_ind(b_k_ind==size_z_vol(3)) = 1; %set to one now, but remove later
remove_data_mask                = b_k_ind==1 | b_k_ind==size_z_vol(3);          
%define b_k_ind
a_k_ind   = b_k_ind+1;
%extract linear index for a_k_ind and b_k_ind
a_ind = sub2ind(size_z_vol,i_grid(:),j_grid(:),a_k_ind(:));
b_ind = sub2ind(size_z_vol,i_grid(:),j_grid(:),b_k_ind(:));
%extract height and z surfaces
z_a   = z_vol(a_ind);
z_b   = z_vol(b_ind);
h_a   = h_vol(a_ind);
h_b   = h_vol(b_ind); 
%interp_h
intp_h   = (z_thresh - z_a).*(h_b-h_a)./(z_b-z_a)+h_b;
%restructure into image
intp_h                = reshape(intp_h,size_z_vol(1),size_z_vol(2));
intp_h(isinf(intp_h)) = -999;
%remove false surface
intp_h(remove_data_mask) = -999;


function [MESH,POSH] = mesh_algorthim(dbzh_grid,h_grid,snd_fzh_height,snd_minus_20_h,v_grid)
%WHAT: Hail grids adapted fromWitt et al. 1998 and Cintineo et al. 2012.
%Exapnded to grids (adapted from wdss-ii)

%INPUT:
%z_vol: subset reflectivity volume (dbz)
%h_vol: voxel height volume (m)
%snd_fzh_height: height of freezing level in closest sounding in time and
%space (m)
%snd_minus_20_h: height of -20C level in closest sounding in time and
%space (m)
%v_grid: vertical grid spacing (m) from global config

%OUTPUTS:
%MESH: maximum estimated severe hail (mm)
%POSH: probability of severe hail (%)
%SHI: Severe Hail Index (J/m/s)

%abort if no fz data
if isempty(snd_minus_20_h) || isempty(snd_fzh_height)
    POSH = [];
    MESH = [];
    return
end

%convert heights from km to m
snd_fzh_height = snd_fzh_height./1000;
snd_minus_20_h = snd_minus_20_h./1000;

%reflectivity weighting function boundary
z_l = 40;
z_u = 50;

%calc reflectivity weighting function
w_z             = (dbzh_grid - z_l)./(z_u - z_l);
w_z(dbzh_grid<=z_l) = 0;
w_z(dbzh_grid>=z_u) = 1;

%calc hail kenitic energy
E = (5*10^-6).*10.^(0.084.*dbzh_grid).*w_z;

%calc temperature based weighting function
w_h = (h_grid - snd_fzh_height) ./ (snd_minus_20_h - snd_fzh_height);
w_h(h_grid<=snd_fzh_height) = 0;
w_h(h_grid>=snd_minus_20_h) = 1;

%calc severe hail index
SHI = 0.1.*sum(w_h.*E,3).*v_grid;

%calc maximum estimated severe hail (mm)
MESH = 2.54.*SHI.^0.5;

%calc warning threshold (J/m/s) NOTE: freezing height must be in meters
WT   = 57.5*snd_fzh_height-121;

%calc probability of severe hail (POSH) (%)
POSH           = 29.*log(SHI./WT)+50;
POSH           = real(POSH);
POSH(POSH<0)   = 0;
POSH(POSH>100) = 100;
