%setup compiled directory structure
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','qc_odimh5.m')
% 
display('tar')
tar_fn = 'qc_odimh5.tar';
tar(tar_fn,{'run_qc_odimh5.sh','qc_odimh5','run','config'})

display('scp')
%ftp machine 1
ssh_ip      = '52.65.81.207';
[sout,eout] = unix(['scp -i /home/meso/aws_key/joshuas_weather_key.pem ', tar_fn ,' fedora@',ssh_ip,':~/qc_odimh5'])
