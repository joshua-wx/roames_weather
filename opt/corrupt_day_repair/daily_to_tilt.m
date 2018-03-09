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
    rapic_cell = rapic_to_cell(ffn);
    scan_flag  = false;
    %while reading
    for i=1:length(rapic_cell)
        %skip empty entries
        if length(rapic_cell{i}) < 4
            continue
        end
        %skip headers
        if rapic_cell{i}(1) == 47 %47 = '/'
            continue
        end
        %catch and collate ray days
        if scan_flag && rapic_cell{i}(1) == 37 %37 = '%'
            tilt_cell = [tilt_cell,rapic_cell{i}];
            continue
        end
        %parse header
        ts_out = textscan(char(rapic_cell{i})','%s','Delimiter',':'); ts_out = ts_out{1};
        if length(ts_out)==1
            val1 = deblank(ts_out{1});
            val2 = '';
        else
            val1 = deblank(ts_out{1});
            val2 = deblank(ts_out{2});
        end
        if strcmp(val1,'COUNTRY')
            %break string into cells using null/newline chars
            tilt_cell   = rapic_cell(i);
            tilt_atts   = struct('vol',false,'timestamp',[],'stnid','','tilt','','pass','');
            scan_flag   = true;
        %if end of scan, stop recording and write to file
        elseif strcmp(val1,'END RADAR IMAGE')
            scan_flag = false;
            tilt_cell = [tilt_cell,rapic_cell{i}];
            %write out
            write_scan(tilt_cell,tilt_atts,tilt_path)
            %if recording
        elseif scan_flag
            %collate
            tilt_cell = [tilt_cell,rapic_cell(i)];
            %build attribute struct
            if strcmp(val1,'PRODUCT') && strcmp(val2(1:3),'VOL')
                tilt_atts.vol = true;
            elseif strcmp(val1,'TIMESTAMP')
                tilt_atts.timestamp = datenum(val2,'yyyymmddHHMMSS');
                if strcmp(val2,'20090302072205')
                    keyboard
                end
            elseif strcmp(val1,'STNID')
                tilt_atts.stnid = val2;
            elseif strcmp(val1,'TILT')   
                tilt_atts.tilt = val2;
            elseif strcmp(val1,'PASS')
                tilt_atts.pass = val2;
            end
        end
    end
    
function rapic_cell = rapic_to_cell(ffn)
    %WHAT: reads rapic file without converting into strings
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    %search and destory messages
    mssg_start_idx = strfind([char(rapicdata)'],'MSSG');
    mssg_mask      = false(length(rapicdata),1);
    %remove MSSG (including stop)
    break_idx = find(rapicdata == 0 | rapicdata == 10);
    if ~isempty(mssg_start_idx)
        for i=1:length(mssg_start_idx)
            stop_idx = find(break_idx>mssg_start_idx(i),1,'first');
            mssg_mask(mssg_start_idx(i):break_idx(stop_idx)) = true;
        end
    end
    rapicdata(mssg_mask) = [];
    %find breaks
    break_idx = find(rapicdata == 0 | rapicdata == 10);
    %build rapic cell
    break_count = length(break_idx);
    rapic_cell  = cell(break_count+1,1);
    start_idx   = 1;
    %collate into cells using breaks
    for i=1:break_count
        rapic_cell{i} = rapicdata(start_idx:break_idx(i));
        start_idx     = break_idx(i)+1;
    end
    rapic_cell{end}   = rapicdata(start_idx:break_idx(end));
    
    
function write_scan(tilt_cell,tilt_atts,tilt_path)
    %WHAT: writes a rapic scan to file. filename constructed from header
    %skip if tilt is not volumetric
    try
        if  tilt_atts.vol
            %split up tilt/pass
            if isempty(tilt_atts.tilt)
                tilt_n    = tilt_atts.pass(1:2);
                tilt_t    = tilt_atts.pass(7:8);
            else
                tilt_n    = tilt_atts.tilt(1:2);
                tilt_t    = tilt_atts.tilt(7:8);
            end
            %construct rapic filename
            rapic_ffn = [tilt_path,tilt_atts.stnid,'_',datestr(tilt_atts.timestamp,'yyyymmdd_HHMMSS'),'_',tilt_n,'_',tilt_t,'.txt'];
            %write out
            fidout    = fopen(rapic_ffn,'w');
            rapic_out = vertcat(tilt_cell{:})';
            rapic_out = [rapic_out,10];
            fwrite(fidout,rapic_out);
            fclose(fidout);
        end
    catch
        disp('tilt skipped, error in header')
    end