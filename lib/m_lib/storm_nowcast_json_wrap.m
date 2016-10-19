function storm_nowcast_json_wrap(dest_root,storm_jstruct,vol_obj)

%(track_idx,storm_jstruct,kml_dir,region,start_td,stop_td,cur_vis,radar_id)

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
load('tmp/process.config.mat');

%blank nl strings
jstruct        = '';
radar_id       = vol_obj.radar_id;
timestamp      = vol_obj.start_timedate;

%list tracks
track_id               = jstruct_to_mat([storm_jstruct.track_id],'N');
[unqiue_track_id,~,ic] = unique(track_id);

for i=1:length(unqiue_track_id)
    %generate forecast poly for track i
    cur_track_id  = unqiue_track_id(i);
    %skip null track
    if cur_track_id == 0
        continue
    end
    %extract cell idxs in track
    cur_track_idx = find(ic==i);
    [fcst_lat_polys,fcst_lon_polys,fcst_dt,~,~,~,~,intensity] = storm_nowcast(cur_track_idx,storm_jstruct,timestamp);
    %if track not at end of database, skip
    if isempty(fcst_lat_polys)
        continue
    end
    %write to well known text
    tmp_jstruct = nowcast_json(radar_id,timestamp,cur_track_id,fcst_dt,fcst_lat_polys,fcst_lon_polys,intensity);
    %collate
    if isempty(jstruct)
        jstruct = tmp_jstruct;
    else
        jstruct = [jstruct,tmp_jstruct];
    end
end

%export jstruct
jtext         = savejson('Nowcast',jstruct);
tmp_jtext_ffn = [tempdir,'nowcast.json'];
fid           = fopen(tmp_jtext_ffn,'w');
fprintf(fid,'%s',jtext);
fclose(fid);

%move to s3
s3_jtext_ffn = [dest_root,num2str(radar_id,'%02.0f'),'/nowcast.json'];
file_mv(tmp_jtext_ffn,s3_jtext_ffn);

function tmp_jstruct = nowcast_json(radar_id,last_timestamp,track_id,fcst_dt,fcst_lat_polys,fcst_lon_polys,intensity)

tmp_jstruct                 = struct;
%id and name
tmp_jstruct.radar_id        = num2str(radar_id,'%02.0f');
tmp_jstruct.timestamp       = datestr(last_timestamp,'yyyy-mm-ddTHH:MM:SSZ');
tmp_jstruct.crs             = '4326';
tmp_jstruct.track_id        = num2str(track_id);
tmp_jstruct.intensity       = intensity;

for i=1:length(fcst_lat_polys)
    fcst_poly_name = ['fcst_poly_',num2str(i)];
    wtk = sprintf('%4.4f %4.4f, ',[fcst_lon_polys{i}';fcst_lat_polys{i}']);
    tmp_jstruct.(fcst_poly_name).domain    = ['POLYGON ((',wtk(1:end-2),'))'];
    tmp_jstruct.(fcst_poly_name).timestamp = datestr(fcst_dt(i),'yyyy-mm-ddTHH:MM:SSZ');
end

all_fcst_lon_polys = vertcat(fcst_lon_polys{:});
all_fcst_lat_polys = vertcat(fcst_lat_polys{:});
c_idx              = convhull(all_fcst_lon_polys,all_fcst_lat_polys);
wtk                = sprintf('%4.4f %4.4f, ',[all_fcst_lon_polys(c_idx)';all_fcst_lat_polys(c_idx)']);
tmp_jstruct.fcst_poly_hull = ['POLYGON ((',wtk(1:end-2),'))'];