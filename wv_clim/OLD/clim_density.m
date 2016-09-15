function [object_kml,image_fn_list,stats_struct,output_images]=clim_density(filt_ident_db,newest_td,oldest_td,track_filt_opt,time_avg_opt,day_time_opt,ci_mode,snd_path,spatial_data)

%used for tags
year_list=year(oldest_td):year(newest_td);

%load config files
load('tmp_global_config.mat')

%load STS nomogram heights
%[snd_datenum,snd_fifty_dbz_min_h]=calc_freezing_h(snd_path);
if ~isempty(snd_path)
    load(snd_path);
    %convert meters to feet
    snd_fz_h=snd_fz_h.*3.2808399;
    %apply formula and convert back then km (ouput is in m...)
    snd_fifty_dbz_min_h=(17.536*snd_fz_h.^(.662))./1000;
    snd_datenum=floor(snd_datenum);
else
    snd_datenum=[];
    snd_fifty_dbz_min_h=[];
end

%extract spatial data
latlonbox=spatial_data{1};
lat_vec=spatial_data{2};
lon_vec=spatial_data{3};
max_lat=latlonbox(1); min_lat=latlonbox(2);
max_lon=latlonbox(3); min_lon=latlonbox(4);
%georeference transform
R = makerefmat('RasterSize',[length(lat_vec),length(lon_vec)],'Latlim', [min_lat max_lat], 'Lonlim', [min_lon max_lon]);

%generate blank swaths
all_swath_img=zeros(length(lat_vec),length(lon_vec));
out_swath=[];
image_fn_list={};
output_images=[];

%stat fields
cell_date_list=[];
cell_stat_list=[];
cell_trck_list=[];
cell_sts_mask=[];
cell_latloncent_list=[];

object_kml='';

%create mode tag
if ci_mode==1;
    mode_tag='CI';
else
    mode_tag='Density';
end

%loop through each track year
for y=1:length(filt_ident_db)
    %extract db for the current year
    yr_filt_ident_db=filt_ident_db{y};
    
    %generate blank swaths
    yr_swath_img=zeros(length(lat_vec),length(lon_vec));
    
    %create waitbar for user info
    try
    h = waitbar(0,['Building density/ci climatology from tracks for ',num2str(year_list(y))]);
    catch
        keyboard
    end
    current_percent=0;
    
    %loop throgh each day in the year
    for i=1:length(yr_filt_ident_db)
        %extract daily ident and track
        curr_day_ident=yr_filt_ident_db{i};
        if isempty(curr_day_ident)
            continue
        end
        curr_track_date=floor(curr_day_ident(1).start_timedate);
        [uniq_simple_tracks,~,ci]=unique([curr_day_ident.simple_id]);
        
        %loop through each track in the current day
        for j=1:length(uniq_simple_tracks)
            
            %extract current track ind
            track_ident_ind=find(ci==j);

            %sort track by time
            [~,sort_ind]=sort([curr_day_ident(track_ident_ind).start_timedate]);
            track_ident_ind=track_ident_ind(sort_ind);
            
            %time filter
            if day_time_opt(2)-day_time_opt(1)~=0
            %extract start_time
                track_start_time=curr_day_ident(track_ident_ind(1)).start_timedate;
                track_start_time=track_start_time-floor(track_start_time);
                if track_start_time<day_time_opt(1) || track_start_time>day_time_opt(2)
                    continue
                    %skip track because it starts outside of the filter
                    %time
                end
            end
            
            %extract filter track stats
            track_stats=vertcat(curr_day_ident(track_ident_ind).stats);
            track_latloncents=vertcat(curr_day_ident(track_ident_ind).dbz_latloncent);
            
            %check track length
            track_length=length(track_ident_ind);
            if track_length<track_filt_opt(1)
                continue
            end
                
            %extract 50hbz h stats
            track_50dbz_h = track_stats(:,13)/1000;
            track_50dbz_h(isnan(track_50dbz_h)) = 0;           
            
            %replace 50dbz threshold with STS nomogram height if entry
            %exists
            fifty_dbz_threshold=track_filt_opt(2);
            ind=find(snd_datenum==curr_track_date,1,'first');
            if ~isempty(ind)
                fifty_dbz_threshold=snd_fifty_dbz_min_h(ind);
            end
            
            %generate stats
            cell_date_list    = [cell_date_list,[curr_day_ident(track_ident_ind).start_timedate]];
            cell_stat_list    = [cell_stat_list;vertcat(curr_day_ident(track_ident_ind).stats)];
            cell_trck_list    = [cell_trck_list,[curr_day_ident(track_ident_ind).simple_id]];
            cell_latloncent_list = [cell_latloncent_list;vertcat(curr_day_ident(track_ident_ind).dbz_latloncent)];
            if ci_mode==1
                %CI plotting
                [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind),R,size(yr_swath_img),ci_mode);
            elseif track_filt_opt(3)==1
                %STS CELLS PLOT
                %create sts mask
                sts_mask   = track_50dbz_h>=fifty_dbz_threshold;
                %cluster into continous groups
                sts_label = bwlabel(sts_mask);
                %plot according to clusters
                if max(sts_label)>0
                    for k=1:max(sts_label)
                        [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind(sts_label==k)),R,size(yr_swath_img),ci_mode);
                        %append to swath img
                        yr_swath_img=yr_swath_img+track_swath_img;
                    end
                end
            elseif track_filt_opt(4)==1
                %TS CELLS PLOT
                %create ts mask
                ts_mask   = track_50dbz_h<fifty_dbz_threshold;
                %cluster into continous groups
                ts_label = bwlabel(ts_mask);
                %plot according to clusters
                if max(ts_label)>0
                    for k=1:max(ts_label)
                        [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind(ts_label==k)),R,size(yr_swath_img),ci_mode);
                        %append to swath img
                        yr_swath_img=yr_swath_img+track_swath_img;
                    end
                end
            elseif track_filt_opt(5)==1
                %STS TRACKS PLOT
                if max(track_50dbz_h)>=fifty_dbz_threshold
                    [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind),R,size(yr_swath_img),ci_mode);
                    %append to swath img
                    yr_swath_img=yr_swath_img+track_swath_img;
                end
            elseif track_filt_opt(6)==1
                %TS TRACKS PLOT
                if max(track_50dbz_h)<fifty_dbz_threshold
                    [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind),R,size(yr_swath_img),ci_mode);
                    %append to swath img
                    yr_swath_img=yr_swath_img+track_swath_img;
                end
            else
                %ALL TRACKS PLOT
                %plot entire track including non severe wells
                [track_swath_img]=gen_swath(curr_day_ident(track_ident_ind),R,size(yr_swath_img),ci_mode);
                %append to swath img
                yr_swath_img=yr_swath_img+track_swath_img;
            end

            %binary mask of sts cells. If threshold is 0, all cells will be
            %one
            cell_sts_mask=[cell_sts_mask;track_50dbz_h>=fifty_dbz_threshold];
            
        end
        
    end

    %update waitbar if on next percentage (daily updates)
    if round(i/length(yr_filt_ident_db)*100)>current_percent
        waitbar(i/length(yr_filt_ident_db))
        current_percent=round(i/length(yr_filt_ident_db)*100);
    end
    
    %close bar
    delete(h);
    
    %append yearly swath
    all_swath_img=all_swath_img+yr_swath_img;
    
    %output for three averaging cases
    if time_avg_opt(1)==1 && y==length(filt_ident_db) %all
        image_start_td=oldest_td;
        image_stop_td=newest_td;
        img_tag=[mode_tag,'_tot_',num2str(year_list(1)),'-',num2str(year_list(end))];
        out_swath=all_swath_img;
    elseif time_avg_opt(2)==1 %avg yearly
        image_start_td=datenum(year_list(y),1,1);
        image_stop_td=datenum(year_list(y),12,31);
        img_tag=[mode_tag,'_tot_',num2str(year_list(y))];
        out_swath=yr_swath_img;
    elseif time_avg_opt(3)==1 %cumulative yearly average
        image_start_td=datenum(year_list(y),1,1);
        image_stop_td=datenum(year_list(y),12,31);
        img_tag=[mode_tag,'_ctot_',num2str(year_list(1)),'-',num2str(year_list(y))];
        out_swath=all_swath_img;
    end
    
    %write colorbar and swath to file if required
    if ~isempty(out_swath)
        [object_kml,image_fn_list]=write_swath_image(object_kml,out_swath,image_start_td,image_stop_td,img_tag,latlonbox,image_fn_list);
        output_images=out_swath;
        out_swath=[];
    end
    
end

%append object kml into folder
object_kml=ge_folder('',object_kml,mode_tag,'',1);

%save stats to struct
stats_struct = struct('cell_date_list',cell_date_list,'cell_stat_list',cell_stat_list,'cell_trck_list',cell_trck_list,'cell_sts_mask',cell_sts_mask,'cell_latloncent_list',cell_latloncent_list);



function [swath_img]=gen_swath(track_ident,georefR,size_img,ci_mode)

%swath coord
swath_img=zeros(size_img);

%create inital and final cell track pairs
if length(track_ident)>1
    init_ident=track_ident(1:end-1);
    finl_ident=track_ident(2:end);
else
    init_ident=track_ident;
    finl_ident=track_ident;    
end

%find oldest
if ci_mode==1
    swath_ind=1;
else
    swath_ind=[1:length(init_ident)];
end

%loop through each pair in the two ident dbs
for i=1:length(swath_ind)
    %extract init and final edge coord
    init_lat_edge_coord=init_ident(swath_ind(i)).subset_lat_edge;
    init_lon_edge_coord=init_ident(swath_ind(i)).subset_lon_edge;
    finl_lat_edge_coord=finl_ident(swath_ind(i)).subset_lat_edge;
    finl_lon_edge_coord=finl_ident(swath_ind(i)).subset_lon_edge;
    
    %collate
    lat_list=roundn([init_lat_edge_coord,finl_lat_edge_coord],-4);
    lon_list=roundn([init_lon_edge_coord,finl_lon_edge_coord],-4);
    
    %compute convexhull
    try
        K = convhull(lon_list,lat_list);
    catch
        disp('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!conv hull fail, collinear points likely')
        continue
    end
    
    hull_lat=lat_list(K);
    hull_lon=lon_list(K);
    
    %convert to clockwise coord order
    [hull_lon, hull_lat] = poly2cw(hull_lon, hull_lat);

    %convert to pixel coords
    [row,col] = latlon2pix(georefR,hull_lat,hull_lon);
    mask_mat = poly2mask(col, row, size_img(1), size_img(2));
    swath_img = swath_img+mask_mat;
end
%normalise
swath_img(swath_img>0)=1;
swath_img=logical(swath_img);

function [object_kml,image_fn_list]=write_swath_image(object_kml,swath_img,oldest_td,newest_td,img_tag,latlonbox,image_fn_list)

%load config variables
load('tmp_global_config.mat')

%generate alpha_img
alpha_img=ones(size(swath_img));

%Generate colorbar and flipud
swath_img=flipud(swath_img)+1;
max_density=max(max(swath_img));
colorbar_fn=generate_colorbar(max_density,'Density',img_tag);

%Colorbar overlay kml
object_kml=ge_screenoverlay(object_kml,'Plot Colorbar',[img_tag,'_colorbar.png'],.94,.2,0,.4,datestr(oldest_td,S),datestr(newest_td,S));

%Swath overlay kml
%create transparency for 1 value pixels
alpha_img(swath_img==1)=0;
%write image to file
A = ind2rgb(swath_img,jet(max_density));
img_fn=[tempdir,img_tag,'_clim.png'];
imwrite(A,img_fn,'Alpha',alpha_img);
%link with kml
object_kml=ge_groundoverlay(object_kml,['Climatology for ',img_tag],[img_tag,'_clim.png'],latlonbox,datestr(oldest_td,S),datestr(newest_td,S),'clamped',0,1);

image_fn_list=[image_fn_list,colorbar_fn,img_fn];

function colorbar_fn=generate_colorbar(max_value,colorbar_title,clim_tag)

%generate tick intervals
intervals=round([0:max_value/5:max_value]);
y_ticks={};

%generate interval names
for i=1:length(intervals)
    y_ticks=[y_ticks,num2str(intervals(i))];
end

%generate colorbar
colormap(jet(max_value));
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
colorbar_fn=[tempdir,clim_tag,'_colorbar.png'];
imwrite(X,map,[tempdir,clim_tag,'_colorbar.png']);

function ind=custom_find_ind(a,b)
[~,ind]=ismember(a,b);

