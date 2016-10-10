%setup compiled directory structure
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','build_index.m')
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_build_index.sh','build_index','run'})

display('scp')
%ftp machine 1
ec2_ip      = '52.65.212.240';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/build_index'])
