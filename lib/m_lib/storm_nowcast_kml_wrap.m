function [fcst_nl,fcst_graph_nl]=storm_nowcast_kml_wrap(track_idx,storm_jstruct,kml_dir,region,start_td,stop_td,cur_vis,radar_id)
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
load('tmp/global.config.mat');
load('tmp/kml.config.mat');

%blank nl strings
fcst_nl       = '';
fcst_graph_nl = '';

end_cell_idx     = track_idx(end);

[fcst_lat_polys,fcst_lon_polys,fcst_dt,trck_vil,trck_top,trck_mesh,trck_dt,intensity] = storm_nowcast(track_idx,storm_jstruct);

if isempty(fcst_dt)
    return
end

cell_fcst_kml = '';
%% generate nowcast kml    
for i=1:length(fcst_lat_polys)
    %if track not at end of database, skip
    if isempty(fcst_lat_polys{i})
        continue
    end
    %generate forecast swath tag
    storm_id        = storm_jstruct(end_cell_idx).subset_id.S;
    storm_id_n      = storm_id(end-2:end);
    single_fcst_tag = ['cell_fcst_',num2str((i)*fcst_step),'min_idx_',storm_id_n];
    %generate poly placemark kml of swath
    try
    cell_fcst_kml   = ge_poly_placemark(cell_fcst_kml,['../doc.kml#fcst_',intensity,'_step_',num2str(i),'_style'],single_fcst_tag,'clampToGround',1,fcst_lon_polys{i},fcst_lat_polys{i},repmat(50,length(fcst_lon_polys{i}),1));
    catch
        keyboard
    end
end

%% save forecast swath kml...
tag     = ['cell_fcst_cell_ind',num2str(end_cell_idx),'_',num2str(radar_id)];
ge_kml_out([kml_dir,storm_data_path,tag],tag,cell_fcst_kml);
%generate nl
fcst_nl = ge_networklink(fcst_nl,tag,[storm_data_path,tag,'.kml'],0,0,'',region,datestr(start_td,ge_tfmt),datestr(stop_td,ge_tfmt),cur_vis);

%% Forecast graph balloon tag
tag = ['graph_cell_ind',num2str(end_cell_idx),'_IDR',num2str(radar_id)];
%generate balloon kml

%calculate number of minutes between end timestep and all other
%timesteps
temp_end_dt = repmat(trck_dt(end),length(trck_dt),1);
hist_min    = etime(datevec(temp_end_dt),datevec(trck_dt))/60;

%preparing graph y data
hist_vild   = trck_vil./trck_top.*1000;
hist_mesh   = trck_mesh;
hist_top    = trck_top./1000;
hist_min    = -hist_min;

fcst_graph_kml = ge_balloon_graph_placemark('',1,'../doc.kml#balloon_graph_style','',hist_min,hist_vild,'VILD (g/m^3)',hist_mesh,'MaxExpSizeHail (mm)',hist_top,'Echo-top Height (km)',mean(fcst_lat_polys{end}),mean(fcst_lon_polys{end}));
%save to file
ge_kml_out([kml_dir,storm_data_path,tag],tag,fcst_graph_kml);
%generate nl
fcst_graph_nl=ge_networklink(fcst_graph_nl,tag,[storm_data_path,tag,'.kml'],0,0,'',region,datestr(start_td,ge_tfmt),datestr(stop_td,ge_tfmt),cur_vis);
    
%place cell forecasts/graph in a folder.
fcst_nl       = ge_folder('',fcst_nl,'Cell Forecasts','',cur_vis);
fcst_graph_nl = ge_folder('',fcst_graph_nl,'Forecast Graphs','',cur_vis);
