%setup compiled directory structure
build_path = 'build/';

if ~isdeployed
    addpath('/home/meso/Dropbox/dev/wv/lib/m_lib');
end

if exist(build_path,'file')==7
    rmdir(build_path,'s')
end
mkdir(build_path)
addpath(build_path)

display('mcc')
mcc('-m','wv_prep.m','-d',build_path)
% 
display('tar')
tar_fn = [build_path,'wv_prep.tar'];
tar(tar_fn,{'run_wv_prep.sh','wv_prep','config','run'})

display('scp')
%ftp machine 1
ec2_ip      = '52.65.186.213';
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/wv_prep'])
