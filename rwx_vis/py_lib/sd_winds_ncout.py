##############################################################################
#
# Joshua Soderholm, Fugro ROAMES, 2017
#
# WHAT: computes the single dop transform and output to netcdf using 
# NASA SingleDop code https://github.com/nasa/SingleDop based on 
# Xu et al., 2006: Background error covariance functions for vector wind analyses using Doppler-radar radial-velocity observations. Q. J. R. Meteorol. Soc., 132, 2887-2904.
#
# INPUTS
# h5_ffn:      full file path to odimh5 input file
# nc_ffn:      full file path to netcdf output file
# sd_l:        decorrelation length scale for single dop (km)
# min_rng:     min rng of single dop grid (km)
# max_rng      max rng of single dop grid (km)
# sweep:       integer of radar sweep to process (starting from 0)
# thin_i:      integer specifiying thin factors of i dim
# thin_j:      integer specifiying thin factors of j dim
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
import h5py

#assign args
h5_ffn      = sys.argv[1]
nc_ffn      = sys.argv[2]
sd_l        = int(sys.argv[3])
min_rng     = int(sys.argv[4])
max_rng     = int(sys.argv[5])
sweep       = int(sys.argv[6])
thin_i      = int(sys.argv[7])
thin_j      = int(sys.argv[8])

#read out NI from sweep
hfile  = h5py.File(h5_ffn, 'r')
d1_how = hfile['dataset'+str(sweep+1)]['how'].attrs
NI     = d1_how['NI']
hfile.close()

#read h5_path into radar object
py_radar = aux_io.read_odim_h5(h5_ffn, file_field_names=True)

# dealais using NI
corr_vel = correct.dealias_region_based(py_radar, vel_field='VRADH', nyquist_vel=NI)
py_radar.add_field('VRADH_corr', corr_vel, False)

#generate sdop fields
sd_obj = singledop.SingleDoppler2D(L=sd_l, radar=py_radar, range_limits=[min_rng,max_rng],
	                                sweep_number=sweep,name_vr='VRADH_corr',thin_factor=[thin_i,thin_j],max_range=max_rng,grid_edge=max_rng)

#output to NC
save = singledop.NetcdfSave(sd_obj, 'test.nc', radar=py_radar)
