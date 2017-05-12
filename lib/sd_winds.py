#! /usr/bin/python

#input
h5_ffn
png_ffn
NI
sd_l
min_rng
max_rng
wspd_max
sweep
thin_factor
vec_thin
vec_scale

#import lbraries
import pyart
import singledop
from matplotlib import pyplot as plt

#read h5_path into radar object
radar = pyart.aux_io.read_odim_h5(h5_ffn, file_field_names=True)

# dealais using NI
corr_vel = pyart.correct.dealias_region_based(radar, vel_field='VRADH', nyquist_vel=NI)
radar.add_field('VRADH_corr', corr_vel, False)

#generate sdop fields
sd_obj = singledop.SingleDoppler2D(L=sd_l, radar=radar, range_limits=[min_rng, max_rng],
                                    sweep_number=sweep,name_vr='VRADH_corr',thin_factor=thin_factor,max_range=max_rng,grid_edge=max_rng)

#setup figure
fig = plt.figure(figsize=(12, 12),frameon=False)
ax = plt.Axes(fig, [0., 0., 1., 1.])
ax.set_axis_off()
fig.add_axes(ax)

#plot wind speed
sd_display = singledop.AnalysisDisplay(sd_obj)
wind_spd = np.sqrt(sd_display.analysis_u**2+sd_display.analysis_v**2)*3.6
cr = ax.pcolormesh(sd_display.analysis_x, sd_display.analysis_y, wind_spd,vmin=0, vmax=wspd_max,cmap='hot_r')

#plot wind vectors
cond = np.logical_and(sd_display.analysis_x % vec_thin == 0, sd_display.analysis_y % vec_thin == 0)
Q = ax.quiver(sd_display.analysis_x[cond], sd_display.analysis_y[cond],
                      sd_display.analysis_u[cond], sd_display.analysis_v[cond],scale=vec_scale)
