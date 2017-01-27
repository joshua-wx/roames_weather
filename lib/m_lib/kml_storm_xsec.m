function [link,ffn] = kml_storm_xsec(dest_root,dest_path,data_tag,storm_vol,xsec_idx,xsec_alt,storm_latlonbox,cmap,min_value,data_type)


%extract layer and extract from volume
xsec_data = flipud(storm_vol(:,:,xsec_idx));
xsec_img  = image_transform(xsec_data,data_type,min_value);
%init fn
xsec_tag  = [data_tag,'_',data_type,'_',num2str(roundn(xsec_alt,2)),'m_xsec'];
%write image and create kml
png_fn   = [xsec_tag,'.png'];
png_ffn  = [tempdir,png_fn];
kmz_fn   = [xsec_tag,'.kmz'];
kmz_ffn  = [tempdir,kmz_fn];
alpha_map = ones(length(cmap),1); alpha_map(1) = 0;
imwrite(xsec_img,cmap,png_ffn,'Transparency',alpha_map);
xsec_kml  = ge_groundoverlay('',xsec_tag,png_fn,storm_latlonbox,'','','absolute',xsec_alt,1);
%use xsec_kml to create a kmz file containing the xsec image file.
ge_kmz_out(kmz_fn,xsec_kml,[dest_root,dest_path],png_ffn);
%init link
link = kmz_fn;
ffn  = [dest_root,dest_path,kmz_fn];