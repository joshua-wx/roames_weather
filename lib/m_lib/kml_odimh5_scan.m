function [link,ffn] = kml_scan(dest_root,dest_path,download_path,odimh5_ffn)

%transfer odimh5 volume to local storage

%extract sweep and regrid



%init filename
png_ffn        = [download_path,scan_tag,'.png'];
%interpolate png to a larger size
resize_png(png_ffn,4);
%generate groundoverlay_kml
scan_name       = [scan_tag,'_tilt_',tilt_str];
scan1_refl_kml  = ge_groundoverlay('',scan_name,[scan_tag,'.png'],vol_latlonbox,'','','clamped','',1);
%size kmlstr and png into a kmz
kmz_fn  = [scan_name,'.kmz'];
ge_kmz_out(kmz_fn,scan1_refl_kml,[dest_root,dest_path],png_ffn);
%create link
link = kmz_fn;
ffn  = [dest_root,dest_path,kmz_fn];

% refl_transp  = ones(length(interp_refl_cmap),1); refl_transp(1) = 0;
% vel_transp   = ones(length(interp_vel_cmap),1);   vel_transp(1) = 0;
% s1_refl_png  = png_transform(vol_obj.scan1_refl,'refl',vol_obj.refl_vars,min_dbz);
% s2_refl_png  = png_transform(vol_obj.scan2_refl,'refl',vol_obj.refl_vars,min_dbz);
% s1_refl_ffn  = [tempdir,data_tag,'.scan1_refl.png'];
% s2_refl_ffn  = [tempdir,data_tag,'.scan2_refl.png'];
% imwrite(s1_refl_png,interp_refl_cmap,s1_refl_ffn,'Transparency',refl_transp);
% imwrite(s2_refl_png,interp_refl_cmap,s2_refl_ffn,'Transparency',refl_transp);
% 
% function data_out = png_transform(data_in,type,vars,min_value)
% 
% %find no data regions
% %scale to true value using transformation constants
% data_out=double(data_in).*vars(1)+vars(2);
% if strcmp(type,'refl');
%         %scale for colormapping
%         data_out=(data_out-min_value)*2+1;
% else strcmp(type,'vel');
%         %scale for colormapping
%         data_out=(data_out-min_value)+1;
% end
% 
% %extract ppi sweep 2 to check sig_refl
% scan2_refl_out = interp2(imgrid_a,imgrid_sr,scan2_refl,rad2deg(imgrid_intp_a+pi),imgrid_intp_sr,'nearest'); %interpolate scan2 into convereted regridded coord
% scan2_refl_out = rot90(scan2_refl_out,3); %orientate