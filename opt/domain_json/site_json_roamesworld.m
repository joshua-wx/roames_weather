function site_json_roamesworld

% init
addpath('/home/meso/Dropbox/dev/wv/etc')
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib')
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
site_info_fn      = 'site_info.txt';
circle_radius     = 150000; %m
% site_info.txt
read_site_info(site_info_fn); load([site_info_fn,'.mat']);

%init struct
jstruct = '';

for i=1:length(site_id_list)
    tmp_jstruct            = struct;
    %id and name
    tmp_jstruct.id         = num2str(site_id_list(i),'%02.0f');
    tmp_jstruct.name       = num2str(site_s_name_list{i});
    tmp_jstruct.crs        = '4326';
    tmp_jstruct.description= 'full name';
    %location
    tmp_lon                = num2str(site_lon_list(i));
    tmp_lat                = num2str(-site_lat_list(i));
    tmp_elv                = num2str(site_elv_list(i));
    tmp_jstruct.location.x = num2str(tmp_lon);
    tmp_jstruct.location.y = num2str(tmp_lat);
    tmp_jstruct.location.z = num2str(tmp_elv);
    %generate circle
    %convert to utm...
    cmd = ['export LD_LIBRARY_PATH=/usr/lib; CoordinateUtility2 -coord 4326 ',tmp_lon,' ',tmp_lat,' 0 -crs 32755'];
    [~,utm_coords] = unix(cmd); utm_coords = utm_coords(1:end-7);
    cmd = ['export LD_LIBRARY_PATH=/usr/lib; GeometryUtility2 -circle ',utm_coords,' 150000 -inputcrs 32755 -segments 200 -outputcrs 4326'];
    [~,wkt] = unix(cmd);
    %cut out polygon
    k = strfind(wkt, 'POLYGON');
    wkt_pol = wkt(k:end-1);
    tmp_jstruct.domain = wkt_pol;
    %convert to jtext
    if isempty(jstruct)
        jstruct = tmp_jstruct;
    else
        jstruct = [jstruct,tmp_jstruct];
    end
end

jtext = savejson('RadarSites',jstruct);

fid = fopen('au_wxradar_domains.json','w');
fprintf(fid,'%s',jtext);
fclose(fid);




%CoordinateUtility2 -coord 4326 144.946 -37.691 0 -crs 32755
%[meso@caspian ~]$ GeometryUtility2 -circle 318900.354533625999466 5826483.096621695905924 150000 -inputcrs 32755 -segments 50 -outputcrs 4326
