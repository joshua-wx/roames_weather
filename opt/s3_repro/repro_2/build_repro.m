%setup compiled directory structure
build_path = 'build/';



if exist(build_path,'file')==7
    rmdir(build_path,'s')
end
mkdir(build_path)
addpath(build_path)

display('mcc')
mcc('-m','repro_2.m','-d',build_path)

display('tar')
tar_fn = [build_path,'repro.tar'];
tar(tar_fn,{'run_repro_2.sh','repro_2','config','run_repro'})

display('scp')
%machine 1 for type 2
ec2_ip      = '52.65.212.240';
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])
