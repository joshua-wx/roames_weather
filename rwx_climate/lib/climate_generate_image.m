function climate_generate_image(data_grid,vec_data,data_grid_R,site_lat,site_lon,map_config_fn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: generates image map for the provided data grid and config settings
%
% INPUTS
% data_grid:        grid of frequeny data
% vec_data:         vector contains locations of lines to draw for streamliner
%                   field (both lines and arrows)
% data_grid_R:      affine refecting matrix for grid
% map_config_fn:    file path to mapping config
%
% RETURNS: images generated as figures and saved to file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%read mapping config
read_config(map_config_fn);
load(['tmp/',map_config_fn,'.mat'])
%read climate config
load('tmp/climate.config.mat')

%create figure
h = figure('color','w','position',[1 1 fig_w fig_h]); hold on;
%set limits
ax=axesm('mercator','MapLatLimit',[map_S_lat map_N_lat],'MapLonLimit',[map_W_lon map_E_lon]);
%set options
mlabel on; plabel on; framem on; axis off;
%set grids and labels
setm(ax, 'MLabelLocation', lat_label_int, 'PLabelLocation', lon_label_int,'MLabelRound',lat_label_rnd,'PLabelRound',lon_label_rnd,'LabelUnits','degrees','Fontsize',label_fontsize)
gridm('MLineLocation',lat_grid_res,'PLineLocation',lon_grid_res)
%set axis mode
axis tight

%plot data
geoshow(flipud(data_grid),data_grid_R,'DisplayType','texturemap','CDataMapping','scaled'); %geoshow assumes xy coords, so need to flip ij data_grid
%assign colourmap
caxis([0 max(data_grid(:))]);
cmap = colormap(hot(128));
cmap = flipud(cmap);
colormap(cmap);

%draw coast
if draw_coast==1
    S = shaperead(coast_ffn);
    coast_lat = S(state_id).Y;
    coast_lon = S(state_id).X;
    linem(coast_lat,coast_lon,'k');
end

%draw topo
if draw_topo==1
    [topo_z,topo_refvec] = gtopo30(topo_ffn,topo_resample,[map_S_lat,map_N_lat],[map_W_lon,map_E_lon]);
    %create contours
    geoshow(topo_z,topo_refvec,'DisplayType','contour','LevelList',[topo_min:topo_step:topo_max],'LineColor',topo_linecolor,'LineWidth',topo_linewidth);
end

%draw placemarks
for i=1:length(cities_names)
    out_name = cities_names{i};
    out_lat  = cities_lat(i);
    out_lon  = cities_lon(i);
    out_horz = cities_horz_align{i};
    out_vert = cities_vert_align{i};
    out_ftsz = cities_fontsize(i);
    out_mksz = cities_marksize(i);
    textm(out_lat,out_lon,out_name,'HorizontalAlignment',out_horz,'VerticalAlignment',out_vert,'fontsize',out_ftsz,'FontWeight','bold')
    geoshow(out_lat,out_lon,'DisplayType','point','Marker','o','MarkerSize',out_mksz,'MarkerFaceColor','k','MarkerEdgeColor','k')
end

%plot streamliner lines and arrows
if draw_streamliners==1
    for i=1:length(vec_data)
        tmp_vec = vec_data{i};
        if ~isempty(tmp_vec)
            linem(tmp_vec(:,2),tmp_vec(:,1),'LineWidth',stream_linewith,'Color',stream_linecolor)
        end
    end
end

%plot cone of silence
if draw_silence == 1
	[cone_lat,cone_lon] = scircle1(site_lat,site_lon,km2deg(silence_radius));
	geoshow(cone_lat,cone_lon,'DisplayType','polygon','FaceColor',silence_face_color,'EdgeColor',silence_edge_color,'LineWidth',silence_line_width)
end

%plot radar site
if draw_site == 1
	geoshow(site_lat,site_lon,'DisplayType','point','Marker','+','MarkerSize',site_marker_size)
end

%plot range rings
if draw_range_rings == 1
	for i=1:length(range_ring_radius)
		[rr_lat,rr_lon] = scircle1(site_lat,site_lon,km2deg(range_ring_radius(i)));
		geoshow(rr_lat,rr_lon,'DisplayType','polygon','FaceColor','None','EdgeColor',rr_edge_color,'LineWidth',rr_line_width)
	end
end

%create colorbar
h = colorbar;
ylabel(h, colorbar_label)

%output
