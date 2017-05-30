##############################################################################
#
# Joshua Soderholm, Fugro ROAMES, 2017
#
# WHAT: computes the single dop transform and output nc file
# NASA SingleDop code https://github.com/nasa/SingleDop based on 
# Xu et al., 2006: Background error covariance functions for vector wind analyses using Doppler-radar radial-velocity observations. Q. J. R. Meteorol. Soc., 132, 2887-2904.
#
# INPUTS
# h5_ffn:      full file path to odimh5 input file
# nc_ffn:     full file path to output plot file
# NI:          nyquist velocity (m/s)
# sd_l:        decorrelation length scale for single dop (km)
# min_rng:     min rng of single dop grid (km)
# max_rng      max rng of single dop grid (km)
# sweep:       integer of radar sweep to process (starting from 0)
# thin_azi:    integer specifiying thin factors of azimuth dim
# thin_rng:    integer specifiying thin factors of slant range dim
# 
##############################################################################

#import lbraries
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import pyart.aux_io as aux_io
import pyart.correct as correct
import singledop
import sys
import numpy as np
from scipy import ndimage
from copy import deepcopy
#assign args
h5_ffn      = sys.argv[1]
nc_ffn     = sys.argv[2]
NI          = float(sys.argv[3])
sd_l        = int(sys.argv[4])
min_rng     = int(sys.argv[5])
max_rng     = int(sys.argv[6])
sweep       = int(sys.argv[7])
thin_azi    = int(sys.argv[8])
thin_rng    = int(sys.argv[9])

#read h5_path into radar object
py_radar = aux_io.read_odim_h5(h5_ffn, file_field_names=True)
# despeckle
gatefilter = correct.despeckle.despeckle_field(py_radar,'VRADH', size = 50)
# dealais using NI
corr_vel = correct.dealias_region_based(py_radar, vel_field='VRADH', nyquist_vel=NI, gatefilter=gatefilter)
py_radar.add_field('VRADH_corr', corr_vel, False)
#median filter
start     = py_radar.get_start(sweep)
end       = py_radar.get_end(sweep) + 1
data      = py_radar.fields['VRADH_corr']['data'][start:end]
flt_data  = ndimage.median_filter(data, size = 9)
flt_data  = np.ma.masked_where(flt_data == 0, flt_data)
py_radar.fields['VRADH_corr']['data'][start:end] = flt_data
#plt.matshow(flt_data)
#plt.savefig('filt_data.png',transparent=True)

#generate sdop fields
sd_obj = singledop.SingleDoppler2D(L=sd_l, radar=py_radar, range_limits=[min_rng,max_rng],
	                                sweep_number=sweep,name_vr='VRADH_corr',thin_factor=[thin_azi,thin_rng],max_range=max_rng,grid_edge=max_rng,
                                    filter_data=True,filter_distance=2)
#output to NC
save = singledop.NetcdfSave(sd_obj, nc_ffn, radar=py_radar)
