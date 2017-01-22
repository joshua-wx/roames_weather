%setup compiled directory structure

build_path = 'build/';
mkdir(build_path)
addpath(build_path)
addpath('/home/meso/dev/roames_weather/bin/json_read');
addpath('/home/meso/dev/roames_weather/bin/mirt3D');
addpath('etc')
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','process.m','-d',build_path)

display('create etc')
etc_path = 'etc';
copyfile('/home/meso/dev/roames_weather/etc/global.config',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/site_info.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/refl24bit.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/vel24bit.txt',etc_path)

display('tar')
tar_fn = [build_path,'process.tar'];
tar(tar_fn,{'run_process.sh','process','run','etc/'})

display('scp')
%historical
%ec2_ip      = '54.66.145.59';
%[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_process/hist/'])
%realtime
ec2_ip      = '13.55.71.192';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_process/real/'])

delete('/home/meso/dev/roames_weather/wv_process/etc/global.config')
delete('/home/meso/dev/roames_weather/wv_process/etc/site_info.txt')
delete('/home/meso/dev/roames_weather/wv_process/etc/refl24bit.txt')
delete('/home/meso/dev/roames_weather/wv_process/etc/vel24bit.txt')