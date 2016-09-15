function [fcst_nl,fcst_graph_nl]=storm_forecast2(cur_track_ident_ind,ident2kml,kml_dir,region,start_td,stop_td,cur_vis,radar_id)
%WHAT
%for the inputted track 'cur_track', a forecast is produced from the end
%cells using the historical data. Forecast data is saved as forecast swaths
%and historical weighted timeseries graphs. nl links for these 

%INPUT
%cur_track: A single track from track_db
%ident2kml: contains cells from cur_track (and others)
%kml_dir: path to kml directory
%region: region for kml generation
%start_td: kml start time
%stop_td: kml stop time
%cur_vis: kml vis

%OUTPUT
%fcst_nl: network link to forecast swaths
%fcst_graph_nl: netowrklink to balloon graph

%% 
%load config file
load('tmp_global_config.mat');

%blank nl strings
fcst_nl='';
fcst_graph_nl='';

end_cell_ind=cur_track_ident_ind(end);

%extract end time of track and database
end_ident2kml_dt=max([ident2kml.start_timedate]);
end_cell_dt=ident2kml(end_cell_ind).start_timedate;

%if track not at end of database, skip
if end_ident2kml_dt~=end_cell_dt
    return
end

%% loop through end cells
for i=1:length(end_cell_ind)
    
    %project track from end_cell_ind(i)
    [proj_azi,proj_arc,vil_dt,trck_stats,trck_dt]=project_storm_kml(end_cell_ind(i),ident2kml);
    
    %extract geometry of end cell
    end_latloncent=ident2kml(end_cell_ind(i)).dbz_latloncent;
    end_stats=ident2kml(end_cell_ind(i)).stats;
    orient_x=cosd(end_stats(6));
    orient_y=-sind(end_stats(6));
    orient_north=rad2deg(atan2(orient_x,orient_y));
    end_maj_axis=km2deg(end_stats(4)*h_grid/1000)/2;
    end_min_axis=km2deg(end_stats(5)*h_grid/1000)/2;
    
    %set ellipse growth parameter
    axis_scaling=1;
    growth=1.1;

    %set the intensity trend parameter using the boundary condition of
    %+-20%/hr of the grid VILD
    if vil_dt>2
        intensity='S'; %strengthening
    elseif vil_dt<2
        intensity='W'; %weakening
    else
        intensity='N'; %no change
    end   
    
    %generate end cell ellipse
    end_ecc=end_min_axis/end_maj_axis;
    end_ellipse=[end_maj_axis,end_ecc];
    [end_ellp_lat,end_ellp_lon] = ellipse1(end_latloncent(1),end_latloncent(2),end_ellipse,orient_north);
    ellp_list={[end_ellp_lat,end_ellp_lon]};
    
    %% generate forecast cell ellipse
    for j=1:n_fcst_steps
        %forcast time steps
        fcst_time=(fcst_step*j); %in minutes
        %increase axis growth
        axis_scaling=axis_scaling*growth;
        %evaluate forecast polynomials at forecast time
        f_arc     = proj_arc*fcst_time;
        %offset centroid
        [fcst_lat_cent,fcst_lon_cent]=reckon(end_latloncent(1),end_latloncent(2),f_arc,proj_azi);
        %scale ellipse geometry
        fcst_maj_axis=end_maj_axis*axis_scaling;
        fcst_min_axis=end_min_axis*axis_scaling;
        fcst_ecc = fcst_min_axis/fcst_maj_axis;
        ellipse=[fcst_maj_axis,fcst_ecc];
        %generate forecast ellise
        [fcst_ellp_lat,fcst_ellp_lon] = ellipse1(fcst_lat_cent,fcst_lon_cent,ellipse,orient_north);
        if sum(isnan(fcst_ellp_lat))>0
            keyboard
        end
        %collate forecast ellipses
        ellp_list=[ellp_list;[fcst_ellp_lat,fcst_ellp_lon]];
    end
    
    %% loop through forecast ellipses and merge pairs to produce swath
    cell_fcst_kml=''; %kml string for forecast swath
    for j=2:n_fcst_steps+1 %offset from start
        %extract ellipse j and j-1 from dataset
        cell1_lat=ellp_list{j-1}(:,1);
        cell1_lon=ellp_list{j-1}(:,2);
        cell2_lat=ellp_list{j}(:,1);
        cell2_lon=ellp_list{j}(:,2);
        %generate convex hull around both ellipses
        lat_list=[cell1_lat;cell2_lat];
        lon_list=[cell1_lon;cell2_lon];

        K = convhull(lon_list,lat_list);

        conv_lat_list=lat_list(K);
        conv_lon_list=lon_list(K);
        %convert to clockwise coord order
        [conv_lon_list, conv_lat_list] = poly2cw(conv_lon_list, conv_lat_list);
        [cell1_lon, cell1_lat] = poly2cw(cell1_lon, cell1_lat);
        %if not at first pair (first pair stay as convex hull)
        if j~=2
            % exclusive region of convecx hull and cell j-1 coord (takes a
            % concave hull out of the region)
            [fcst_lon_list,fcst_lat_list] = polybool('xor',cell1_lon,cell1_lat,conv_lon_list,conv_lat_list);
        else
            %keep convex hull
            fcst_lon_list=conv_lon_list; fcst_lat_list=conv_lat_list;
        end
        
        %to prevent an untraced error
        ind=find(fcst_lat_list==0 | isnan(fcst_lat_list));
        fcst_lon_list(ind)=[]; fcst_lat_list(ind)=[];
        
        %generate forecast swath tag
        single_fcst_tag=['cell_fcst_',num2str((j-1)*fcst_step),'min_idx',num2str(ident2kml(end_cell_ind(i)).index)];
        %generate poly placemark kml of swath
        cell_fcst_kml=ge_poly_placemark(cell_fcst_kml,['../doc.kml#fcst_',intensity,'_step_',num2str(j-1),'_style'],single_fcst_tag,'clampToGround',1,fcst_lon_list,fcst_lat_list,repmat(50,length(fcst_lat_list),1));    
 
    end    
   
    %% save forecast swath kml...
    tag=['cell_fcst_cell_ind',num2str(end_cell_ind(i)),'_IDR',num2str(radar_id)];
    ge_kml_out([kml_dir,track_data_path,tag],tag,cell_fcst_kml);
    %generate nl
    fcst_nl=ge_networklink(fcst_nl,tag,[track_data_path,tag,'.kml'],0,0,'',region,datestr(start_td,S),datestr(stop_td,S),cur_vis);
    
    %% Forecast graph balloon tag
    tag=['graph_cell_ind',num2str(end_cell_ind(i)),'_IDR',num2str(radar_id)];
    %generate balloon kml
    
    %calculate number of minutes between end timestep and all other
    %timesteps
    temp_end_dt=repmat(trck_dt(end),length(trck_dt),1);
    hist_min=etime(datevec(temp_end_dt),datevec(trck_dt))/60;
    
    %preparing graph y data
    hist_vild=trck_stats(:,11)/trck_stats(:,7)*1000;
    hist_mesh=trck_stats(:,15);
    %hist_50h=trck_stats(:,14)./1000; hist_50h(isnan(hist_50h))=0;
    hist_top=trck_stats(:,7)./1000;
    
    fcst_graph_kml=ge_balloon_graph_placemark('',1,'../doc.kml#balloon_graph_style','',hist_min,hist_vild,'VILD (g/m^3)',hist_mesh,'MaxExpSizeHail (mm)',hist_top,'Echo-top Height (km)',fcst_lat_cent,fcst_lon_cent);
    %save to file
    ge_kml_out([kml_dir,track_data_path,tag],tag,fcst_graph_kml);
    %generate nl
    fcst_graph_nl=ge_networklink(fcst_graph_nl,tag,[track_data_path,tag,'.kml'],0,0,'',region,datestr(start_td,S),datestr(stop_td,S),cur_vis);
    
end
%place cell forecasts/graph in a folder.
fcst_nl=ge_folder('',fcst_nl,'Cell Forecasts','',cur_vis);
fcst_graph_nl=ge_folder('',fcst_graph_nl,'Forecast Graphs','',cur_vis);