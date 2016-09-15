function [ewtBasinExtend] = wdss_ewt(filt_refl_image)
%WHAT: Implementation of the extended watershed transform (ewt) described in
%Lakshamanan et al 2009. Using a local dual threshold method to find
%regions which meet the saliency criteria

%PAPER: An efficient, general-Purpose Technique for Identifiying Storm
%Cells in Geospatial Images, Lakshmanan, Hondl and Rabin, March 2009,
%Journal of Atmospheric and Oceanic Technology

%INPUT: refl_image: image of regridded refl data in dBZ at height index of
%ewt_refl_h

%OUTPUT:
%ewtBasin:       label matrix of regions identified as cells by EWT (uses a
%local threshold between ewt_a and ewt_b
%ewtBasinExtend: label matrix of ewtBasin regions extended to etw_a

ewtBasin       = zeros(size(filt_refl_image));
ewtBasinExtend = zeros(size(filt_refl_image));
%Profiling Code...
%tic
%profile clear
%profile on
%% Initalise variables
load('tmp_global_config.mat');
ewt_max_level = (ewt_b-ewt_a)/ewt_del;
%transform refl data to double...
%% SMOOTHING
%WHAT: Applies selected smoothing function with kernel ewt_kernel_size

%median filter
%filt_refl_image = medfilt2(refl_image, [ewt_kernel_size,ewt_kernel_size]);

%gaussian filter
%h = fspecial('gaussian', ewt_kernel_size, .5)
%filt_refl_image = imfilter(refl_image,h);

%wiener apadtive filter
%filt_refl_image = wiener2(refl_image,ewt_kernel_size);

%% QUANTISATION into Q
%WHAT: Quantises data according to upper and lower limits, and scaling.
%Also applies rounding. Necessary for building Q ordered index matrix.
%Find regions for limits
%case1_mask = filt_refl_image<=ewt_a;
case2_mask = and(ewt_a<filt_refl_image,filt_refl_image<=ewt_b);
case3_mask = filt_refl_image>ewt_b;

%Apply masks and quantise
%Q1 = zeros(size(filt_refl_image));
Q2 = case2_mask.*round(filt_refl_image-ewt_a./ewt_del); %set case 2
Q3 = case3_mask.*round(ewt_max_level);              %set case 1

%Combine for final quantised images
Q  = Q2+Q3;

%% TRANSFORMATION in cell
%WHAT: Build Q ordered index matrix
%NOTE: level+1 index applies for matlab non zero indexing

%declare max level
max_level_ind=ewt_max_level+1;
%create blank cell array for index matrix
pixels = cell(1,max_level_ind);
size_Q=size(Q);
%for each level, find level=Q pixels and store in pixels(level)
for i=0:ewt_max_level
    temp_Q_ind=find(Q==i);
    level_ind=i+1;
    pixels{level_ind}=temp_Q_ind;
end

%% FINDING CENTRES
%WHAT: find the centre of every local max. Also ensure that local max's with
%mulitple pixels (same value) are transformed into a single centroid pixel

%create centres index strucutre (same indexing as pixels)
centres                   = cell(1,max_level_ind);
%Apply local max function to intensity image
local_all_max_mask        = imregionalmax(Q);
%check local max exists
if min(min(local_all_max_mask))==1
    %no local max
    return
end
%Calc region prop centroids for each regions in local max mask
mask_centroid             = regionprops(local_all_max_mask,Q,'WeightedCentroid');
%round centroids and convert to index values
local_max_cent            = round(vertcat(mask_centroid.WeightedCentroid));
local_max_ind             = sub2ind(size_Q,local_max_cent(:,2),local_max_cent(:,1));
%Convert index values into mask of size Q
local_max_mask            = zeros(size(Q));
local_max_mask(local_max_ind)=1;

%loop through local_max_ind and allocation to associated Q value in centres
%matrix
for i=1:length(local_max_ind)
    level_ind          = Q(local_max_ind(i))+1;
    centres{level_ind} = [centres{level_ind};local_max_ind(i)];
end

%% IMMERSION METHOD
%WHAT: Applies the extended watershed method. First the basin is declared
%is the area meets the ewt_saliency for continous pixels around centre
%which have Q>=hlevel. Second, for captured basins, foothills are expanded
%to all Q>0 pixels which are nearest to the centre. These foothills are
%assigned to the overall basin background.

%declare first basin number
basin_no=1;
%initalise labelled Basin image (ewtBasin) as Q>0 = -1, else 0 (default)
ewtBasin=Q; ewtBasin(ewtBasin>0)=-1;
%declare foothills matrix
foothills=[];

%Loop through depth starting from zero
for depth=0:ewt_max_depth
    %Loop through level starting for maximum intensity
    for level = ewt_max_level:-1:0
        %calculate hlevel for current level and depth (depth increases for
        %every level cycle)
        hlevel = level-depth;
        %skip shallow hlevels
        if hlevel<ewt_min_hlevel
            continue
        end
        %declare level ind in structure (matlab notation)
        level_ind     = level+1;
        %extract all centres for current level
        level_centres = centres{level_ind};
        %Loop through centres for level
        for i=1:length(level_centres)
            %extract current centre
            centre = level_centres(i);
            %if centre is not part of a basin
            if ewtBasin(centre)<0 
                %run basin capture
                [ewtBasin,local_foothills,basin]=capture_basin(hlevel,ewt_saliency,centre,Q,basin_no,ewtBasin,h_grid);
                %if basin capture was a success
                if ewtBasin(centre)>0
                    %check for multiple centres inside basin
                    temp_mask      = ismember(local_max_ind,basin);
                    %allocate for foothill reserving
                    expand_centres = local_max_ind(temp_mask);
                    %expand foothills for centre
                    out            = reserve_foothills2(expand_centres,local_max_ind,Q,ewtBasin,basin_no);
                    %reserve foothills
                    foothills      = [foothills;out];
                    %move to next basin
                    basin_no=basin_no+1;
                else
                    %copy centre to centres(level - 1) to process centre at
                    %next lower level and remove from current level
                    lower_level_ind          = level_ind - 1;
                    centres{lower_level_ind} = [centres{lower_level_ind};centre];
                    %remove centre from centres(level) to prevent
                    %duplication
                    level_centres(i)   = NaN;
                    centres{level_ind} = level_centres(~isnan(level_centres));
                end
            else
                %centre already in basin, remove centre from centres(level)
                level_centres(i)   = NaN;
                centres{level_ind} = level_centres(~isnan(level_centres));
            end
        end
        %set foothill points to background basin (eqt_B=0)
        if ~isempty(foothills)
            for i=1:length(foothills)
                ewtBasin(foothills(i)) = 0;
            end
            %empty foothills
            foothills = [];
        end
    end
end

%Assign unallocated Q>0 pixels in ewtBasin to the background
ewtBasin(ewtBasin==-1) = 0;

%% Expand each region back to ewt_a (new step)

%remove pixels less than ewt_a
etw_a_mask     = filt_refl_image>=ewt_a;
%create preallocated of array
ewtBasinExtend = zeros(size(etw_a_mask));
etw_dist       = inf(size(etw_a_mask));
%loop through all basin numbers
for i=1:max(max(ewtBasin))
    %calc geodesic distance
    geoD             = bwdistgeodesic(etw_a_mask,ewtBasin==i);
    %filter out pixels which have been allocated a distance
    compare_ind      = find(~isinf(geoD) & ~isnan(geoD));
    %extract geoD and etw_dist distance values
    compare_geoD     = geoD(compare_ind);
    compare_etw_dist = etw_dist(compare_ind);
    %filter out new nearest basins
    replace_ind      = compare_ind(compare_geoD<compare_etw_dist);
    %update extended basin
    ewtBasinExtend(replace_ind) = i;
    etw_dist(replace_ind)       = geoD(replace_ind);
end


%% Final Options

%Profiling options
% profile off
% profile viewer
% toc

function [ewtBasin,foothills,basin]=capture_basin(hlevel,ewt_saliency,centre,Q,basin_no,ewtBasin,h_grid)
%WHAT: starts with ewt_a local maximum pixel and adds this to the basin. All
%contigous pixels to this pixel are identified. If the Q intensity of these
%pixels is above the hlevel, they are added as neighbours. If they are
%less, they are added as foothills. The process is repeated until there are
%no more neighbours (they have all been assigned as foothills)

%INPUT:
%hlevel:        min Q searh threshold from centre
%ewt_saliency:  size criteria (km2)
%centre:        linear index of centre coordinate
%Q:             Quantisied matrix
%basin_no:      Current basin index
%ewtBasin:         Basin label image
%h_grid:        image pixel size in m

%OUTPUT:
%ewtBasin:         Updated labeled basin matrix
%foothills:     Linear index of foothills
%basin:         Linear index of basins

%initalise stacks
neighbours = [];
basin      = [];
foothills  = [];

%initalise variables
neighbours = centre;
size_img   = size(ewtBasin);

%loop while neighbours still need to be checked
while ~isempty(neighbours)
    %extract next neighbour pixel for processing and remove from list
    temp_nn       = neighbours(1);
    neighbours(1) = [];
    %add pixel to basin
    basin           = [basin;temp_nn];
    %find contigous pixels
    contig_pixels   = find_contig_pixels(temp_nn,size_img);
    %loop through contiguous pixels
    for i=1:length(contig_pixels)
       temp_pixel=contig_pixels(i);
       %check temp_pixel is not labeled and not already processed
       if  ~any(temp_pixel==neighbours) && ~any(temp_pixel==basin) && ewtBasin(temp_pixel)==-1
           %check temp_pixel is above= hlevel
            if Q(temp_pixel)>=hlevel 
                %add to neighbours
                neighbours=[neighbours;temp_pixel];
            %temp_pixel<hlevel, check if in foothills
            %elseif ~any(temp_pixel==foothills)
            %    %add to foothills
            %    foothills=[foothills;temp_pixel];
            end
       end
    end
    
end
%check if basin size in km is smaller than ewt_saliency threshold
if size(basin,1)*h_grid^2/10^6 < ewt_saliency
    %Basin has not been caputred
    basin     = []; %empty stack
    foothills = [];
else
    %Basin has been captured, apply basin_no using basin index
    for i=1:length(basin)
        ewtBasin(basin(i))=basin_no;
    end
end

function foothills=reserve_foothills2(centres,local_max_ind,Q,ewtBasin,basin_no)
%WHAT: Compares the geodist of the target basin centres to the geodist of
%all other centres. Pixels which are not in a basin and are a minimum
%distance for the current basin are assigned as basin pixels.

%INPUT:
%centres:       linear index of all centre coordinates inside target basin
%local_max_ind: index of all centres
%Q:             Quantisied matrix
%ewtBasin:      Basin label image

%OUTPUT:
%foothills:     Linear index of captured foothills

%mask valid Q regions
ewt_a_mask   = Q>0;
%exclusive subset for alt centres
alt_centres  = setxor(centres,local_max_ind);
%create mask of all regions excluding basin_no and alt_centres
alt_mask     = ewtBasin~=basin_no & ewtBasin>0;
alt_mask(alt_centres) = true;

%calc geodesic from mask to current basin and alt_mask
centres_geodist     = bwdistgeodesic(ewt_a_mask,ewtBasin==basin_no);
alt_centres_geodist = bwdistgeodesic(ewt_a_mask,alt_mask);
%set pixels where geodist in a new min to a foothill
mask_centres_geodist= centres_geodist<alt_centres_geodist & ewtBasin==-1;
%assign new foothills
foothills=find(mask_centres_geodist);

function contig_pixels=find_contig_pixels(pixel,size_img)
%WHAT: Find contigous pixels to pixel then checks the checking boundary
%conditions. FAST LINEAR EDITION

%INPUT: pixel: linear index of centre pixel
%size_img: size of image

%OUTPUT: contig_pixels: linear index of nn pixels which meet boundary
%conditions

%extact size paramters
size_img_r   = size_img(1);             %no rows
size_img_ind = size_img(1)*size_img(2); %index size
%create transform matrix
d = [-1,1,-size_img_r-1,-size_img_r,-size_img_r+1,size_img_r-1,size_img_r,size_img_r+1];
%apply transform matrix
contig_pixels = d + [pixel,pixel,pixel,pixel,pixel,pixel,pixel,pixel];
%mask pixels within the image
keep_mask=contig_pixels>=1 & contig_pixels<=size_img_ind;
%apply mask
contig_pixels=contig_pixels(keep_mask);
