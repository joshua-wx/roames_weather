%setup compiled directory structure

display('mcc')
mcc('-m','broken_vol_stat.m')
% 
display('tar')
tar_fn = 'scp.tar';
tar(tar_fn,{'run_broken_vol_stat.sh','broken_vol_stat','run'})

display('scp')
%ftp machine 1
ec2_ip      = '52.63.20.78';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/broken_vol_stat'])