%setup compiled directory structure
mkdir('build')
build_path = 'build/';
addpath(build_path)
addpath('../../lib/m_lib')

copyfile('/home/meso/dev/roames_weather/etc/pushover.token','./')

display('mcc')
mcc('-m','remove_corrupt_tilts.m','-d',build_path)
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_remove_corrupt_tilts.sh','remove_corrupt_tilts','run','clean.config','pushover.token'})

delete('pushover.token')

display('scp')
%ftp machine 1
ec2_ip      = '13.210.175.115';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/broken_vol_clean'])