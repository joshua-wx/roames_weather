function wv_tracking3(dest_dir,crnt_timedate,scan_time,crnt_radar_id)
%WHAT: For the curr timedate and curr radar id, the assocaited cells in
%ident are checks using nn and forecasting methods for temporal and spatial
%association with other cells in ident. Tracks are compiled using ident id
%and storaged in track_ind. Tracks can also be merged.

%INPUT:
%dest_dir: archive root path
%crnt_timedate: timedate of crnt cells
%crnt_radar_id: radar ids of crnt cells

%OUTPUT:
%updated track_db

%NOTE: Looks in the current utc day only.

%global variables shared between function
global track_db ident_db ident_latloncent crnt_latloncent crnt_td crnt_lat_edge crnt_lon_edge
load('tmp_global_config.mat');
%% Setup variables

%extract datetag
date_tag=datevec(floor(crnt_timedate));

%create correct archive folder
archive_dest=[dest_dir,'IDR',num2str(crnt_radar_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/'];

%create db filenames
track_db_fn=[archive_dest,'track_db_',datestr(crnt_timedate,'dd-mm-yyyy'),'.mat'];
ident_db_fn=[archive_dest,'ident_db_',datestr(crnt_timedate,'dd-mm-yyyy'),'.mat'];

%check if track exists, if not create it, else load track_db    
if exist(track_db_fn,'file')==2
    track_db=mat_wrapper(track_db_fn,'track_db');
else
    %inital and current fields
    track_db={};
end

%load ident_db
if exist(ident_db_fn,'file')==2
    ident_db=mat_wrapper(ident_db_fn,'ident_db');
    %find index of subv elements from target scan in ident_db
    crnt_ind=find([ident_db.start_timedate]==crnt_timedate);
else
    return
    %no cells for the current radar/time, no point in tracking
end

%load latloncent, start td and stop td for cells in ident_db
ident_latloncent=vertcat(ident_db.subset_latloncent);
ident_start_timedate=vertcat(ident_db.start_timedate);

%find the newest scan time for the current radar
newest_radar_td=max(ident_start_timedate);
modified=0;
%loop through crnt cell entires in ident_db
for i=1:length(crnt_ind)
    
    %load crnt cell properties
    crnt_latloncent   = ident_db(crnt_ind(i)).subset_latloncent;
    crnt_lat_edge     = ident_db(crnt_ind(i)).subset_lat_edge;
    crnt_lon_edge     = ident_db(crnt_ind(i)).subset_lon_edge;
    crnt_td           = ident_db(crnt_ind(i)).start_timedate;
    
    %% PASS1 : broad temporal and spatial nn sweep to find ident cells which are near crnt cell
    
    %generate bounds on distance of other cells from crnt cell.
    [rng,~]=distance(crnt_latloncent(1),crnt_latloncent(2),ident_latloncent(:,1),ident_latloncent(:,2));
    dist=deg2km(rng);
    
    %check to see if a sufficent period of time to identify a scan was
    %missing.
    if (crnt_td-newest_radar_td)>(scan_time+1)
        %scan was missing, use broad distance from nn distances
        pass1_time=addtodate(crnt_timedate,-(scan_time*2+1),'minute');
        pass2_nn_dist=pass2_stm_speed/(60/scan_time)*2;
        pass1_nn_dist=pass2_nn_dist*2;
    else
        %use normal nn distance
        pass1_time=addtodate(crnt_timedate,-(scan_time*2+1),'minute');
        pass2_nn_dist=pass2_stm_speed/(60/scan_time);
        pass1_nn_dist=pass2_nn_dist*1.5;
    end
    
    %find subv that fall within this bound.
    pass1_ind=find(ident_start_timedate<crnt_timedate & ident_start_timedate>=pass1_time & dist<pass1_nn_dist);
    %move to next cell if no nn are found in pass1
    if isempty(pass1_ind)
        continue
    end
    
    %filter pass1 ids into cells from tracks and one not in any tracks
    [pass1_exist_ind,pass1_exist_storm_ind,pass1_new_ind,end_cell_ind,end_storm_ind,all_init_ind,all_storm_ind]=filter_nn_points(pass1_ind);
    
    
    %% PASS1: seperate new track and exisiting track methods
    
    %apply pass2 nn filter for ident cells not in track_db
    [pass2_new_ind]=pass2_tracking_new(pass1_new_ind,pass2_nn_dist,end_cell_ind,end_storm_ind);

    %apply pass2 nn filter for ident cells in track_db
    [pass2_exist_ind,pass2_exist_storm_ind]=pass2_tracking_exist(pass1_exist_ind,pass1_exist_storm_ind,pass2_nn_dist);
    
% PLOTTING outputs of pass2
%     if ~isempty(pass2_new_ind)
%         figure; hold on; axis xy
%         plot(crnt_lon_edge,crnt_lat_edge,'r-')
%         plot(crnt_latloncent(2),crnt_latloncent(1),'r*')
%         title(['new cell ',num2str(crnt_ind(i))])
%         pass1_new_ind=find_db_ind(pass1_new_ind,{ident_db.ident_ind},1);
%         for j=1:length(pass1_new_ind)
%             temp_lon=ident_db(pass1_new_ind(j)).subset_lon_edge;
%             temp_lat=ident_db(pass1_new_ind(j)).subset_lat_edge;
%             plot(temp_lon,temp_lat,'m-')
%             plot(ident_db(pass1_new_ind(j)).subset_latloncent(2),ident_db(pass1_new_ind(j)).subset_latloncent(1),'m*')
%             text(temp_lon(1),temp_lat(1),num2str(pass1_new_ind(j)))
%         end
%         pass2_new_ind=find_db_ind(pass2_new_ind,{ident_db.ident_ind},1);
%         for j=1:length(pass2_new_ind)
%             temp_lon=ident_db(pass2_new_ind(j)).subset_lon_edge;
%             temp_lat=ident_db(pass2_new_ind(j)).subset_lat_edge;
%             plot(temp_lon,temp_lat,'k-')
%             plot(ident_db(pass2_new_ind(j)).subset_latloncent(2),ident_db(pass2_new_ind(j)).subset_latloncent(1),'k*')
%             text(temp_lon(1),temp_lat(1),num2str(pass2_new_ind(j)))
%         end
%     end
%build new track matrix

    %collate outputs
    pass2_ind=[pass2_new_ind;pass2_exist_ind];
    
    %move to next cell if empty
    if isempty(pass2_ind)
        continue
    end
    
    %set modified flag
    modified=1;
    
    
    %build track containing [past cell id, curr cell id, past cell start_timedate, curr cell stop_timedate, past cell radar id]
    try
    temp_track=[pass2_ind,repmat(crnt_ind(i),length(pass2_ind),1),[ident_db(pass2_ind).start_timedate]',repmat(ident_start_timedate(crnt_ind(i)),length(pass2_ind),1),repmat(crnt_radar_id,length(pass2_ind),1)];
    catch
        keyboard
    end
 

    
    %update tracked flag for current and current-1 tracked cells.
    for b=1:length(pass2_ind)
        ident_db(pass2_ind(b)).tracked=1;
    end
    ident_db(crnt_ind(i)).tracked=1;
    
    %check for inital new cells which form the start of a splitting storm
    %(special case that is removed by end cells filter for tracks length=2)
    init_split_intersect=ismember(all_init_ind,pass2_new_ind);
    init_split_storm_ind=all_storm_ind(init_split_intersect);
    
    %unique storm id from past cells
    unique_storm_ind=unique([pass2_exist_storm_ind;init_split_storm_ind]);
    
    %join storms together if required
    if ~isempty(unique_storm_ind)
        %loop through and merge tracks into temp track
        for j=1:length(unique_storm_ind)
            temp_track=[temp_track;track_db{unique_storm_ind(j)}];
        end
        %remove merged storms
        track_db(unique_storm_ind)=[];
    end
    
    %write track_db to file
    if ~isempty(temp_track)
        track_db=[track_db,{temp_track}];
    end
    
end

%write updated .tracked values ident_db back to file if there are new
%tracks
if modified==1
    mat_wrapper(ident_db_fn,'ident_db',ident_db);
    mat_wrapper(track_db_fn,'track_db',track_db);
end
function [out_end_cell_ind,out_storm_ind,out_new_cell_ind,end_cell_ind,end_storm_ind,out_all_init_ind,out_all_storm_ind]=filter_nn_points(pass1_nn_ind)
%WHAT: searches for pass1 nn ids in track_db end cells. This allows the ids
%to be sorted into those which form end cells and those which have no
%association to tracks

%INPUT:
%pass1_nn_ind: ident ids from the pass1 filter

%OUTPUT:
%out_end_cell_ind: cells which are end cells in tracks
%out_storm_ind: track index of cells in out_end_cell_ind
%out_new_cell_ind: cells which are not in tracks
%all_init_ind: id of all inital cells in track_db
%all_storm_ind: storm index of all cells in track_db

%setup vars
global track_db crnt_td
out_end_cell_ind=[];
out_storm_ind=[];
end_storm_ind=[];
end_cell_ind=[];

%decompose track db
all_init_ind=[];
all_finl_ind=[];
all_finl_td=[];
all_storm_ind=[];

for i=1:length(track_db)
    all_init_ind   =[all_init_ind;[track_db{i}(:,1)]];
    all_finl_ind   =[all_finl_ind;[track_db{i}(:,2)]];
    all_finl_td   =[all_finl_td;vertcat(track_db{i}(:,4))];
    all_storm_ind =[all_storm_ind;repmat(i,length([track_db{i}(:,1)]),1)];
end

out_all_init_ind=all_init_ind;
out_all_storm_ind=all_storm_ind;

%remove tracks which end in current timestamp
if ~isempty(all_finl_td)
     td_mask=all_finl_td<crnt_td;
     all_init_ind=all_init_ind(td_mask);
     all_finl_ind=all_finl_ind(td_mask);   
     all_storm_ind=all_storm_ind(td_mask);
end

if ~isempty(track_db)

    %check for end cells via intersection between final and inital cell pairs
    temp_intersection =~ismember(all_finl_ind,all_init_ind);
    end_cell_ind       =all_finl_ind(temp_intersection);
    end_storm_ind     =all_storm_ind(temp_intersection);

    %check for pass1_nn_ind cells which are members of end cells and not a memeber of init cells -> track
    end_intersect  =ismember(end_cell_ind,pass1_nn_ind);
    out_end_cell_ind =end_cell_ind(end_intersect);
    
    %filter out unique id's (as there may be multiple in the same storm)
    [out_end_cell_ind,uniq_ind,~] =unique(out_end_cell_ind);
    
    %save storm ind
    out_storm_ind      =  end_storm_ind(end_intersect);
    out_storm_ind      =  out_storm_ind(uniq_ind); %apply uniq ind filter
end

%is not a memeber of end cells or init cells -> new cell
new_intersect=logical(~ismember(pass1_nn_ind,all_finl_ind).*~ismember(pass1_nn_ind,all_init_ind));
out_new_cell_ind=pass1_nn_ind(new_intersect)';

function [pass2_new_ind]=pass2_tracking_new(pass1_new_ind,nn_dist,end_cell_ind,end_storm_ind)
%WHAT: Performs a much more refines nn check of pass1_new_ind cells.

%INPUT: 
%pass1_new_ind: cell ids from filter_nn_points which are not in tracks

%OUTPUT:
%pass2_new_ind: cell ids which have passed the spatial filter

%setup vars
load('tmp_global_config.mat');
global ident_db crnt_latloncent crnt_lat_edge crnt_lon_edge
pass2_new_ind      = [];
pass2_new_storm_ind = [];
%break if empty
if isempty(pass1_new_ind)
    return
end

%cat the latloncent for all pass1_exist_ind
pass1_new_latloncent   = vertcat(ident_db(pass1_new_ind).subset_latloncent);

%attempt to use historical tracks to predict next location of storm
if ~isempty(end_cell_ind)
    
    %if more than 5 end cells are present, use the last 5 only.
    if length(end_cell_ind)>5
        end_cell_ind=end_cell_ind(end-4:end);
        end_storm_ind=end_storm_ind(end-4:end);
    end
    
    %forecast for same time stamp as end cell creates a distance of zero
    [~,f_rng,f_az_x,f_az_y]=generate_forecast(end_cell_ind,end_storm_ind);

    %average output of forecast
    mean_f_rng=mean(f_rng);
    mean_f_az_x=mean(f_az_x);
    mean_f_az_y=mean(f_az_y);
    mean_f_az  =rad2deg(atan2(mean_f_az_y,mean_f_az_x));

    %project forecast range and azimuth onto centroids
    [f_latout,f_lonout] = reckon(pass1_new_latloncent(:,1),pass1_new_latloncent(:,2),mean_f_rng,mean_f_az);
    
    %test for points inside current polygon
    poly_test=inpolygon(f_lonout,f_latout,crnt_lon_edge,crnt_lat_edge);
    
    if any(poly_test)
    %inside poly true for some cells
        pass2_new_ind = pass1_new_ind(poly_test)';
    else
        for i=1:length(f_lonout)
            [rng,~]= distance(f_latout(i),f_lonout(i),crnt_latloncent(1),crnt_latloncent(2));
            min_dist= min(deg2km(rng));
            if min_dist<=nn_dist/2
                pass2_new_ind=[pass2_new_ind;pass1_new_ind(i)];
            end
        end
    end
end

%raidal search from centroid attempt (only triggered when nothing is
%returned from forecast
if isempty(pass2_new_ind)
    %loop though each pass1_new_ind cell using a radial search from centroid (no storm
    %history)
    for i=1:length(pass1_new_ind)
        %calculate distances of pass1_new_ind cell from crnt cell.
        [rng,~]=distance(pass1_new_latloncent(i,1),pass1_new_latloncent(i,2),crnt_latloncent(1),crnt_latloncent(2));
        %find the min distance (not needed unless edge is used)
        min_dist=min(deg2km(rng));
        %find cells which are less than max_nn_dist away from curr cell
        if  min_dist<=nn_dist
            pass2_new_ind=[pass2_new_ind;pass1_new_ind(i)];
        end
    end
end

function [pass2_exist_ind,pass2_exist_storm_ind]=pass2_tracking_exist(pass1_exist_ind,pass1_exist_storm_ind,nn_dist)
%WHAT: produces a forecast location for each pass1_exist_ind and uses a nn
%approach from this forecast location to determine if crnt cell belongs to
%that track.
%1-10-12: Added polygonin functionality to test if points are inside a
%polygon

%INPUT:
%pass1_exist_ind: cell ids from filter_nn_points which are end cells of
%tracks
%pass2_exist_storm_ind: track index of cells in out_end_cell_ind

%OUTPUT:
%pass2_exist_ind: pass1_exist_ind which have passed the forecast nn test
%pass2_exist_storm_ind: storm track index values for pass2_exist_ind

%setup vars
load('tmp_global_config.mat');
global ident_db crnt_latloncent crnt_lat_edge crnt_lon_edge
pass2_exist_ind=[]; pass2_exist_storm_ind=[];

%exit if input is empty
if isempty(pass1_exist_ind)
    return
end

%PLOTTING FORECAST OUTPUT
%figure; axis xy
%plot(crnt_lon_edge,crnt_lat_edge,'r-')
%hold on
%plot(crnt_latloncent(2),crnt_latloncent(1),'r*')

%generate forecast distance and range for each cell
[f_az,f_rng,~,~]=generate_forecast(pass1_exist_ind,pass1_exist_storm_ind);

%cat the latloncent for all pass1_exist_ind
pass1e_latloncent   = vertcat(ident_db(pass1_exist_ind).subset_latloncent);
%project forecast range and azimuth onto centroids
[f_latout,f_lonout] = reckon(pass1e_latloncent(:,1),pass1e_latloncent(:,2),f_rng,f_az);

%test for points inside current polygon
fcst_poly_test=inpolygon(f_lonout,f_latout,crnt_lon_edge,crnt_lat_edge);

if any(fcst_poly_test)
    %inside poly true for some cells
    pass2_exist_ind       = pass1_exist_ind(fcst_poly_test);
    pass2_exist_storm_ind = pass1_exist_storm_ind(fcst_poly_test);
else
    %no inside polygon, run nn algorithm
    for i=1:length(f_latout)

        %PLOTTING FORECAST OUTPUT
        %plot_track(track_db,ident_db,pass1_exist_storm_ind(i))
        %plot(f_lonout(i),f_latout(i),'bo')

        %calculate distance between curr cell and forecast location of end cell
        [rng,~]= distance(f_latout(i),f_lonout(i),crnt_latloncent(1),crnt_latloncent(2));
        min_dist= min(deg2km(rng));

        %apply distance criteria
        if min_dist<=nn_dist/2
            %PLOTTING FORECAST OUTPUT
            %text(f_lonout(i),f_latout(i),'FORECAST PASSED!!!!!!!')

            %append to output
            pass2_exist_ind        = [pass2_exist_ind;pass1_exist_ind(i)];
            pass2_exist_storm_ind = [pass2_exist_storm_ind;pass1_exist_storm_ind(i)];
        end
    end
end

%test for polyong overlap using only current lat lon edge and past
%centroids
if isempty(pass2_exist_storm_ind)
    %test for points inside current polygon
    overlap_poly_test=inpolygon(pass1e_latloncent(:,2),pass1e_latloncent(:,1),crnt_lon_edge,crnt_lat_edge);
    %inside poly true for some cells
    pass2_exist_ind        = pass1_exist_ind(fcst_poly_test);
    pass2_exist_storm_ind = pass1_exist_storm_ind(fcst_poly_test);
end

function [f_az,f_rng,f_az_x,f_az_y]=generate_forecast(pass1_exist_ind,pass1_exist_storm_ind)

%setup vars
load('tmp_global_config.mat');
global track_db ident_db crnt_td

%generate historical weighted means timeseries data for each end cell track
[hist_dist,hist_az_x,hist_az_y,hist_stats,hist_min,end_td]=storm_weighted_history(track_db,ident_db,pass1_exist_ind,pass1_exist_storm_ind);
%fit polynomial to these datasets
[f_poly_dist,f_poly_az_x,f_poly_az_y,~]=storm_history_fit(hist_dist,hist_az_x,hist_az_y,hist_stats,hist_min,max_hist_cells);

%produce forecast values for each end cell
f_dist=[];
f_az_x=[];
f_az_y=[];
for i=1:length(pass1_exist_ind)
    f_min  =minute(crnt_td-end_td(i));
    f_dist =[f_dist;polyval([f_poly_dist(i,:)],f_min)];
    f_az_x =[f_az_x;polyval([f_poly_az_x(i,:)],f_min)];
    f_az_y =[f_az_y;polyval([f_poly_az_y(i,:)],f_min)];
end
f_az       = rad2deg(atan2(f_az_y,f_az_x));
f_rng      = km2deg(f_dist);
