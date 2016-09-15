function [site_name_selection, site_no_selection]=site_selection(zone_selection,site_no)

%WHAT
%uses the site numbers or zones to output a list of names and numbers
%of the selected radar sites. Uses zone csv file and site_info.txt

%INPUT
%zone selection: string of zone id
%site_no: list of site ids (NaN if using zone)

%OUTPUT
%site_name_selection: names of sites selected
%site_no_selection: ids of sites selected

%load site info path
load('site_info.mat');

%load wv_zones config
wv_zones_path='../config_files/wv_zones.csv';
if exist(wv_zones_path,'file')==2
    zones_raw=importdata(wv_zones_path,';');
    zones_names=zones_raw.textdata(1,2:end);
    zones_ul_lat=zones_raw.data(1,:);
    zones_ul_lon=zones_raw.data(2,:);
    zones_lr_lat=zones_raw.data(3,:);
    zones_lr_lon=zones_raw.data(4,:);
else
    disp([wv_zones_path,' not found'])
    return
end

if isnan(site_no) %if a zone selection is performed
    %load latlonbox of zone
    zone_ind=find(strcmp(zone_selection,zones_names));
    llbox_ul_lat=zones_ul_lat(zone_ind);
    llbox_ul_lon=zones_ul_lon(zone_ind);
    llbox_lr_lat=zones_lr_lat(zone_ind);
    llbox_lr_lon=zones_lr_lon(zone_ind);
    %mask using site latlon and select correct site no and names
    location_mask=logical(site_lat_list>=llbox_ul_lat & site_lat_list<=llbox_lr_lat & site_lon_list>=llbox_ul_lon & site_lon_list<=llbox_lr_lon);
    site_no_selection=site_id_list(location_mask);
    site_name_selection=site_s_name_list(location_mask);
else
    %use manual site no input to create a list of names from site_info.txt
    site_no_selection=site_no;
    site_name_selection=site_s_name_list(ismember(site_id_list,site_no_selection));
end