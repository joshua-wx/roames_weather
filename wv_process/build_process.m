%setup compiled directory structure

build_path = 'build/';
addpath(build_path)
addpath('/home/meso/Dropbox/dev/wv/bin/json_read');
addpath('/home/meso/Dropbox/dev/wv/bin/mirt3D');
addpath('etc')
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','process.m','-d',build_path)

display('create etc')
etc_path = 'etc';
copyfile('/home/meso/Dropbox/dev/wv/etc/global.config',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/site_info.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/refl24bit.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/vel24bit.txt',etc_path)

display('tar')
tar_fn = [build_path,'process.tar'];
tar(tar_fn,{'run_process.sh','process','run','etc/'})

display('scp')
%historical
ec2_ip      = '54.66.145.59';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_process/hist/'])
%realtime
ec2_ip      = '52.64.180.181';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_process/real/'])

delete('/home/meso/Dropbox/dev/wv/wv_process/etc/global.config')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/site_info.txt')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/refl24bit.txt')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/vel24bit.txt')