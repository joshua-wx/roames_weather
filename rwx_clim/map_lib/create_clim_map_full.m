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
setm(ax, 'MLabelLocation', 1, 'PLabelLocation', .5,'MLabelRound',0,'PLabelRound',-1,'LabelUnits','degrees','Fontsize',12)
