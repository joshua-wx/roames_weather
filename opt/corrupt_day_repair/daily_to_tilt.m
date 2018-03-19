function daily_to_tilt(daily_path,tilt_path)
%WHAT: for a given set of daily rapic files, split into ppi rapic files
%(with an index of scan number of total number). Target: 7/2008 to 3/2009
%This script was written to recover corrupt daily volumes

%set paths
daily_path  = '/home/meso/Desktop/corrupt_rapic_testing/daily/';
tilt_path    = '/home/meso/Desktop/corrupt_rapic_testing/tilt/';

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
    rapicdata   = rapic_to_cell(ffn);
    break_idx   = find(rapicdata == 0 | rapicdata == 10);
    line_count  = length(break_idx);

    %init
    scan_flag  = false;
    start_idx  = 1;
    rapic_tilt = [];
    prefix     = [];
    %while reading
    for i=1:line_count+1
        
        %extract next line
        if i == line_count+1
            rapic_line  = rapicdata(start_idx:break_idx(end));
        else
            rapic_line  = rapicdata(start_idx:break_idx(i));
            start_idx   = break_idx(i)+1;
        end
        rapic_line = [prefix,rapic_line];
        prefix = [];
        
        %check for error messages ->use prefix to store uncorrupt data and
        %append to next rapic_line
        mssg_start_idx = strfind(rapic_line,double('MSSG'));
        if ~isempty(mssg_start_idx)
            prefix = rapic_line(1:mssg_start_idx-1);
            continue
        end
        
        %skip empty entries
        if length(rapic_line) < 4
            continue
        end
        
        %skip headers
        if rapic_line(1) == 47 %47 = '/'
            continue
        end
        
        %catch and collate ray days
        if scan_flag && rapic_line(1) == 37 %37 = '%'
            rapic_tilt = [rapic_tilt,rapic_line];
            continue
        end
        
        %parse header
        ts_out = textscan(char(rapic_line)','%s','Delimiter',':'); ts_out = ts_out{1};
        if length(ts_out)==1
            val1 = deblank(ts_out{1});
            val2 = '';
        else
            val1 = deblank(ts_out{1});
            val2 = deblank(ts_out{2});
        end
        if strcmp(val1,'COUNTRY')
            %break string into cells using null/newline chars
            rapic_tilt  = rapic_line;
            tilt_atts   = struct('vol',false,'timestamp',[],'stnid','','tilt','','pass','');
            scan_flag   = true;
        %if end of scan, stop recording and write to file
        elseif strcmp(val1,'END RADAR IMAGE')
            scan_flag  = false;
            rapic_tilt = [rapic_tilt,rapic_line];
            %write out
            write_scan(rapic_tilt,tilt_atts,tilt_path)
            %if recording
        elseif scan_flag
            %collate
            rapic_tilt = [rapic_tilt,rapic_line];
            %build attribute struct
            if strcmp(val1,'PRODUCT') && strcmp(val2(1:3),'VOL')
                tilt_atts.vol = true;
            elseif strcmp(val1,'TIMESTAMP')
                tilt_atts.timestamp = datenum(val2,'yyyymmddHHMMSS');
            elseif strcmp(val1,'STNID')
                tilt_atts.stnid = val2;
            elseif strcmp(val1,'TILT')   
                tilt_atts.tilt = val2;
            elseif strcmp(val1,'PASS')
                tilt_atts.pass = val2;
            end
        end
    end
    
function rapicdata = rapic_to_cell(ffn)
    %WHAT: reads rapic file without converting into strings
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    rapicdata = rapicdata';
    fclose(fid)
    
    
function write_scan(rapic_tilt,tilt_atts,tilt_path)
    %WHAT: writes a rapic scan to file. filename constructed from header
    %skip if tilt is not volumetric
    if isempty(tilt_atts.pass) && isempty(tilt_atts.tilt)
        tiltpass_err = true;
    else
        tiltpass_err = false;        
    end
    
    try
        if  tilt_atts.vol && ~isempty(tilt_atts.stnid) && ~isempty(tilt_atts.timestamp) && ~tiltpass_err      
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
            rapic_out = [rapic_tilt,10];
            fwrite(fidout,rapic_out);
            fclose(fidout);
        end
    catch
        disp('tilt skipped, error in header')
    end