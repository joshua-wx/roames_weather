%% Create Map of SEQ for cliamtology paper

%load subsetted mapping data
subset_fn='marburg_map.mat';
load(subset_fn);

%create figure and axis
figure('color','w','position',[1 1 800 800]); hold on
ax=axesm('mercator','MapLatLimit',[-28.51 -26.71],'MapLonLimit',[151.8 153.6]);
%ax=axesm('mercator','MapLatLimit',lat_limit,'MapLonLimit',lon_limit)

%create correct grid and label spacing
gridm('MLineLocation',.5,'PLineLocation',.5)
mlabel on; plabel on; framem on; axis off;
setm(ax, 'MLabelLocation', .5, 'PLabelLocation', .5,'MLabelRound',-1,'PLabelRound',-1,'LabelUnits','degrees','Fontsize',12)

%plot coast lines
geoshow(coast_lat,coast_lon,'DisplayType','line','color','k','LineWidth',1)

%plot somerset
%geoshow(somerset_lat,somerset_lon,'DisplayType','polygon','FaceColor','w','LineWidth',1)

%plot wivenhow
%geoshow(wivenhoe_lat,wivenhoe_lon,'DisplayType','polygon','FaceColor','w','LineWidth',1)

%plot border lines
%geoshow(border_lat,border_lon,'DisplayType','line','Linestyle','-.','color','k','LineWidth',1)

%plot shaded topo
%h = fspecial('gaussian',[15,15]);
%topo_z = imfilter(topo_z,h);
%geoshow(topo_z,topo_refvec,'DisplayType','contour','LevelList',[300:200:2000],'LineColor','k','LineWidth',2);
%%geoshow(topo_z,topo_refvec,'DisplayType','texturemap');


%add radar location and range rings
r_lat = -27.61;
r_lon = 152.54;
ring_r1 = 40;
ring_r2 = 80;
[lat,lon] = scircle1(r_lat,r_lon,km2deg(ring_r1));
plotm(lat,lon,'k')
[lat,lon] = scircle1(r_lat,r_lon,km2deg(ring_r2));
plotm(lat,lon,'k')
plotm(r_lat,r_lon,'kd','MarkerSize',10,'MarkerFaceColor','k')


%set colormap for topo
% cmap=flipud(colormap(gray(12)));
% caxis([0 1200])
% colormap(cmap)
% colorbar

% %add scale ruler
% patchm([-28.4 -28.5 -28.5 -28.4 -28.4],[151.82,151.82,152.55,152.55,151.82],'w')
% scaleruler on
% setm(handlem('scaleruler1'), ...
%     'XLoc',-.013,'YLoc',-.519, ...
%     'MajorTick',0:10:50,'fontsize',12)