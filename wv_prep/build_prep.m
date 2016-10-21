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
mcc('-m','prep.m','-d',build_path)

%copy global config
etc_path = 'etc';
copyfile('/home/meso/Dropbox/dev/wv/etc/global.config',etc_path)

display('tar')
tar_fn = [build_path,'prep.tar'];
tar(tar_fn,{'run_prep.sh','prep','etc','run'})

display('scp')
%ftp machine 1
ec2_ip      = '54.66.205.187';
[sout,eout] = unix(['scp -i /home/meso/aws_key/JoshPlayKey.pem ', tar_fn ,' fedora@',ec2_ip,':~/wv_prep'])

delete('/home/meso/Dropbox/dev/wv/wv_prep/etc/global.config')