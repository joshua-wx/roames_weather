function cloud_objects3(arch_dir,intp2kml,ident2kml,kml_dir,options)
%HELP: Generates google earth objects from regridded radar data in intp_obj.
    %These objects are: cell inner iso kml data, outer cell surface
    %kml, metrics for each cell and cappi refl image. Writes the outeriso,
    %cell_iso and cappi data to kmz files with standard filename (linked
    %with file id) into the folder specified in global_config

%INPUT:
    %intp2kml: array of intp_objs to process
    %ident2kml: ident_db spanning multiple days
    %kml_dir: root of kml path
    %option: specify types of kml objects to generate

%OUTPUT
    %kml/kmz files for each kml layer object in the ident_data path ofthe kml root
  
%load radar colormap and gobal config
load('colormaps.mat');
load('tmp_global_config.mat');
load('site_info.mat');

%loop through each intp_obj
for i=1:length(intp2kml)
    
    %extract intp parameters
    target_start_td=intp2kml(i).start_timedate; target_start_td_vec=datevec(target_start_td);
    target_radar_id=intp2kml(i).radar_id;
    target_radar_type=intp2kml(i).radar_mode;
    target_sig_refl=intp2kml(i).sig_refl;
    target_start_timedate=intp2kml(i).start_timedate;
    target_refl_vars=intp2kml(i).refl_vars;
    target_vel_vars=intp2kml(i).vel_vars;
    
    %set kml file tad
    file_tag=['IDR',num2str(target_radar_id),'_',datestr(target_start_timedate,'dd-mm-yyyy_HHMM')];
    %data folder path
    data_path=[arch_dir,'IDR',num2str(target_radar_id,'%02.0f'),'/',num2str(target_start_td_vec(1)),'/',num2str(target_start_td_vec(2),'%02.0f'),'/',num2str(target_start_td_vec(3),'%02.0f'),'/data/',file_tag,'.mat'];
    
    %CREATE mapping coordinates vectors for radar site. needed for
    %isosurface generation
    cur_r_lat  = -site_lat_list(site_id_list==target_radar_id);
    cur_r_lon  = site_lon_list(site_id_list==target_radar_id);
    curr_r_elv = site_elv_list(site_id_list==target_radar_id);
    %mapping coordinates, working in ij coordinates
    mstruct        = defaultm('mercator');
    mstruct.origin = [cur_r_lat cur_r_lon];
    mstruct.geoid  = almanac('earth','wgs84','meters');
    mstruct        = defaultm(mstruct);
    %transfore x,y into lat long using centroid
    x_vec=-h_range:h_grid:h_range;
    y_vec=-h_range:h_grid:h_range; 
    [r_lat_vec, r_lon_vec] = minvtran(mstruct, x_vec, x_vec);
    r_amsl_vec = [v_grid:v_grid:v_range]'+curr_r_elv;
    
    %scan1_refl
    if options(1)==1
        %load image mat file
        scan1_refl=mat_wrapper(data_path,'scan1_refl');
        scan1_refl=data_transform(scan1_refl,'refl',target_refl_vars,min_dbz);
        %save to file, generate kml, zip kml and image into kmz (transform
        %for 24bit colourmap)
        imwrite(scan1_refl,interp_refl_cmap,[tempdir,'scan1_refl_',file_tag,'.gif'],'TransparentColor',1);
        scan1_refl_kml=ge_groundoverlay('',['scan1_refl_',file_tag],['scan1_refl_',file_tag,'.gif'],intp2kml(i).region_latlonbox,'','','clamped','',1);
        ge_kmz_out(['scan1_refl_',file_tag],scan1_refl_kml,[kml_dir,ident_data_path],[tempdir,'scan1_refl_',file_tag,'.gif']);
    end
    
    %scan2_refl
    if options(2)==1
        %load image mat file
        scan2_refl=mat_wrapper(data_path,'scan2_refl');
        scan2_refl=data_transform(scan2_refl,'refl',target_refl_vars,min_dbz);
        
        %save to file, generate kml, zip kml and image into kmz
        imwrite(scan2_refl,interp_refl_cmap,[tempdir,'scan2_refl_',file_tag,'.gif'],'TransparentColor',1);
        scan2_refl_kml=ge_groundoverlay('',['scan2_refl_',file_tag],['scan2_refl_',file_tag,'.gif'],intp2kml(i).region_latlonbox,'','','clamped','',1);
        ge_kmz_out(['scan2_refl_',file_tag],scan2_refl_kml,[kml_dir,ident_data_path],[tempdir,'scan2_refl_',file_tag,'.gif']);
    end
    
    %scan1_vel
    if (options(3)==1 && strcmp(target_radar_type,'vel'));
        %load image mat file
        scan1_vel=mat_wrapper(data_path,'scan1_vel');
        scan1_vel=data_transform(scan1_vel,'vel',target_vel_vars,min_vel);
        
        %save to file, generate kml, zip kml and image into kmz
        imwrite(scan1_vel,interp_vel_cmap,[tempdir,'scan1_vel_',file_tag,'.gif'],'TransparentColor',1);
        scan1_vel_kml=ge_groundoverlay('',['scan1_vel_',file_tag],['scan1_vel_',file_tag,'.gif'],intp2kml(i).region_latlonbox,'','','clamped','',1);
        ge_kmz_out(['scan1_vel_',file_tag],scan1_vel_kml,[kml_dir,ident_data_path],[tempdir,'scan1_vel_',file_tag,'.gif']);
    end
    
    %scan2_vel
    if (options(4)==1 && strcmp(target_radar_type,'vel'));
        %load image mat file
        scan2_vel=mat_wrapper(data_path,'scan2_vel');
        scan2_vel=data_transform(scan2_vel,'vel',target_vel_vars,min_vel);
        
        imwrite(scan2_vel,interp_vel_cmap,[tempdir,'scan2_vel_',file_tag,'.gif'],'TransparentColor',1);
        scan2_vel_kml=ge_groundoverlay('',['scan2_vel_',file_tag],['scan2_vel_',file_tag,'.gif'],intp2kml(i).region_latlonbox,'','','clamped','',1);
        ge_kmz_out(['scan2_vel_',file_tag],scan2_vel_kml,[kml_dir,ident_data_path],[tempdir,'scan2_vel_',file_tag,'.gif']);
    end    
    %before attempting to produce other kml layers, check for sig refl
    if target_sig_refl==1
        %find ident objects belong to the current intp scan
        ident_ind=find([ident2kml.start_timedate]==target_start_timedate & [ident2kml.radar_id]==target_radar_id);
        
        for j=1:length(ident_ind)
            
            %load reflectivity data
            %subset_lon_vec=ident2kml(ident_ind(j)).subset_lon_vec;
            %subset_lat_vec=ident2kml(ident_ind(j)).subset_lat_vec;
            subset_latlonbox=ident2kml(ident_ind(j)).subset_latlonbox;
            %subset_z_vec=intp2kml(i).subset_z_asl_vec;
            
            subset_id=ident2kml(ident_ind(j)).subset_id;
            subv_refl_varname=['subv_refl_',num2str(subset_id)];
            subv_refl=mat_wrapper(data_path,subv_refl_varname);
            
            subset_tag=[file_tag,'_cell_',num2str(subset_id)];
            
            xsec_levels=options(15:end);
            %refl x section
            if options(5)==1
                
                for k=1:length(xsec_levels)
                    %calculate cappi layer and extract from v
                    temp_x_section=flipud(subv_refl(:,:,xsec_levels(k)));
                    elev=subset_z_vec(xsec_levels(k));
                    %transform and scale for colormat
                    temp_x_section=data_transform(temp_x_section,'refl',target_refl_vars,min_dbz);
                    
                    x_section_fn=['refl_xsec_',num2str(xsec_levels(k)),'_',subset_tag];
                    
                    %write cappi_refl as a gif file to tempdir
                    imwrite(temp_x_section,interp_refl_cmap,[tempdir,x_section_fn,'.gif'],'TransparentColor',1);
                    %create groundoverlay kml data
                    cappi_kml=ge_groundoverlay('',x_section_fn,[x_section_fn,'.gif'],subset_latlonbox,'','','absolute',elev,1);

                    %use cappi_kml to create a kmz file containing the image file.
                    ge_kmz_out(x_section_fn,cappi_kml,[kml_dir,ident_data_path],[tempdir,x_section_fn,'.gif']);
                end

            end

            %doppler x section
            if options(6)==1 && strcmp(target_radar_type,'vel')
                
                %load doppler data
                subv_vel_varname=['subv_vel_',num2str(subset_id)];
                subv_vel=mat_wrapper(data_path,subv_vel_varname);
                
                for k=1:length(xsec_levels)
                    %calculate cappi layer and extract from v
                    temp_x_section=flipud(subv_vel(:,:,xsec_levels(k)));
                    elev=subset_z_vec(xsec_levels(k));
                    %find values outside domain and set to the transparent index (1) or maximum
                    temp_x_section=data_transform(temp_x_section,'vel',target_vel_vars,min_vel);
                    
                    x_section_fn=['vel_xsec_',num2str(xsec_levels(k)),'_',subset_tag];
                    
                    %write cappi_refl as a gif file to tempdir
                    imwrite(temp_x_section,interp_vel_cmap,[tempdir,x_section_fn,'.gif'],'TransparentColor',1);
                    %create groundoverlay kml data
                    cappi_kml=ge_groundoverlay('',x_section_fn,[x_section_fn,'.gif'],subset_latlonbox,'','','absolute',elev,1);

                    %use cappi_kml to create a kmz file containing the image file.
                    ge_kmz_out(x_section_fn,cappi_kml,[kml_dir,ident_data_path],[tempdir,x_section_fn,'.gif']);
                end
                
            end
            
            %smooth subv
            if options(7)==1 | options(8)==1
                subv_refl = smooth3(subv_refl);
                subset_ijbox = ident2kml(ident_ind(j)).subset_ijbox;
                lat_ind = subset_ijbox(1):subset_ijbox(2);
                lon_ind = subset_ijbox(3):subset_ijbox(4);
                subset_lat_vec = r_lat_vec(lat_ind);
                subset_lon_vec = r_lon_vec(lon_ind);
            end
            
            %inneriso
            if options(7)==1
                %generate isosurface for inner dbz
                try
                    iso_kml('inneriso',subset_tag,subv_refl,subset_lon_vec,subset_lat_vec,r_amsl_vec,kml_dir);
                catch
                    keyboard
                end
                end

            %outeriso
            if options(8)==1
                %generate isosurface for outer dbz
                iso_kml('outeriso',subset_tag,subv_refl,subset_lon_vec,subset_lat_vec,r_amsl_vec,kml_dir);
            end

            %storm_stats_chk
            if options(9)==1
                %extract stats and latloncent vec
                ident_stats=ident2kml(ident_ind(j)).stats;
                ident_latloncent=ident2kml(ident_ind(j)).dbz_latloncent;
                %generate balloon stats kml and save
                vild=roundn(ident_stats(11)/ident_stats(7)*1000,-2);
                kml_str=ge_balloon_stats_placemark('',1,'../doc.kml#balloon_stats_style','',vild,round(ident_stats(15)),round(ident_stats(7)),ident2kml(ident_ind(j)).index,ident_latloncent(1),ident_latloncent(2));
                ge_kml_out([kml_dir,ident_data_path,'celldata_',subset_tag],['celldata_',subset_tag],kml_str);
            end
        end
    end
end
 
function data_out=data_transform(data_in,type,vars,min_value)

%find no data regions
data_alpha=logical(data_in==0);
%scale to true value using transformation constants
data_out=double(data_in).*vars(1)+vars(2);
if strcmp(type,'refl');
        %scale for colormapping
        data_out=(data_out-min_value)*2+1;
        %enforce no data regions
        data_out(data_alpha)=1;
else strcmp(type,'vel');
        %scale for colormapping
        data_out=(data_out-min_value)+1;
        %enforce no data regions
        data_out(data_alpha)=1;
end
