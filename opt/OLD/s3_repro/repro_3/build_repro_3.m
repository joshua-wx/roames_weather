%setup compiled directory structure
build_path = 'build/';

if exist(build_path,'file')==7
    rmdir(build_path,'s')
end
mkdir(build_path)
addpath(build_path)

display('mcc')
mcc('-m','repro_3.m','-d',build_path)

display('tar')
tar_fn = [build_path,'repro.tar'];
tar(tar_fn,{'run_repro_3.sh','repro_3','config','run_repro','site_info.txt'})

display('scp')
%machine 1
ec2_ip      = '52.65.205.133'
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
