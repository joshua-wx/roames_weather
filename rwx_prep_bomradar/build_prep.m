%setup compiled directory structure
build_path = 'build/';


addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/bin/json_read')
addpath('/home/meso/dev/shared_lib/jsonlab');


if exist(build_path,'file')==7
    delete([build_path,'*'])
else
    mkdir(build_path)
end
addpath(build_path)

display('mcc')
mcc('-m','prep.m','-d',build_path)

%copy global config
etc_path = 'etc';
copyfile('/home/meso/dev/roames_weather/etc/global.config',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/site_info.txt',etc_path)

display('tar')
tar_fn = [build_path,'prep.tar'];
tar(tar_fn,{'run_prep.sh','prep','etc/','run'})

display('scp')
%ftp primary machine
ec2_ip      = '13.54.40.153';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/rwx_prep_bomradar'])

%ftp testing/backup machine
%ec2_ip      = '13.55.62.132';
%[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/rwx_prep_bomradar'])


delete('/home/meso/dev/roames_weather/rwx_prep_bomradar/etc/global.config')
delete('/home/meso/dev/roames_weather/rwx_prep_bomradar/etc/site_info.txt')
