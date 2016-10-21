function process
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
process_config_fn = 'process.config';
global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
tmp_config_path   = 'tmp/';
download_path     = [tempdir,'h5_download/'];

if exist(tmp_config_path,'file') ~= 7
    mkdir(tmp_config_path)
end

% setup kill time (restart program to prevent memory fragmentation)
kill_wait  = 60*60*2; %kill time in seconds
kill_timer = tic; %create timer object

% Add folders to path and read config files
if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
    addpath('/home/meso/Dropbox/dev/wv/etc')
    addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
    addpath('bin/json_read');
    addpath('bin/mirt3D');
    addpath('etc')
    addpath('tmp')
    unix('touch tmp/kill_process');
else
    addpath('etc')
    addpath('tmp')
    %never include mex file paths in addpath when compiled!!!!!!!!!!!
end

if exist('tmp','file')~=7
    mkdir('tmp')
end

% load process_config
read_config(process_config_fn);
load([tmp_config_path,process_config_fn,'.mat'])
% check for restart or first start
if exist(restart_cofig_fn,'file')==2
    %silent restart detected, load vars from reset and remove file
    load(restart_cofig_fn);
    delete(restart_cofig_fn);
else
    %new start
    complete_h5_dt      = [];
    complete_h5_fn_list = {};
    gfs_extract_list    = [];
    hist_oldest_restart = [];
end

% Load global config files
read_config(global_config_fn);
load([tmp_config_path,global_config_fn,'.mat']);

%load colourmaps for png generation
colormap_interp('refl24bit.txt','vel24bit.txt');

% site_info.txt
read_site_info(site_info_fn); load([tmp_config_path,site_info_fn,'.mat']);
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
[aazi_grid,sl_rrange_grid,eelv_grid]=create_inv_grid(['tmp/',global_config_fn,'.mat']);
%profile clear
%profile on
%% Primary Loop
try
while exist('tmp/kill_process','file')==2

    % create time span
    if realtime_flag == 1
        date_list = utc_time;
    elseif isempty(hist_oldest_restart) %new climatology processing instance
        date_list = datenum(hist_oldest,'yyyy_mm_dd'):datenum(hist_newest,'yyyy_mm_dd');
    else %restart climatology processing
        date_list = hist_oldest_restart:datenum(hist_newest,'yyyy_mm_dd');
    end
    %loop through target ffn's
    for d = 1:length(date_list)
        %init download dir
        if exist(download_path,'file')==7
            delete([download_path,'*']);
        else
            mkdir(download_path);
        end
        
        %fetch files
        if realtime_flag == 1
            %Produce a list of filenames to process
            oldest_time                           = addtodate(date_list,realtime_offset,'hour');
            newest_time                           = date_list;
            [fetch_h5_ffn_list,fetch_h5_fn_list]  = realtime_file_filter(staging_ddb_table,oldest_time,newest_time,radar_id_list);
            new_index                             = ~ismember(fetch_h5_fn_list,complete_h5_fn_list);
            fetch_h5_ffn_list                     = fetch_h5_ffn_list(new_index);
            %update user
            disp(['Realtime processing downloading ',num2str(length(fetch_h5_ffn_list)),' files']);
            for i=1:length(fetch_h5_ffn_list)
                file_cp(fetch_h5_ffn_list{i},download_path,0,1)
            end
        else
            radar_id = radar_id_list(1); %only has one entry for climatology processing
            date_vec = datevec(date_list(d));
            s3_path  = [src_root,num2str(radar_id,'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
            %update user
            disp(['Climatology processing downloading files from ',s3_path]);
            file_cp(s3_path,download_path,1,1)
        end
        %wait for aws process to finish
        wait_aws_finish
        %build filelist
        download_path_dir = dir(download_path); download_path_dir(1:2) = [];
        pending_h5_fn_list = {download_path_dir.name};

        
        for i=1:length(pending_h5_fn_list)
            display(['processing file of ',num2str(i),' of ',num2str(length(pending_h5_fn_list))])
            %init local filename for processing
            h5_ffn = [download_path,pending_h5_fn_list{i}];
            if exist(h5_ffn,'file')~=2
                continue
            end

            %QA the h5 file (attempt to read groups)
            [qa_flag,no_groups,radar_id,vel_flag,start_dt] = qa_h5(h5_ffn,min_n_groups,radar_id_list);

            %QA exit
            if qa_flag==0
                disp(['Volume failed QA: ' pending_h5_fn_list{i}])
                complete_h5_fn_list = [complete_h5_fn_list;pending_h5_fn_list{i}];
                complete_h5_dt   = [complete_h5_dt;start_dt];
                delete(h5_ffn)
                continue
            end

            %run regridding/interpolation
            [vol_obj,refl_vol,vel_vol] = vol_regrid(h5_ffn,aazi_grid,sl_rrange_grid,eelv_grid,no_groups,vel_flag);
            if isempty(vol_obj)
                disp(['Volume datasets missing: ' pending_h5_fn_list{i}])
                complete_h5_fn_list = [complete_h5_fn_list;pending_h5_fn_list{i}];
                complete_h5_dt   = [complete_h5_dt;start_dt];
                delete(h5_ffn)
                continue
            end
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
                    %retrieve current GFS temperature data for above radar site
                    [gfs_extract_list,nn_snd_fz_h,nn_snd_minus20_h] = gfs_latest_analysis_snding(gfs_extract_list,vol_obj.r_lat,vol_obj.r_lon);
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
                updated_storm_jstruct = wdss_tracking(vol_obj.start_timedate,vol_obj.radar_id);
                %generate nowcast json on s3 for realtime data
                if realtime_flag == 1
                     storm_nowcast_json_wrap(dest_root,updated_storm_jstruct,vol_obj);
                     storm_nowcast_svg_wrap(dest_root,updated_storm_jstruct,vol_obj);
                end
            else
                %remove nowcast files is no prc_objects exist anymore
                nowcast_root = [dest_root,num2str(radar_id,'%02.0f'),'/nowcast.'];
                file_rm([nowcast_root,'json'],0)
                file_rm([nowcast_root,'wtk'],0)
                file_rm([nowcast_root,'svg'],0)
            end

            %append and clean h5_list for realtime processing
            if realtime_flag == 1
                complete_h5_fn_list = [complete_h5_fn_list;pending_h5_fn_list{i}];
                complete_h5_dt   = [complete_h5_dt;start_dt];
                clean_idx        = complete_h5_dt < oldest_time;
                complete_h5_fn_list(clean_idx) = [];
                complete_h5_dt(clean_idx)   = [];
            end
            
            disp(['Added ',num2str(length(prc_obj)),' objects from ',pending_h5_fn_list{i},' Volume ',num2str(i),' of ',num2str(length(pending_h5_fn_list))])

            %Kill function
            if toc(kill_timer)>kill_wait
                hist_oldest_restart = date_list(d);
                save('temp_process_vars.mat','complete_h5_fn_list','complete_h5_dt','hist_oldest_restart','gfs_extract_list')
                %update user
                disp(['@@@@@@@@@ wv_process restarted at ',datestr(now)])
                %restart
                if ~isdeployed
                    %not deployed method: trigger background restart command before
                    %kill
                    [~,~] = system(['matlab -desktop -r "run ',pwd,'/process.m" &'])
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
    disp(['Processing complete at ',datestr(now),10])
    
    %rotate ddb, cp_file, and qa logs to 200kB
    unix(['tail -c 200kB  etc/log.qa > etc/log.qa']);
    unix(['tail -c 200kB  etc/log.ddb > etc/log.ddb']);
    unix(['tail -c 200kB  etc/log.cp > etc/log.cp']);
    
    %break loop if cts_loop=0
    if realtime_flag==0
        delete('tmp/kill_process')
        break
    end
    
    pause(2)
    
end
catch err
    %save vars
    display(err)
    hist_oldest_restart = date_list(d);
    save('temp_process_vars.mat','complete_h5_fn_list','complete_h5_dt','hist_oldest_restart','gfs_extract_list')
    log_cmd_write('tmp/log.crash','',['crash error at ',datestr(now)],[err.identifier,' ',err.message]);
    rethrow(err)
end

%soft exit display
disp([10,'@@@@@@@@@ Soft Exit at ',datestr(now),' runtime: ',num2str(toc(kill_timer)),' @@@@@@@@@'])
%profile off
%profile viewer
function [pending_ffn_list,pending_fn_list] = realtime_file_filter(ddb_table,oldest_time,newest_time,radar_id_list)
%WHAT: filters files in scr_dir using the time and site no criteria.

%INPUT
%src_dir (see wv_process input)
%oldest_time: oldest time to crop files to (in datenum)
%newest_time: newest time to crop files to (in datenum)
%radar_id_list: site ids of selected radar sites

%OUTPUT
%pending_list: updated list of all processed ftp files

%init pending_list
pending_ffn_list = {};
pending_fn_list  = {};
%read staging index
p_exp            = 'data_type,data_id,h5_ffn'; %attributes to return
jstruct          = ddb_query_part('data_type','odimh5','S',p_exp,ddb_table);
pending_ffn_list = jstruct_to_mat([jstruct.h5_ffn],'S');
for j=1:length(pending_ffn_list)
    [~,fn,ext] = fileparts(pending_ffn_list{j});
    tmp_radar_id    = str2num(fn(1:2));
    tmp_timestamp   = datenum(fn(4:end),'yyyymmdd_HHMMSS');
    %filter
    if any(ismember(tmp_radar_id,radar_id_list)) && tmp_timestamp>=oldest_time && tmp_timestamp<=newest_time
        pending_fn_list = [pending_fn_list;[fn,ext]];
        pending_ffn_list = [pending_ffn_list;pending_ffn_list{j}];
        %clean ddb table
        delete_struct           = struct;
        delete_struct.data_id   = jstruct(j).data_id;
        delete_struct.data_type = jstruct(j).data_type;
        ddb_rm_item(delete_struct,ddb_table);  
    end
end

% for i=1:length(radar_id_list)
%     radar_id      = num2str(radar_id_list(i),'%02.0f');
%     start_datestr = datestr(oldest_time,ddb_tfmt);
%     stop_datestr  = datestr(newest_time,ddb_tfmt);
%     %run a query for a radar_id, between for time and no processed
%     %(sig_refl)
%     disp(['ddb query: ',start_datestr,' ',radar_id])
%     p_exp   = 'ffn'; %attributes to return
%     jstruct = ddb_query('radar_id',radar_id,'start_timestamp',start_datestr,stop_datestr,p_exp,odimh5_ddb_table);
%     if isempty(jstruct)
%         continue
%     end
%     %convert jstruct fields to arrays
%     tmp_sig_refl_flag = jstruct_to_mat([jstruct.sig_refl_flag],'N');
%     tmp_h5_ffn        = jstruct_to_mat([jstruct.h5_ffn],'S');
%     %filter for realtime
%     if realtime_flag==1
%         tmp_h5_ffn = tmp_h5_ffn(tmp_sig_refl_flag==0);
%     end
%     %append to list unprocessed files
%     pending_ffn_list = [pending_ffn_list;tmp_h5_ffn];
%     tmp_h5_fn = {};
%     for j=1:length(tmp_h5_ffn)
%         [~,fn,ext] = fileparts(tmp_h5_ffn{j});
%         tmp_h5_fn = [tmp_h5_fn;[fn,ext]];
%     end
%     pending_fn_list = [pending_fn_list;tmp_h5_fn];
% end



function update_archive(dest_root,vol_obj,storm_obj,odimh5_ddb_table,storm_ddb_table)
%WHAT: Updates the ident_db and intp_db database mat files fore
%that day with the additional entires from input

%INPUT:
%archive_dest: path to archive destination
%vol_obj: new entires for vol_obj from cart_interpol6
%storm_obj: new entires for storm_obj from ewt2ident

%% Update vol_db and vol_data

load('tmp/global.config.mat')
load('tmp/interp_cmaps.mat')

%setup paths and tags
date_vec  = datevec(vol_obj.start_timedate);
radar_id  = vol_obj.radar_id;
data_path = [dest_root,num2str(radar_id,'%02.0f'),...
    '/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),...
    '/',num2str(date_vec(3),'%02.0f'),'/'];
data_tag  = [num2str(radar_id,'%02.0f'),'_',datestr(vol_obj.start_timedate,r_tfmt)];
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
scaled_llb  = round(vol_obj.llb*geo_scale)';

%delete h5 if exists
if exist(tmp_h5_ffn,'file') == 2
    delete(tmp_h5_ffn)
end

%append to odimh5_ddb_table (replaces any previous entries)
%get-item
jstruct = ddb_get_item(odimh5_ddb_table,...
    'radar_id','N',num2str(radar_id,'%02.0f'),...
    'start_timestamp','S',datestr(vol_obj.start_timedate,ddb_tfmt),'');
%update init_sig_relf_flag
if ~isempty(jstruct)
    init_sig_relf_flag = jstruct.Item.sig_refl_flag.N;
else
    init_sig_relf_flag = 0;
    jstruct            = struct;
end

jstruct.Item.radar_id.N       = num2str(radar_id,'%02.0f');
jstruct.Item.start_timestamp.S= datestr(vol_obj.start_timedate,ddb_tfmt);
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
tar_ffn_list = {[data_tag,'.scan1_refl.png'];[data_tag,'.scan2_refl.png']};
%convert vel images to png
if vol_obj.vel_ni~=0
    s1_vel_png = png_transform(vol_obj.scan1_vel,'vel',vol_obj.vel_vars,min_vel);
    s2_vel_png = png_transform(vol_obj.scan2_vel,'vel',vol_obj.vel_vars,min_vel);
    s1_vel_ffn = [tempdir,data_tag,'.scan1_vel.png'];
    s2_vel_ffn = [tempdir,data_tag,'.scan2_vel.png'];
    imwrite(s1_vel_png,interp_vel_cmap,s1_vel_ffn,'Transparency',vel_transp);
    imwrite(s2_vel_png,interp_vel_cmap,s2_vel_ffn,'Transparency',vel_transp);
    tar_ffn_list = [tar_ffn_list;[data_tag,'.scan1_vel.png'];[data_tag,'.scan2_vel.png']];
end

%skip if storm_obj is empty
if ~isempty(storm_obj)
    track_id        = 0; %default for no track
    %delete storm ddb entries for this volume if they already exist
    if init_sig_relf_flag == 1 %since indicates volumes was previous processed for storms
        storm_atts      = 'radar_id,subset_id';
        oldest_time_str = datestr(vol_obj.start_timedate,ddb_tfmt);
        newest_time_str = datestr(addtodate(vol_obj.start_timedate,1,'second'),ddb_tfmt); %duffer time for between function
        delete_jstruct  = ddb_query('radar_id',num2str(radar_id,'%02.0f'),'subset_id',oldest_time_str,newest_time_str,storm_atts,storm_ddb_table);
        for i=1:length(delete_jstruct)
            ddb_rm_item(delete_jstruct(i),storm_ddb_table);
        end
        %run a query for radar_id and time_start
        %pass to delete
    end
    %init struct
    ddb_put_struct  = struct;
    for i=1:length(storm_obj)
        subset_id  = i;
        storm_llb      = round(storm_obj(i).subset_latlonbox*geo_scale);
        storm_dcent    = round(storm_obj(i).dbz_latloncent*geo_scale);
        storm_edge_lat = round(storm_obj(i).subset_lat_edge*geo_scale);
        storm_edge_lon = round(storm_obj(i).subset_lon_edge*geo_scale);
        storm_stats    = round(storm_obj(i).stats*stats_scale);
        %append and write db
        tmp_jstruct                     = struct;
        tmp_jstruct.radar_id.N          = num2str(vol_obj.radar_id);
        tmp_jstruct.subset_id.S         = [datestr(vol_obj.start_timedate,ddb_tfmt),'_',num2str(i,'%03.0f')];
        tmp_jstruct.start_timestamp.S   = datestr(vol_obj.start_timedate,ddb_tfmt);
        tmp_jstruct.track_id.N          = num2str(track_id);
        tmp_jstruct.storm_ijbox.S       = num2str(storm_obj(i).subset_ijbox);
        tmp_jstruct.storm_latlonbox.S   = num2str(storm_llb');
        tmp_jstruct.storm_edge_lat.S    = num2str(storm_edge_lat);
        tmp_jstruct.storm_edge_lon.S    = num2str(storm_edge_lon);
        tmp_jstruct.storm_dbz_centlat.N = num2str(storm_dcent(1));
        tmp_jstruct.storm_dbz_centlon.N = num2str(storm_dcent(2));
        tmp_jstruct.h_grid.N            = num2str(h_grid);
        tmp_jstruct.v_grid.N            = num2str(v_grid);
        %append stats
        for j=1:length(storm_stats)
            tmp_jstruct.(storm_obj(i).stats_labels{j}).N = num2str(storm_stats(j));
        end
        %append to put struct
        [ddb_put_struct,tmp_sz] = addtostruct(ddb_put_struct,tmp_jstruct,['item',num2str(i)]);
        %write if needed
        if tmp_sz==25 || i == length(storm_obj)
            %batch write
            ddb_batch_write(ddb_put_struct,storm_ddb_table,1);
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
        h5_data_write(h5_fn,tempdir,subset_id,data_struct,r_scale);
    end
    %move h5 files to data_path
    if exist(tmp_h5_ffn,'file') == 2
        tar_ffn_list = [tar_ffn_list;h5_fn];
    end
end

%tar data and move to s3
%create file list
tartxt_fid = fopen('etc/tar_ffn_list.txt','w');
for i=1:length(tar_ffn_list)
    fprintf(tartxt_fid,'%s\n',tar_ffn_list{i});
end
fclose(tartxt_fid);
%unix tar cmd (matlab breaks...)
cmd         = ['tar -C ',tempdir,' -cvf ',tmp_tar_ffn,' -T etc/tar_ffn_list.txt'];
[sout,eout] = unix(cmd);
file_mv(tmp_tar_ffn,dst_tar_ffn);
for i=1:length(tar_ffn_list)
    delete([tempdir,tar_ffn_list{i}]);
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
