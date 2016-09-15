function colormap_interp

%load simple original colormap config files
refl_cmap=load('refl24bit.txt');
vel_cmap=load('vel24bit.txt');

%interp1 refl cmap
refl_index=refl_cmap(1,1):refl_cmap(end,1);

%interpolate components
interp_refl_r = interp1(refl_cmap(:,1),refl_cmap(:,2),refl_index);
interp_refl_g = interp1(refl_cmap(:,1),refl_cmap(:,3),refl_index);
interp_refl_b = interp1(refl_cmap(:,1),refl_cmap(:,4),refl_index);

%collate and convert to decimal
interp_refl_cmap=[interp_refl_r',interp_refl_g',interp_refl_b']./255;

%interp1 vel cmap
vel_index=vel_cmap(1,1):vel_cmap(end,1);

%interpolate components
interp_vel_r = interp1(vel_cmap(:,1),vel_cmap(:,2),vel_index);
interp_vel_g = interp1(vel_cmap(:,1),vel_cmap(:,3),vel_index);
interp_vel_b = interp1(vel_cmap(:,1),vel_cmap(:,4),vel_index);

%collate and convert to decimal
interp_vel_cmap=[interp_vel_r',interp_vel_g',interp_vel_b']./255;

%save to file
save('../config_files/colormaps.mat','interp_vel_cmap','interp_refl_cmap')