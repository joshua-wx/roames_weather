function compile_kmz
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Compiles a directory of kmz files with the naming structure
% IDR##_name.kmz into a networks links to a master doc.kml. This entire
% structure is transfered to s3
% INPUTS
% compile.config
% RETURNS: generates doc.kml. Copies doc.kml and kmz files to s3
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% init

%setup config names
config_fn      = 'compile.config';
site_info_fn   = 'site_info.txt';
local_tmp_path = 'tmp/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/lib/ge_lib')
addpath('etc/')
addpath('lib/')

% load climate config
read_config(config_fn);
load([local_tmp_path,config_fn,'.mat']);

% Load site info
read_site_info(site_info_fn); load([local_tmp_path,site_info_fn,'.mat']);


%% list kmz files and copy to s3
dir_out = dir(local_path); dir_out(1:2) = [];
%halt on no files in local path
if isempty(dir_out)
    disp('No files in local_path')
    return
end
%filter for kmz files
kmz_fn_list = {};
siteid_list = [];
for i=1:length(dir_out)
   [~,fn,ext] = fileparts(dir_out(i).name);
   if strcmp(ext,'.kmz')
       kmz_fn_list = [kmz_fn_list;[fn,ext]];
       siteid_list = [siteid_list;str2num(fn(4:5))];
   end
end
%halt on no kmz files in local path
if isempty(kmz_fn_list)
    disp('No kmz files in local_path')
    return
end
%copy to s3
for i=1:length(kmz_fn_list)
    file_cp([local_path,kmz_fn_list{i}],[s3_path,kmz_fn_list{i}],0,1)
end

%% build coverage kml

%generate coverage kml for each radar site
site_latlonbox = [];
cov_lat        = [];
cov_lon        = [];
coverage_str   = '';

%loop through sites and merge coverage
for i=1:length(siteid_list)
    %site list idx
    siteinfo_idx        = find(siteinfo_id_list==siteid_list(i));
    %generate circle latlon
    [site_cov_lat, site_cov_lon] = scircle1(siteinfo_lat_list(siteinfo_idx),siteinfo_lon_list(siteinfo_idx),km2deg(range_ring));
    [site_cov_lon, site_cov_lat] = poly2cw(site_cov_lon, site_cov_lat);
    %union with all coverage
    [cov_lon,cov_lat]   = polybool('Union',cov_lon,cov_lat,site_cov_lon,site_cov_lat);
    %append site latlonbox
    site_latlonbox      = [site_latlonbox;[max(site_cov_lat),min(site_cov_lat),max(site_cov_lon),min(site_cov_lon)]];
end
%split up coverage polygons into cells
[cov_lat,cov_lon] = polysplit(cov_lat,cov_lon);
coverage_str      = ge_line_style(coverage_str,'coverage_style',html_color(0.5,[1,1,1]),2);
for i=1:length(cov_lat)
    %write each polygon to kml string
    temp_lat     = cov_lat{i};
    temp_lon     = cov_lon{i};
    coverage_str = ge_line_string(coverage_str,1,['segment_',num2str(i)],'','','#coverage_style',0,'clampToGround',0,1,temp_lat(1:end-1),temp_lon(1:end-1),temp_lat(2:end),temp_lon(2:end));
end
%generate kml and move to s3
ge_kml_out([tempdir,'coverage.kml'],'Coverage',coverage_str)
file_mv([tempdir,'coverage.kml'],[s3_path,'coverage.kml'])

%% build index kml
%init master and link 
master_str = '';
master_str = ge_networklink(master_str,'Coverage',[url_prefix,'coverage.kml'],0,0,'','','','',1);
%build network link for each kmz file
for i=1:length(kmz_fn_list)
    kml_tag = kmz_fn_list{i}(1:end-4);
    master_str = ge_networklink(master_str,kml_tag,[url_prefix,kmz_fn_list{i}],0,0,'','','','',1);
end

%save to file
temp_ffn = tempname;
ge_kml_out(temp_ffn,'RoamesWX Climate',master_str);
%transfer to root path
file_mv(temp_ffn,[s3_path,'doc.kml']);

wait_aws_finish
disp('RWX Climate kmz compile complete')


