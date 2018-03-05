function tilt_to_volume
%WHAT: takes a directory of tilts, and cat's into volumes based on rapic
%filename description

tilt_path = '/home/meso/Desktop/corrupt_testing/tilt/';
vol_path  = '/home/meso/Desktop/corrupt_testing/vols/';

%read daily rapic directory
dir_listing = dir(tilt_path); dir_listing(1:2) = [];
fn_listing  = {dir_listing.name};

%load first tilt
[vol_rid,vol_start_dt,last_pass] = parse_rapic_fn(fn_listing{1});
vol_idx = 1;
%loop through tilt files from the second
for i=2:length(fn_listing)
    tilt_fn = fn_listing{i};
    [tilt_rid,tilt_dt,tilt_pass] = parse_rapic_fn(tilt_fn);
    
    %check if tilt part of same volume
    if tilt_rid==vol_rid && tilt_pass>last_pass && minute(tilt_dt-vol_start_dt)<10
        vol_idx = [vol_idx,i];
    else
        %otherwise, if there are sufficent tilts for a volumes (say min of 8)
        if length(vol_idx)>8
            %cat rapic files
            vol_fn  = [num2str(radar_id,'%02.0f'),'_',datestr(vol_start_dt,'yyyymmdd_HHMMSS'),'.txt'];
            vol_ffn = [vol_path,vol_fn];
            for j=1:length(vol_idx)
                cmd = ['cat '
            end
            keyboard
        end
        %reset volume vars
        vol_idx      = i;
        vol_rid      = tilt_rid;
        vol_start_dt = tilt_dt;
    end
    last_pass = tilt_pass;
    
end

function [rid,dt,pass] = parse_rapic_fn(rapic_fn)
    C = textscan(rapic_fn,'%f %s %s %f %f','Delimiter','_');
    rid   = C{1};
    dt    = datenum([C{2}{1},'_',C{3}{1}],'yyyymmdd_HHMMSS');
    pass  = C{4};
    %tpass = C{5};