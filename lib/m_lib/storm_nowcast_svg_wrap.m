function storm_nowcast_svg_wrap(dest_root,storm_jstruct,vol_obj)

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

%list tracks
track_id               = jstruct_to_mat([storm_jstruct.track_id],'N');
[unqiue_track_id,~,ic] = unique(track_id);
radar_id               = vol_obj.radar_id;
timestamp              = vol_obj.start_timedate;
%output to file
svg_struct = '';

%build colormaps
forecast_S_colormap = colormap(hot(n_fcst_steps)); %stregthening
forecast_W_colormap = colormap(bone(n_fcst_steps)); %weakening
forecast_N_colormap = colormap(pink(n_fcst_steps)); %no change
%set_bounds
%use radar lat lon and use global config range * 1.5

%normalise fcst_polys
r_lat        = vol_obj.r_lat;
r_lon        = vol_obj.r_lon;
r_d_offset   = km2deg(h_range/1000)*1.5; %increase domain for nowcasts which move outside domain
d_lat_min    = r_lat-r_d_offset;
d_lat_max    = r_lat+r_d_offset;
d_lon_min    = r_lon-r_d_offset;
d_lon_max    = r_lon+r_d_offset;
domain_wkt   = sprintf('%4.4f %4.4f, ',[[d_lon_min,d_lon_min,d_lon_max,d_lon_max,d_lon_min];[d_lat_min,d_lat_max,d_lat_max,d_lat_min,d_lat_min]]); domain_wkt = domain_wkt(1:end-2);

x_offset = d_lon_min;
y_offset = d_lat_min+90;
x_scale  = d_lon_max-d_lon_min;
y_scale  = (d_lat_max+90)-(d_lat_min+90);

for i=1:length(unqiue_track_id)
    %generate forecast poly for track i
    cur_track_id  = unqiue_track_id(i);
    %skip null track
    if cur_track_id == 0
        continue
    end
    %extract cell idxs in track
    cur_track_idx = find(ic==i);
    [fcst_lat_polys,fcst_lon_polys,~,~,~,~,~,intensity] = storm_nowcast(cur_track_idx,storm_jstruct,timestamp);
    %if track not at end of database, skip
    if isempty(fcst_lat_polys)
        continue
    elseif isempty(svg_struct)
        svg_struct = struct;
    end
    %build group in struct
    g_id = ['group_',num2str(i)];
    for j=1:length(fcst_lat_polys)
        %assign path fill colour
        if strcmp(intensity,'S')
            fill_c = forecast_S_colormap(j,:);
        elseif strcmp(intensity,'W')
            fill_c = forecast_W_colormap(j,:);
        else
            fill_c = forecast_N_colormap(j,:);
        end
        %normalise fcst_polys
        tmp_poly_x = fcst_lon_polys{j}';
        tmp_poly_y = fcst_lat_polys{j}'+90; %offset so always positive
        tmp_poly_x = (tmp_poly_x-x_offset)./x_scale;
        tmp_poly_y = (tmp_poly_y-y_offset)./y_scale;
        %build path struct    
        p_id     = ['path_',num2str(j)];
        path_wkt = sprintf('%4.4f %4.4f, ',[tmp_poly_x;tmp_poly_y]);
        svg_struct.(g_id).(p_id).fill_c   = html_color_svg(fill_c);
        svg_struct.(g_id).(p_id).fill_o   = num2str(0.5);
        svg_struct.(g_id).(p_id).stroke_c = html_color_svg([1,1,1]);
        svg_struct.(g_id).(p_id).stroke_w = num2str(0.001);
        svg_struct.(g_id).(p_id).stroke_o = num2str(1);
        svg_struct.(g_id).(p_id).path_wkt = path_wkt(1:end-2);
    end

end

%exit is no data to write out
if isempty(svg_struct)
    return
end

%export svg text
tmp_svg_ffn = [tempdir,'nowcast.svg'];
svg_path_write(svg_struct,tmp_svg_ffn);
tmp_wtk_ffn = [tempdir,'nowcast.wtk'];
wtk_latlonbox(tmp_wtk_ffn,domain_wkt,4326);


%move to s3
s3_svg_ffn = [dest_root,num2str(radar_id,'%02.0f'),'/nowcast.svg'];
file_mv(tmp_svg_ffn,s3_svg_ffn);
s3_wtk_ffn = [dest_root,num2str(radar_id,'%02.0f'),'/nowcast.wtk'];
file_mv(tmp_wtk_ffn,s3_wtk_ffn);

function str = html_color_svg(map)
%WHAT:
%converts a colormap in the format [0,1] [r,g,b] and trans [0,1] into a hex
%html string

%convert to 255 colormap
map = round(255.*map);
%restructure into r,g,b format in hex
str = ['#',dec2hex(map(1),2),dec2hex(map(2),2),dec2hex(map(3),2)];


function wtk_latlonbox(out_ffn,wtk,crs)

tmp_str = ['SRID=',num2str(crs),'; POLYGON ((',wtk,'))'];
fid = fopen(out_ffn,'wt');
fprintf(fid,'%s',tmp_str);
fclose(fid);
