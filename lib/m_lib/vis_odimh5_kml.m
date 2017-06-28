function [link,ffn] = vis_odimh5_kml(dest_path,data_tag,img_atts,ppi_struct,data_number)

load('tmp/interp_cmaps.mat')
load('tmp/vis.config.mat')
load('tmp/global.config.mat')

%generate png
if data_number == 1
    ppi_data  = ppi_struct.data1.data;
    img_cmap  = interp_refl_cmap;
    min_value = min_dbzh;
elseif data_number == 2
    ppi_data  = ppi_struct.data2.data;
    img_cmap  = interp_vel_cmap;
    min_value = min_vradh;
end

%regrid into cartesian
[ppi_azi_grid,ppi_rng_grid] = meshgrid(ppi_struct.atts.azi_vec,ppi_struct.atts.rng_vec); %grid for dataset
ppi_img                     = interp2(ppi_azi_grid,ppi_rng_grid,ppi_data,img_atts.img_azi,img_atts.img_rng,'linear');

%filter refl
if data_number == 1
    ppi_img(ppi_img<ppi_dbzh_mask) = min_value;
end

%apply domain mask
domain_mask           = img_atts.radar_mask;
ppi_img(~domain_mask) = min_value;

%transform into png
ppi_img_png = png_transform(ppi_img,'refl',min_value);
%resize png (smoother in GE)
[ppi_img_png,img_cmap] = imresize(ppi_img_png,img_cmap,ppi_resize_scale,'nearest','Colormap','original');
%build alpha map
alpha_map   = ones(length(img_cmap),1); alpha_map(1) = 0;
%write to file
png_ffn     = [tempdir,data_tag,'.png'];
imwrite(ppi_img_png,img_cmap,png_ffn,'Transparency',alpha_map);

%wrap in kmz and generate link
%generate groundoverlay_kml
ppi_img_kml  = ge_groundoverlay('',data_tag,[data_tag,'.png'],img_atts.img_latlonbox,'','','clamped','',1,0);
%size kmlstr and png into a kmz
kmz_fn  = [data_tag,'.kmz'];
ge_kmz_out(kmz_fn,ppi_img_kml,dest_path,png_ffn);
%create link
link = kmz_fn;
ffn  = [dest_path,kmz_fn];

function data_out = png_transform(data_in,type,min_value)
%find no data regions
%scale to true value using transformation constants
if strcmp(type,'refl');
        %scale for colormapping
        data_out = (data_in-min_value)*2+1;
else strcmp(type,'vel');
        %scale for colormapping
        data_out = (data_in-min_value)+1;
end
