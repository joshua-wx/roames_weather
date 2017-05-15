%setup compiled directory structure

%build paths
build_path = 'build/';
mkdir(build_path)
addpath(build_path)
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/etc');
addpath('/home/meso/dev/shared_lib/jsonlab');
addpath('etc')

%compile
display('mcc')
mcc('-m','qc_odimh5.m','-d',build_path)

%build etc from global
display('create etc')
etc_path = 'etc';
copyfile('/home/meso/dev/roames_weather/etc/pushover.token',etc_path)
copyfile('/home/meso/dev/roames_weather/etc/global.config',etc_path)

%build tar
display('tar')
tar_fn = [build_path,'qc_odimh5.tar'];
tar(tar_fn,{'run_qc_odimh5.sh','qc_odimh5','run','etc/'})

%scp
display('scp')
% %ftp machine 01-10
% ssh_ip      = '52.62.40.126';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% %ftp machine 11-20
% ssh_ip      = '52.62.201.208';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% %ftp machine 21-30
ssh_ip      = '52.65.133.13';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% %ftp machine 31-40
% ssh_ip      = '52.62.185.149';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% %ftp machine 41-50
% ssh_ip      = '52.65.131.100';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% %ftp machine 51-60
% ssh_ip      = '52.65.132.91';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
% % %ftp machine 61-70
% ssh_ip      = '52.64.139.211';
% [sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])

delete('/home/meso/dev/roames_weather/opt/qc_odimh5/etc/pushover.token')
delete('/home/meso/dev/roames_weather/opt/qc_odimh5/etc/global.config')