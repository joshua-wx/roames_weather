function merged_track_db=merge_daily_tracks(cated_track_db,cated_ident_db)
%WHAT: finds any nn (time and space) between daily track_dbs. tracks which
%satisfy this criteria are merged and and remaining tracks are collated.

%INPUT:
%cated_track_db: output of cat_db for track_db objects
%arch_dir: archive directory of mat objects

%OUTPUT:
%merged_track_db: modified cated_track_db containing merged tracks

load('tmp_global_config.mat');

%load inital track for merge test
merged_track_db=cated_track_db{1};
%look up info on end storms
try
[m_ind,merged_end_storm_ind,merged_end_latloncent,merged_radar_id]=track_info(merged_track_db,cated_ident_db,'end',track_merge_t_offset);
catch err
    keyboard
end
%loop for 2 onwards
for i=2:length(cated_track_db)
    %load current track_db
    curr_track_db=cated_track_db{i};
    
    if isempty(curr_track_db)
        continue
    end  
        
    %compute start stats on current tracks
    [c_ind,curr_start_storm_ind,curr_start_latloncent,curr_radar_id]=track_info(curr_track_db,cated_ident_db,'start',track_merge_t_offset);
    %loop through each end cell in merge track_db
    for j=1:length(merged_end_storm_ind)
        %calc distance between current merge_track_db end cell and
        %curr_track_db start cell
        if isempty(c_ind)
        	break
        end
        [rng,~]=distance(merged_end_latloncent(j,1),merged_end_latloncent(j,2),curr_start_latloncent(:,1),curr_start_latloncent(:,2));

        dist=deg2km(rng);
        %use dist and radar_id for nn analysis
        curr_nn=find(dist<merge_nn_dist & merged_radar_id(j)==curr_radar_id);
        if ~isempty(curr_nn)
            %merge nn storms into merged_track_db
            
            %build temp track containing [past cell id, curr cell id, past cell start_timedate, curr cell stop_timedate, past cell radar id            
            temp_track=[repmat(cellstr(cated_ident_db(m_ind(j))),length(curr_nn),1),{cated_ident_db(c_ind(curr_nn)).ident_id}',repmat({cated_ident_db(m_ind(j)).start_timedate},length(curr_nn),1),{cated_ident_db(c_ind(curr_nn)).stop_timedate}',{cated_ident_db(c_ind(curr_nn)).radar_id}'];
            
            %generate unique ind of storms for merging
            uniq_storm_merge=unique(curr_start_storm_ind(curr_nn));  
            
            %append current merged storm with temp track with nn current
            %tracks
            merged_track_db{merged_end_storm_ind(j)}=[merged_track_db{merged_end_storm_ind(j)};temp_track;vertcat(curr_track_db{uniq_storm_merge})];
            
            %clear this storms from curr_track_db
            curr_track_db(uniq_storm_merge)=[];
            %recalc info for curr_track_db
            [c_ind,curr_start_storm_ind,curr_start_latloncent,curr_radar_id]=track_info(curr_track_db,cated_ident_db,'start',track_merge_t_offset);
        end
    end
    %merge remaining tracks in curr_track_db into merged_tracks_db
    merged_track_db=[merged_track_db,curr_track_db];
    %recalc info for merged_tracks_db
    [m_ind,merged_end_storm_ind,merged_end_latloncent,merged_radar_id]=track_info(merged_track_db,cated_ident_db,'end',track_merge_t_offset);
end


function [cell_ind,storm_ind,latloncent,radar_id]=track_info(track_db,cated_ident_db,option,track_merge_t_offset)
%WHAT: searches track_db for start/end cells of tracks towards the start/end
%of the day. outputs their storm ind, timedate and latloncent.

%INPUT:
%track_db
%arch_dir: path to processed data
%option (start/end)

%OUTPUT:
%storm_ind: index of end/start storm
%timedate: start/end time of first/last cell
%latloncent: centroid of first/last cell

try

cell_ind=[];
storm_ind=[];
latloncent=[];
radar_id=[];

if isempty(track_db)
   return 
end

%decompose track db
init_id={};
finl_id={};
storm_ind=[];
for j=1:length(track_db)
    init_id   =[init_id;track_db{j}(:,1)];
    finl_id   =[finl_id;track_db{j}(:,2)];
    storm_ind =[storm_ind;repmat(j,length(track_db{j}(:,1)),1)];
end

%find final cells using intersection between init and finl pairs, apply
%this to find start of end storm cells.
%filter timedate to remove enties not an last/first 20min of the day
if strcmp(option,'start')
    [init_id_uniq,uniq_ind,~]=unique(init_id);
    storm_ind_uniq=storm_ind(uniq_ind);
    intersection =~ismember(init_id_uniq,finl_id); %enforce uniqueness
    cell_id      =init_id_uniq(intersection);
    cell_ind     =find_db_ind(cell_id,{cated_ident_db.ident_id},1);
    storm_ind    =storm_ind_uniq(intersection);
    latloncent   =vertcat(cated_ident_db(cell_ind).subset_latloncent);
    timedate     =vertcat(cated_ident_db(cell_ind).start_timedate);
    radar_id     =vertcat(cated_ident_db(cell_ind).radar_id);
    
    try
    date_num=floor(timedate(1));
    catch
        keyboard
    end
    cutoff_time  =addtodate(date_num,track_merge_t_offset,'min');
    ind=find(timedate<cutoff_time);
    storm_ind=storm_ind(ind); latloncent=latloncent(ind,:); cell_ind=cell_ind(ind); radar_id=radar_id(ind);
    
elseif strcmp(option,'end')
    [finl_id_uniq,uniq_ind,~]=unique(finl_id);
    storm_ind_uniq=storm_ind(uniq_ind);
    intersection   =~ismember(finl_id_uniq,init_id); %enforce uniqueness
    cell_id        =finl_id_uniq(intersection);
    cell_ind       =find_db_ind(cell_id,{cated_ident_db.ident_id},1);
    
    storm_ind      =storm_ind_uniq(intersection);

    latloncent =vertcat(cated_ident_db(cell_ind).subset_latloncent);
    
    timedate       =vertcat(cated_ident_db(cell_ind).start_timedate);
    radar_id       =vertcat(cated_ident_db(cell_ind).radar_id);
    
    date_num=floor(timedate(1));
    cutoff_time  =addtodate(date_num+1,-track_merge_t_offset,'min');
    ind=find(timedate>cutoff_time);
    storm_ind=storm_ind(ind); latloncent=latloncent(ind,:); cell_ind=cell_ind(ind); radar_id=radar_id(ind);
end

catch err
    rethrow(err)
    keyboard
end