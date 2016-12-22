function wv_clim(opt_struct)

%profile on
%profile clear

silence_radius = 16;


%% Add folders to path
addpath('../etc');
addpath('map_lib');
addpath('../lib/m_lib','../lib/ge_lib');
read_site_info
%% Check for GUI inputs
if nargin==0
    msgbox('please run with gui')
    return
end
%% Load global config files
config_input_path = 'global.config';
read_config(config_input_path);
load(['tmp/',config_input_path,'.mat']);

%% load site info and mapping coordinates
%load radar site lat, long and name
load('tmp/site_info.txt.mat')
r_ind=find(opt_struct.site_id==site_id_list);
site_lat=site_lat_list(r_ind); site_lon=site_lon_list(r_ind);

%mapping coordinates, working in ij coordinates
mstruct = defaultm('mercator');
mstruct.origin = [site_lat site_lon];
mstruct.geoid = almanac('earth','wgs84','kilometers');
mstruct = defaultm(mstruct);

%transform x,y into lat long using centroid
x_vec=-h_range:h_grid:h_range; %m, X domain vector
x_vec=x_vec./1000;
[lat_vec, lon_vec] = minvtran(mstruct, x_vec, x_vec);

%compute lat matrix
[lon_mat,lat_mat]=meshgrid(lon_vec,lat_vec);
%generate latlon box
min_lat=min(lat_vec); max_lat=max(lat_vec);
min_lon=min(lon_vec); max_lon=max(lon_vec);

%create custom centroid grid and cone mask if required
if opt_struct.type_opt==5
    %setup custom centroid grid which is generally courses than the proced
    %grid to accumulate CE/CI
    cent_grid = opt_struct.proc_opt(7);
    cent_x_vec=-h_range:cent_grid:h_range; %m, X domain vector
    cent_x_vec=cent_x_vec./1000;
    [cent_lat_vec, cent_lon_vec] = minvtran(mstruct, cent_x_vec, cent_x_vec);
    
    %create custom cone of silence region for centroid grid
    [cent_lon_mat,cent_lat_mat]=meshgrid(cent_lon_vec,cent_lat_vec);
    [site_dist,~] = distance(site_lat,site_lon,cent_lat_mat,cent_lon_mat);
    site_dist=deg2km(site_dist);
    cone_mask=site_dist>silence_radius;
    
    %make custom R
    %generate latlon box
    cent_min_lat=min(cent_lat_vec); cent_max_lat=max(cent_lat_vec);
    cent_min_lon=min(cent_lon_vec); cent_max_lon=max(cent_lon_vec);

    %georeference transform
    R = makerefmat('RasterSize',[length(cent_lat_vec),length(cent_lon_vec)],'Latlim', [cent_min_lat cent_max_lat], 'Lonlim', [cent_min_lon cent_max_lon]);
else
    %cone of silence region for proced grid
    [site_dist,~] = distance(site_lat,site_lon,lat_mat,lon_mat);
    site_dist=deg2km(site_dist);
    cone_mask=site_dist>silence_radius;
    %georeference transform
    R = makerefmat('RasterSize',[length(lat_vec),length(lon_vec)],'Latlim', [min_lat max_lat], 'Lonlim', [min_lon max_lon]);
end

%collate spatial data
latlonbox=[max_lat;min_lat;max_lon;min_lon];
spatial_data={latlonbox,lat_vec,lon_vec};

%start timer
tic
%% Create target date list

%attempt to load date_list_ffn
if ~isempty(opt_struct.date_list_ffn)
    if exist(opt_struct.date_list_ffn,'file')==2
        load(opt_struct.date_list_ffn)
        if exist('target_days','var')~=1
            msgbox('Date file does not contain the target_days variable')
            return
        elseif ~isnumeric(target_days)
            msgbox('date_list variable is not valid')
            return
        end
    else
        msgbox('Date list file does not exist')
        return
    end
else
    target_days=[];
end

%enfore stop/start dates, target days and month selection conditions to
%generate date_list
date_list = generate_date_list(opt_struct.td_opt(1),opt_struct.td_opt(2),opt_struct.month_selection,target_days);

%% Join ident_db's

%cat daily databases for times between oldest and newest time,
%allows for mulitple to be joined
filt_ident_db_ffn = db_cat_clim(opt_struct.arch_dir,date_list,'ident_db',opt_struct.site_id);

if isempty(filt_ident_db_ffn)
    msgbox('no intp_db for the time period')
    return
end

%% Process climatology plots

[grid_img_struct,dir_img_struct,stats_struct] = clim_grid(opt_struct,filt_ident_db_ffn,spatial_data);

%% Post process data

%calc mean intensity
if opt_struct.type_opt==2
    %divide sum by total count
    grid_img_struct.wdss_grid = grid_img_struct.wdss_grid./grid_img_struct.mean_density_grid;
end

%wind vectors
if opt_struct.dir_opt
    %extract vars
    grid_u = dir_img_struct.u_grid;
    grid_v = dir_img_struct.v_grid;
    grid_n = dir_img_struct.n_grid;
    %calc mean
    mean_grid_u = grid_u ./ grid_n;
    mean_grid_v = grid_v ./ grid_n;
    %apply cone mask
    mean_grid_u = mean_grid_u.*cone_mask;
    mean_grid_v = mean_grid_v.*cone_mask;
    %compute lat matrix
    [lon_mat,lat_mat]=meshgrid(lon_vec,lat_vec);
    %calc streamslice
    [dir_vertices,dir_arrowvertices] = streamslice(lon_mat,lat_mat,mean_grid_u,mean_grid_v,10);
end

%select plot_grid
if opt_struct.type_opt==1 || opt_struct.type_opt==2
    %MAX/MEAN selected
    plot_grid = grid_img_struct.wdss_grid;
    
    %convert centroid list into a grid
elseif opt_struct.type_opt==5
    %create plot_grid
    plot_grid = zeros(length(cent_lat_vec),length(cent_lat_vec));
    %extract centroids
    current_list = grid_img_struct.centroids_list;
    %regrid into plot_grid
    for i=1:size(current_list,1)
        temp_lat = current_list(i,1);
        temp_lon = current_list(i,2);
        [~,lat_ind] = min(abs(cent_lat_vec - temp_lat));
        [~,lon_ind] = min(abs(cent_lon_vec - temp_lon));
        plot_grid(lat_ind,lon_ind)=plot_grid(lat_ind,lon_ind)+1;
    end
    
else
    
    %DENSITY MERGED/CELL selected
    plot_grid = grid_img_struct.density_grid;
end
%normalise density
if opt_struct.proc_opt(5) %normalise by unique number of days
    %create list of unique sts days
    cell_date_list     = stats_struct.cell_date_list;
    cell_sts_date_list = cell_date_list(logical(stats_struct.cell_mask_list));
    sts_day_count      = length(unique(floor(cell_sts_date_list)));
    %normalise
    max_plot_grid = max(max(plot_grid));
    plot_grid = plot_grid./sts_day_count;
elseif opt_struct.proc_opt(8) %normalise by unique number of years
    %create count of years
    cell_date_list     = stats_struct.cell_date_list;
    cell_sts_year_list = seq_rain_year(cell_date_list(logical(stats_struct.cell_mask_list)));
    sts_year_count     = length(unique(cell_sts_year_list));
    %normalise
    max_plot_grid = max(max(plot_grid));
    plot_grid = plot_grid./sts_year_count;
else
    max_plot_grid = max(max(plot_grid));
end

%apply cone mask to plot_grid
%plot_grid = plot_grid.*cone_mask;



%% KML Generation

if opt_struct.output_opt(4)

    %generate range ring kml
    [object_kml,style_kml] = ge_rr_kml('','',site_lat,site_lon,120,10);
    %topo map
    %[object_kml,style_kml] = ge_topo_kml(object_kml,style_kml,'gtopo30/AUS-gtopo30.zip',50,1200,latlonbox);

    %grid output
    [output_kml,image_fn_list]=generate_grid_kml('',plot_grid,opt_struct,latlonbox);
    %append object kml into folder
    object_kml=ge_folder(object_kml,output_kml,'Primary Layer','',1);
    
    %generate driection layer kml
    if opt_struct.dir_opt
        %generate streamline style
        style_kml=ge_line_style(style_kml,['streamline_style'],html_color(1,[0,0,0]),2);
        %generate streamline kml
        stream_kml=ge_multi_line_string('',1,'ge_dir_clim','#streamline_style',0,'clampToGround',0,1,datestr(opt_struct.td_opt(1),S),datestr(opt_struct.td_opt(2)),[dir_vertices,dir_arrowvertices]);
        %append object kml into folder
        object_kml=ge_folder(object_kml,stream_kml,'Direction','',1);
    end
    
    %kmz output
    out_kml=[style_kml,object_kml];
    ge_kmz_out('ge_vis',out_kml,opt_struct.clim_dir,image_fn_list);
end

%% Static Image Generation

if opt_struct.output_opt(3)
    %inialise plot
    create_clim_map_uq  
    %primary grid
    if opt_struct.ci_opt || opt_struct.ce_opt
        geoshow(plot_grid,R,'DisplayType','texturemap','CDataMapping','scaled');
    else
        geoshow(plot_grid,R,'DisplayType','contour','LevelList',[0.1:0.1:1],'LineColor','none','Fill','on');
        %geoshow(plot_grid,R,'DisplayType','texturemap','CDataMapping','scaled');%,'FaceAlpha','texturemap','AlphaData',double(cone_mask))
    end
    %set clim
    if ~isnan(opt_struct.proc_opt(4))
        caxis([0 opt_struct.proc_opt(4)]);
    else
        caxis([0 max(plot_grid(:))]);
    end
    
    cmap = colormap(hot(128));
    cmap = flipud(cmap);
    colormap(cmap)
    
    
    %load subsetted mapping data
    subset_fn='marburg_map.mat';
    load(subset_fn);
    %plot coast lines
    geoshow(coast_lat,coast_lon,'DisplayType','line','color','k','LineWidth',1)
    
    %generate driection plot
    if opt_struct.dir_opt
        vec_data=[dir_vertices,dir_arrowvertices];
        for i=1:length(vec_data)
            tmp_vec=vec_data{i};
            if ~isempty(tmp_vec)
                linem(tmp_vec(:,2),tmp_vec(:,1),'LineWidth',.5,'color',[.3,.3,.3])
            end
        end
    end    
    %overlay place names
    create_clim_map_names_uq
    
    %setup colorbar
    ch=colorbar('FontSize',12);
    set(get(ch,'ylabel'),'string','Annual Frequency','fontsize',16); %MODIFY LABEL ACCORDING TO SURFACE IMAGE UNITS

    add cone of silence
    [cone_lat,cone_lon] = scircle1(site_lat,site_lon,km2deg(silence_radius));
    geoshow(cone_lat,cone_lon,'DisplayType','polygon','facecolor','w','edgecolor','k')
    
    
    %set(get(ch,'ylabel'),'string','Density','fontsize',16);
    
    %add scale ruler 800x800 plot
%     patchm([-28.4 -28.5 -28.5 -28.4 -28.4],[152.75,152.75,153.53,153.53,152.75],'w')
%     scaleruler on
%     setm(handlem('scaleruler1'), ...
%         'XLoc',.0035,'YLoc',-.519, ...
%         'MajorTick',0:10:50,'fontsize',12)

    %add scale ruler 400x400 plot  
%     patchm([-28.35 -28.5 -28.5 -28.35 -28.35],[152.75,152.75,153.53,153.53,152.75],'w')
%     scaleruler on
%     setm(handlem('scaleruler1'), ...
%         'XLoc',.002,'YLoc',-.519, ...
%         'MajorTick',0:25:50,'MinorTick',0,'fontsize',8)
    
    %print to tiff file
    set(gcf, 'PaperPositionMode', 'auto');
    print(gcf,'-dpng','-r400',[opt_struct.clim_dir,'plot.png'])
    close all;
end

%% Save storm stats
if opt_struct.output_opt(1)
    save([opt_struct.clim_dir,'stats_struct.mat'],'stats_struct','-v7.3')
end
%% Create log file is required
if opt_struct.output_opt(2)
    %create log for stats
    cated_log=log_cat(arch_dir,date_list,site_id);
    log_stats(clim_dir,cated_log,oldest_td,newest_td,site_id);
end

%% Update user
%Update user
disp([10,'climatology pass complete. ',num2str(year(opt_struct.td_opt(2))-year(opt_struct.td_opt(1))),' years added',10])

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc),' @@@@@@@@@'])

%profile off
%profile viewer

%TO DO FINISH TESTING PLOT AND KMZ OUTPUTS OF ALL CHARTS



function date_list=generate_date_list(start_date,stop_date,month_selection,target_date_list)
%generates a date_list between oldest_td and newest_td for the
%month_selection. date_list is organised in a matrix

%OUTPUT:
%datelist: matrix of cells where each cells contains all the dates required
    %to process for a single year

%round time down to the day (remove decimal)
start_date=floor(start_date);
stop_date=floor(stop_date);
time_vec=[start_date:stop_date];

%if target_date_list, intersect with time_vec to enforce start/stop limits
if ~isempty(target_date_list)
    time_vec = intersect(time_vec, target_date_list');
end

%setup month numbers and year list
month_selection=str2num(month_selection);
year_list=year(start_date):year(stop_date);
date_list=[];

%loop through year list
for i=1:length(year_list)
    %loop through months
    temp_date_list=[];
    for j=1:length(month_selection)
        %generate starting date for the month
        start_date=datenum(year_list(i),month_selection(j),1);
        %apend remaining dates
 
        temp_date_list=[temp_date_list,start_date:(addtodate(start_date,1,'month')-1)];
  
        
    end
    %keep temp_date_list entires which lie between start and stop date
    %(rather than just year and month)
    temp_date_list = intersect(time_vec, temp_date_list);
    %cat to date_list
    date_list=[date_list;temp_date_list'];


end


function filt_db_ffn=db_cat_clim(arch_dir,date_list,db_name,site_id)
%WHAT: Search arch dir for db of type db_name which fall between oldest and
%newest time. The ffn's of these databases are collated.

%INPUT
%arch_dir: path of processed data directort
%datelist: matrix of cells where each cells contains all the dates required
%to process for a single year
%db_name: database type (intp_db, ident_db, track_db)
%site id: radar site id

%loop through each date list
filt_db_ffn={};
for i=1:length(date_list)
    %build path to db_name for that date
    date_tag=datevec(date_list(i));
    db_path=[arch_dir,'IDR',num2str(site_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/',db_name,'_',datestr(date_list(i),'dd-mm-yyyy'),'.mat'];
    if exist(db_path,'file')==2
        filt_db_ffn=[filt_db_ffn;db_path];
    else
        %report database missing for that day
        disp([db_name,' database missing for ',datestr(date_list(i),'dd-mm-yyyy')]);
    end
end


function [object_kml,style_kml]=ge_topo_kml(object_kml,style_kml,gtopo_path,interval_m,max_height_m,latlonbox)
%WHAT: Generates the topo contours in google earth kml using a gtopo30 file

%create tmp dir
tmp_dir='/tmp/gtopo30/';
if exist(tmp_dir,'file')==7
    rmdir(tmp_dir,'s');
end
mkdir(tmp_dir);

%generate kml topo layer
unzip(gtopo_path,tmp_dir);
[Z,Z_refvec] = gtopo30(tmp_dir,1,latlonbox([2,1])',latlonbox([4,3])');
h=figure;
[topo_style,topo_object]=ge_kml_contour(Z_refvec,Z,[0:interval_m:max_height_m]);
%append kml
object_kml = [object_kml,topo_object];
style_kml  = [style_kml,topo_style];

function [object_kml,style_kml]=ge_rr_kml(object_kml,style_kml,site_lat,site_lon,range_radius,cone_radius)
%WHAT: Generates kml objects and style for cone of silence and 120km range
%ring
rr_style='';
rr_object='';

%generate range ring style
rr_style=ge_line_style(rr_style,['coverage_style'],html_color(1,[1,1,1]),1);

%Range ring kml
%generate outer 120km range ring latlon
[temp_lat,temp_lon] = scircle1(site_lat,site_lon,km2deg(range_radius));
%generate kml string
coverage_kml=ge_line_string('',1,'coverage','#coverage_style',0,'relativeToGround',0,1,temp_lat(1:end-1),temp_lon(1:end-1),temp_lat(2:end),temp_lon(2:end));
%place in folder
rr_object=ge_folder(rr_object,coverage_kml,'coverage ring','',1);

%Cone of silence ring
%generate outer 9km range ring latlon
[temp_lat,temp_lon] = scircle1(site_lat,site_lon,km2deg(cone_radius));
%generate kml string
silence_kml=ge_line_string('',1,'silence','#coverage_style',0,'relativeToGround',0,1,temp_lat(1:end-1),temp_lon(1:end-1),temp_lat(2:end),temp_lon(2:end));
%place in folder
rr_object=ge_folder(rr_object,silence_kml,'silence ring','',1);

%append to global kml
object_kml = [object_kml,rr_object];
style_kml  = [style_kml,rr_style];



function [object_kml,image_fn_list]=generate_grid_kml(object_kml,grid_img,opt_struct,latlonbox)
%WHAT: Generates the kml object/style string + images for the primary grid including
%colourbar. Export kml string and assocaited image filenames
image_fn_list = {};
    
%load config variables
load('tmp/global.config.mat')

%generate alpha_img
alpha_img=ones(size(grid_img));

%Generate colorbar and flipud
grid_img=flipud(grid_img)+1;
max_density=max(grid_img(:));
colorbar_ffn=generate_colorbar(max_density,'Density');

%Colorbar overlay kml
object_kml=ge_screenoverlay(object_kml,'Plot Colorbar','geclim_colorbar.png',.94,.2,0,.4,datestr(opt_struct.td_opt(1),S),datestr(opt_struct.td_opt(2),S));

%Swath overlay kml
%create transparency for 1 value pixels
alpha_img(grid_img==1)=0;
%write image to file
A = ind2rgb(grid_img,flipud(hot(12)));

img_ffn=[tempdir,'geclim_grid.png'];
imwrite(A,img_ffn,'Alpha',alpha_img);
%link with kml
object_kml=ge_groundoverlay(object_kml,'GE Climatology','geclim_grid.png',latlonbox,datestr(opt_struct.td_opt(1),S),datestr(opt_struct.td_opt(2),S),'clamped',0,1);

image_fn_list=[image_fn_list,colorbar_ffn,img_ffn];



function colorbar_ffn=generate_colorbar(max_value,colorbar_title)
%generates kmz colorbar image
%generate tick intervals
intervals=round([0:max_value/5:max_value]);
y_ticks={};

%generate interval names
for i=1:length(intervals)
    y_ticks=[y_ticks,num2str(intervals(i))];
end

%generate colorbar
colormap(flipud(hot((max_value))));
h=colorbar('YTickLabel',y_ticks,'YTick',intervals+1);
set(h,'FontWeight','bold','FontSize',16);
set(get(h,'ylabel'),'string',colorbar_title,'fontsize',16);
%save figure to image
saveas(gca,[tempdir,'colorbar.png'],'png');
close gcf
%load image as matrix
A = imread([tempdir,'colorbar.png'],'png');
%convert to ind image
[X,map] = rgb2ind(A, 65536);
%crop image matrix
X=X(40:840,980:1165);
%write back to file
colorbar_ffn=[tempdir,'geclim_colorbar.png'];
imwrite(X,map,colorbar_ffn);

function rain_year=seq_rain_year(dt_num)

%WHAT: calculate the rain year for each date num entry. Example 2010 rain year runs
%from 1/7/2010 to 31/6/2011

dt_vec    = datevec(dt_num);
rain_year = dt_vec(:,1);

%loop through every date num
for i=1:length(dt_num)
    
    %change rain_years if month is between Jan-June
    if dt_vec(i,2)<=6
        %case: Jan-June, use year before
        rain_year(i)=dt_vec(i,1)-1;
    end
    
end
