function ident_obj=identify3D_2(intp_obj,r_refl_vol,r_vel_vol)
%WHAT
    %Identified cells using a method which combines vild analysis and refl_vol
    %thresholds. These cells are then subsetted from the refl_vol dataset and a
    %series of statisitics are produced for each cell.
%INPUT
    %intp_obj: See cart_interpol6.m
    %refl_vol: regridded refl_vol volume
%OUTPUT
    %ident_obj: a cell array with a series of fields containing ther subset
    %and its metadata.

    
%convert to double for all calcs....
%subset volume must be unit8 though....
    
    
%Load config file
load('tmp_global_config.mat');
%create blank ident_obj
ident_obj = struct ('radar_mode',{},'subset_refl',{},'subset_vel',{},'subset_id',{},'vild_latloncent', {},'dbz_latloncent',{},'subset_latlonbox',{},'subset_lat_vec',{},'subset_lon_vec',{},'subset_z_asl_vec',{},'subset_lat_edge',{},'subset_lon_edge',{},'stats',[]);

%transform refl data to double...
refl_vol=double(r_refl_vol).*intp_obj.refl_vars(1)+intp_obj.refl_vars(2);

%% Calc transformations

%calc tops and depth
[~,~,z_grid]=meshgrid(intp_obj.lon_vec,intp_obj.lat_vec,intp_obj.z_vec_amsl);
low_dbz_mask=refl_vol>18.5; %WDR-88D criteria
%calc cloud reflectivity heights
cloud_height=z_grid.*low_dbz_mask./1000;
cloud_height(cloud_height==0)=NaN;
%calculate cloud top, bottom and depth
tops=max(cloud_height,[],3);
bottoms=min(cloud_height,[],3);
cloud_depth=tops-bottoms;

%calc vil
z_v=10.^(refl_vol(:,:,2:end)./10); %SKIP SURFACE SCAN FOR VILD CALC TO REMOVE CLUTTER
vil=3.44*10^-6.*500.*sum(((z_v(:,:,1:end-1)+z_v(:,:,2:end))./2).^(4/7),3);

%calc vild
cloud_depth(cloud_depth<0)=NaN;
vild=vil./cloud_depth;
vild(vild==Inf)=0;
vild(isnan(vild))=0;

%% Apply VILD segmentation
%generate threshold
values=vild(:); values=values(values>0);
vild_prc_thresh=prctile(values,vild_prc); %from global_config

if vild_prc_thresh<min_vild
    vild_prc_thresh=min_vild;
elseif vild_prc_thresh>max_vild
    vild_prc_thresh=max_vild;
end

%apply VILD threshold
bw_vild = vild>=vild_prc_thresh;
%image manipulation to grow and shrink regions in BW
bw_vild = bwareaopen(bw_vild, min_vild_area); %remove regions smaller than...
se = strel('disk',vild_grow_dia);
bw_vild = imdilate(bw_vild,se); %imclose:too spikey imopen:too segmented
bw_vild = imfill(bw_vild,'holes'); %fill holes
l_vild = labelmatrix(bwconncomp(bw_vild)); %generate label matrix with stats
vild_stats=regionprops(l_vild,vild,'WeightedCentroid');

%% MASK refl_vol WITH VILD and REGROW/MASK to dbz_thresh

if length(vild_stats)>0 %ensure there are vild stats
    
    %MASK with Threhold
    mask_dbz=refl_vol.*repmat(bw_vild,[1,1,size(refl_vol,3)]); %stretch bw_vild to 3D and mask refl_vol
    
    %calculate refl_vol threshold from global config percentile value
    %values=mask_dbz(:); values=values(values>0);
    %dbz_prc_thresh=round(prctile(values,dbz_prc));
    %if dbz_prc_thresh<low_dbz
    dbz_prc_thresh=low_dbz; %NOTE: dbz percentile calc removed.
    %end
    
    %apply thresh_dbz to masked_dbz
    bw_th_dbz=mask_dbz>=dbz_prc_thresh;
    
    if any(bw_th_dbz)==0
        %refl_vol>35 detected in cart_interpol6, but removed in vild filter.
        %break function
        return
    end
    
    %use vild labels and apply bw_th_dbz
    l_th_dbz= bw_th_dbz.*repmat(single(l_vild),[1,1,size(refl_vol,3)]);
    %SLOWEST LINE>>>
    %calc bwdist and associated dist indx values
    [dist_th_dbz,indx_dist]=bwdist(bw_th_dbz); 
    
    %GROW regions to threshold
    mask_unident_dbz=refl_vol.*~bw_th_dbz; %mask unidentified regions using bw_th_dbz from refl_vol
    bw_regrow_dbz=mask_unident_dbz>=dbz_prc_thresh; %create a mask of the unidentified regions with refl_vol>=dbz_threshold
    l_regrow_dbz=labelmatrix(bwconncomp(bw_regrow_dbz)); %create label matrix
    mask_regrow_dist=bw_regrow_dbz.*dist_th_dbz; %apply bw_regrow_dbz to the distance

    %check min dist of each region in regrow_dbz, if greater than 1 assume
    %separate cloud and delete
    regrow_stats=regionprops(l_regrow_dbz,mask_regrow_dist,'MinIntensity','PixelIdxList');
    for i=1:length(regrow_stats);
        if regrow_stats(i).MinIntensity>1
            bw_regrow_dbz(regrow_stats(i).PixelIdxList)=0;
        end
    end

    %lookup label values using bwdist index values and apply regrow mask
    l_regrow_dbz=l_th_dbz(indx_dist).*(bw_regrow_dbz);
    %append regrow and threshold mask outputs
    l_dbz=single(l_th_dbz)+l_regrow_dbz;

    %use the total x,y coverage to extend the mask to the entire depth of
    %the volume
    l_dbz=repmat(max(l_dbz,[],3),[1,1,size(l_dbz,3)]);
    
    %generate stats
    dbz_stats=regionprops(l_dbz,refl_vol,'BoundingBox');

    %% Loop through each refl_vol threshold label
    ident_obj_idx=0;

    %Generate regionprops on max refl_vol 2D matrix
    label_stats     =   regionprops(l_dbz(:,:,1),max(refl_vol,[],3),'Area','Centroid','MajorAxisLength','MinorAxisLength','Orientation');
    %calculate rainrate at 3km
    [~,idx_4km]     =   min(abs(intp_obj.z_vec_amsl-rain_rate_h));
    rain_rate       =   (10.^(refl_vol(:,:,idx_4km)/10)./200).^(5/8);

    for i=1:length(dbz_stats) %loop each label 'cell'

%         check if region hasn't been eroded/lost beyond limits in processing
%         if label_stats(i).Area<min_low_dbz_area
%             continue
%         end
        
        %round upper and lower limits on bounding towards +-inf
        bb=dbz_stats(i).BoundingBox;
        lower_b=floor([bb(2),bb(1),bb(3)]); lower_b(lower_b<=0)=1;
        upper_b=ceil([bb(2)+bb(5),bb(1)+bb(4),bb(3)+bb(6)]);
        %limit upper bounds to length of dimensions
        if upper_b(1)>length(intp_obj.lat_vec); upper_b(1)=length(intp_obj.lat_vec); end
        if upper_b(2)>length(intp_obj.lon_vec); upper_b(2)=length(intp_obj.lon_vec); end
        if upper_b(3)>length(intp_obj.z_vec_amsl); upper_b(3)=length(intp_obj.z_vec_amsl); end

        %check if region still exists
        if (upper_b(1)-lower_b(1))>0

            %subset spatial coordinated
            subset_lat_vec   =intp_obj.lat_vec(lower_b(1):upper_b(1));
            subset_lon_vec   =intp_obj.lon_vec(lower_b(2):upper_b(2));
            subset_z_asl_vec =intp_obj.z_vec_amsl(1:upper_b(3));
            
            %create masks for subsets
            subset_l_dbz    =   l_dbz(lower_b(1):upper_b(1),lower_b(2):upper_b(2),1:upper_b(3));
            subset_bw_dbz   =   subset_l_dbz==i;
            subset_2d_bw_dbz=   max(subset_bw_dbz,[],3);
            
            %calculate edge boundary coordinates
            subset_2d_edge  =   bwboundaries(subset_2d_bw_dbz,4);
            %merge multiple objects into one
            subset_2d_edge = vertcat(subset_2d_edge{:});
            %extract edges
            subset_lat_edge=subset_lat_vec(subset_2d_edge(:,1));
            subset_lon_edge=subset_lon_vec(subset_2d_edge(:,2));

            %create subsets
            subset_g_vild   =   vild(lower_b(1):upper_b(1),lower_b(2):upper_b(2)).*subset_2d_bw_dbz;
            subset_vil      =   vil(lower_b(1):upper_b(1),lower_b(2):upper_b(2)).*subset_2d_bw_dbz;
            subset_tops     =   tops(lower_b(1):upper_b(1),lower_b(2):upper_b(2)).*subset_2d_bw_dbz;
            %subset uint8 data, don't apply the mask!
            subset_r_refl     =   r_refl_vol(lower_b(1):upper_b(1),lower_b(2):upper_b(2),1:upper_b(3)); subset_r_refl(~subset_bw_dbz)=0;
            subset_refl       =   refl_vol(lower_b(1):upper_b(1),lower_b(2):upper_b(2),1:upper_b(3)); subset_refl(~subset_bw_dbz)=0;
            if strcmp(intp_obj.radar_mode,'vel')
                subset_r_vel  =   r_vel_vol(lower_b(1):upper_b(1),lower_b(2):upper_b(2),1:upper_b(3));
                subset_r_vel(~subset_bw_dbz)=0;
            else
                subset_r_vel  =   [];
            end
            
            subset_rr       =   rain_rate(lower_b(1):upper_b(1),lower_b(2):upper_b(2)).*subset_2d_bw_dbz;

            %create basic stats
            volume          =   sum(subset_bw_dbz(:))*h_grid^2*v_grid/10^9;
            area            =   label_stats(i).Area*h_grid^2/10^6;
            maj_axis        =   label_stats(i).MajorAxisLength;
            min_axis        =   label_stats(i).MinorAxisLength;
            orient          =   label_stats(i).Orientation;
            mean_rr         =   mean(subset_rr(:));
            max_rr          =   max(subset_rr(:));
            max_tops        =   max(subset_tops(:));
            [max_dbz,md_idx]=   max(subset_refl(:)); [~,~,md_k] = ind2sub(size(subset_refl),md_idx);
            max_dbz_h       =   subset_z_asl_vec(md_k);
            mean_dbz        =   mean(subset_refl(:));
            max_g_vild      =   max(subset_g_vild(:));
            mass            =   sum(subset_vil(:))*area/10^6;
            m50_ind          =   find(subset_refl(:)>=50); [~,~,m50_k] = ind2sub(size(subset_refl),m50_ind);
            max_50dbz_h     =   max(subset_z_asl_vec(m50_k));
            if isempty(max_50dbz_h); max_50dbz_h=NaN; end

            %check if volume hasn't been eroded/lost beyond limits in processing
            if volume/area>size_threshold || max_tops<top_threshold
                continue
            end
        
            %creat indent_obj idx for archiving as object has passed test
            ident_obj_idx=ident_obj_idx+1;
        
            %collate centroids
            vild_cent=floor(vild_stats(i).WeightedCentroid);
            vild_cent(vild_cent<=0)=1;
            vild_latloncent =[intp_obj.lat_vec(vild_cent(2)),intp_obj.lon_vec(vild_cent(1))];
            
            dbz_cent=floor(label_stats(i).Centroid);
            dbz_cent(dbz_cent<=0)=1;            
            dbz_latloncent  =[intp_obj.lat_vec(dbz_cent(2)),intp_obj.lon_vec(dbz_cent(1))];
            
            %generate latlon box for region
            subset_latlonbox=[max(subset_lat_vec);min(subset_lat_vec);max(subset_lon_vec);min(subset_lon_vec)];

            %Cell based VILD and core geometry
            layer_coord=[];
            layer_dbz=[];
            %identify the max refl_vol value and it's coord for each layer
            for j=1:length(subset_z_asl_vec)
                temp=subset_refl(:,:,j); [temp_max,temp_ind]=max(temp(:));
                if temp_max>0
                    layer_dbz=[layer_dbz;temp_max];
                    [temp_y,temp_x]=ind2sub(size(subset_2d_bw_dbz),temp_ind);
                    layer_coord=[layer_coord;[temp_x,temp_y]];
                end
            end
            
            %convert to m and Z respectively
            layer_coord=layer_coord.*h_grid;
            layer_z=10.^(layer_dbz./10);
            
            %cumulatively caluclate cell_vil
            cell_vil=0;
            for j=1:length(layer_dbz)-1
                dist=sqrt((layer_coord(j,1)-layer_coord(j+1,1))^2+(layer_coord(j,2)-layer_coord(j+1,2))^2+v_grid^2);
                cell_vil=cell_vil+ (3.44*10^-6*dist*((layer_z(j)+layer_z(j+1))/2)^(4/7));
            end
            
            %generate complex cell stats
            cell_vild     =  roundn(cell_vil/max_tops*10^3,-2);
            x_offset      =  layer_coord(end,1)-layer_coord(1,1);
            y_offset      =  -(layer_coord(end,2)-layer_coord(1,2));
            cell_tilt     =  atand(sqrt(x_offset^2+y_offset^2)/(subset_z_asl_vec(end)-subset_z_asl_vec(1)));
            cell_orient   =  polar2compass(atand(y_offset/x_offset));

            %Collate into ident_db object
            other_stats=[volume,area,maj_axis,min_axis,orient,mean_rr,max_rr,max_tops,max_dbz,max_dbz_h,mean_dbz,max_g_vild,mass,max_50dbz_h,cell_vild,cell_tilt,cell_orient];
            ident_obj(ident_obj_idx).radar_mode=intp_obj.radar_mode;
            ident_obj(ident_obj_idx).subset_refl=subset_r_refl;
            ident_obj(ident_obj_idx).subset_vel=subset_r_vel;
            ident_obj(ident_obj_idx).subset_id=i;
            ident_obj(ident_obj_idx).vild_latloncent=vild_latloncent;
            ident_obj(ident_obj_idx).dbz_latloncent=dbz_latloncent;
            ident_obj(ident_obj_idx).subset_latlonbox=subset_latlonbox;
            ident_obj(ident_obj_idx).subset_lat_vec=subset_lat_vec;
            ident_obj(ident_obj_idx).subset_lon_vec=subset_lon_vec;
            ident_obj(ident_obj_idx).subset_lat_edge=subset_lat_edge;
            ident_obj(ident_obj_idx).subset_lon_edge=subset_lon_edge;
            ident_obj(ident_obj_idx).subset_z_asl_vec=subset_z_asl_vec;
            ident_obj(ident_obj_idx).stats=other_stats;
            
        end
    end
end