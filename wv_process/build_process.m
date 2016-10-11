%setup compiled directory structure

build_path = 'build/';
addpath(build_path)
addpath('bin/json_read');
addpath('bin/mirt3D');
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
tar(tar_fn,{'run_process.sh','process','run','etc/','bin/'})

display('scp')
%machine realtime
ec2_ip      = '52.65.218.97';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/wv_process/real/'])
%machine historical
ec2_ip      = '52.63.216.144';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/wv_process/hist/'])

delete('/home/meso/Dropbox/dev/wv/wv_process/etc/global.config')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/site_info.txt')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/refl24bit.txt')
delete('/home/meso/Dropbox/dev/wv/wv_process/etc/vel24bit.txt')