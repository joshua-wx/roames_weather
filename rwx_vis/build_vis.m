%setup compiled directory structure
mkdir('build')
build_path = 'build/';
addpath(build_path)
addpath('etc')
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/lib/ge_lib');
addpath('/home/meso/dev/shared_lib/jsonlab');
addpath('/home/meso/dev/roames_weather/bin/json_read')

display('mcc')
mcc('-m','vis.m','-d',build_path)

display('create etc')
etc_path = 'etc';
copyfile('/home/meso/dev/roames_weather/etc/global.config',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/site_info.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/site_info_ignore.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/site_info_moved.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/priority_list.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/refl24bit.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/vel24bit.txt',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/pushover.token',etc_path)

display('tar')
tar_fn = [build_path,'vis.tar'];
tar(tar_fn,{'run_vis.sh','vis','run','etc/','py_lib/'})

display('scp')
%realtime
ec2_ip      = '52.64.1.240';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ec2_ip,':~/rwx_vis/'])


delete('/home/meso/dev/roames_weather/rwx_vis/etc/global.config')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/site_info.txt')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/site_info_ignore.txt')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/site_info_moved.txt')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/pushover.token')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/refl24bit.txt')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/vel24bit.txt')
delete('/home/meso/dev/roames_weather/rwx_vis/etc/priority_list.txt')
