function daily_to_tilt(daily_path,tilt_path)
%WHAT: for a given set of daily rapic files, split into ppi rapic files
%(with an index of scan number of total number). Target: 7/2008 to 3/2009
%This script was written to recover corrupt daily volumes

%set paths
%daily_path  = '/home/meso/Desktop/corrupt_rapic_testing/daily/';
%tilt_path    = '/home/meso/Desktop/corrupt_rapic_testing/tilt/';

%read daily rapic directory
dir_listing = dir(daily_path); dir_listing(1:2) = [];
fn_listing  = {dir_listing.name};

%loop through daily files
for i=1:length(fn_listing)
    rapic_ffn = [daily_path,fn_listing{i}]
    read_daily(rapic_ffn,tilt_path);
end



function read_daily(ffn,tilt_path)
    %WHAT: reads a rapic database file, when a volume is detected, it is
    %parse into cells and broken up into scans. Scans are written to
    %seperate rapic files
    
    %read file
    fid = fopen(ffn,'r','n','ISO-8859-1');
    tline = ' ';
    %while reading
    while ischar(tline)
        %read next line
        tline       = fgets(fid);
        %if test is a volume
        if strncmp(tline,'COUNTRY: ',9)
            %break string into cells using null/newline chars
            tline_cell  = strsplit(tline, {char(0),char(10)});
            scan_flag   = false;
            %for each entry
            for i=1:length(tline_cell)
                %if start of scan, clear cell and begin recording
                if strncmp(tline_cell{i},'COUNTRY: ',9)
                    scan_flag = true;
                    scan_cell = {};
                    scan_cell = [scan_cell,tline_cell{i}];
                %if end of scan, stop recording and write to file
                elseif strncmp(tline_cell{i},'END RADAR',9)
                    scan_flag = false;
                    scan_cell = [scan_cell,tline_cell{i}];
                    %write out
                    write_scan(scan_cell,tilt_path)
                %if recording, collate
                elseif scan_flag
                    scan_cell = [scan_cell,tline_cell{i}];
                end
            end
        end
    end
    fclose(fid);
    
    
    
function write_scan(scan_cell,tilt_path)
    %WHAT: writes a rapic scan to file. filename constructed from header
    %skip if tilt is not volumetric
    prod_idx  = find(strncmp(scan_cell,'PRODUCT: VOLUMETRIC',19),1);
    try
        if ~isempty(prod_idx)
            %extract timestamp
            ts_idx    = find(strncmp(scan_cell,'TIMESTAMP: ',11),1,'first');
            timestamp = datenum(scan_cell{ts_idx}(12:end),'yyyymmddHHMMSS');
            %extract station id
            id_idx    = find(strncmp(scan_cell,'STNID: ',7),1,'first');
            radar_id  = scan_cell{id_idx}(8:9);
            %extract tilt/scan index
            tilt_idx  = find(strncmp(scan_cell,'TILT: ',6),1,'first');
            if isempty(tilt_idx)
                tilt_idx  = find(strncmp(scan_cell,'PASS: ',6),1,'first');
            end
            tilt_n    = scan_cell{tilt_idx}(7:8);
            tilt_t    = scan_cell{tilt_idx}(13:14);
            %construct rapic filename
            rapic_ffn = [tilt_path,radar_id,'_',datestr(timestamp,'yyyymmdd_HHMMSS'),'_',tilt_n,'_',tilt_t,'.txt'];
            %write out
            fidout = fopen(rapic_ffn,'w','n','ISO-8859-1');
            rapic_text_out = strjoin(scan_cell, char(0));
            rapic_text_out = [rapic_text_out,char(0),char(10)];
            fprintf(fidout,'%s',rapic_text_out);
            fclose(fidout);
        end
    catch
        disp('tilt skipped, error in header')
    end