function update_kml_4(intp2kml,ident2kml,kml_dir,options,oldest_time,newest_time)
%WHAT: Generates the nt_kml link and track kml and links using the three
%input databases. The network links are structured into folders in an optimised way.

%INPUT:
%intp2kml: subset of intp_db for updating the kml
%ident2kml: subset of ident_db for updating the kml
%ident2kml: to preserve the indexing used in tracking for quick data
%extraction from ident
%track2kml: subset of track_db for updating the kml
%kml_dir: root of kml dir
%options: logical array for the types of kml layers to produce
%oldest_time: lower limit on timedate nums
%newest_time: upper limit on timedate nums

%OUTPUT:
%kml network links in the layers_links kml file (root dir) and track kml
%objects

%% load config file setup master kml string
load('tmp_global_config.mat');
load('colormaps.mat');
load('site_info.mat');
master_kml='';

%check if targets exist
if ~isempty(intp2kml)
    
    %generate unique list of radar ids for targets
    unique_r_id=unique([intp2kml.radar_id]);
    
    %loop through uniq site numbers
    for i=1:length(unique_r_id)
       
        %select current radar id and name
        cur_r_id   = unique_r_id(i);
        cur_r_name = site_s_name_list{site_id_list==cur_r_id};
        
        %kml string for objects
        scan1_refl_nl=''; scan2_refl_nl='';
        scan1_vel_nl=''; scan2_vel_nl='';
        refl_xsec_nl=''; vel_xsec_nl='';
        in_iso_nl=''; out_iso_nl='';
        path_nl='';
        swath_nl='';
        nowcast_nl='';
        nowcast_graph_nl='';
        stats_nl='';
        
        %kml strings for COLLATING ALL track specific objects
        %tracks_nl='';
                        
        %lookup intp targets from this radar id
        intp_ind=find([intp2kml.radar_id]==cur_r_id);
        % enfore continous timestamps
        [intp_start_td,intp_stop_td,intp_ref_td]=cts_timestamps(intp2kml,intp_ind,newest_time,oldest_time);
        %generate region data (used for other objects)
        scan_region=ge_region(intp2kml(intp_ind(1)).region_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels); %only need to generate once since radar site is not changing
        
        %% Generate networklink kml for scan elev's 1&2 for refl and vel data
        temp_a=''; temp_b=''; temp_c=''; temp_d='';
        for j=1:length(intp_ind)
            %generate nl kml
            scan_tag=['IDR',num2str(cur_r_id),'_',datestr(intp_ref_td(j),'dd-mm-yyyy_HHMM')];
            if options(1)==1;
                temp_a=ge_networklink(temp_a,['scan1_refl_',scan_tag],[ident_data_path,'scan1_refl_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),1); end
            if options(2)==1;
                temp_b=ge_networklink(temp_b,['scan2_refl_',scan_tag],[ident_data_path,'scan2_refl_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),1); end
            if options(3)==1;
                temp_c=ge_networklink(temp_c,['scan1_vel_',scan_tag],[ident_data_path,'scan1_vel_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),1); end
            if options(4)==1;
                temp_d=ge_networklink(temp_d,['scan2_vel_',scan_tag],[ident_data_path,'scan2_vel_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),1); end
        end
        %place scans in a folder
        scan1_refl_nl=ge_folder(scan1_refl_nl,temp_a,'Scan 1 Refl','',1);
        scan2_refl_nl=ge_folder(scan2_refl_nl,temp_b,'Scan 2 Refl','',1);
        scan1_vel_nl=ge_folder(scan1_vel_nl,temp_c,'Scan 1 Vel','',1);
        scan2_vel_nl=ge_folder(scan2_vel_nl,temp_d,'Scan 2 Vel','',1);
        
        %% Generate cell object kml
        
        if ~isempty(ident2kml)

            %index of all ident entires for current radar
            ident_idx=find([ident2kml.radar_id]==cur_r_id);

            %generate nl kml for all objects
            if ~isempty(ident_idx)
                %generate kml for ident objects created in cloud_objects3
                [refl_xsec_nl,vel_xsec_nl,out_iso_nl,in_iso_nl,stats_nl]=cell_nl_kml(ident2kml(ident_idx),intp_ref_td,intp_start_td,intp_stop_td,options);
                
                %list unique simple if from ident_idx
                [uniq_simple_id,~,ic]=unique([ident2kml(ident_idx).simple_id]);
                
                %loop through each track for cur radar id
                for j=1:length(uniq_simple_id)
                    %load curr track
                    cur_track_ident_ind=ident_idx(ic==j);
                    if length(cur_track_ident_ind)<min_track_cells
                        continue
                    end
                    %find index for ident2kml for init and finl entries
                    init_ident_ind=cur_track_ident_ind(1:end-1);
                    finl_ident_ind=cur_track_ident_ind(2:end);
                    %find uniq ident ind for the current track
                    stm_simple_id=num2str(uniq_simple_id(j));
                    %skip track layers if number of uniq cells is less than
                    %min_track_cells


                    %                     %generate kml for cell layers
                    %                     try
                    %                     [t_refl_xsec_nl,t_vel_xsec_nl,t_out_iso_nl,t_in_iso_nl,t_stats_nl]=cell_nl_kml(ident2kml(uniq_track_ident_ind),intp_ref_td,intp_start_td,intp_stop_td,options);
                    %                     catch
                    %                         keyboard
                    %                     end
                    %                     t_cell_nl=[t_refl_xsec_nl,t_vel_xsec_nl,t_out_iso_nl,t_in_iso_nl,t_stats_nl];

                    t_path_nl='';
                    %path kml and nl
                    if options(10)==1
                        t_path_nl=storm_path(ident2kml(init_ident_ind),ident2kml(finl_ident_ind),kml_dir,stm_simple_id,scan_region,oldest_time,newest_time,1);
                        path_nl=[path_nl,t_path_nl];
                    end

                    t_swath_nl='';
                    %swath kml and nl
                    if options(11)==1
                        t_swath_nl=storm_swath3(ident2kml(init_ident_ind),ident2kml(finl_ident_ind),kml_dir,stm_simple_id,scan_region,oldest_time,newest_time,1);
                        swath_nl=[swath_nl,t_swath_nl];
                    end

                    t_nowcast_nl='';
                    t_nowcast_graph_nl='';
                    %generate forecast if requires and number of uniq cells
                    %exceeds min_fcst_cells
                    if options(12)==1
                        [t_nowcast_nl,t_nowcast_graph_nl]=storm_forecast2(cur_track_ident_ind,ident2kml,kml_dir,scan_region,oldest_time,newest_time,1,cur_r_id);
                        nowcast_nl=[nowcast_nl,t_nowcast_nl];
                        nowcast_graph_nl=[nowcast_graph_nl,t_nowcast_graph_nl];
                    end

                    %collate all track layer into a folder for this track
                    %!!! THIS DOUBLES TRACK LAYERS
                    %tracks_nl=ge_folder(tracks_nl,[t_cell_nl,t_path_nl,t_swath_nl,t_nowcast_nl,t_nowcast_graph_nl],['Track no: ',num2str(j),', size:',num2str(length(uniq_track_ident_ind))],'',1);
                end

                %collate track kmls into a folder !!! THIS DOUBLES TRACK LAYERS
                %tracks_nl=ge_folder('',tracks_nl,'Track Layers','',1);
            end
            %collate cell layer nl into folders
            vel_xsec_nl=ge_folder('',vel_xsec_nl,'Vel XSec Layers','',1);
            in_iso_nl=ge_folder('',in_iso_nl,'Inner Iso Layers','',1);
            out_iso_nl=ge_folder('',out_iso_nl,'Outer Iso Layers','',1);
            path_nl=ge_folder('',path_nl,'Path Layers','',1);
            swath_nl=ge_folder('',swath_nl,'Swath Layers','',1);
            nowcast_nl=ge_folder('',nowcast_nl,'Nowcast Layers','',1);
            nowcast_graph_nl=ge_folder('',nowcast_graph_nl,'Nowcast Graph Layers','',1);
            stats_nl=ge_folder('',stats_nl,'Stats Layers','',1);
        end
        
        %collate cappi layer nl into folders
        scan1_refl_nl=ge_folder('',scan1_refl_nl,'Scan1 Refl Layers','',1);
        scan1_vel_nl=ge_folder('',scan1_vel_nl,'Scan1 Vel Layers','',1);
        scan2_refl_nl=ge_folder('',scan2_refl_nl,'Scan2 Refl Layers','',1);
        scan2_vel_nl=ge_folder('',scan2_vel_nl,'Scan2 Vel Layers','',1);
        refl_xsec_nl=ge_folder('',refl_xsec_nl,'Refl XSec Layers','',1);
        
        
        %append
        site_nl=[scan1_refl_nl,scan1_vel_nl,scan2_refl_nl,scan2_vel_nl,refl_xsec_nl,vel_xsec_nl,in_iso_nl,out_iso_nl,path_nl,swath_nl,nowcast_nl,nowcast_graph_nl,stats_nl];%,tracks_nl];
        %save into master kml
        master_kml=ge_folder(master_kml,site_nl,['IDR',num2str(cur_r_id),' ',cur_r_name],'',1);
        
    end
    
    %output master kml nl to layer_links
    ge_kml_out([kml_dir,'layers_links'],'layers_links',master_kml);
end


function [refl_xsec_nl,vel_xsec_nl,outeriso_nl,inneriso_nl,stats_nl]=cell_nl_kml(ident2kml,intp_ref_td,intp_start_td,intp_stop_td,options)
%WHAT: Generated nl for cappi, outer iso, inner iso and cell stats objects
%(generated in cloud_objects) using adjusted timedates

%INPUT:
%ident2kml: %subset of ident_db, will generate kml nl for all objects in
%this.
%cur_r_id: current radar ID
%red_td: unmodified start timedate for filenames
%intp_start_td: modified start timedate of each intp obj
%intp_stop_td: modified stop timedate of each intp obj
%1: visibility of current radar
%options: cloud layer options (logical)

%OUTPUT:
%kml_out: network links for cloud objects

%load global config
load('tmp_global_config.mat');

%blank kml nl strings
refl_xsec_nl='';
vel_xsec_nl='';
outeriso_nl='';
outeriso_h_nl='';
outeriso_l_nl='';
inneriso_nl='';
inneriso_h_nl='';
inneriso_l_nl='';
stats_nl='';

%one cell for each level allowing for organisation
xsec_levels=options(15:end);
t_refl_xsec_nl=cell(length(xsec_levels),1);
t_vel_xsec_nl=cell(length(xsec_levels),1);

%% loop through elements
for i=1:length(ident2kml)
    
    cur_r_id=ident2kml(i).radar_id;
    %load latlonbox and start td
    subset_latlonbox=ident2kml(i).subset_latlonbox;
    subset_start_td=ident2kml(i).start_timedate;
    
    %load z vec
    %subset_z_vec=ident2kml(i).subset_z_asl_vec;
    
    %lookup adjusted time values
    time_ind=find(intp_ref_td==subset_start_td,1,'first');
    
    %if missing use ident stat/stop time
    if isempty(time_ind)
        temp_start_td=subset_start_td;
        temp_stop_td=ident2kml(i).stop_timedate;      
    else
        %use adjusted start stop time
        temp_start_td=intp_start_td(time_ind);
        temp_stop_td=intp_stop_td(time_ind);
    end
    
    %create subset tag
    subset_tag=['IDR',num2str(cur_r_id),'_',datestr(subset_start_td,'dd-mm-yyyy_HHMM'),'_cell_',num2str(ident2kml(i).subset_id)];
    
    %create regions
    subset_region_G=ge_region(subset_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels);
    subset_region_H=ge_region(subset_latlonbox,0,0,high_minLodPixels,high_maxLodPixels);
    subset_region_L=ge_region(subset_latlonbox,0,0,low_minLodPixels,low_maxLodPixels);
    
    %% create nl for cloud objects
    
    %TO DO: ADD LOOPS FOR DIFFERENT LEVELS OF REFL AND VEL DATA...
    
    %refl xsection
    if options(5)==1
        for k=1:length(xsec_levels)
            t_refl_xsec_nl{k}=ge_networklink(t_refl_xsec_nl{k},['refl_xsec_',num2str(xsec_levels(k)),'_',subset_tag],[ident_data_path,'refl_xsec_',num2str(xsec_levels(k)),'_',subset_tag,'.kmz'],0,0,'',subset_region_G,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
        end
    end
    %vel xsection
    if options(6)==1
        for k=1:length(xsec_levels)
            t_vel_xsec_nl{k}=ge_networklink(t_vel_xsec_nl{k},['vel_xsec_',num2str(xsec_levels(k)),'_',subset_tag],[ident_data_path,'vel_xsec_',num2str(xsec_levels(k)),'_',subset_tag,'.kmz'],0,0,'',subset_region_G,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
        end
    end
    %inneriso
    if options(7)==1
        inneriso_h_nl=ge_networklink(inneriso_h_nl,['inneriso_H_',subset_tag],[ident_data_path,'inneriso_H_',subset_tag,'.kmz'],0,0,'',subset_region_H,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
        inneriso_l_nl=ge_networklink(inneriso_l_nl,['inneriso_L_',subset_tag],[ident_data_path,'inneriso_L_',subset_tag,'.kmz'],0,0,'',subset_region_L,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
    end
    %outeriso
    if options(8)==1
        outeriso_h_nl=ge_networklink(outeriso_h_nl,['outeriso_H_',subset_tag],[ident_data_path,'outeriso_H_',subset_tag,'.kmz'],0,0,'',subset_region_H,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
        outeriso_l_nl=ge_networklink(outeriso_l_nl,['outeriso_L_',subset_tag],[ident_data_path,'outeriso_L_',subset_tag,'.kmz'],0,0,'',subset_region_L,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
    end
    %cellstats
    if options(9)==1
        stats_nl=ge_networklink(stats_nl,['celldata_',subset_tag],[ident_data_path,'celldata_',subset_tag,'.kml'],0,0,'',subset_region_G,datestr(temp_start_td,S),datestr(temp_stop_td,S),1);
    end
end

%% organise into folders
%Refl Xsec
if options(5)==1
    for k=1:length(xsec_levels)
        refl_xsec_nl=ge_folder(refl_xsec_nl,t_refl_xsec_nl{k},['Refl Xsec Level ',num2str(subset_z_vec(xsec_levels(k))),'m'],'',1);
    end
end
%Vel Xsec
if options(6)==1
    for k=1:length(xsec_levels)
        vel_xsec_nl=ge_folder(vel_xsec_nl,t_vel_xsec_nl{k},['Vel Xsec Level ',num2str(subset_z_vec(xsec_levels(k))),'m'],'',1);
    end
end
%inneriso folder
if options(7)==1
    inneriso_nl=[ge_folder('',inneriso_h_nl,'Inner H Iso features','',1),ge_folder('',inneriso_l_nl,'Inner L Iso features','',1)];
end
%outeriso folder
if options(8)==1
    outeriso_nl=[ge_folder('',outeriso_h_nl,'Outer H Iso features','',1),ge_folder('',outeriso_l_nl,'Outer L Iso features','',1)];
end
%cellstats folder
if options(9)==1
    stats_nl=ge_folder('',stats_nl,'Cell Stats features','',1);
end

function [db_start_td,db_stop_td,db_ref_td]=cts_timestamps(db,db_ind,newest_time,oldest_time)
%WHAT: (1) sets the start_time for objects to the previous objects stop
%time. (2) sets the start/stop time to new/old time if close to those
%values

%INPUT:
%db: either a intp_db or ident_db
%db_ind: indicies of objects
%newest/oldest time: upper/lower limits on time for the kml file

%OUPUT: Adjusted start, stop times and a reference original start time

        %% enfore continous timestamps
        %sort by time to enforce correct start-stop times
        [~,IX] = sort([db(db_ind).start_timedate]);
        db_ind=db_ind(IX);
        %decompose into start and stop times for each scan
        db_start_td=[db(db_ind).start_timedate];
        db_stop_td=[db(db_ind).stop_timedate];
        %keep an original copy of start_datetime to reference radar_objects       
        db_ref_td=db_start_td;
        %loop through each time element
        for j=1:length(db_ind)
            %adapt stop_time to next scan start_time if not at the last scan
            if j~=length(db_ind)
                db_stop_td(j)=db(db_ind(j+1)).start_timedate;
            end
            %adapt for oldest and newest time to times in function header
            
            %overlap
            if db_stop_td(j)>newest_time
                db_stop_td(j)=newest_time;
            end
            if db_start_td(j)<oldest_time
                db_start_td(j)=oldest_time;
            end
            % stretch to oldest and newest if near the edge
            if j==length(db_ind) && abs(newest_time-db_stop_td(j))<addtodate(0,15,'minute')
                db_stop_td(j)=newest_time;
            end            
            if j==1 && abs(oldest_time-db_start_td(j))<addtodate(0,15,'minute')
                db_start_td(j)=oldest_time;
            end
        end
