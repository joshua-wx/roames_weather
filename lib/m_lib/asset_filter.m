function stats_struct = asset_filter(poly_lat,poly_lon)
%WHAT: using the poly lat/lon filter to filter geo statbases to build
%impact stats

poly_lat = [-27.70,-27.0,-27.0,-27.70,-27.70];
poly_lon = [152.70,152.70,153.85,153.85,152.70];
%% load data

%subsetstation
sub_struct  = [];
sub_fn      = '../../etc/geo_data/NationalElectricityTransmissionSubstations.csv';
fileID      = fopen(sub_fn);
raw_headers = textscan(fileID,'%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s',1,'Delimiter',',');
raw_data    = textscan(fileID,'%f %s %s %f %s %s %s %s %f %s %f %s %f %f %f %f','Delimiter',',','HeaderLines',1);
for i=1:length(raw_headers)
    sub_struct.(raw_headers{i}{1}) = raw_data{i};
end

%powerlines
power_fn     = '../../etc/geo_data/national_transmission_201702.shp';
power_struct = shaperead(power_fn);

%population
pop_fn   = '../../etc/geo_data/Australian_Population_Grid_2011.tif';
pop_grid = geotiffread(pop_fn);
pop_info = geotiffinfo(pop_fn);

save('asset_data.mat','sub_struct','power_struct','pop_grid','pop_info')

%% filter data
tic
load('asset_data.mat')
%substation
sub_mask        = inpolygon(sub_struct.LONGITUDE,sub_struct.LATITUDE,poly_lon,poly_lat);
sub_names       = [sub_struct.NAME(sub_mask)];
sub_capacity    = [sub_struct.CAPACITY_kV(sub_mask)];

%powerlines
%shapefile stores individual powerline segments
power_kv  = [];
power_len = [];
for i=1:length(power_struct)
    power_lat  = power_struct(i).Y;
    power_lon  = power_struct(i).X;
    power_mask = inpolygon(power_lon,power_lat,poly_lon,poly_lat);
    if sum(power_mask)>1 %need more than one pole
        power_lat     = power_lat(power_mask);
        power_lon     = power_lon(power_mask);
        [len_pairs,~] = distance(power_lat(1:end-1),power_lon(1:end-1),power_lat(2:end),power_lon(2:end));
        seg_len       = deg2km(sum(len_pairs));
        power_kv      = [power_kv;str2num(power_struct(i).CAPACITY_k)];
        power_len     = [power_len;seg_len];
    end
end
[sum_power_kv,~,ic]  = unique(power_kv);
sum_power_len        = zeros(length(sum_power_kv),1);
for i=1:length(sum_power_len)
    sum_mask         = ic==i;
    sum_power_len(i) = sum(power_len(sum_mask));
end

%population
[poly_map_x,poly_map_y] = projfwd(pop_info,poly_lat,poly_lon);
[poly_y,poly_x]         = map2pix(pop_info.RefMatrix,poly_map_x,poly_map_y);
pop_mask                = poly2mask(poly_x, poly_y, pop_info.Height, pop_info.Width);
total_pop               = sum(pop_grid(pop_mask));

%output
stats_struct = struct('sub_names',sub_names,'sub_capacity',sub_capacity,...
    'power_kv',power_kv,'power_len',power_len,'total_pop',total_pop);

toc

keyboard