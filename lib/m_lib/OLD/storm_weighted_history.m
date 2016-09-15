function [hist_dist,hist_az_x,hist_az_y,hist_stats,hist_min,hist_end_td]=storm_weighted_history(track_db,ident_db,nn_cell_ind,nn_storm_ind)
%WHAT: Compiles a list of weighted storm parameters for each track for each timestamp (weights
%multiple cells for one timestamp)

%INPUT:
%track_db: track_db containing all tracks
%ident_db: ident_db containing all cells
%nn_cell_ind: target end cells
%nn_storm_ind: assocaited track containing the target cells

%OUTPUT:
%hist_dist: weighted distance from end_cell
%hist_az_x: weighted x component of the azimuth between timestamps
%hist_az_y: weighted y component of the azimuth between timestamps
%hist_stats: weighted stats
%hist_min: time since end cell
%hist_end_td: end cell timedate

%blank vars
hist_dist     = [];
hist_az_x     = [];
hist_az_y     = [];
hist_stats    = [];
hist_min      = [];
hist_end_td   = [];

%loop through each end cell
for i=1:length(nn_cell_ind);
    
    %decompose end cell track
    init_ind         = [track_db{nn_storm_ind(i)}(:,1)];
    finl_ind         = [track_db{nn_storm_ind(i)}(:,2)];
    
    %extract timedate, latloncent, stats and mass for each track cell from ident_db
    init_datetime   = vertcat(ident_db(init_ind).start_timedate);
    finl_datetime   = vertcat(ident_db(finl_ind).start_timedate);
    init_latloncent = vertcat(ident_db(init_ind).subset_latloncent);
    finl_latloncent = vertcat(ident_db(finl_ind).subset_latloncent);
    init_stats      = vertcat(ident_db(init_ind).stats);
    finl_stats      = vertcat(ident_db(finl_ind).stats);
    init_mass       = init_stats(:,13);     
    finl_mass       = finl_stats(:,13);
    
    %calculate the most common time difference
    temp_dt         = mode(minute(finl_datetime-init_datetime)); %in minutes
    
    %calculate the azimuth and dist of the track between pairs
    [dist,az]       = distance(init_latloncent(:,1),init_latloncent(:,2),finl_latloncent(:,1),finl_latloncent(:,2));
    az_x            = cosd(az);
    az_y            = sind(az);
    dist            = deg2km(dist);
    
    %find the end cell location(s) in finl_ind
    prior_idx       = find_db_ind(finl_ind,nn_cell_ind(i),2);
    
    %load in history for end cell(s)
    try
    step_stats      = weighted_mean(finl_stats(prior_idx,:),finl_mass(prior_idx),1);
    catch
        keyboard
    end
    end_td          = mode(finl_datetime(prior_idx,:));
    hist_end_td     = [hist_end_td,end_td];
    step_min        = 0;
    step_dist       = 0;
    step_az_x       = [];
    step_az_y       = [];   
    
    %infinite loop until data runs out...
    loop=1;
    while loop==1
        %search in final id for target ids, and exact associated init_inds
        %(working backwards...)
        if ~isempty(prior_idx)
            %cumulative weighted distance!
            step_dist     = [step_dist;weighted_mean(dist(prior_idx),init_mass(prior_idx),0)];
            step_az_x     = [step_az_x;weighted_mean(az_x(prior_idx),init_mass(prior_idx),0)];
            step_az_y     = [step_az_y;weighted_mean(az_y(prior_idx),init_mass(prior_idx),0)];
            step_stats    = [step_stats;weighted_mean(init_stats(prior_idx,:),init_mass(prior_idx),1)];
            step_min      = [step_min;-datenum_min(end_td-mode(init_datetime(prior_idx,:)))];
        else
            %data has run out (reached first cell)
            loop=0;
            break
        end
        %load index of current init_ind in the finl_ind list
        prior_idx    = find_db_ind(finl_ind,init_ind(prior_idx),2);
        
    end
    %append end_cell history to output
    hist_dist     = [hist_dist,{-cumsum(step_dist)}]; %reverse direction cumulative sum
    hist_az_x     = [hist_az_x,{step_az_x}];
    hist_az_y     = [hist_az_y,{step_az_y}];
    hist_stats    = [hist_stats,{step_stats}];
    hist_min      = [hist_min,{step_min}];
end

function mean_w_var=weighted_mean(var,mass,flag)
%WHAT: calculates the weighted mean (from mass) of the input variable.
%Operates in non-stats (vector) or stats mode (matrix)

%INPUT:
%var: input variable (vector or matrix)
%mass: same number of rows as var, mass of cell
%flag: 0: vector mode.. 1: matrix mode...

%OUTPUT:
%mean_w_var: weighted mean of var

%calculate cell weight from weight...
percentage=mass./sum(mass);
if flag==0 %operate in vector mode
    weighted_var=percentage.*var;
    mean_w_var=mean(weighted_var);  
elseif flag==1 %operate in matrix mode
    [m,n]=size(var);
    weighted_var=repmat(percentage,1,n).*var; %repeat weighting
    mean_w_var=mean(weighted_var,1); %apply weighting
end
function out=datenum_min(in)
%WHAT: Converts datenum in into total number of minutes (out)
out=ceil(in*60*24);
if out==0
    out=1;
end