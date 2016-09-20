%setup compiled directory structure
build_path = 'build/';
% 
% 
% 
% if exist(build_path,'file')==7
%     rmdir(build_path,'s')
% end
% mkdir(build_path)
% addpath(build_path)
% 
% display('mcc')
% mcc('-m','repro_1.m','-d',build_path)
% 
% display('tar')
tar_fn = [build_path,'repro.tar'];
% tar(tar_fn,{'run_repro_1.sh','repro_1','config','run_repro'})

% display('scp')
% %machine 1
% ec2_ip      = '52.65.210.114'
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])
% %machine 2
% ec2_ip      = '52.65.205.133'
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])
% %machine 3
% ec2_ip      = '52.64.122.7'
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])
% %machine 4
% ec2_ip     = '52.64.119.33'
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
% [sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])
%machine 5
ec2_ip     = '52.65.203.69'
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_1/'])
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_2/'])
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/s3_repro/instance_3/'])