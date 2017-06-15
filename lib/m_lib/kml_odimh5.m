function kmlobj_struct = kml_odimh5(kmlobj_struct,odimh5_ffn,mask_grid,radar_id,radar_step,dest_root,transform_path,options)

%WHAT: Master script that generates new kml objects and updates the kml
%network tree structure

%load radar colormap and gobal config
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load(['tmp/',site_info_fn,'.mat']);
load('tmp/vis.config.mat')

%init vars
ppi_path     = [dest_root,ppi_obj_path,num2str(radar_id,'%02.0f'),'/'];
transform_fn = [transform_path,'regrid_transform_',num2str(radar_id,'%02.0f'),'.mat'];

%% ppi ground overlays ########### CHANGE LOOP TO RUN odimh5_fn_list
    
%load transform
load(transform_fn,'img_azi','img_rng','img_latlonbox','geo_coords','h_grid_deg')
%struct up atts
img_atts = struct('img_azi',img_azi,'img_rng',img_rng,'img_latlonbox',img_latlonbox,'radar_mask',mask_grid);
%process odimh5
ppi_struct               = process_read_ppi_data(odimh5_ffn,ppi_sweep);
ppi_NI                   = ppi_struct.atts.NI;
[ppi_elv,~]              = process_read_ppi_atts(odimh5_ffn,ppi_sweep);
vol_start_time           = process_read_vol_time(odimh5_ffn);
if isempty(ppi_elv) || isempty(ppi_struct)
    %error loading file, skip this ppi
    return
end
vol_stop_time            = addtodate(vol_start_time,radar_step,'minute');
[~,data_tag,~]           = fileparts(odimh5_ffn);
%PPI Reflectivity
if options(1)==1
    %create kml for refl ppi
    ppi_tag                   = [data_tag,'.ppi_dbzh.elv_',num2str(ppi_elv,'%02.1f')];
    [link,ffn]                = kml_odimh5_ppi(ppi_path,ppi_tag,img_atts,ppi_struct,1);
    kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',vol_start_time,vol_stop_time,img_latlonbox,'ppi_dbzh',link,ffn);
end
%PPI Velocity
if options(2)==1 && ~isempty(ppi_NI)
    %create kml for vel ppi
    ppi_tag                   = [data_tag,'.ppi_vradh.sweep_',num2str(ppi_elv,'%02.1f')];
    [link,ffn]                = kml_odimh5_ppi(ppi_path,ppi_tag,img_atts,ppi_struct,2);
    kmlobj_struct             = collate_kmlobj(kmlobj_struct,radar_id,'',vol_start_time,vol_stop_time,img_latlonbox,'ppi_vradh',link,ffn);
end
%Single Doppler Velocity
if options(9)==1 && ~isempty(ppi_NI)
    %create kml for vel ppi
	sdppi_struct              = process_read_ppi_data(odimh5_ffn,sd_sweep+1); %python to matlab index
	[sdppi_elv,~]             = process_read_ppi_atts(odimh5_ffn,sd_sweep+1); %python to matlab index
    sdppi_tag                 = [data_tag,'.ppi_singledop.sweep_',num2str(sdppi_elv,'%02.1f')];
    [error,png_ffn,~]         = process_singledop(odimh5_ffn,sdppi_struct,data_tag,radar_id);
    if isempty(error)
        [link,ffn]            = kml_singledop_ppi(dest_path,png_ffn,data_tag,geo_coords,h_grid_deg);
        kmlobj_struct         = collate_kmlobj(kmlobj_struct,radar_id,'',vol_start_time,vol_stop_time,img_latlonbox,'ppi_singledop',link,ffn);
    else
        log_cmd_write('tmp/log.singledop','','',odimh5_ffn)
		disp(error)
    end
end

function kmlobj_struct = collate_kmlobj(kmlobj_struct,radar_id,sort_id,vol_start_time,vol_stop_time,storm_latlonbox,type,link,ffn)
%WHAT: Append entry to kmlobj_struct

if isempty(link)
    return
end

tmp_struct = struct('radar_id',radar_id,'sort_id',sort_id,...
    'start_timestamp',vol_start_time,'stop_timestamp',vol_stop_time,...
    'latlonbox',storm_latlonbox,'type',type,'nl',link,'ffn',ffn);

kmlobj_struct = [kmlobj_struct,tmp_struct];
