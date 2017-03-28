function colormap_interp(refl_cmap_fn,vel_cmap_fn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: load simple original colormap config files and saves colour maps to
% a mat file (with a fixed fn)
% INPUTS 
% refl_cmap_fn: fn for reflectivity colour map (str)
% vel_cmap_fn: fn for velcoity colour map (str)
% RETURNS
% saves matlab colourmaps to mat file: tmp/interp_cmaps.mat
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%load cmaps
refl_cmap = load(refl_cmap_fn);
vel_cmap  = load(vel_cmap_fn);

%interp1 refl cmap
refl_index=refl_cmap(1,1):refl_cmap(end,1);

%interpolate components
interp_refl_r = interp1(refl_cmap(:,1),refl_cmap(:,2),refl_index);
interp_refl_g = interp1(refl_cmap(:,1),refl_cmap(:,3),refl_index);
interp_refl_b = interp1(refl_cmap(:,1),refl_cmap(:,4),refl_index);

%collate and convert to fractions of 255
interp_refl_cmap  = [interp_refl_r',interp_refl_g',interp_refl_b']./255;
%interp1 vel cmap
vel_index=vel_cmap(1,1):vel_cmap(end,1);

%interpolate components
interp_vel_r = interp1(vel_cmap(:,1),vel_cmap(:,2),vel_index);
interp_vel_g = interp1(vel_cmap(:,1),vel_cmap(:,3),vel_index);
interp_vel_b = interp1(vel_cmap(:,1),vel_cmap(:,4),vel_index);

%collate and convert to decimal
interp_vel_cmap  = [interp_vel_r',interp_vel_g',interp_vel_b']./255;

%save to file
mat_output_path = 'tmp/interp_cmaps.mat';
save(mat_output_path,'interp_vel_cmap','interp_refl_cmap')