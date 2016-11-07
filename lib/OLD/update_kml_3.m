function update_kml_3(intp2kml,ident2kml,track2kml,kml_dir,options,oldest_time,newest_time)
%WHAT: Generates the nt_kml link and track kml and links using the three
%input databases. The network links are structured into folders in an optimised way.

%INPUT:
%intp2kml: subset of intp_db for updating the kml
%ident2kml: subset of ident_db for updating the kml
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
load('../config_files/colormap.mat');
load('site_info.mat')
master_kml='';

%check if targets exist
if ~isempty(intp2kml)
    
    %generate unique list of radar ids for targets
    unique_r_id=unique([intp2kml.radar_id]);
    
    %determine mode radar id for each track
    track_r_id=[];
    for i=1:length(track2kml)
        track_r_id=[track_r_id;[track2kml{i}{1,5}]];
    end
    
    %loop through uniq site numbers
    for i=1:length(unique_r_id)
        
        %select current radar id and name
        cur_r_id=unique_r_id(i);
        cur_r_name=site_s_name_list{site_id_list==cur_r_id};
        
        %set priority visibility
        if options(13)==1
            cur_vis=site_priority(site_id_list==cur_r_id); else cur_vis=1;
        end
        
        %kml string for type organised objects
        scan1_refl_nl='';
        scan2_refl_nl='';
        scan1_vel_nl='';
        scan2_vel_nl='';
        tracks_nl='';
        refl_xsec_nl='';
        vel_xsec_nl='';
        in_iso_nl='';
        out_iso_nl='';
        path_nl='';
        swath_nl='';
        nowcast_nl='';
        stats_nl='';
        
        
        
        %lookup intp targets from this radar id
        intp_ind=find([intp2kml.radar_id]==cur_r_id);
        % enfore continous timestamps
        [intp_start_td,intp_stop_td,intp_ref_td]=cts_timestamps(intp2kml,intp_ind,newest_time,oldest_time);
        %generate region data (used for other objects)
        scan_region=ge_region(intp2kml(intp_ind(1)).region_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels); %only need to generate once since radar site is not changing
        scan_tag=['IDR',num2str(cur_r_id),'_',datestr(intp_ref_td(j),'dd-mm-yyyy_HHMM')];
        
        %% scan1 refl nl
        if options(1)==1
            temp_nl='';
            for j=1:length(intp_ind)
                %generate scan1 nl kml
                temp_nl=ge_networklink(temp_nl,['scan1_refl_',scan_tag],[ident_data_path,'scan1_refl_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),cur_vis);
            end
            %place scans in a folder
            scan1_refl_nl=ge_folder(scan1_refl_nl,temp_nl,'Scan 1 Refl','',cur_vis);
        end
        
        %% scan2 refl nl
        if options(2)==1
            temp_nl='';
            for j=1:length(intp_ind)
                %generate scan1 nl kml
                temp_nl=ge_networklink(temp_nl,['scan2_refl_',scan_tag],[ident_data_path,'scan2_refl_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),cur_vis);
            end
            %place scans in a folder
            scan2_refl_nl=ge_folder(scan2_refl_nl,temp_nl,'Scan 2 Refl','',cur_vis);
        end
        
        %% scan1 vel nl
        if options(3)==1
            temp_nl='';
            for j=1:length(intp_ind)
                %generate scan1 nl kml
                temp_nl=ge_networklink(temp_nl,['scan1_vel_',scan_tag],[ident_data_path,'scan1_vel_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),cur_vis);
            end
            %place all sscans for this radar in a folder in master kml
            scan1_vel_nl=ge_folder(scan1_vel_nl,temp_nl,'Scan 1 Vel','',cur_vis);
        end
        
        %% scan2 vel nl
        if options(4)==1
            temp_nl='';
            for j=1:length(intp_ind)
                %generate scan1 nl kml
                temp_nl=ge_networklink(temp_nl,['scan2_vel_',scan_tag],[ident_data_path,'scan2_vel_',scan_tag,'.kmz'],0,0,'',scan_region,datestr(intp_start_td(j),S),datestr(intp_stop_td(j),S),cur_vis);
            end
            %place all sscans for this radar in a folder in master kml
            scan2_vel_nl=ge_folder(scan2_vel_nl,temp_nl,'Scan 2 Vel','',cur_vis);
        end
                
        %% ADD TYPE AND RADAR NL below and check options... and make it simplier??????? soooooo complex.......
        %% REMOVE MASTER KML in line 22 and replace with radar_nl?
        
        
        %% tracks objects
        %check if track targets exist
        if ~isempty(track2kml)
            %find track_r_id (mode) which are the same as the curr radar id 
            track_ind=find(track_r_id==cur_r_id);
            %reset nl string for each track
            single_tracks_nl='';
            %loop through each track which shares the same radar id
            for j=1:length(track_ind)
                %load curr track
                cur_track=track2kml{track_ind(j)};
                %find index for ident2kml for init and finl entries in curr
                %track
                init_ident_ind=find_db_ind(cur_track(:,1),{ident2kml.ident_id},1);
                finl_ident_ind=find_db_ind(cur_track(:,2),{ident2kml.ident_id},1);
                %find uni ident ind for the curr track
                uniq_track_ident_ind=unique([init_ident_ind;finl_ident_ind]);
                
                %skip track layers if number of uniq cells is less than
                %min_track_cells, but retain ind for nt track kml generation
                if length(uniq_track_ident_ind)<min_track_cells
                    nt_ident_ind=[nt_ident_ind;uniq_track_ident_ind];
                    continue
                end
                
                %generate cell/cappi nl for the cell index values from
                %ident
                track_cell_nl=cell_nl_kml(ident2kml(uniq_track_ident_ind),intp_ref_td,intp_start_td,intp_stop_td,cur_vis,options);
                stm_id=['IDR',num2str(cur_r_id),'_stm_',num2str(j)];
                %track path kml and nl
                path_nl='';
                if options(6)==1
                    path_nl=storm_path(ident2kml(init_ident_ind),ident2kml(finl_ident_ind),kml_dir,stm_id,sscan_region,oldest_time,newest_time,cur_vis);
                end
                
                %swath kml and nl
                swaths_nl='';
                if options(7)==1
                    swaths_nl=storm_swath3(ident2kml(init_ident_ind),ident2kml(finl_ident_ind),kml_dir,stm_id,sscan_region,oldest_time,newest_time,cur_vis);
                end               
                
                %generate forecast if requires and number of uniq cells
                %exceeds min_fcst_cells
                if length(uniq_track_ident_ind)>=min_track_cells && options(8)==1
                    [fcst_nl,fcst_graph_nl]=storm_forecast2(cur_track,ident2kml,kml_dir,sscan_region,oldest_time,newest_time,cur_vis);
                else
                    fcst_nl=''; fcst_graph_nl='';
                end
                
                %collate track nl kml into a folder for this track
                single_tracks_nl=ge_folder(single_tracks_nl,[track_cell_nl,path_nl,swaths_nl,fcst_nl,fcst_graph_nl],['Track no: ',num2str(j),', size:',num2str(length(uniq_track_ident_ind))],'',cur_vis);
            end
            
        %collate track kmls into a folder
        all_tracks_nl=ge_folder('',single_tracks_nl,'Track Layers','',cur_vis);
        end
        
        %% nt cell nl
        nt_cell_nl='';
        if ~isempty(ident2kml)
            %append no track cells into nt_ident_ind using tracked variable
            nt_ident_ind=[nt_ident_ind;find([ident2kml.radar_id]==cur_r_id & [ident2kml.tracked]==0)'];
            %generate cell/cappi nl for the nt_ident_ind index values from ident
            nt_cell_nl=cell_nl_kml(ident2kml(nt_ident_ind),intp_ref_td,intp_start_td,intp_stop_td,cur_vis,options);
        end
        %% collate
        %nt nl (sscan and nt cells)
        nt_cell_nl=ge_folder('',nt_cell_nl,'No Track Cells','',cur_vis);
        all_nt_nl=ge_folder('',[nt_cell_nl,sscan_nl,scan2_nl],'No Track Layers','',cur_vis);
        
        %tracks and nt nl into a master kml
        master_kml=ge_folder(master_kml,[all_tracks_nl,all_nt_nl],['IDR',num2str(cur_r_id),' ',cur_r_name],'',cur_vis);
    end
    
    %output master kml nl to layer_links
    ge_kml_out([kml_dir,'layers_links'],'layers_links',master_kml);
end


function kml_out=cell_nl_kml(ident2kml,intp_ref_td,intp_start_td,intp_stop_td,cur_vis,options)
%WHAT: Generated nl for cappi, outer iso, inner iso and cell stats objects
%(generated in cloud_objects) using adjusted timedates

%INPUT:
%ident2kml: %subset of ident_db, will generate kml nl for all objects in
%this.
%cur_r_id: current radar ID
%red_td: unmodified start timedate for filenames
%intp_start_td: modified start timedate of each intp obj
%intp_stop_td: modified stop timedate of each intp obj
%cur_vis: visibility of current radar
%options: cloud layer options (logical)

%OUTPUT:
%kml_out: network links for cloud objects

%load global config
load('tmp_global_config.mat');

%blank kml nl strings
kml_out='';
cappi_links_kml='';
outeriso_H_links_kml='';
outeriso_L_links_kml='';
inneriso_H_links_kml='';
inneriso_L_links_kml='';
cellstats_kml='';

%% loop through elements
for i=1:length(ident2kml)
    
    cur_r_id=ident2kml(i).radar_id;
    %load ident_struct
    ident_struct=mat_wrapper(ident2kml(i).subv_ln,'ident_struct');
    
    %lookup adjusted time values
    subset_start_td=ident2kml(i).start_timedate;
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
    
    %create tag
    subset_id=ident2kml(i).subset_id;    
    subset_tag=['IDR',num2str(cur_r_id),'_cell',num2str(subset_id),'_',datestr(subset_start_td,'dd-mm-yyyy_HHMM')];
    
    %create regions
    subset_region_G=ge_region(ident_struct.subset_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels);
    subset_region_H=ge_region(ident_struct.subset_latlonbox,0,0,high_minLodPixels,high_maxLodPixels);
    subset_region_L=ge_region(ident_struct.subset_latlonbox,0,0,low_minLodPixels,low_maxLodPixels);
    
    %% create nl for cloud objects
    %cappi
    if options(2)==1
        cappi_links_kml=ge_networklink(cappi_links_kml,['cappi_',subset_tag],[ident_data_path,'cappi_',subset_tag,'.kmz'],0,0,'',subset_region_G,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
    end
    %inneriso
    if options(3)==1
        inneriso_H_links_kml=ge_networklink(inneriso_H_links_kml,['inneriso_H_',subset_tag],[ident_data_path,'inneriso_H_',subset_tag,'.kmz'],0,0,'',subset_region_H,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
        inneriso_L_links_kml=ge_networklink(inneriso_L_links_kml,['inneriso_L_',subset_tag],[ident_data_path,'inneriso_L_',subset_tag,'.kmz'],0,0,'',subset_region_L,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
    end
    %outeriso
    if options(4)==1
        outeriso_H_links_kml=ge_networklink(outeriso_H_links_kml,['outeriso_H_',subset_tag],[ident_data_path,'outeriso_H_',subset_tag,'.kmz'],0,0,'',subset_region_H,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
        outeriso_L_links_kml=ge_networklink(outeriso_L_links_kml,['outeriso_L_',subset_tag],[ident_data_path,'outeriso_L_',subset_tag,'.kmz'],0,0,'',subset_region_L,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
    end
    %cellstats
    if options(5)==1
        cellstats_kml=ge_networklink(cellstats_kml,['celldata_',subset_tag],[ident_data_path,'celldata_',subset_tag,'.kml'],0,0,'',subset_region_G,datestr(temp_start_td,S),datestr(temp_stop_td,S),cur_vis);
    end
end

%% organise into folders
%cappi folder
cappi_links_folder='';
if options(2)==1
    cappi_links_folder=ge_folder('',cappi_links_kml,'Cappi features','',cur_vis);
end
%inneriso folder
inneriso_links_folder='';
if options(3)==1
    inneriso_links_folder=[ge_folder('',inneriso_H_links_kml,'Inner H Iso features','',cur_vis),ge_folder('',inneriso_L_links_kml,'Inner L Iso features','',cur_vis)];
end
%outeriso folder
outeriso_links_folder='';
if options(4)==1
    outeriso_links_folder=[ge_folder('',outeriso_H_links_kml,'Outer H Iso features','',cur_vis),ge_folder('',outeriso_L_links_kml,'Outer L Iso features','',cur_vis)];
end
%cellstats folder
cellstats_links_folder='';
if options(5)==1
    cellstats_links_folder=ge_folder('',cellstats_kml,'Cell Stats features','',cur_vis);
end
%cat to output kml_out
kml_out=[cappi_links_folder,outeriso_links_folder,inneriso_links_folder,cellstats_links_folder];

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