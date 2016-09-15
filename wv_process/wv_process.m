function wv_process
%WHAT: This modules takes odimh5 volumes (realtime or archive), regrids (cart_interpol6),
%applies identification (wdss_ewt), tracking (wdss_tracking), then archives the data for 
%use in climatology (wv_clim) or visualisation

%INPUT:
%see wv_process.config

%OUTPUT: Archive The processed data base of matfile, organised into daily track,
%ident and intp databases (no overheads).

%%Load VARS
	% general vars
	restart_cofig_fn  = 'temp_process_vars.mat';
	process_config_fn = 'wv_process.config';
	global_config_fn  = 'wv_global.config';
	site_info_fn      = 'site_info.txt';

	% setup kill time (restart program to prevent memory fragmentation)
	kill_wait  = 60*60*2; %kill time in seconds
	kill_timer = tic; %create timer object

	% Add folders to path and read config files
	addpath('../etc')
	if ~isdeployed
		addpath('../lib/m_lib','../bin');
	end

	% load process_config
    read_config(process_config_fn);
	load([process_config_fn,'.mat'])
	% check for restart or first start
	if exist(restart_cofig_fn,'file')==2
		%silent restart detected, load vars from reset and remove file
		load(restart_cofig_fn);
		delete(restart_cofig_fn);
	else
		%new start
        pending_h5_list  = {};
		complete_h5_list = {};
        gfs_extract_list = [];
	end

	% Load global config files
	read_config(global_config_fn);
	load([global_config_fn,'.mat']);

	% site_info.txt
	read_site_info(site_info_fn); load([site_info_fn,'.mat']);
	% check if all sites are needed
	if strcmp(site_list,'all')
		site_list = site_id_list;
	end

%% check environment
	% halt if source dir fails
	if exist(src_dir,'file')==0
		disp('src_dir non existant');
		return
	end

	% Create kill file, allowing the program to shutdown softly when deleted
	if exist('kill_wv_process','file')~=2
		[~,~]=unix('touch kill_wv_process');
	end

%% Preallocate cartesian regridding coordinates
	[aazi_grid,sl_rrange_grid,eelv_grid]=create_inv_grid([global_config_fn,'.mat']);

%% Primary Loop
while exist('kill_wv_process','file')==2

    % create time span
	if realtime_flag == 1
		newest_time = utc_time;
		oldest_time = addtodate(utc_time,realtime_offset,'hour');
	else
		newest_time = datenum(hist_newest,'dd-mm-yy_HH:MM');
		oldest_time = datenum(hist_oldest,'dd-mm-yy_HH:MM');
	end
    
    %Produce a list of filenames to process
    if ~isempty(pending_h5_list)
        pending_h5_list = file_filter(src_dir,oldest_time,newest_time,site_list);
        complete_index  = ismember(pending_h5_list,complete_h5_list);
        pending_h5_list = pending_h5_list(~complete_index);
    end
    
    %loop through target ffn's
    for i=1:length(pending_h5_list)
        display(['processing file of ',num2str(i),' of ',num2str(length(pending_h5_list))])
        
        %check for tiny cappi files
        file_info = dir(pending_h5_list{i}); file_size = file_info.bytes;
        if file_size<20000
            display('Skipping due to CAPPI')
            continue
        end
        
        %QA the h5 file (attempt to read groups)
        [qa_flag,no_groups,start_timedate,radar_id,vel_flag] = qa_h5(pending_h5_list{i},min_n_groups,site_list);
        
        %QA exit
        if qa_flag==0
            disp(['Volume failed QA: ' pending_h5_list{i}])
            continue
        end
        
        %build processed archive directory and generic fn
        date_tag  = datevec(start_timedate);
        arch_path = [dest_dir,num2str(radar_id,'%02.0f'),...
                    '/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),...
                    '/',num2str(date_tag(3),'%02.0f'),'/'];
        arch_tag  = [num2str(radar_id,'%02.0f'),'_',datestr(start_timedate,'yyyymmdd')];
        %create new directory if required
        if ~isdir(arch_path)
            mkdir(arch_path);
        end
        
        %run regridding/interpolation
        [vol_obj,refl_vol,vel_vol] = cart_interpol6(pending_h5_list{j},aazi_grid,sl_rrange_grid,eelv_grid,no_groups,vel_flag);
        
        %run cell identify if sig_refl has been detected
        if vol_obj.sig_refl==1
            
            %extract ewt image for processing using radar transform
            ewt_refl_image = max(refl_vol,[],3); %allows the assumption only shrinking is needed.
            ewt_refl_image = medfilt2(ewt_refl_image, [ewt_kernel_size,ewt_kernel_size]);       
            %run EWT
            ewtBasinExtend = wdss_ewt(ewt_refl_image);

            %extract sounding level data
            if realtime_flag == 1
                %extract radar lat lon
                r_ind = find(site_id_list==radar_id);
                r_lat = site_lat_list(r_ind); r_lon = site_lon_list(r_ind);
                %retrieve current GFS temperature data for above radar site
                [gfs_extract_list,nn_snd_fz_h,nn_snd_minus20_h] = gfs_latest_analysis_snding(gfs_extract_list,r_lat,r_lon);
            else
                %load era-interim data for r_lat,r_lon,start_timedate
            end
            
            %run ident
            prc_obj = ewt2ident(vol_obj,ewt_refl_image,refl_vol,vel_vol,ewtBasinExtend,nn_snd_fz_h,nn_snd_minus20_h);
        else
            prc_obj = {};
        end
        
        %create/update daily archives/objects from ident and intp objects
        update_archive(arch_path,arch_tag,vol_obj,prc_obj)
        
        %run tracking algorithm if sig_refl has been detected
        if vol_obj.sig_refl==1 && ~isempty(prc_obj)
            %need to adapt for new archive
            
            keyboard
            %up to here%%%%%
            
            wdss_tracking(dest_dir,vol_obj.start_timedate,vol_obj.radar_id);
        end
        
        %%%%%%ADD PENDING FILE TO COMPLETE LIST
        %%%%%%need to clean out complete using oldest datetime
        disp(['Added ',num2str(length(prc_obj)),' objects from ',arch_tag,'. Volume ',num2str(i),' of ',num2str(length(pending_h5_list))])
        
        %Kill function
        if toc(kill_timer)>kill_wait
            save('temp_process_vars.mat','pending_h5_list','complete_h5_list','gfs_extract_list')
            %update user
            disp(['@@@@@@@@@ wv_process restarted at ',datestr(now)])
            %restart
            if ~isdeployed
                %not deployed method: trigger background restart command before
                %kill
                [~,~]=system(['matlab -desktop -r "run ',pwd,'/wv_process.m" &'])
            else
                %deployed method: restart controlled by run_wv_process sh
                %script
                disp('is deployed - passing restart to run script via temp_process_vars.mat existance')
            end
            quit force
        end
    end
    
    %Update user
    disp([10,'Processing complete',10])
    
    %break loop if cts_loop=0
    if cts_loop==0
        delete('kill_wv_process');
    else
        pause(10)
    end
end

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(kill_timer),' @@@@@@@@@'])

%cumulative track display
% ident_db_fn=[archive_dest,'ident_db_',datestr(vol_obj.start_timedate,'dd-mm-yyyy'),'.mat'];
% track_db_fn=[archive_dest,'track_db_',datestr(vol_obj.start_timedate,'dd-mm-yyyy'),'.mat'];
% ident_db = mat_wrapper(ident_db_fn,'ident_db');
% track_db = mat_wrapper(track_db_fn,'track_db');
% figure; hold on; axis xy;
% for i=1:length(track_db); plot_track(track_db,ident_db,i); end

function pending_list = file_filter(src_dir,oldest_time,newest_time,site_list)
%WHAT: filters files in scr_dir using the time and site no criteria.

%INPUT
%src_dir (see wv_process input)
%oldest_time: oldest time to crop files to (in datenum)
%newest_time: newest time to crop files to (in datenum)
%site_list: site ids of selected radar sites

%OUTPUT
%pending_list: updated list of all processed ftp files

%init pending_list
pending_list = {};

%create a list of dates to read index
date_list = floor(oldest_time):floor(newest_time);

%read index files
for i=1:length(site_list)
    tmp_site_no = num2str(site_list(i),'%02.0f');
    for j=1:length(date_list)
        %read index ffn
        [~,index_ffn] = index_read(src_dir,site_list(i),date_list(j));
        %append to list
        pending_list = [pending_list;index_ffn];
    end
end



function update_archive(archive_path,arch_tag,vol_obj,prc_obj)
%WHAT: Updates the ident_db and intp_db database mat files fore
%that day with the additional entires from input

%INPUT:
%archive_dest: path to archive destination
%vol_obj: new entires for vol_obj from cart_interpol6
%prc_obj: new entires for prc_obj from ewt2ident

%% Update vol_db and vol_data

%create paths
vol_db_fn   = [arch_tag,'_vol_db.txt'];
vol_data_fn = [arch_tag,'_vol_data.h5'];
start_time  = str2num(datestr(vol_obj.start_timedate,'HHMMSS'));
stop_time   = str2num(datestr(vol_obj.stop_timedate,'HHMMSS'));

%load db
if exist([archive_path,vol_db_fn],'file')==2 %file exists
    %read from file
    vol_db     = db_read(vol_db_fn,archive_path);
    %find any repeated times
    delete_idx = find([vol_db.start_time] == start_time);
    %remove data from same timestep
    if ~isempty(ind)
        disp(['duplicate vol_db objects exist ',datestr(vol_obj.start_timedate),' IDR ',num2str(vol_obj.radar_id)]);
        vol_db = db_delete(vol_db,delete_idx);
        disp('old data removed')
    end
    vol_id = max(vol_db.vol_id)+1;
else
    %create a new vol_db
    vol_db = struct;
    vol_id = 1;
end

%append and write db
vol_db(end+1).vol_id        = vol_id;
vol_db(end+1).start_time    = vol_obj.start_time;
vol_db(end+1).stop_time     = vol_obj.stop_time;
vol_db(end+1).sig_refl      = vol_obj.sig_refl;
vol_db(end+1).vel_flag      = vol_obj.vel_flag;
vol_db(end+1).tilt1         = vol_obj.tilt1;
vol_db(end+1).tilt2         = vol_obj.tilt2;
vol_db(end+1).vel_ni        = vol_obj.vel_ni;

db_write(vol_db_fn,archive_path,vol_db);

%write data/atts
scaled_llb  = round(vol_obj.llb*1000);
att_struct  = struct('img_max_lat',scaled_llb(1),'img_min_lat',scaled_llb(2),'img_max_lon',scaled_llb(3),'img_min_lon',scaled_llb(4));
data_struct = struct('tilt1_refl',vol_obj.scan1_refl,'tilt1_vel',vol_obj.scan1_vel,'tilt2_refl',vol_obj.scan2_refl,'tilt2_vel',vol_obj.scan2_vel);
h5_data_write(vol_data_fn,archive_path,vol_id,data_struct,att_struct)

%% Update prc_db and prc_data

%skip if prc_obj is empty
if isempty(prc_obj)
    return
end

%create paths
prc_db_fn   = [arch_tag,'_prc_db.txt'];
prc_data_fn = [arch_tag,'_prc_data.h5'];

%load db
if exist([archive_path,prc_db_fn],'file')==2 %file exists
    %read from file
    prc_db     = db_read(prc_db_fn,archive_path);
    %find any repeated times
    delete_idx = find([prc_db.start_time] == start_time);
    %remove data from same timestep
    if ~isempty(ind)
        disp(['duplicate prc_db objects exist for ',datestr(prc_obj.start_timedate),' IDR ',num2str(prc_obj.radar_id)]);
        prc_db = db_delete(prc_db,delete_idx);
        disp('old data removed')
    end
    subset_id = max(prc_db.subset_id)+1;
else
    %create a new vol_db
    prc_db    = struct;
    subset_id = 1;
end


track_id = 0;
for i=1:length(prc_obj)
    
    cell_llb   = round(prc_obj(i).subset_latlonbox*1000);
    cell_dcent = round(prc_obj(i).dbz_latloncent*1000);
    cell_stats = round(prc_obj(i).stats*10);
    %append and write db
    prc_db(end+1).subset_id     = subset_id;
    prc_db(end+1).track_id      = prc_obj.track_id;
    prc_db(end+1).start_time    = vol_obj.start_time;
    prc_db(end+1).stop_time     = vol_obj.stop_time;
    prc_db(end+1).cell_max_lat  = cell_llb(1);
    prc_db(end+1).cell_min_lat  = cell_llb(2); 
    prc_db(end+1).cell_max_lon  = cell_llb(3);
    prc_db(end+1).cell_min_lon  = cell_llb(4);
    prc_db(end+1).dbz_cent_lat  = cell_dcent(1);
    prc_db(end+1).dbz_cent_lon  = cell_dcent(2);
    %append stats
    for j=1:length(cell_stats)
        prc_db(end+1).(prc_obj(i).stats_labels{j}) = cell_stats(j);
    end
    db_write(prc_db_fn,archive_path,prc_db);


    %write data
    att_struct  = struct('h_grid',h_grid,'v_grid',v_grid);
    data_struct = struct('refl_vol',prc_obj(i).subset_refl,'vel_vol',prc_obj(i).subset_vel,...
                        'top_h_grid',prc_obj(i).top_h_grid,'sts_h_grid',prc_obj(i).sts_h_grid,...
                        'MESH_grid',prc_obj(i).MESH_grid,'POSH_grid',prc_obj(i).sts_h_grid,...
                        'max_dbz_grid',prc_obj(i).max_dbz_grid,'vil_grid',prc_obj(i).vil_grid);      
    h5_data_write(vol_data_fn,archive_path,vol_id,data_struct,att_struct)

    %move to next subset if
    subset_id = subset_id + 1;
    
end
