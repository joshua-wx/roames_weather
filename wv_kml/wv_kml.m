function wv_kml(arch_dir,kml_dir,oldest_opt,newest_opt,cts_loop,zone_name,site_no,nl_path,s3sync_chk,options)

%WHAT: This modules takes a subset of the processed db and converts it to a
%kml layer using cloud_objects and update_kml3.

%INPUT:
%arch_dir: path to root of processed archive
%kml_dir: path to kml root
%oldest_opt: oldest time/offset to crop src_dir files to
    %(min,'dd-mm-yy_HH:MM',NaN). 'min' offset from current time in minutes,
    %'date' specific oldest time. 'NaN' no specific cutoff time
%newest_opt: newest time/offset to crop src_dir files to
%cts_loop: logical operation to loop process function, allowing new ftp
%files to be processed
%zone_name: name of spatial zone to subset radar sites to
%site_no: specific list of radar sites for processing
%nl_path: dropbox path to kml for nl key file
%options: see wv_config file

%OUTPUT: kml visualisation of selected mat file archive


%% Add folders to path
addpath('../config_files')
if ~isdeployed
    addpath('../libraries/functions','../libraries/ge_functions');
end
read_site_info
colormap_interp
%% Check for GUI, commandline or 'silent reset' start
if exist('temp_kml_vars.mat','file')==2
    %silent start detected
    load('temp_kml_vars.mat');
    delete('temp_kml_vars.mat')
else
    if nargin==0
        %load from config file for commandline start
        config_input_path='wv_kml.config';
        mat_output_path='tmp_kml_config.mat';
        read_config(config_input_path,mat_output_path)
        load(mat_output_path)
    end
    prev_intp2kml=struct('start_timedate',[],'stop_timedate',[],'region_latlonbox',[],'radar_id',[],'sig_refl',[],'refl_vars',[],'vel_vars',[],'radar_mode',{});
end

%extract site_name and site_no from 
[~,site_no_selection]=site_selection(zone_name,site_no);

%Rebuild kml hierarchy if required
if options(14)==1
    build_kml_hierarchy_2(true,kml_dir,site_no_selection);
    rebuild_rad(14)=0; %reset so kml is not deleted during kill restart
end
%Build kml nl key file for dropbox
if ~isempty(nl_path);
    public_nl_kml=ge_networklink('','NetworkLink',nl_path,0,0,'','','','',1);
    ge_kml_out([kml_dir,'weathervis_public_nl'],'WeatherVis Public NetworkLink',public_nl_kml)
end

%% Calculate time limits from time options
if isnan(oldest_opt) %NaN=0
    oldest_time=datenum('01-01-00_00:00','dd-mm-yy_HH:MM');
elseif isnumeric(oldest_opt) %offset from now
    oldest_time=addtodate(utc_time,oldest_opt,'minute');
else %specific time
    oldest_time=datenum(oldest_opt,'dd-mm-yy_HH:MM');
end

if isnan(newest_opt) %NaN=now
    newest_time=utc_time;
elseif isnumeric(newest_opt) %offset from now
    newest_time=addtodate(utc_time,newest_opt,'minute');
else %specific time
    newest_time=datenum(newest_opt,'dd-mm-yy_HH:MM'); %set newest cutoff
end

%% setup kill time (restart program to prevent memory fragmentation)
kill_wait=2*60*60; %kill matlab time in seconds
kill_timer=tic; %create timer object

%% Load global config files
config_input_path='wv_global.config';
mat_output_path='tmp_global_config.mat';
read_config(config_input_path,mat_output_path);
load(mat_output_path);

%% Create kill file, allowing the program to shutdown softly when deleted
if exist('kill_wv_kml','file')~=2
    fid = fopen('kill_wv_kml', 'w'); fprintf(fid, '%s', ''); fclose(fid);
end

tic
%% Primary Loop
while exist('kill_wv_kml','file')==2
   
        %cat daily databases for times between oldest and newest time,
        %allows for mulitple days to be joined
        intp2kml=db_cat2(arch_dir,site_no_selection,'intp_db',0,oldest_time,newest_time);
        ident2kml=db_cat2(arch_dir,site_no_selection,'ident_db',1,oldest_time,newest_time);
        
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


% function ident2kml=ident_filter(cated_ident_db,oldest_time,newest_time)
% %WHAT: Filters an ident database using time and site_id
% 
% %INPUTS:
% %cated_ident_db: a ident_db which may span multiple days
% %oldest_time: in datenum
% %newest_time: in datenum
% %site_no_selection: list of site_ids
% 
% %OUTPUTS:
% %ident2kml: filtered cated_ident_db
% 
% %create blank outputs
% ident2kml=[];
% 
% %apply time and site condtions
% for i=1:length(cated_ident_db)
%     if ~isempty(cated_ident_db{i})
%         %radar_select=ismember([cated_ident_db.radar_id],site_no_selection);
%         ind=find([cated_ident_db{i}.stop_timedate]>=oldest_time & [cated_ident_db{i}.start_timedate]<=newest_time);% & radar_select==1);
%         ident2kml=cated_ident_db{i}(ind);
%     end
% end

% function track2kml=track_filter(cated_track_db,ident2kml,cated_ident_db)
% %WHAT: Filters an track database using ident2kml and merges tracks between
% %days
% 
% %INPUTS:
% %arch_dir: path to processed dir root
% %cated_track_db: a track db which may span multiple days
% %ident2kml: output of ident_filter function
% 
% %OUTPUTS:
% %track2kml: filtered output of cated_track_db
% %create blank outputs
% track2kml={};
% 
% if isempty(ident2kml) || isempty(cated_track_db)
%     return
% end
% 
% %merge tracks using nnmerge method...
% if length(cated_track_db)>1
%     cated_track_db=merge_daily_tracks(cated_track_db,cated_ident_db);
% else
%     cated_track_db=cated_track_db{1};
% end
% 
% %filter to only include tracks with cels from ident2kml
% for i=1:length(cated_track_db)
%     %load track
%     temp_track=cated_track_db{i};
%     %check if track is in the site selection list
%     temp_ind=find(ismember([temp_track(:,3)],[ident2kml.start_timedate]) & ismember([temp_track(:,4)],[ident2kml.start_timedate]));
%     if ~isempty(temp_ind)
%         track2kml=[track2kml; {temp_track(temp_ind,:)}];
%     end
% end