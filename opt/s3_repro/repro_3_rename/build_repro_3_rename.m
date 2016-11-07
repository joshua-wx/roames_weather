%setup compiled directory structure
build_path = 'build/';

addpath('/home/meso/Dropbox/dev/wv/lib/m_lib')
addpath('/home/meso/Dropbox/dev/wv/etc')

if exist(build_path,'file')==7
    rmdir(build_path,'s')
end
mkdir(build_path)
addpath(build_path)

display('mcc')
mcc('-m','repro_3_rename.m','-d',build_path)

display('tar')
tar_fn = [build_path,'repro.tar'];
tar(tar_fn,{'run_repro_3_rename.sh','repro_3_rename','config','run_repro','site_info.txt'})

display('scp')
%machine 1
ec2_ip      = '52.63.227.18';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/build_index'])