function [link,ffn] = kml_scan_ppi(dest_root,scan_tag,download_path,vol_latlonbox,dest_path,tilt_str)

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