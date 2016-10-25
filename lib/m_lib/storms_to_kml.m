function object_struct = storms_to_kml(object_struct,radar_id,oldest_time,newest_time,tar_fn_list,dest_root,options)

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

%init
oldest_time_str = datestr(oldest_time,ddb_tfmt);
newest_time_str = datestr(newest_time,ddb_tfmt);
radar_id_str    = num2str(radar_id,'%02.0f');

%extract odimh5 atts for radar_id
odimh5_atts   = 'tilt1,tilt2,img_latlonbox,vel_ni,sig_refl_flag';
jstruct_out   = ddb_query('radar_id',radar_id_str,'start_timestamp',oldest_time_str,newest_time_str,odimh5_atts,odimh5_ddb_table);
vol_latlonbox = str2num(jstruct_out(1).img_latlonbox.S)./geo_scale;
vol_vel_ni    = str2num(jstruct_out(1).vel_ni.N);
vol_tilt1_str = jstruct_out(1).tilt1.N;
vol_tilt2_str = jstruct_out(1).tilt2.N;
sig_refl_list = jstruct_to_mat(jstruct_out.sig_refl_flag,'N');

%generate data from tar_fn_list (scans and storm volumes)
for i=1:length(tar_fn_list)
    %init kmlobj ffn list
    kmlobj_ffn_list = {};
    %extract data_tag
    data_tag = tar_fn_list{i}(1:end-7);
    
    %% scan ground overlays
    %scan1_refl
    if options(1)==1
        %create kml for tilt1 image
        scan_tag         = [data_tag,'.scan1_refl'];
        kmlobj_ffn_list = ppi_groundoverlay(kmlobj_ffn_list,dest_root,scan_tag,download_path,vol_latlonbox,scan_obj_path,vol_tilt1_str);
    end
    %scan2_refl
    if options(2)==1
        %create kml for tilt2 image
        scan_tag         = [data_tag,'.scan2_refl'];
        kmlobj_ffn_list = ppi_groundoverlay(kmlobj_ffn_list,dest_root,scan_tag,download_path,vol_latlonbox,scan_obj_path,vol_tilt2_str);
    end
    %scan1_vel
    if options(3)==1 && vol_vel_ni~=0
        %create kml for tilt2 image
        scan_tag         = [data_tag,'.scan1_vel'];
        kmlobj_ffn_list = ppi_groundoverlay(kmlobj_ffn_list,dest_root,scan_tag,download_path,vol_latlonbox,scan_obj_path,vol_tilt1_str);
    end
    %scan2_vel
    if options(4)==1 && vol_vel_ni~=0
        %create kml for tilt1 image
        scan_tag         = [data_tag,'.scan2_vel'];
        kmlobj_ffn_list = ppi_groundoverlay(kmlobj_ffn_list,dest_root,scan_tag,download_path,vol_latlonbox,scan_obj_path,vol_tilt2_str);
    end
    
    %% isosurfaces
    h5_fn = [data_tag,'.wv.h5'];
    %check for a h5 dataset with the tar
    if exist(h5_ffn,'file') == 2
        %list groups
        h5_info  = h5info([download_path,h5_fn]);
        n_groups = length(h5_info.Groups);
        %convert each group to volume
        for i=1:length(n_groups)
            group_id          = num2str(i,'%02.0f');
            storm_data_struct = h5_data_read(h5_fn,download_path,group_id);
            %add collada code here!
            %move to dest
            %append new objects to kmlobj_ffn_list
        end
    end
end

%append kmlobj_ffn_list to file

%process objects from storm ddb if sig_refl exists
if any(sig_refl_list)
    %query storm ddb
    storm_atts = 'subset_id,start_timestamp,track_id,storm_dbz_centlat,storm_dbz_centlon,area,cell_vil,max_tops,max_mesh,orient,maj_axis,min_axis';
    storm_jstruct = ddb_query('radar_id',radar_id_str,'subset_id',oldest_time_str,newest_time_str,storm_atts,storm_ddb_table);
    %return if no storm_jstruct
    if ~isempty(storm_jstruct)
        

    %loop through by track groups
    %maybe make track_id by appending day?
    %generate kml for paths, swaths, nowcast, nowcast_stats, cell_stats.
    %Use folders for radar groups
    %append to kmlobj_ffn_list
    end
end

% delete track/cell kml files if no storms too!
    

function kmlobj_ffn_list = ppi_groundoverlay(kmlobj_ffn_list,dest_dir,scan_tag,download_path,vol_latlonbox,scan_obj_path,tilt_str)

%init filename
png_ffn        = [download_path,scan_tag,'.png'];
%interpolate png to a larger size
resize_png(png_ffn,4);
%generate groundoverlay_kml
scan_name       = [scan_tag,'_tilt_',tilt_str];
scan1_refl_kml  = ge_groundoverlay('',scan_name,[scan_tag,'.png'],vol_latlonbox,'','','clamped','',1);
%size kmlstr and png into a kmz
kmz_ffn         = ge_kmz_out(scan_tag,scan1_refl_kml,[dest_dir,scan_obj_path],png_ffn);
%append kmz ffn
kmlobj_ffn_list = [kmlobj_ffn_list;kmz_ffn];