function [fcst_lat_polys,fcst_lon_polys,fcst_dt,trck_vil,trck_top,trck_mesh,trck_dt,intensity] = kml_storm_nowcast_polys(track_idx,storm_jstruct,tracking_id_list,target_dt)
%WHAT
%for the inputted track index list 'track_idx', nowcast elipsses are produced from the end
%cells using the historical data.

%INPUT
%track_idx: index of cells from a single track
%storm_jstruct: storm database
%kml_dir: path to kml directory
%region: region for kml generation
%start_td: kml start time
%stop_td: kml stop time
%cur_vis: kml vis

%OUTPUT
%fsct_lat_polys: cell, where each entry is a polygon
%fcst_lon_polys: cell, where each entry is a polygon
%trck_vil:  vil for track
%trck_top:  tops for track
%trck_mesh: mesh for track
%trck_dt:   dt for track


%% 
%load config file
load('tmp/global.config.mat');
load('tmp/vis.config.mat');

%init vars
fcst_lat_polys = {};
fcst_lon_polys = {};
fcst_dt        = [];
trck_vil       = [];
trck_top       = [];
trck_mesh      = [];
trck_dt        = [];
intensity      = [];

%extract end time of track and database
jstruct_dt       = datenum(jstruct_to_mat([storm_jstruct.start_timestamp],'S'),ddb_tfmt);
track_dt         = jstruct_dt(track_idx);
track_dt_mask    = track_dt <= target_dt;

%no tracks to process
if sum(track_dt_mask) < min_track_cells
    return
end

%extract track
filt_track_idx   = track_idx(track_dt_mask);
end_cell_idx     = filt_track_idx(end);
end_cell_dt      = jstruct_dt(end_cell_idx);

%skip if end of filt track is not target_dt
if end_cell_dt ~= target_dt
    return
end



%% extract track

%extract geometry of end cell
z_centlat      = str2num(storm_jstruct(end_cell_idx).storm_z_centlat.N);
z_centlon      = str2num(storm_jstruct(end_cell_idx).storm_z_centlon.N);
h_grid_deg     = str2num(storm_jstruct(end_cell_idx).h_grid.N);
end_orient     = str2num(storm_jstruct(end_cell_idx).orient.N);
end_orient_x   = cosd(end_orient);
end_orient_y   = -sind(end_orient);
end_orient_n   = rad2deg(atan2(end_orient_x,end_orient_y));
end_maj_axis   = str2num(storm_jstruct(end_cell_idx).maj_axis.N)/2;
end_maj_axis   = end_maj_axis*h_grid_deg/2;
end_min_axis   = str2num(storm_jstruct(end_cell_idx).min_axis.N)/2;
end_min_axis   = end_min_axis*h_grid_deg/2;

%check elipse exists
if isnan(end_maj_axis) || isnan(end_min_axis)
    return
end 

%project track from end_cell_idx(i)
[proj_azi,proj_arc,vil_dt,trck_mesh,trck_vil,trck_top,trck_dt] = nowcast_project(end_cell_idx,storm_jstruct,tracking_id_list);


%set the intensity trend parameter using the boundary condition of
%+-20%/hr of the grid VILD
if vil_dt > 0.5
    intensity = 'S'; %strengthening
elseif vil_dt < -0.5
    intensity = 'W'; %weakening
else
    intensity = 'N'; %no change
end

%generate end cell ellipse
end_ecc                     = axes2ecc(end_maj_axis,end_min_axis);
end_ellipse                 = [end_maj_axis,end_ecc];
[end_ellp_lat,end_ellp_lon] = ellipse1(z_centlat,z_centlon,end_ellipse,end_orient_n);
ellp_list                   = {[end_ellp_lat,end_ellp_lon]};
fcst_dt                     = [end_cell_dt];
%% generate forecast cell ellipse
for j=1:n_fcst_steps
    %forcast time steps
    fcst_time    = (fcst_step*j); %in minutes
    fcst_dt      = [fcst_dt,addtodate(end_cell_dt,fcst_time,'minute')];
    %evaluate forecast polynomials at forecast time
    f_arc        = proj_arc*fcst_time;
    %offset centroid
    [fcst_lat_cent,fcst_lon_cent] = reckon(z_centlat,z_centlon,f_arc,proj_azi);
    %scale ellipse geometry
    fcst_maj_axis = end_maj_axis;
    fcst_min_axis = end_min_axis;
    fcst_ecc      = axes2ecc(fcst_maj_axis,fcst_min_axis);
    ellipse       = [fcst_maj_axis,fcst_ecc];
    %generate forecast ellise
    [fcst_ellp_lat,fcst_ellp_lon] = ellipse1(fcst_lat_cent,fcst_lon_cent,ellipse,end_orient_n);
    %collate forecast ellipses
    ellp_list=[ellp_list;[fcst_ellp_lat,fcst_ellp_lon]];
end

%% loop through forecast ellipses and merge pairs to produce swath
fcst_lat_polys = cell(length(n_fcst_steps),1);
fcst_lon_polys = cell(length(n_fcst_steps),1);
for j=2:n_fcst_steps+1 %offset from start
    %extract ellipse j and j-1 from dataset
    cell1_lat = ellp_list{j-1}(:,1);
    cell1_lon = ellp_list{j-1}(:,2);
    cell2_lat = ellp_list{j}(:,1);
    cell2_lon = ellp_list{j}(:,2);
    %generate convex hull around both ellipses
    lat_list  = [cell1_lat;cell2_lat];
    lon_list  = [cell1_lon;cell2_lon];
    
    K = convhull(lon_list,lat_list);
    
    conv_lat_list = lat_list(K);
    conv_lon_list = lon_list(K);
    %convert to clockwise coord order
    [conv_lon_list, conv_lat_list] = poly2cw(conv_lon_list, conv_lat_list);
    [cell1_lon, cell1_lat]         = poly2cw(cell1_lon, cell1_lat);
    %if not at first pair (first pair stay as convex hull)
    if j~=2
        % exclusive region of convecx hull and cell j-1 coord (takes a
        % concave hull out of the region)
        [fcst_lon_list,fcst_lat_list] = polybool('xor',cell1_lon,cell1_lat,conv_lon_list,conv_lat_list);
    else
        %keep convex hull
        fcst_lon_list = conv_lon_list;
        fcst_lat_list = conv_lat_list;
    end
    
    %to prevent an untraced error
    ind = find(fcst_lat_list==0 | isnan(fcst_lat_list));
    fcst_lon_list(ind) = [];
    fcst_lat_list(ind) = [];
    
    %collate and output to cell
    fcst_lat_polys{j-1} = fcst_lat_list;
    fcst_lon_polys{j-1} = fcst_lon_list;
end