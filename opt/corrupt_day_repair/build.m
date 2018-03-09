%setup compiled directory structure
mkdir('build')
build_path = 'build/';
addpath(build_path)
addpath('../../lib/m_lib')

display('mcc')
mcc('-m','batch_reprocess.m','-d',build_path)
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_batch_reprocess.sh','batch_reprocess','run','pushover.token','restore_rapic_fflist.mat','corrupt.config'})


display('scp')
%ftp machine 1
ec2_ip      = '13.210.240.105';
[sout,eout] = unix(['scp -i /home/meso/keys/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/corrupt_day_rebuild'])
