function [azi_vec,rng_vec] = read_odimh5_ppi_dims(h5_ffn,dataset_no,wrap_azi)

%WHAT: reads dims variables from dataset and generates azimuth and rng
%vectors

dataset_no_str = num2str(dataset_no);
%azimuth (deg)
n_rays   = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'nrays'));                     %number of rays
azi_vec  = linspace(0,360,n_rays+1); azi_vec = azi_vec(1:end-1);                    %azimuth vector, without end point
if wrap_azi
    azi_vec = [azi_vec,360];
end
%slant range (km)
r_bin    = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'rscale'))./1000;              %range bin size
r_start  = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'rstart'));                    %starting range of radar
r_range  = double(h5readatt(h5_ffn,['/dataset',dataset_no_str,'/where'],'nbins'))*r_bin+r_start-r_bin; %number of range bins
rng_vec  = r_start:r_bin:r_range;