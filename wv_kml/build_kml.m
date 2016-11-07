%setup compiled directory structure
mkdir('build')
build_path = 'build/';
addpath(build_path)
addpath('bin/json_read');
addpath('etc')
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
addpath('/home/meso/Dropbox/dev/wv/lib/ge_lib');
addpath('/home/meso/Dropbox/dev/shared_lib/jsonlab');
addpath('/home/meso/Dropbox/dev/wv/wv_process/bin/json_read')

display('mcc')
mcc('-m','kml.m','-d',build_path)

display('create etc')
etc_path = 'etc';
copyfile('/home/meso/Dropbox/dev/wv/etc/global.config',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/site_info.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/site_info_hide.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/refl24bit.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/vel24bit.txt',etc_path)

display('tar')
tar_fn = [build_path,'kml.tar'];
tar(tar_fn,{'run_kml.sh','kml','run','etc/','bin/'})

display('scp')
%historical
ec2_ip      = '52.65.167.91';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_kml/'])


delete('/home/meso/Dropbox/dev/wv/wv_kml/etc/global.config')
delete('/home/meso/Dropbox/dev/wv/wv_kml/etc/site_info.txt')
delete('/home/meso/Dropbox/dev/wv/wv_kml/etc/site_info_hide.txt')