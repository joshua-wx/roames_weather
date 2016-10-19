function update_kml_4(odimh5_jstruct,storm_jstruct,dest_root,options,oldest_time,newest_time)
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
load('tmp/interp_cmaps.mat')
load('tmp/global.config.mat')
load('tmp/site_info.txt.mat')
load('tmp/kml.config.mat')

master_kml = '';

%check if targets exist
if ~isempty(odimh5_jstruct)
    
    %generate unique list of radar ids for targets
    vol_radar_id            = jstruct_to_mat([odimh5_jstruct.radar_id],'N');
    vol_start_td            = datenum(jstruct_to_mat([odimh5_jstruct.start_timestamp],'S'),ddb_tfmt);
    vol_latlonbox           = str2num(odimh5_jstruct(1).img_latlonbox.S)./geo_scale; %only need to get first entry, never changes!
    unique_radar_id         = unique(vol_radar_id);
    
    %loop through uniq site numbers
    for i=1:length(unique_radar_id)
       
        %select current radar id and name
        cur_radar_id   = unique_radar_id(i);
        cur_radar_name = site_s_name_list{site_id_list==cur_radar_id};
        cur_radar_alt  = site_elv_list(site_id_list==cur_radar_id);

        %kml string for objects
        scan1_refl_nl    = '';
        scan2_refl_nl    = '';
        scan1_vel_nl     = '';
        scan2_vel_nl     = '';
        refl_xsec_nl     = '';
        vel_xsec_nl      = '';
        in_iso_nl        = '';
        out_iso_nl       = '';
        path_nl          = '';
        swath_nl         = '';
        nowcast_nl       = '';
        nowcast_graph_nl = '';
        stats_nl         = '';
                        
        %lookup intp targets from this radar id
        vol_idx     = find(vol_radar_id == cur_radar_id);
        % create timestamps
        [vol_stop_td,vol_mode_int] = create_stop_td(vol_start_td);
        %generate region data (used for other objects)
        scan_region = ge_region(vol_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels); %only need to generate once since radar site is not changing
        
        %% Generate networklink kml for scan elev's 1&2 for refl and vel data
        temp_a = ''; temp_b = ''; temp_c = ''; temp_d = '';
        for j=1:length(odimh5_jstruct)
            %generate nl kml
            scan_tag = [num2str(vol_radar_id(j),'%02.0f'),'_',datestr(vol_start_td(j),r_tfmt)];
            if options(1)==1;
                temp_a = ge_networklink(temp_a,[scan_tag,'.scan1_refl'],[vol_data_path,scan_tag,'.scan1_refl.kmz'],...
                    0,0,'',scan_region,datestr(vol_start_td(j),ge_tfmt),datestr(vol_stop_td(j),ge_tfmt),1); end
            if options(2)==1;
                temp_b = ge_networklink(temp_b,[scan_tag,'.scan2_refl'],[vol_data_path,scan_tag,'.scan2_refl.kmz'],...
                    0,0,'',scan_region,datestr(vol_start_td(j),ge_tfmt),datestr(vol_stop_td(j),ge_tfmt),1); end
            if options(3)==1;
                temp_c = ge_networklink(temp_c,[scan_tag,'.scan1_vel'],[vol_data_path,scan_tag,'.scan1_vel.kmz'],...
                    0,0,'',scan_region,datestr(vol_start_td(j),ge_tfmt),datestr(vol_stop_td(j),ge_tfmt),1); end
            if options(4)==1;
                temp_d = ge_networklink(temp_d,[scan_tag,'.scan2_vel'],[vol_data_path,scan_tag,'.scan2_vel.kmz'],...
                    0,0,'',scan_region,datestr(vol_start_td(j),ge_tfmt),datestr(vol_stop_td(j),ge_tfmt),1); end
        end
        %place scans in a folder
        scan1_refl_nl = ge_folder(scan1_refl_nl,temp_a,'Scan 1 Refl','',1);
        scan2_refl_nl = ge_folder(scan2_refl_nl,temp_b,'Scan 2 Refl','',1);
        scan1_vel_nl  = ge_folder(scan1_vel_nl,temp_c,'Scan 1 Vel','',1);
        scan2_vel_nl  = ge_folder(scan2_vel_nl,temp_d,'Scan 2 Vel','',1);
        
        %% Generate cell object kml
        
        if ~isempty(storm_jstruct)

            %index of all ident entires for current radar
            storm_radar_id = jstruct_to_mat([storm_jstruct.radar_id],'N');
            storm_idx      = find(storm_radar_id==cur_radar_id);
            storm_track_id = jstruct_to_mat([storm_jstruct.track_id],'N');

            %generate nl kml for all objects
            if ~isempty(storm_idx)
                %generate kml for ident objects created in cloud_objects3
                [refl_xsec_nl,vel_xsec_nl,out_iso_nl,in_iso_nl,stats_nl] = cell_nl_kml(storm_jstruct(storm_idx),vol_start_td,vol_stop_td,vol_mode_int,cur_radar_alt,options);
                
                %list unique simple if from ident_idx
                
                [uniq_track_id,~,ic] = unique(storm_track_id);
                
                %loop through each track for cur radar id
                for j=1:length(uniq_track_id)
                    %skip track 0 (null track)
                    if uniq_track_id(j)==0
                        continue
                    end
                    %load index for cells in curr track
                    cur_track_idx = storm_idx(ic==j);
                    %skip short tracks
                    if length(cur_track_idx)<min_track_cells
                        continue
                    end
                    %find index for ident2kml for init and finl entries
                    init_storm_idx = cur_track_idx(1:end-1);
                    finl_storm_idx = cur_track_idx(2:end);
                    %find uniq ident ind for the current track
                    cur_track_id   = num2str(uniq_track_id(j));


                    %                     %generate kml for cell layers
                    %                     try
                    %                     [t_refl_xsec_nl,t_vel_xsec_nl,t_out_iso_nl,t_in_iso_nl,t_stats_nl]=cell_nl_kml(ident2kml(uniq_track_ident_ind),intp_ref_td,intp_start_td,intp_stop_td,options);
                    %                     catch
                    %                         keyboard
                    %                     end
                    %                     t_cell_nl=[t_refl_xsec_nl,t_vel_xsec_nl,t_out_iso_nl,t_in_iso_nl,t_stats_nl];

                    %path kml and nl
                    t_path_nl = '';
                    if options(10)==1
                        t_path_nl = storm_path(storm_jstruct(init_storm_idx),storm_jstruct(finl_storm_idx),dest_root,cur_track_id,scan_region,oldest_time,newest_time,1);
                        path_nl   = [path_nl,t_path_nl];
                    end
                    %swath kml and nl
                    t_swath_nl = '';
                    if options(11)==1
                        t_swath_nl = storm_swath3(storm_jstruct(init_storm_idx),storm_jstruct(finl_storm_idx),dest_root,cur_track_id,scan_region,oldest_time,newest_time,1);
                        swath_nl   = [swath_nl,t_swath_nl];
                    end
 
                     t_nowcast_nl       = '';
                     t_nowcast_graph_nl = '';
                     %generate forecast if requires and number of uniq cells
                     %exceeds min_fcst_cells
                     if options(12)==1
                         [t_nowcast_nl,t_nowcast_graph_nl] = storm_nowcast_kml_wrap(cur_track_idx,storm_jstruct,dest_root,scan_region,oldest_time,newest_time,1,cur_radar_id);
                         nowcast_nl                        = [nowcast_nl,t_nowcast_nl];
                         nowcast_graph_nl                  = [nowcast_graph_nl,t_nowcast_graph_nl];
                     end

                    %collate all track layer into a folder for this track
                    %!!! THIS DOUBLES TRACK LAYERS
                    %tracks_nl=ge_folder(tracks_nl,[t_cell_nl,t_path_nl,t_swath_nl,t_nowcast_nl,t_nowcast_graph_nl],['Track no: ',num2str(j),', size:',num2str(length(uniq_track_ident_ind))],'',1);
                end

                %collate track kmls into a folder !!! THIS DOUBLES TRACK LAYERS
                %tracks_nl=ge_folder('',tracks_nl,'Track Layers','',1);
            end
            %collate cell layer nl into folders
            vel_xsec_nl      = ge_folder('',vel_xsec_nl,'Vel XSec Layers','',1);
            in_iso_nl        = ge_folder('',in_iso_nl,'Inner Iso Layers','',1);
            out_iso_nl       = ge_folder('',out_iso_nl,'Outer Iso Layers','',1);
            path_nl          = ge_folder('',path_nl,'Path Layers','',1);
            swath_nl         = ge_folder('',swath_nl,'Swath Layers','',1);
            nowcast_nl       = ge_folder('',nowcast_nl,'Nowcast Layers','',1);
            nowcast_graph_nl = ge_folder('',nowcast_graph_nl,'Nowcast Graph Layers','',1);
            stats_nl         = ge_folder('',stats_nl,'Stats Layers','',1);
        end
        
        %collate cappi layer nl into folders
        scan1_refl_nl = ge_folder('',scan1_refl_nl,'Scan1 Refl Layers','',1);
        scan1_vel_nl  = ge_folder('',scan1_vel_nl,'Scan1 Vel Layers','',1);
        scan2_refl_nl = ge_folder('',scan2_refl_nl,'Scan2 Refl Layers','',1);
        scan2_vel_nl  = ge_folder('',scan2_vel_nl,'Scan2 Vel Layers','',1);
        refl_xsec_nl  = ge_folder('',refl_xsec_nl,'Refl XSec Layers','',1);
        
        
        %append
        site_nl = [scan1_refl_nl,scan1_vel_nl,scan2_refl_nl,scan2_vel_nl,refl_xsec_nl,vel_xsec_nl,in_iso_nl,out_iso_nl,path_nl,swath_nl,nowcast_nl,nowcast_graph_nl,stats_nl];%,tracks_nl];
        %save into master kml
        master_kml = ge_folder(master_kml,site_nl,[num2str(cur_radar_id,'%02.0f'),' ',cur_radar_name],'',1);
        
    end
    
    %output master kml nl to layer_links
    ge_kml_out([dest_root,'layers_links'],'layers_links',master_kml);
end


function [refl_xsec_nl,vel_xsec_nl,outeriso_nl,inneriso_nl,stats_nl] = cell_nl_kml(storm_jstruct,vol_start_td,vol_stop_td,vol_mode_int,cur_radar_alt,options)
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
load('tmp/global.config.mat')
load('tmp/kml.config.mat')

%blank kml nl strings
refl_xsec_nl  = '';
vel_xsec_nl   = '';
outeriso_nl   = '';
outeriso_h_nl = '';
outeriso_l_nl = '';
inneriso_nl   = '';
inneriso_h_nl = '';
inneriso_l_nl = '';
stats_nl      = '';

%one cell for each level allowing for organisation
t_refl_xsec_nl = cell(length(xsec_levels),1);
t_vel_xsec_nl  = cell(length(xsec_levels),1);
vol_amsl_vec   = [v_grid:v_grid:v_range]'+cur_radar_alt;
%% loop through elements
for i=1:length(storm_jstruct)
    
    %load storm atts
    storm_radar_id  = str2num(storm_jstruct(i).radar_id.N);
    storm_latlonbox = str2num(storm_jstruct(i).storm_latlonbox.S)./geo_scale;
    storm_start_td  = datenum(storm_jstruct(i).start_timestamp.S,ddb_tfmt);
    storm_id        = storm_jstruct(i).subset_id.S;
    storm_tag       = [num2str(storm_radar_id,'%02.0f'),'_',datestr(storm_start_td,r_tfmt),'_',storm_id(end-2:end)];

    %lookup adjusted time values
    vol_td_idx = find(vol_start_td==storm_start_td,1,'first');
    
    %if missing use ident stat/stop time
    if isempty(vol_td_idx)
        tmp_start_td = storm_start_td;
        tmp_stop_td  = addtodate(storm_start_td,vol_mode_int,'minute');    
    else
        %use adjusted start stop time
        tmp_start_td = vol_start_td(vol_td_idx);
        tmp_stop_td  = vol_stop_td(vol_td_idx);
    end

    %create regions
    subset_region_G = ge_region(storm_latlonbox,0,0,overlay_minLodPixels,overlay_maxLodPixels);
    subset_region_H = ge_region(storm_latlonbox,0,0,high_minLodPixels,high_maxLodPixels);
    subset_region_L = ge_region(storm_latlonbox,0,0,low_minLodPixels,low_maxLodPixels);
    
    %% create nl for cloud objects
    
    %TO DO: ADD LOOPS FOR DIFFERENT LEVELS OF REFL AND VEL DATA...
    
    %refl xsection
    if options(5) == 1
        for k=1:length(xsec_levels)
            t_refl_xsec_nl{k} = ge_networklink(t_refl_xsec_nl{k},['refl_xsec_',num2str(xsec_levels(k)),'_',storm_tag],...
                [storm_data_path,'refl_xsec_',num2str(xsec_levels(k)),'_',storm_tag,'.kmz'],0,0,'',subset_region_G,...
                datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
        end
    end
    %vel xsection
    if options(6) == 1
        for k=1:length(xsec_levels)
            t_vel_xsec_nl{k} = ge_networklink(t_vel_xsec_nl{k},['vel_xsec_',num2str(xsec_levels(k)),'_',storm_tag],...
                [storm_data_path,'vel_xsec_',num2str(xsec_levels(k)),'_',storm_tag,'.kmz'],0,0,'',subset_region_G,...
                datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
        end
    end
    %inneriso
    if options(7) == 1
        inneriso_h_nl = ge_networklink(inneriso_h_nl,['inneriso_H_',storm_tag],[storm_data_path,'inneriso_H_',storm_tag,'.kmz'],...
            0,0,'',subset_region_H,datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
        inneriso_l_nl = ge_networklink(inneriso_l_nl,['inneriso_L_',storm_tag],[storm_data_path,'inneriso_L_',storm_tag,'.kmz'],...
            0,0,'',subset_region_L,datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
    end
    %outeriso
    if options(8) == 1
        outeriso_h_nl = ge_networklink(outeriso_h_nl,['outeriso_H_',storm_tag],[storm_data_path,'outeriso_H_',storm_tag,'.kmz'],...
            0,0,'',subset_region_H,datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
        outeriso_l_nl = ge_networklink(outeriso_l_nl,['outeriso_L_',storm_tag],[storm_data_path,'outeriso_L_',storm_tag,'.kmz'],...
            0,0,'',subset_region_L,datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
    end
    %cellstats
    if options(9) == 1
        stats_nl=ge_networklink(stats_nl,['celldata_',storm_tag],[storm_data_path,'celldata_',storm_tag,'.kml'],...
            0,0,'',subset_region_G,datestr(tmp_start_td,ge_tfmt),datestr(tmp_stop_td,ge_tfmt),1);
    end
end

%% organise into folders
%Refl Xsec
if options(5) == 1
    for k=1:length(xsec_levels)
        refl_xsec_nl = ge_folder(refl_xsec_nl,t_refl_xsec_nl{k},['Refl Xsec Level ',num2str(vol_amsl_vec(xsec_levels(k))),'m'],'',1);
    end
end
%Vel Xsec
if options(6) == 1
    for k=1:length(xsec_levels)
        vel_xsec_nl = ge_folder(vel_xsec_nl,t_vel_xsec_nl{k},['Vel Xsec Level ',num2str(vol_amsl_vec(xsec_levels(k))),'m'],'',1);
    end
end
%inneriso folder
if options(7) == 1
    inneriso_nl = [ge_folder('',inneriso_h_nl,'Inner H Iso features','',1),ge_folder('',inneriso_l_nl,'Inner L Iso features','',1)];
end
%outeriso folder
if options(8) == 1
    outeriso_nl = [ge_folder('',outeriso_h_nl,'Outer H Iso features','',1),ge_folder('',outeriso_l_nl,'Outer L Iso features','',1)];
end
%cellstats folder
if options(9) == 1
    stats_nl = ge_folder('',stats_nl,'Cell Stats features','',1);
end


function [stop_td,mode_diff_min] = create_stop_td(start_td)
%create stop_td from start_td vector

%only single value, default to 6min
if length(start_td)==1
    stop_td       = addtodate(start_td,'minute',6);
    mode_diff_min = 6;
    return
end

%loop for vector!
stop_td = zeros(length(start_td),1);
for j=1:length(start_td)
    if j ~= length(start_td)
        %set stop to next start_td
        stop_td(j) = start_td(j+1);
    else
        %set final stop to mode minute diff
        mode_diff_min = mode(minute(start_td(2:end)-start_td(1:end-1)));
        stop_td(j)    = addtodate(start_td(j),mode_diff_min,'minute');
    end
end