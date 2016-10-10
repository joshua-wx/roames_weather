function wv_kml

%WHAT: This module pulls data from storm_archive and create kml objects for
%GE

%INPUT:
%see wv_kml.config

%OUTPUT: kml visualisation of selected mat file archive

%%Load VARS
% general vars
kml_config_fn     = 'wv_kml.config';
global_config_fn  = 'wv_global.config';
site_info_fn      = 'site_info.txt';
h5_path           = 'h5_download/';

% Add folders to path and read config files
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/wv/lib/ge_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
addpath('/home/meso/Dropbox/dev/wv/etc')


% load kml_config
read_config(kml_config_fn);
load([kml_config_fn,'.mat'])
date_list           = [];
complete_h5_dt      = [];
complete_h5_list    = {};
gfs_extract_list    = [];
hist_oldest_restart = [];

% Load global config files
read_config(global_config_fn);
load([global_config_fn,'.mat']);

%load colourmaps for png generation
colormap_interp('refl24bit.txt','vel24bit.txt');

% site_info.txt
read_site_info(site_info_fn); load([site_info_fn,'.mat']);
% check if all sites are needed
if strcmp(radar_id_list,'all')
    radar_id_list = site_id_list;
end

% Calculate time limits from time options
oldest_time = datenum(hist_oldest,'yyyy_mm_dd');
newest_time = datenum(hist_newest,'yyyy_mm_dd');

%% Primary code
tic
%cat daily databases for times between oldest and newest time,
%allows for mulitple days to be joined
intp2kml  = db_cat2(arch_dir,site_no_selection,'intp_db',0,oldest_time,newest_time);
ident2kml = db_cat2(arch_dir,site_no_selection,'ident_db',1,oldest_time,newest_time);

%Rebuild kml hierarchy
build_kml_hierarchy_2(true,kml_dir,site_no_selection);


if isempty(intp2kml)
    disp('no intp_db for the time period')
    if cts_loop==0
        break
    else
        pause(20);
        continue
    end
end

%generate list of target folders to untar
temp_date_list=floor(oldest_time):floor(newest_time);
data_path_list={};
for i=1:length(site_no_selection)
    for j=1:length(temp_date_list)
        date_tag=datevec(temp_date_list(j));
        data_path_list=[data_path_list,[arch_dir,'IDR',num2str(site_no_selection(i),'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/']];
    end
end

%filter (filter out entried which have already been kmled)
[new_intp2kml]=intp_filter(prev_intp2kml,intp2kml);

%untar data folders
for i=1:length(data_path_list)
    mkdir([data_path_list{i},'data']);
    %skip if it doesn't exist
    if exist([data_path_list{i},'data.tar'],'file')==2
        untar([data_path_list{i},'data.tar'],[data_path_list{i}]);
    end
end

%build kml from intp and their associated ident entires
cloud_objects3(arch_dir,new_intp2kml,ident2kml,kml_dir,options);

%remove data folders
for i=1:length(data_path_list)
    rmdir([data_path_list{i},'data'],'s');
end

%clean kml folder using newest and oldest time...
tf=~ismember([prev_intp2kml.start_timedate],[intp2kml.start_timedate]);
del_list=unique([prev_intp2kml(tf).start_timedate]);
for i=1:length(del_list)
    delete([kml_dir,ident_data_path,'*',datestr(del_list(i),'dd-mm-yyyy_HHMM'),'*'])
end

%clean kml folder of all track items
delete([kml_dir,track_data_path,'*'])

%update prev_intp2kml
prev_intp2kml=intp2kml;

%Build kml network links and generate tracked kml objects
update_kml_4(intp2kml,ident2kml,kml_dir,options,oldest_time,newest_time);

%Update user
disp([10,'kml pass complete. ',num2str(length(new_intp2kml)),' new volumes added and ',num2str(length(intp2kml)),' volumes updated',10]);

%Kill function
if toc(kill_timer)>kill_wait
    %save input vars to file
    save('temp_kml_vars.mat','arch_dir','kml_dir','oldest_opt','newest_opt','cts_loop','zone_name','site_no','nl_path','options','intp2kml')
    %update user
    disp(['@@@@@@@@@ wv_kml restarted at ',datestr(now)])
    %restart
    if ~isdeployed
        %not deployed method: trigger background restart command before
        %kill
        [~,~]=system(['matlab -desktop -r "run ',pwd,'/wv_kml.m" &']);
    else
        %deployed method: restart controlled by run_wv_process sh
        %script
        disp('is deployed - passing restart to run script via temp_kml_vars.mat existance')
        break
    end
    quit force
end

%break loop if not cts flag set
if cts_loop==0
    break
else
    %drawnow
    pause(20);
end


%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc),' @@@@@@@@@'])


function [new_intp2kml]=intp_filter(prev_intp2kml,intp2kml)
%WHAT: Filters an intp database using intp2kml (alreadyed kmled), time and
%site_id

%INPUTS:
%intp2kml: list of already processed intp objects
%cated_intp_db: a intp_db which may span multiple days
%oldest_time: in datenum
%newest_time: in datenum
%site_no_selection: list of site_ids

%OUTPUTS:
%new_intp2kml: new intp2kml items to convert to kml
%updated_intp2kml: intp2kml merged with updated_intp2kml

%create outputs
new_intp2kml=intp2kml;
%skip if no prev cells
if isempty(prev_intp2kml)
    return
end

%REMOVE ENTIRIES OF new_intp2kml WHICH ARE IN prev_intp2kml
filter_mask=ismember([new_intp2kml.start_timedate],[prev_intp2kml.start_timedate]);
new_intp2kml(filter_mask)=[];
