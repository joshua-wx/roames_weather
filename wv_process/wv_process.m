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
restart_cofig_fn  = 'restart_vars.mat';
process_config_fn = 'wv_process.config';
global_config_fn  = 'wv_global.config';
site_info_fn      = 'site_info.txt';
h5_path           = 'h5_download/';
% setup kill time (restart program to prevent memory fragmentation)
kill_wait  = 60*60*2; %kill time in seconds
kill_timer = tic; %create timer object

% Add folders to path and read config files
if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
    addpath('/home/meso/Dropbox/dev/wv/bin');
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
    addpath('/home/meso/Dropbox/dev/wv/wv_process/bin/json_read');
    addpath('/home/meso/Dropbox/dev/wv/wv_process/bin/mirt3D');
    %setenv('LD_PRELOAD','/usr/lib64/libstdc++.so.6');
    addpath('/home/meso/Dropbox/dev/wv/etc')
    unix('touch kill_wv_process');
else
    addpath('etc')
    addpath('bin/mirt3D')
    addpath('bin/json_read')
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
    date_list        = [];
    complete_h5_dt   = [];
    complete_h5_list = {};
    gfs_extract_list = [];
    hist_oldest_restart = [];
end

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

%break if processing climatology for more than one radar
if realtime_flag==0 && length(radar_id_list)>1
    display('only run climatology processing for one radar at a time')
    display('halting')
    return
end

%create/update daily archives/objects from ident and intp objects
if local_dest_flag == 1
    dest_root = local_dest_root;
else
    dest_root = s3_dest_root;
end
if local_src_flag == 1 %only used for climatology processing
    src_root = local_src_root;
else
    src_root = s3_src_root;
end

%% Preallocate cartesian regridding coordinates
[aazi_grid,sl_rrange_grid,eelv_grid]=create_inv_grid([global_config_fn,'.mat']);
%profile clear
%profile on
%% Primary Loop
while exist('kill_wv_process','file')==2

    % create time span
    if realtime_flag == 1
        date_list = utc_time;
    elseif isempty(hist_oldest_restart) %new climatology processing instance
        date_list = datenum(hist_oldest,'yyyy_mm_dd'):datenum(hist_newest,'yyyy_mm_dd');
    else %restart climatology processing
        date_list = datenum(hist_oldest_restart,'yyyy_mm_dd'):datenum(hist_newest,'yyyy_mm_dd');
    end
    %loop through target ffn's
    for d = 1:length(date_list)
        %init download dir
        if exist(h5_path,'file')==7
            delete([h5_path,'*']);
        else
            mkdir(h5_path);
        end
        
        %fetch files
        if realtime_flag == 1
            %realtime odimh5 file fetch
            newest_time = date_list(d);
            oldest_time = addtodate(date_list(d),realtime_offset,'hour');
            %Produce a list of filenames to process
            fetch_h5_list  = file_filter(odimh5_ddb_table,oldest_time,newest_time,radar_id_list,realtime_flag);
            new_index      = ~ismember(fetch_h5_list,complete_h5_list);
            fetch_h5_list  = fetch_h5_list(new_index);
            %update user
            disp(['Realtime processing downloading ',num2str(length(fetch_h5_list)),' files']);
            for i=1:length(fetch_h5_list)
                file_cp(fetch_h5_list{i},h5_path,0)
            end
        else
            radar_id = radar_id_list(1); %only has one entry for climatology processing
            date_vec = datevec(date_list(d));
            s3_path  = [src_root,num2str(radar_id),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
            %update user
            disp(['Climatology processing downloading files from ',s3_path]);
            file_cp(s3_path,h5_path,1)
        end
        
        %build filelist
        h5_path_dir = dir(h5_path); h5_path_dir(1:2) = [];
        pending_h5_list = {h5_path_dir.name};

        
        for i=1:length(pending_h5_list)
            display(['processing file of ',num2str(i),' of ',num2str(length(pending_h5_list))])
            %init local filename for processing
            h5_ffn = [h5_path,pending_h5_list{i}];
            if exist(h5_ffn,'file')~=2
                continue
            end

            %QA the h5 file (attempt to read groups)
            [qa_flag,no_groups,radar_id,vel_flag,start_dt] = qa_h5(h5_ffn,min_n_groups,radar_id_list);

            %QA exit
            if qa_flag==0
                disp(['Volume failed QA: ' pending_h5_list{i}])
                complete_h5_list = [complete_h5_list;pending_h5_list{i}];
                complete_h5_dt   = [complete_h5_dt;start_dt];
                delete(h5_ffn)
                continue
            end

            %run regridding/interpolation
            [vol_obj,refl_vol,vel_vol] = vol_regrid(h5_ffn,aazi_grid,sl_rrange_grid,eelv_grid,no_groups,vel_flag);

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
                    %load era-interim fzlvl data from ddb
                    [nn_snd_fz_h,nn_snd_minus20_h] = eraint_ddb_extract(vol_obj.start_timedate,radar_id,eraint_ddb_table);
                end
                %run ident
                prc_obj = ewt2ident(vol_obj,ewt_refl_image,refl_vol,vel_vol,ewtBasinExtend,nn_snd_fz_h,nn_snd_minus20_h);
            else
                prc_obj = {};
            end
            
            update_archive(dest_root,vol_obj,prc_obj,odimh5_ddb_table,storm_ddb_table)

            %run tracking algorithm if sig_refl has been detected
            if vol_obj.sig_refl==1 && ~isempty(prc_obj)
                %tracking
                wdss_tracking(vol_obj.start_timedate,vol_obj.radar_id);
            end

            %append and clean h5_list for realtime processing
            if realtime_flag == 1
                complete_h5_list = [complete_h5_list;fetch_h5_list{i}];
                complete_h5_dt   = [complete_h5_dt;start_dt];
                clean_idx        = complete_h5_dt < oldest_time;
                complete_h5_list(clean_idx) = [];
                complete_h5_dt(clean_idx)   = [];
            end
            
            disp(['Added ',num2str(length(prc_obj)),' objects from ',pending_h5_list{i},' Volume ',num2str(i),' of ',num2str(length(pending_h5_list))])

            %Kill function
            if toc(kill_timer)>kill_wait
                hist_oldest_restart = date_list(d);
                save('temp_process_vars.mat','pending_h5_list','complete_h5_list','complete_h5_dt','hist_oldest_restart')
                %update user
                disp(['@@@@@@@@@ wv_process restarted at ',datestr(now)])
                %restart
                if ~isdeployed
                    %not deployed method: trigger background restart command before
                    %kill
                    [~,~] = system(['matlab -desktop -r "run ',pwd,'/wv_process.m" &'])
                else
                    %deployed method: restart controlled by run_wv_process sh
                    %script
                    disp('is deployed - passing restart to run script via temp_process_vars.mat existance')
                end
                quit force
            end
        end
    end
    
    %Update user and clear pending list
    disp([10,'Processing complete',10])
    
    %rotate ddb, cp_file, and qa logs to 200kB
    unix(['tail -c 200kB  log.qa > log.qa']);
    unix(['tail -c 200kB  log.ddb > log.ddb']);
    unix(['tail -c 200kB  log.cp > log.cp']);
    
    %break loop if cts_loop=0
    if realtime_flag==0
        delete('kill_wv_process');
    else
        pause(10)
    end
    
end

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc(kill_timer)),' @@@@@@@@@'])
%profile off
%profile viewer
function pending_list = file_filter(odimh5_ddb_table,oldest_time,newest_time,radar_id_list,realtime_flag)
%WHAT: filters files in scr_dir using the time and site no criteria.

%INPUT
%src_dir (see wv_process input)
%oldest_time: oldest time to crop files to (in datenum)
%newest_time: newest time to crop files to (in datenum)
%radar_id_list: site ids of selected radar sites

%OUTPUT
%pending_list: updated list of all processed ftp files

%init pending_list
pending_list = {};
%read index files
for i=1:length(radar_id_list)
    radar_id      = num2str(radar_id_list(i),'%02.0f');
    start_datestr = datestr(oldest_time,'yyyy-mm-ddTHH:MM:SS');
    stop_datestr  = datestr(newest_time,'yyyy-mm-ddTHH:MM:SS');
    %run a query for a radar_id, between for time and no processed
    %(sig_refl)
    disp(['ddb query: ',start_datestr,' ',radar_id])
    p_exp   = 'h5_ffn,sig_refl_flag'; %attributes to return
    jstruct = ddb_query('radar_id',radar_id,'start_timestamp',start_datestr,stop_datestr,p_exp,odimh5_ddb_table);
    if isempty(jstruct)
        continue
    end
    %convert jstruct fields to arrays
    tmp_sig_refl_flag = jstruct_to_mat([jstruct.sig_refl_flag],'N');
    tmp_h5_ffn        = jstruct_to_mat([jstruct.h5_ffn],'S');
    %filter for realtime
    if realtime_flag==1
        tmp_h5_ffn = tmp_h5_ffn(tmp_sig_refl_flag==0);
    end
    %append to list unprocessed files
    pending_list = [pending_list;tmp_h5_ffn];
end



function update_archive(dest_root,vol_obj,storm_obj,odimh5_ddb_table,storm_ddb_table)
%WHAT: Updates the ident_db and intp_db database mat files fore
%that day with the additional entires from input

%INPUT:
%archive_dest: path to archive destination
%vol_obj: new entires for vol_obj from cart_interpol6
%storm_obj: new entires for storm_obj from ewt2ident

%% Update vol_db and vol_data

load('wv_global.config.mat')
load('interp_cmaps.mat')

%setup paths and tags
date_vec  = datevec(vol_obj.start_timedate);
radar_id  = vol_obj.radar_id;
data_path = [dest_root,num2str(radar_id,'%02.0f'),...
    '/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),...
    '/',num2str(date_vec(3),'%02.0f'),'/'];
data_tag  = [num2str(radar_id,'%02.0f'),'_',datestr(vol_obj.start_timedate,'yyyymmdd_HHMMSS')];
%create local data path
if ~strcmp(dest_root(1:2),'s3')
    mkdir(data_path)
end

%% volume data
tar_fn      = [data_tag,'.wv.tar'];
tmp_tar_ffn = [tempdir,tar_fn];
h5_fn       = [data_tag,'.storm.h5'];
tmp_h5_ffn  = [tempdir,h5_fn];
dst_tar_ffn = [data_path,tar_fn];
scaled_llb  = round(vol_obj.llb*1000)';

%append to odimh5_ddb_table (replaces any previous entries)
%get-item
jstruct = ddb_get_item(odimh5_ddb_table,...
    'radar_id','N',num2str(radar_id,'%02.0f'),...
    'start_timestamp','S',datestr(vol_obj.start_timedate,'yyyy-mm-ddTHH:MM:SS'),'');
%update jstruct
jstruct.Item.sig_refl_flag.N  = num2str(vol_obj.sig_refl);
jstruct.Item.tilt1.N          = num2str(vol_obj.tilt1);
jstruct.Item.tilt2.N          = num2str(vol_obj.tilt2);
jstruct.Item.vel_ni.N         = num2str(vol_obj.vel_ni);
jstruct.Item.img_latlonbox.S  = num2str(scaled_llb);
%write back to ddb
ddb_put_item(jstruct.Item,odimh5_ddb_table);
%convert refl images to png
refl_transp  = ones(length(interp_refl_cmap),1); refl_transp(1) = 0;
vel_transp   = ones(length(interp_vel_cmap),1);   vel_transp(1) = 0;
s1_refl_png  = png_transform(vol_obj.scan1_refl,'refl',vol_obj.refl_vars,min_dbz);
s2_refl_png  = png_transform(vol_obj.scan2_refl,'refl',vol_obj.refl_vars,min_dbz);
s1_refl_ffn  = [tempdir,data_tag,'.scan1_refl.png'];
s2_refl_ffn  = [tempdir,data_tag,'.scan2_refl.png'];
imwrite(s1_refl_png,interp_refl_cmap,s1_refl_ffn,'Transparency',refl_transp);
imwrite(s2_refl_png,interp_refl_cmap,s2_refl_ffn,'Transparency',refl_transp);
tar_ffn_list = {s1_refl_ffn,s2_refl_ffn};
%convert vel images to png
if vol_obj.vel_ni~=0
    s1_vel_png = png_transform(vol_obj.scan1_vel,'vel',vol_obj.vel_vars,min_vel);
    s2_vel_png = png_transform(vol_obj.scan2_vel,'vel',vol_obj.vel_vars,min_vel);
    s1_vel_ffn = [tempdir,data_tag,'.scan1_vel.png'];
    s2_vel_ffn = [tempdir,data_tag,'.scan2_vel.png'];
    imwrite(s1_vel_png,interp_vel_cmap,s1_vel_ffn,'Transparency',vel_transp);
    imwrite(s2_vel_png,interp_vel_cmap,s2_vel_ffn,'Transparency',vel_transp);
    tar_ffn_list = [tar_ffn_list,s1_vel_ffn,s2_vel_ffn];
end

%skip if storm_obj is empty
if ~isempty(storm_obj)
    track_id        = 0; %default for no track
    ddb_put_struct  = struct;
    for i=1:length(storm_obj)
        subset_id  = i;
        cell_llb   = round(storm_obj(i).subset_latlonbox*1000);
        cell_dcent = round(storm_obj(i).dbz_latloncent*1000);
        cell_stats = round(storm_obj(i).stats*10);
        %append and write db
        tmp_jstruct                   = struct;
        tmp_jstruct.radar_id.N        = num2str(vol_obj.radar_id);
        tmp_jstruct.subset_id.S       = [datestr(vol_obj.start_timedate,'yyyy-mm-ddTHH:MM:SS'),'_',num2str(i,'%03.0f')];
        tmp_jstruct.start_timestamp.S = datestr(vol_obj.start_timedate,'yyyy-mm-ddTHH:MM:SS');
        tmp_jstruct.track_id.N        = num2str(track_id);
        tmp_jstruct.storm_latlonbox.S = num2str(cell_llb);
        tmp_jstruct.storm_dbz_centlat.N = num2str(cell_dcent(1));
        tmp_jstruct.storm_dbz_centlon.N = num2str(cell_dcent(2));
        tmp_jstruct.h_grid.N          = num2str(h_grid);
        tmp_jstruct.v_grid.N          = num2str(v_grid);
        %append stats
        for j=1:length(cell_stats)
            tmp_jstruct.(storm_obj(i).stats_labels{j}).N = num2str(cell_stats(j));
        end
        %append to put struct
        [ddb_put_struct,tmp_sz] = addtostruct(ddb_put_struct,tmp_jstruct,['item',num2str(i)]);
        %write if needed
        if tmp_sz==25 || i == length(storm_obj)
            %batch write
            ddb_batch_write(ddb_put_struct,storm_ddb_table);
            %clear ddb_put_struct
            ddb_put_struct  = struct;
        end
        %write data to h5   
        data_struct = struct('refl_vol',storm_obj(i).subset_refl,...
                            'tops_h_grid',storm_obj(i).tops_h_grid,'sts_h_grid',storm_obj(i).sts_h_grid,...
                            'MESH_grid',storm_obj(i).MESH_grid,'POSH_grid',storm_obj(i).POSH_grid,...
                            'max_dbz_grid',storm_obj(i).max_dbz_grid,'vil_grid',storm_obj(i).vil_grid);      
        if vol_obj.vel_ni~=0
            data_struct.vel_vol = storm_obj(i).subset_vel;
        end
        h5_data_write(h5_fn,tempdir,subset_id,data_struct);
    end
    %move h5 files to data_path
    if exist(tmp_h5_ffn,'file') == 2
        tar_ffn_list = [tar_ffn_list,tmp_h5_ffn];
    end
end

%tar data and move to s3
tar(tmp_tar_ffn,tar_ffn_list);
file_mv(tmp_tar_ffn,dst_tar_ffn);
for i=1:length(tar_ffn_list)
    delete(tar_ffn_list{i});
end



function [ddb_struct,tmp_sz] = addtostruct(ddb_struct,data_struct,item_id)

%init
data_name_list  = fieldnames(data_struct);

for i = 1:length(data_name_list);
    %read from data_struct
    data_name  = data_name_list{i};
    data_type  = fieldnames(data_struct.(data_name)); data_type = data_type{1};
    data_value = data_struct.(data_name).(data_type);
    %add to ddb master struct
    ddb_struct.(item_id).(data_name).(data_type) = data_value;
end
%check size
tmp_sz =  length(fieldnames(ddb_struct));

function data_out = png_transform(data_in,type,vars,min_value)

%find no data regions
%scale to true value using transformation constants
data_out=double(data_in).*vars(1)+vars(2);
if strcmp(type,'refl');
        %scale for colormapping
        data_out=(data_out-min_value)*2+1;
else strcmp(type,'vel');
        %scale for colormapping
        data_out=(data_out-min_value)+1;
end
