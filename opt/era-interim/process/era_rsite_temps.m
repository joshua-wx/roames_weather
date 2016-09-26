function era_rsite_temps()
%WHAT: processes an era-interim dataset of pressure level temps into
%freezing and -20C heights for each radar site across the country

%add paths for lib/etc
addpath('/home/meso/Dropbox/dev/wv/lib/m_lib/')
addpath('/home/meso/Dropbox/dev/wv/etc/')

%out_dir
out_path = 'out/';
if exist(out_path,'file')==7
    rmdir(out_path,'s')
end
mkdir(out_path)

%read site
%read_site_info('site_info.txt');
load('site_info.txt.mat');

ddb_tmp_struct  = struct;
year_list       = 1997:2016;
ddb_table       = 'wxradar-eraint-fzlvl';

for i=1:length(year_list)
    target_year = num2str(year_list(i));
    era_ffn     = ['/run/media/meso/DATA/project_data/era-int_wv/era_wv_',target_year,'.nc'];
    era_lon     = ncread(era_ffn,'longitude');
    era_lat     = ncread(era_ffn,'latitude');
    era_hour    = double(ncread(era_ffn,'time'));
    era_t       = double(ncread(era_ffn,'t'))-273.15;   %K -> C
    era_z       = double(ncread(era_ffn,'z'))./9.80665; %geopot to geopotH
    
    %convert time from hours past 1900-01-01 to matlab time number
    offset_dt = datenum('1900-01-01','yyyy-mm-dd');
    era_dt    = offset_dt + era_hour./24;
    
    %loop through radar sites
    for j=1:length(site_id_list)
        %init radar data
        site_lat     = site_lat_list(j);
        site_lon     = site_lon_list(j);
        site_id      = site_id_list(j);
        site_id_str  = ['r',num2str(site_id)];
        
        [~,lat_ind]  = min(abs(era_lat-site_lat));
        [~,lon_ind]  = min(abs(era_lon-site_lon));
        for k=1:length(era_dt)
            %extract profile for single time
            t_profile = era_t(lon_ind,lat_ind,:,k);
            z_profile = era_z(lon_ind,lat_ind,:,k);
            %reshape profile
            t_profile = flipud(reshape(t_profile,length(t_profile),1));
            z_profile = flipud(reshape(z_profile,length(z_profile),1));
            %interpolate
            fz_level      = sounding_interp(t_profile,z_profile,0);
            minus20_level = sounding_interp(t_profile,z_profile,-20);
            %add to ddb struct
            [ddb_tmp_struct,tmp_sz] = addtostruct(ddb_tmp_struct,fz_level,minus20_level,era_dt(k),site_id);
            %write to ddb
            if tmp_sz==25 || k == length(era_dt)
                batch_write_ddb(ddb_tmp_struct,ddb_table);
                %clear ddb_tmp_struct
                ddb_tmp_struct  = struct;
                %display('written_to ddb')
            end
        end
        disp(['finished site ',site_id_str,' for year ',num2str(target_year)]);
    end
    disp(['finished year ',num2str(target_year)]);
end
disp(['finished all']);
keyboard

function intp_h = sounding_interp(snd_temp,snd_height,target_temp)
%WHAT: Provides an interpolated height for a target temperature using a
%sounding vertical profile

intp_h=[];
%find index above and below freezing level
above_ind = find(snd_temp<target_temp,1,'first');
if above_ind > 1  
    below_ind = above_ind-1;
else
    %above ind is either 1 or 0, cannot provide interpolation
    return
end

%attempt to interpolate and floor
intp_h   = interp1(snd_temp(below_ind:above_ind),snd_height(below_ind:above_ind),target_temp);
intp_h   = floor(intp_h);

function [ddb_tmp_struct,tmp_sz] = addtostruct(ddb_tmp_struct,fz_level,minus20_level,era_dt,radar_id)

timestamp          = datestr(floor(era_dt),'yyyy-mm-ddTHH:MM:SS'); %floor to day
hour_str           = num2str(hour(era_dt),'%02.0f');
fieldname_0C       = ['lvl_0C_',hour_str,'Z'];
fieldname_minus20C = ['lvl_minus20C_',hour_str,'Z'];
item_id            = ['item_',num2str(radar_id,'%02.0f'),'_',datestr(floor(era_dt),'yyyymmdd')];

%write to dynamo db
ddb_tmp_struct.(item_id).radar_id.N             = num2str(radar_id,'%02.0f');
ddb_tmp_struct.(item_id).eraint_timestamp.S     = timestamp;
ddb_tmp_struct.(item_id).(fieldname_0C).N       = num2str(fz_level);
ddb_tmp_struct.(item_id).(fieldname_minus20C).N = num2str(minus20_level);

tmp_sz =  length(fieldnames(ddb_tmp_struct));
if hour(era_dt)<18 %haven't added the final timestamp for the last day, reduce size by one
    tmp_sz = tmp_sz -1;
end


function batch_write_ddb(ddb_tmp_struct,ddb_table)

batch_json  = '';
ddb_items_list = fieldnames(ddb_tmp_struct);

for i=1:length(ddb_items_list)
    tmp_struct                 = struct;
    tmp_struct.PutRequest.Item = ddb_tmp_struct.(ddb_items_list{i});
    batch_json                 = [batch_json,savejson('',tmp_struct)];
    if i~=length(ddb_items_list)
        batch_json = [batch_json,','];
    end
end
batch_json  = ['{"',ddb_table,'": [',batch_json,']}'];
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws dynamodb batch-write-item --request-items ''',batch_json,''''];
[sout,eout] = unix(cmd);
if sout ~=0
    log_cmd_write('log.ddb','',cmd,eout)
end

