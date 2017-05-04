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
climate_fn     = 'climate.config';
compile_fn     = 'compile.config';
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
read_config(climate_fn);
load([local_tmp_path,climate_fn,'.mat']);

% load compile config
read_config(compile_fn);
load([local_tmp_path,compile_fn,'.mat']);

% site_info.txt
site_warning = read_site_info(site_info_fn,site_info_old_fn,radar_id_list,datenum(date_start,'yyyy_mm_dd'),datenum(date_stop,'yyyy_mm_dd'),1);
if site_warning == 1
    disp('site id list and contains ids which exist at two locations (its been reused or shifted), fix using stricter date range (see site_info_old)')
    return
end
load([local_tmp_path,site_info_fn,'.mat']);

%% list kmz files and copy to s3
dir_out          = dir(local_path); dir_out(1:2) = [];
old_idx          = find(strcmp({dir_out.name},'OLD'));
dir_out(old_idx) = [];

%halt on no files in local path
if isempty(dir_out)
    disp('No files in local_path')
    return
end
%filter for kmz files
kmz_fn_list = {};
siteid_list = [];
for i=1:length(dir_out)
   %set upper path name
   upper_path = dir_out(i).name;
   %skip if not dir
   if dir_out(i).isdir == 0
       continue
   end
   %scan sub directory
   sub_dir = dir([local_path,upper_path]); sub_dir(1:2) = [];
   %for each sub dir entry
   for j=1:length(sub_dir)
       [~,fn,ext] = fileparts(sub_dir(j).name);
       if strcmp(ext,'.kmz')
           kmz_fn_list = [kmz_fn_list;[upper_path,'/',fn,ext]];
           siteid_list = [siteid_list;str2num(fn(4:5))];
       end
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
    %generates range rings for all site locations over time
    for j=1:length(siteinfo_idx)
        %generate circle latlon
        [site_cov_lat, site_cov_lon] = scircle1(siteinfo_lat_list(siteinfo_idx(j)),siteinfo_lon_list(siteinfo_idx(j)),km2deg(range_ring));
        [site_cov_lon, site_cov_lat] = poly2cw(site_cov_lon, site_cov_lat);
        %union with all coverage
        [cov_lon,cov_lat]   = polybool('Union',cov_lon,cov_lat,site_cov_lon,site_cov_lat);
        %append site latlonbox
        site_latlonbox      = [site_latlonbox;[max(site_cov_lat),min(site_cov_lat),max(site_cov_lon),min(site_cov_lon)]];
    end
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

%% build style kml (duplicated from individual radar kmz)
kml_style = '';
kml_style = ge_swath_poly_style(kml_style,'poly_style',html_color(1,silence_edge_color),silence_line_width,html_color(1,silence_face_color),false);
kml_style = ge_swath_poly_style(kml_style,'trans_poly',html_color(1/255,silence_edge_color),silence_line_width,html_color(1/255,silence_face_color),true);

%% build index kml
%init master and link 
master_str = kml_style;
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


