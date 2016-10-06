%setup compiled directory structure
addpath('/home/meso/Dropbox/dev/wv/etc')

build_path = 'build/';
addpath(build_path)
addpath('bin/json_read')
addpath('bin/mirt3D')

etc_path = ['etc/'];
if exist(etc_path,'file')==7
    rmdir(etc_path,'s')
end
mkdir(etc_path)
addpath('/etc')


display('mcc')
mcc('-m','wv_process.m','-d',build_path)

display('create etc')
copyfile('/home/meso/Dropbox/dev/wv/etc/wv_process.config',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/wv_global.config',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/site_info.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/refl24bit.txt',etc_path)
copyfile('/home/meso/Dropbox/dev/wv/etc/vel24bit.txt',etc_path)

display('tar')
tar_fn = [build_path,'wv_process.tar'];
tar(tar_fn,{'run_wv_process.sh','wv_process','run','etc/','bin/'})

display('scp')
%machine realtime
ec2_ip      = '52.65.218.97';
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/wv_process/real/']);
%machine historical
ec2_ip      = '52.65.22.137';
[sout,eout] = unix(['scp -i /home/meso/roames_vpn/JoshPlayKey.pem ', tar_fn ,' ec2-user@',ec2_ip,':~/wv_process/hist/'])