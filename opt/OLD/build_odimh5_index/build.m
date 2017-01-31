%setup compiled directory structure
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/shared_lib/jsonlab');

display('mcc')
mcc('-m','index_s3_to_ddb.m')
mcc('-m','clean_s3.m')
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_index_s3_to_ddb.sh','index_s3_to_ddb','run_clean_s3.sh','clean_s3','run_index','run_clean','config'})

display('scp')
%ftp machine 1
ec2_ip      = '13.55.235.87';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/build_index'])