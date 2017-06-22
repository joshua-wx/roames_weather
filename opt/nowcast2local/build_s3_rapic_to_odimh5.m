%setup compiled directory structure

%build paths
build_path = 'build/';
mkdir(build_path)
addpath(build_path)
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/etc');

%compile
display('mcc')
mcc('-m','s3_rapic_to_odimh5.m','-d',build_path)

%build etc from global
display('create etc')
etc_path = 'etc';
copyfile('/home/meso/dev/roames_weather/etc/pushover.token',etc_path)

%build tar
display('tar')
tar_fn = [build_path,'rapic_to_odimh5.tar'];
tar(tar_fn,{'run_s3_rapic_to_odimh5.sh','s3_rapic_to_odimh5','run','etc/'})

%scp
display('scp')

ssh_ip      = '52.64.26.123';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_1/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_2/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_3/'])

ssh_ip      = '52.65.179.11';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_1/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_2/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_3/'])

ssh_ip      = '52.64.80.77';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_1/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/rapic_to_odimh5_2/'])


delete('/home/meso/dev/roames_weather/opt/nowcast2local/etc/pushover.token')
