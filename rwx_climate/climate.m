function climate
%WHAT: Core climatology script for roames weather which takes the local
%database built by sync_database and generate outputs for spatial and
%statistical analysis

%setup config names
climate_config_fn  = 'climate.config';
global_config_fn   = 'global.config';
local_tmp_path     = 'tmp/';

%create temp paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
end

%add library paths
addpath('/home/meso/dev/roames_weather/lib/m_lib')
addpath('/home/meso/dev/roames_weather/etc')
addpath('etc/')

% load climate config
read_config(climate_config_fn);
load([local_tmp_path,climate_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat'])

keyboard