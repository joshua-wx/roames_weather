function ident_obj=identify3D_3(intp_obj,r_refl_vol,r_vel_vol)

refl_thresh     = 30; %dbz
media_filter    = [3,3]; %pixels
min_ratio       = 30; %km^3/km^2

%Load config file
load('tmp_global_config.mat');
%create blank ident_obj
ident_obj = struct ('radar_mode',{},'subset_refl',{},'subset_vel',{},'subset_id',{},'vild_latloncent', {},'dbz_latloncent',{},'subset_latlonbox',{},'subset_lat_vec',{},'subset_lon_vec',{},'subset_z_asl_vec',{},'subset_lat_edge',{},'subset_lon_edge',{},'stats',[]);

%transform refl data to double...
refl_vol=double(r_refl_vol).*intp_obj.refl_vars(1)+intp_obj.refl_vars(2);
%find max refl in z dimension
max_refl=max(refl_vol,[],3);
%apply median filter to remove noise
filt_max_refl = medfilt2(max_refl, media_filter);
%set minimum
mask_filt_max_refl=filt_max_refl>=refl_thresh;
%apply label transform
label_filt_max_refl=labelmatrix(bwconncomp(mask_filt_max_refl));
%calculate regionprops
label_stats=regionprops(label_filt_max_refl,'PixelList');

for i=1:length(label_stats)
    %expand current label to 3D mask, apply mask to volume and remove pixels less than refl_thresh
    temp_pixel_list=label_stats(i).PixelList;
    %create bounding box
    bnd_row         = min(temp_pixel_list(:,2)):max(temp_pixel_list(:,2)); bnd_col=min(temp_pixel_list(:,1)):max(temp_pixel_list(:,1));
    temp_mask       = label_filt_max_refl(bnd_row,bnd_col)==i;
    temp_mask_3d    = repmat(temp_mask,[1,1,size(refl_vol,3)]);
    subset_refl_vol = refl_vol(bnd_row,bnd_col,:).*temp_mask_3d;
    subset_tops     = lakshamanan_tops(subset_refl_vol,intp_obj.z_vec_amsl);
    %merge small watersheds until no more small watershes exists or only
    %one watershed exists
    loop=true;
    while loop==true
        watersed_refl_vol  = watershed(-subset_refl_vol);
        uniq_watershed_id=unique(watersed_refl_vol);
        for i=1:length(uniq_watershed_id)
            %calc watershed volume and area
            ws_mask=watersed_refl_vol==uniq_watershed_id(i);
            ws_volume=sum(ws_mask(:))*h_grid^2*v_grid/10^9;
            wx_area=max(ws_mask,[],3); wx_area=sum(wx_area(:))*h_grid^2/10^6;
            %if fails ratio test,cluster and restart loop
            if ws_volume/wx_area<min_ratio && length(uniq_watershed_id)>1
                %merge by applying regional min to this watershed
                subset_refl_vol=imimposemin(subset_refl_vol,ws_mask);
                keyboard
                break
            end
        end
        loop=false;
    end
    %calculate stats for watershed region
    watershed_stats=regionprops(watersed_refl_vol,'PixelList');
    for i=1:length(watershed_stats)
        ws_3mask=watersed_refl_vol==uniq_watershed_id(i);
        ws_volume=sum(ws_3mask(:))*h_grid^2*v_grid/10^9;
        wx_2mask=max(ws_3mask,[],3); wx_area=sum(wx_2mask(:))*h_grid^2/10^6;  
        ws_tops=subset_tops(wx_2mask);
        if ws_volume/wx_area<min_ratio && ws_tops>top_threshold
            
            
            
            
            
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
        end
    end
   
end

keyboard 


function tops=lakshamanan_tops(subset_refl_vol,z_vec)
%WHAT: Lakshmanan, Valliappa, Kurt Hondl, Corey K. Potvin, David Preignitz, 2013: An Improved Method for Estimating Radar Echo-Top Height. Wea. Forecasting, 28, 481–488.
%estimates true echo top height from above and below heights/dbz

tops=NaN(size(subset_refl_vol,1),size(subset_refl_vol,2));
tops_threshold=18.5;
for i=1:size(subset_refl_vol,1)
    for j=1:size(subset_refl_vol,2)
        above_ind=find(subset_refl_vol(i,j,:)<tops_threshold,1,last);
        
        if above_ind==1; continue; end
        
        above_h=z_vec(above_ind);
        above_dbz=subset_refl_vol(i,j,above_ind);
        below_h=z_vec(above_ind-1);
        below_dbz=subset_refl_vol(i,j,above_ind-1);
        tops(i,j) = interp1([above_dbz,below_dbz],[above_h,below_h],tops_threshold);
    end
end

%interpolate for 18.5dbz level

