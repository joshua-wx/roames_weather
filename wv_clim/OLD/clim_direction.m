function [object_kml,style_kml,output_images]=clim_direction(filt_ident_db,newest_td,oldest_td,track_filt_opt,time_avg_opt,day_time_opt,snd_path,spatial_data)

%used for user info
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

%generate blank swaths
mat_size=[length(lat_vec),length(lon_vec)];
zero_mat=zeros(mat_size);
all_tot_u=zero_mat;
all_tot_v=zero_mat;
all_n=zero_mat;
out_avg_u=[];
out_avg_v=[];
out_n=[];
output_images=[];

object_kml='';
style_kml='';

%georeference transform
R = makerefmat('RasterSize',[length(lat_vec),length(lon_vec)],'Latlim', [min_lat max_lat], 'Lonlim', [min_lon max_lon]);

%loop through each track year
for y=1:length(filt_ident_db)
    %extract db for the current year
    yr_filt_ident_db=filt_ident_db{y};
    
    %generate blank swaths
    yr_tot_u=zero_mat;
    yr_tot_v=zero_mat;
    yr_n=zero_mat;
    
    %create waitbar for user info
    h = waitbar(0,['Building direction climatology from tracks for ',num2str(year_list(y))]);
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
            
            %check track length
            track_length=length(track_ident_ind);
            if track_length<track_filt_opt(1)
                continue
            end
            
            %PLOTTING
            if track_filt_opt(3)==1
                %STS CELLS PLOT
                %create sts mask
                sts_mask   = track_50dbz_h>=fifty_dbz_threshold;
                %cluster into continous groups
                sts_label = bwlabel(sts_mask);
                %plot according to clusters
                if max(sts_label)>0
                    for k=1:max(sts_label)
                        [daily_tot_u,daily_tot_v,n]=gen_swath(curr_day_ident(track_ident_ind(sts_label==k)),R,mat_size);
                        %append to swath img
                        yr_tot_u=yr_tot_u+daily_tot_u;
                        yr_tot_v=yr_tot_v+daily_tot_v;
                        yr_n=yr_n+n;
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
                        [daily_tot_u,daily_tot_v,n]=gen_swath(curr_day_ident(track_ident_ind(ts_label==k)),R,mat_size);
                        %append to swath img
                        yr_tot_u=yr_tot_u+daily_tot_u;
                        yr_tot_v=yr_tot_v+daily_tot_v;
                        yr_n=yr_n+n;
                    end
                end
            elseif track_filt_opt(5)==1
                %STS TRACKS PLOT
                if max(track_50dbz_h)>=fifty_dbz_threshold
                    [daily_tot_u,daily_tot_v,n]=gen_swath(curr_day_ident(track_ident_ind),R,mat_size);
                    %append to swath img
                    yr_tot_u=yr_tot_u+daily_tot_u;
                    yr_tot_v=yr_tot_v+daily_tot_v;
                    yr_n=yr_n+n;
                end
            elseif track_filt_opt(6)==1
                %TS TRACKS PLOT
                if max(track_50dbz_h)<fifty_dbz_threshold
                    [daily_tot_u,daily_tot_v,n]=gen_swath(curr_day_ident(track_ident_ind),R,mat_size);
                    %append to swath img
                    yr_tot_u=yr_tot_u+daily_tot_u;
                    yr_tot_v=yr_tot_v+daily_tot_v;
                    yr_n=yr_n+n;
                end
            else
                %ALL TRACKS PLOT
                %plot entire track including non severe wells
                [daily_tot_u,daily_tot_v,n]=gen_swath(curr_day_ident(track_ident_ind),R,mat_size);
                %append to swath img
                yr_tot_u=yr_tot_u+daily_tot_u;
                yr_tot_v=yr_tot_v+daily_tot_v;
                yr_n=yr_n+n;
            end
        
            %update waitbar if on next percentage (daily updates)
            if round(i/length(yr_filt_ident_db)*100)>current_percent
                waitbar(i/length(yr_filt_ident_db))
                current_percent=round(i/length(yr_filt_ident_db)*100);
            end
        end
    end
    
    %close bar
    delete(h);
    
    %append yearly data
    all_tot_u=all_tot_u+yr_tot_u;
    all_tot_v=all_tot_v+yr_tot_v;
    all_n=all_n+yr_n;
    
    %output for three averaging cases
    if time_avg_opt(1)==1 && y==length(filt_ident_db) %all
        image_start_td=oldest_td;
        image_stop_td=newest_td;
        img_tag=['tot_',num2str(year_list(1)),'-',num2str(year_list(end))];
        out_avg_u=all_tot_u./all_n;
        out_avg_v=all_tot_v./all_n;
        out_n=all_n;
    elseif time_avg_opt(2)==1 %avg yearly
        image_start_td=datenum(year_list(y),1,1);
        image_stop_td=datenum(year_list(y),12,31);
        img_tag=['tot_',num2str(year_list(y))];
        out_avg_u=yr_tot_u./yr_n;
        out_avg_v=yr_tot_v./yr_n;
        out_n=yr_n;
    elseif time_avg_opt(3)==1 %cumulative yearly average
        image_start_td=datenum(year_list(y),1,1);
        image_stop_td=datenum(year_list(y),12,31);
        img_tag=['ctot_',num2str(year_list(1)),'-',num2str(year_list(y))];
        out_avg_u=all_tot_u./all_n;
        out_avg_v=all_tot_v./all_n;
        out_n=all_n;
    end
    
    %write colorbar and swath to file if required
    if ~isempty(out_avg_u)
        object_kml=streamline2kml(object_kml,out_avg_u,out_avg_v,out_n,datestr(image_start_td,S),datestr(image_stop_td,S),img_tag,lat_vec,lon_vec);
        output_images={out_avg_u,out_avg_v,out_n};
        out_avg_u=[];
        out_avg_v=[];
        out_n=[];
    end        
end

%generate streamline style
style_kml=ge_line_style(style_kml,['streamline_style'],html_color(1,[0,0,0]),2);

%append object kml into folder
object_kml=ge_folder('',object_kml,'Direction','',1);

function [u_out,v_out,n_out]=gen_swath(track_ident,georefR,size_img)

%swath coord
u_out=zeros(size_img);
v_out=zeros(size_img);
n_out=zeros(size_img);

if length(track_ident)<2
    return
end

%create inital and final cell track pairs
init_ident=track_ident(1:end-1);
finl_ident=track_ident(2:end);

%loop through each pair in the two ident dbs
for i=1:length(init_ident)
    
    %extract init and final edge coord
    init_lat_edge_coord=init_ident(i).subset_lat_edge;
    init_lon_edge_coord=init_ident(i).subset_lon_edge;
    finl_lat_edge_coord=finl_ident(i).subset_lat_edge;
    finl_lon_edge_coord=finl_ident(i).subset_lon_edge;
    init_latloncent=init_ident(i).dbz_latloncent; %vild latloncent
    finl_latloncent=finl_ident(i).dbz_latloncent;
    init_timedate=init_ident(i).start_timedate;
    finl_timedate=finl_ident(i).start_timedate;
    
    %collate
    lat_list=roundn([init_lat_edge_coord,finl_lat_edge_coord],-4);
    lon_list=roundn([init_lon_edge_coord,finl_lon_edge_coord],-4);
    
    %compute convexhull
    try
        K = convhull(lon_list,lat_list);
    catch
        continue %empty lat lon list
    end
    
    hull_lat=lat_list(K);
    hull_lon=lon_list(K);
    
    %convert to clockwise coord order
    [hull_lon, hull_lat] = poly2cw(hull_lon, hull_lat);

    %convert to pixel coords
    [row,col] = latlon2pix(georefR,hull_lat,hull_lon);
    mask_mat = poly2mask(col, row, size_img(1), size_img(2));
    
    %calculate vector
    [dist,az]       = distance(init_latloncent(:,1),init_latloncent(:,2),finl_latloncent(:,1),finl_latloncent(:,2));
    dist            = deg2km(dist);
    vel             = dist/((finl_timedate-init_timedate)*24);
    az              = mod(90-az,360); %convert from compass to cartesian deg
    az_u            = vel*cosd(az);
    az_v            = vel*sind(az);
    
    %append to outputs
    u_out=u_out+mask_mat.*az_u;
    v_out=v_out+mask_mat.*az_v;
    n_out=n_out+mask_mat;
end

function ind=custom_find_ind(a,b)
[~,ind]=ismember(a,b);


function [object_kml]=streamline2kml(object_kml,out_u,out_v,out_n,oldest_td,newest_td,img_tag,lat_vec,lon_vec)
%load config variables
load('tmp_global_config.mat')

%compute lat matrix
[lon_mat,lat_mat]=meshgrid(lon_vec,lat_vec);

%mask
mask=out_n>=3;
out_u=out_u.*mask;
out_v=out_v.*mask;

[vertices arrowvertices] = streamslice(lon_mat,lat_mat,out_u,out_v,10);

object_kml=ge_multi_line_string(object_kml,1,img_tag,'#streamline_style',0,'clampToGround',0,1,oldest_td,newest_td,[vertices,arrowvertices]);
