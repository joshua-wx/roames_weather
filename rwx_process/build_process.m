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
copyfile('/home/meso/dev/roames_weather/etc/pushover.token',etc_path)

display('tar')
tar_fn = [build_path,'process.tar'];
tar(tar_fn,{'run_process.sh','process','run','etc/'})

display('scp')
%historical - moree
ec2_ip      = '52.63.43.235';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/'])
%historical - yarrawonga
ec2_ip      = '52.64.188.218';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/'])
%historical - sellicks
ec2_ip      = '13.55.152.24';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/'])

% %realtime
% ec2_ip      = '52.62.240.73';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/rwx_process'])

delete('/home/meso/dev/roames_weather/rwx_process/etc/global.config')
delete('/home/meso/dev/roames_weather/rwx_process/etc/site_info.txt')
delete('/home/meso/dev/roames_weather/rwx_process/etc/pushover.token')
