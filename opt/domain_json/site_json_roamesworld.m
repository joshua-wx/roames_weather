function site_json_roamesworld

% init
addpath('/home/meso/Dropbox/dev/wv/etc')
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
site_info_fn      = 'site_info.txt';
circle_radius     = 150000; %m
% site_info.txt
read_site_info(site_info_fn); load([site_info_fn,'.mat']);

%init struct
jstruct = struct;

for i=1:length(site_id_list)
    radar_id_str = ['ID',num2str(site_id_list(i),'%02.0f')];
    jstruct.(radar_id_str).id         = num2str(site_id_list(i),'%02.0f');
    jstruct.(radar_id_str).name       = num2str(site_s_name_list{i});
    jstruct.(radar_id_str).latitude   = num2str(-site_lat_list(i));
    jstruct.(radar_id_str).longitude  = num2str(site_lon_list(i));
    jstruct.(radar_id_str).altitude   = num2str(site_elv_list(i));
    %generate circle
    ellipsoid = referenceEllipsoid('wgs84');
    [domain_lat,domain_lon] = scircle1(-site_lat_list(i),site_lon_list(i),circle_radius,[],ellipsoid);
    domain_lat_str = num2str(domain_lat','%03.4f,'); domain_lat_str = ['[',domain_lat_str(1:end-1),']'];
    domain_lon_str = num2str(domain_lon','%03.4f,'); domain_lon_str = ['[',domain_lon_str(1:end-1),']'];
    jstruct.(radar_id_str).domain_lat = domain_lat_str;
    jstruct.(radar_id_str).domain_lon = domain_lon_str;
end

jtext = savejson('',jstruct);

fid = fopen('au_wxradar_domains.json','w');
fprintf(fid,'%s',jtext);
fclose(fid);

keyboard



