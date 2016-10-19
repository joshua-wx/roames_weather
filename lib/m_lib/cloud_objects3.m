function cloud_objects3(data_path,odimh5_jstruct,storm_jstruct,dest_dir,options)
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
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%loop through each intp_obj
for i=1:length(odimh5_jstruct)
    
    %init current vol atts
    vol_radar_id     = str2num(odimh5_jstruct(i).radar_id.N);
    vol_start_td     = datenum(odimh5_jstruct(i).start_timestamp.S,ddb_tfmt);
    vol_vel_ni       = str2num(odimh5_jstruct(i).vel_ni.N);
    vol_sig_refl     = str2num(odimh5_jstruct(i).sig_refl_flag.N);
    vol_latlonbox    = str2num(odimh5_jstruct(i).img_latlonbox.S)./geo_scale; %offset
    
    
    %set kml file tad
    data_tag = [num2str(vol_radar_id,'%02.0f'),'_',datestr(vol_start_td,r_tfmt)];
    
    %CREATE mapping coordinates vectors for radar site. needed for
    %isosurface generation
    vol_r_lat  = -site_lat_list(site_id_list==vol_radar_id);
    vol_r_lon  = site_lon_list(site_id_list==vol_radar_id);
    vol_r_alt  = site_elv_list(site_id_list==vol_radar_id);
    %mapping coordinates, working in ij coordinates
    mstruct        = defaultm('mercator');
    mstruct.origin = [vol_r_lat vol_r_lon];
    mstruct.geoid  = almanac('earth','wgs84','meters');
    mstruct        = defaultm(mstruct);
    %transfore x,y into lat long using centroid
    x_vec = -h_range:h_grid:h_range;
    [vol_lat_vec, vol_lon_vec] = minvtran(mstruct, x_vec, x_vec);
    vol_amsl_vec = [v_grid:v_grid:v_range]'+vol_r_alt;
    
    %scan1_refl
    if options(1)==1
        %create kml for tilt1 image
        kml_name       = [data_tag,'.scan1_refl'];
        png_ffn        = [pwd,'/',data_path,kml_name,'.png'];
        resize_png(png_ffn,4);
        scan1_refl_kml = ge_groundoverlay('',kml_name,[kml_name,'.png'],vol_latlonbox,'','','clamped','',1);
        ge_kmz_out(kml_name,scan1_refl_kml,[dest_dir,vol_data_path],png_ffn);
    end
    
    %scan2_refl
    if options(2)==1
        %create kml for tilt2 image
        kml_name       = [data_tag,'.scan2_refl'];
        png_ffn        = [pwd,'/',data_path,kml_name,'.png'];
        resize_png(png_ffn,4);
        scan2_refl_kml = ge_groundoverlay('',kml_name,[kml_name,'.png'],vol_latlonbox,'','','clamped','',1);
        ge_kmz_out(kml_name,scan2_refl_kml,[dest_dir,vol_data_path],png_ffn);
    end
    
    %scan1_vel
    if options(3)==1 && vol_vel_ni~=0
        %create kml for tilt2 image
        kml_name       = [data_tag,'.scan1_vel'];
        png_ffn        = [pwd,'/',data_path,kml_name,'.png'];
        resize_png(png_ffn,4);
        scan1_vel_kml  = ge_groundoverlay('',kml_name,[kml_name,'.png'],vol_latlonbox,'','','clamped','',1);
        ge_kmz_out(kml_name,scan1_vel_kml,[dest_dir,vol_data_path],png_ffn);
    end
    
    %scan2_vel
    if options(4)==1 && vol_vel_ni~=0
        %create kml for tilt1 image
        kml_name       = [data_tag,'.scan2_vel'];
        png_ffn        = [pwd,'/',data_path,kml_name,'.png'];
        resize_png(png_ffn,4);
        scan2_vel_kml  = ge_groundoverlay('',kml_name,[kml_name,'.png'],vol_latlonbox,'','','clamped','',1);
        ge_kmz_out(kml_name,scan2_vel_kml,[dest_dir,vol_data_path],png_ffn);
    end    
    %before attempting to produce other kml layers, check for sig refl
    if vol_sig_refl==1 && ~isempty(storm_jstruct)
        %init storm atts
        storm_radar_id = jstruct_to_mat([storm_jstruct.radar_id],'N');
        storm_start_td = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
        %find ident objects belong to the current intp scan
        storm_idx   = find(storm_start_td==vol_start_td & storm_radar_id==vol_radar_id);
        h5_data_fn  = [data_tag,'.storm.h5'];
        %loop through storms from this volume
        for j=1:length(storm_idx)
            %init storm atts
            subset_latlonbox  = str2num(storm_jstruct(storm_idx(j)).storm_latlonbox.S)./geo_scale;
            subset_id         = storm_jstruct(storm_idx(j)).subset_id.S;
            subset_id_n       = str2num(subset_id(end-2:end));
            subset_tag        = [num2str(vol_radar_id,'%02.0f'),'_',datestr(vol_start_td,r_tfmt),'_',subset_id(end-2:end)];
            %load storm refl vol
            storm_data_struct = h5_data_read(h5_data_fn,data_path,subset_id_n);
            storm_refl_vol    = double(storm_data_struct.refl_vol./r_scale);
            %refl x section
            if options(5)==1
                for k=1:length(xsec_levels)
                    %extract layer and extract from volume
                    xsec_refl = flipud(storm_refl_vol(:,:,xsec_levels(k)));
                    xsec_refl = image_transform(xsec_refl,'refl',min_dbz);
                    xsec_alt  = vol_amsl_vec(xsec_levels(k));
                    %init fn
                    xsec_tag = ['refl_xsec_',num2str(xsec_levels(k)),'_',subset_tag];
                    %write image and create kml
                    xsec_fn  = [xsec_tag,'.gif'];
                    xsec_ffn = [tempdir,xsec_fn];
                    imwrite(xsec_refl,interp_refl_cmap,xsec_ffn,'TransparentColor',1);
                    xsec_kml = ge_groundoverlay('',xsec_tag,xsec_fn,subset_latlonbox,'','','absolute',xsec_alt,1);
                    %use xsec_kml to create a kmz file containing the xsec image file.
                    ge_kmz_out(xsec_tag,xsec_kml,[dest_dir,storm_data_path],xsec_ffn);
                end

            end
            %doppler x section
            if options(6)==1 && vol_vel_ni~=0
                %load doppler data
                storm_vel_vol = double(storm_data_struct.vel_vol./r_scale);
                for k=1:length(xsec_levels)
                    %extract layer and extract from volume
                    xsec_vel = flipud(storm_vel_vol(:,:,xsec_levels(k)));
                    xsec_vel = image_transform(xsec_vel,'vel',min_vel);
                    xsec_alt = vol_amsl_vec(xsec_levels(k));
                    %init fn
                    xsec_tag = ['vel_xsec_',num2str(xsec_levels(k)),'_',subset_tag];
                    %write image and create kml
                    xsec_fn  = [xsec_tag,'.gif'];
                    xsec_ffn = [tempdir,xsec_fn];
                    imwrite(xsec_vel,interp_refl_cmap,xsec_ffn,'TransparentColor',1);
                    xsec_kml = ge_groundoverlay('',xsec_tag,xsec_fn,subset_latlonbox,'','','absolute',xsec_alt,1);
                    %use xsec_kml to create a kmz file containing the xsec image file.
                    ge_kmz_out(xsec_tag,xsec_kml,[dest_dir,storm_data_path],xsec_ffn);
                end
                
            end
            %smooth storm refl volume for isosurface and init atts
            if options(7)==1 || options(8)==1
                storm_refl_vol = smooth3(storm_refl_vol);
                storm_mat_size = size(storm_refl_vol);
                subset_lat_vec = linspace(subset_latlonbox(1),subset_latlonbox(2),storm_mat_size(1));
                subset_lon_vec = linspace(subset_latlonbox(3),subset_latlonbox(4),storm_mat_size(2));
            end
            
            %inneriso
            if options(7)==1
                %generate isosurface for inner dbz
                iso_kml('inneriso',subset_tag,storm_refl_vol,subset_lon_vec,subset_lat_vec,vol_amsl_vec,dest_dir);
            end

            %outeriso
            if options(8)==1
                %generate isosurface for outer dbz
                iso_kml('outeriso',subset_tag,storm_refl_vol,subset_lon_vec,subset_lat_vec,vol_amsl_vec,dest_dir);
            end

            %storm_stats_chk
            if options(9)==1
                %extract stats and latloncent vec
                storm_max_tops   = str2num(storm_jstruct(storm_idx(j)).max_tops.N)./stats_scale;
                storm_max_mesh   = str2num(storm_jstruct(storm_idx(j)).max_mesh.N)./stats_scale;
                storm_cell_vil   = str2num(storm_jstruct(storm_idx(j)).cell_vil.N)./stats_scale;
                storm_cell_vild  = roundn(storm_cell_vil/storm_max_tops*1000,-2);
                storm_dbz_centlat = str2num(storm_jstruct(storm_idx(j)).storm_dbz_centlat.N)./geo_scale;
                storm_dbz_centlon = str2num(storm_jstruct(storm_idx(j)).storm_dbz_centlon.N)./geo_scale;
                %generate balloon stats kml and save
                kml_str = ge_balloon_stats_placemark('',1,'../doc.kml#balloon_stats_style','',...
                    storm_cell_vild,round(storm_max_mesh),round(storm_max_tops),num2str(subset_id_n)...
                    ,storm_dbz_centlat,storm_dbz_centlon);
                ge_kml_out([dest_dir,storm_data_path,'celldata_',subset_tag],['celldata_',subset_tag],kml_str);
            end
        end
    end
end
 
function data_out = image_transform(data_in,type,min_value)

%find no data regions
data_alpha = logical(data_in==min_value);
%scale to true value using transformation constants
if strcmp(type,'refl');
        %scale for colormapping
        data_out = (data_in-min_value)*2+1;
        %enforce no data regions
        data_out(data_alpha) = 1;
else strcmp(type,'vel');
        %scale for colormapping
        data_out = (data_in-min_value)+1;
        %enforce no data regions
        data_out(data_alpha) = 1;
end
