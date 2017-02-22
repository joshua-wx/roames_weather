function [stats_struct] = asset_filter(poly_lat,poly_lon)
%WHAT: using the poly lat/lon filter to filter geo statbases to build
%impact stats

poly_lat = [-27.70,-27.55,-27.55,-27.70,-27.70];
poly_lon = [152.70,152.70,152.85,152.85,152.70];
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
pop_fn                  = '../../etc/geo_data/Australian_Population_Grid_2011.tif';
[pop_grid,pop_refmat,~] = geotiffread(pop_fn);
pop_struct              = struct('pop_grid',pop_grid,'pop_refmat',pop_refmat);

%% filter data

%substation
sub_mask        = inpolygon(sub_struct.LONGITUDE,sub_struct.LATITUDE,poly_lon,poly_lat);
sub_names       = [sub_struct.NAME(sub_mask)];
sub_capacity    = [sub_struct.CAPACITY_kV(sub_mask)];

%powerlines
%power_mask      = inpolygon([power_struct.X],[power_struct.Y],poly_lon,poly_lat);

%population
[poly_y,poly_x] = latlon2pix(pop_refmat,poly_lat,poly_lon);
BW              = poly2mask(poly_x, poly_y, pop_R.RasterSize(1), pop_R.RasterSize(2));



stats_struct = [];


keyboard