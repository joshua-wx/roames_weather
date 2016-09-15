function build_script
%% compiles wv_ftp, wv_process and wv_kml modules to standalone applications

clc

%Build additional matlab paths
restoredefaultpath
addpath('libraries/functions','libraries/ge_functions','wv_process/c_libraries');

%setup compiled directory structure
root=[pwd,'/build/'];
build_path=[root,'wv_',datestr(now,'yyyymmdd_HHMM'),'/'];
old_build_path=[root,'OLD/'];

if exist(old_build_path,'file')~=7
    mkdir(old_build_path)
end

%move and rename old compiled versions to the OLD folder
dir_listing=dir([root,'wv_*']);
if ~isempty(dir_listing)
    movefile([root,dir_listing.name],[old_build_path]);
end

if exist(build_path,'file')~=7
    mkdir(build_path)
end

%copy the config files
copyfile('config_files',[build_path,'config_files']);
%copy the utility scripts files
copyfile('utility_scripts',[build_path,'utility_scripts']);


%% compile wv_ftp
ftp_path=[build_path,'wv_ftp'];
mkdir(ftp_path);

copyfile('run_scripts/run_ftp',ftp_path);
copyfile('wv_ftp/ftp_wrapper',ftp_path);
try
mcc('-m','wv_ftp/wv_fetch4.m','-d',ftp_path);
catch
    keyboard
end
disp('Finished compiling ftp_fetch4.m to build directory')
%'-R','-nojvm',

%% compile wv_process
process_path=[build_path,'wv_process/'];
mkdir(process_path);

copyfile('run_scripts/run_process',process_path);
copyfile('wv_process/c_libraries',[process_path,'c_libraries']);
mcc('-m','wv_process/wv_process.m', '-d' , process_path)
disp('Finished compiling wv_process.m to build directory')

%% compile wv_kml
kml_path=[build_path,'wv_kml/'];
mkdir(kml_path);

copyfile('run_scripts/run_kml',kml_path);
copyfile('wv_kml/overlays',[kml_path,'overlays']);
mcc('-m','wv_kml/wv_kml.m', '-d' , kml_path)
disp('Finished compiling wv_kml.m to build directory')


