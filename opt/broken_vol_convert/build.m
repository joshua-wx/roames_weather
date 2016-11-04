%setup compiled directory structure
mkdir('build')
build_path = 'build/';
addpath(build_path)
addpath('bin');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','broken_vol_convert.m','-d',build_path)
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_broken_vol_convert.sh','broken_vol_convert','run','convert.config','bin/'})

display('scp')
%ftp machine 1
ec2_ip      = '54.66.250.58';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/broken_vol_convert'])