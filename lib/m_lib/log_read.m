function [write_td,radar_id,scan_td,module,message]=log_read(file_name,path)

%formatting of timedate string
td_format='HH:MM_dd-mm-yy';

%file path
file_path=[path,file_name];

%open/create file and read size
fid = fopen(file_path, 'a+t');
s = dir(file_path);

%if not empty
if s.bytes > 0
    %read contents in correct format
    log_out=textscan(fid,'%s %s %s %s %s');
    
    %isolate contents into output variables
    write_td=datenum(log_out{1},td_format);
    try
    radar_id=cellfun(@str2num,log_out{2});
    catch
        keyboard
    end
    scan_td=datenum(log_out{3},td_format);
    module=log_out{4};
    message=log_out{5};
    
    %filter for radar id
    %filter1_ind=find(radar_id==curr_radar_id);
% 
%     write_td=write_td(filter1_ind);
%     radar_id=radar_id(filter1_ind);
%     scan_td=scan_td(filter1_ind);
%     module=module(filter1_ind);
%     message=message(filter1_ind);
    
    %filter for unique timedate
    [~,filter2_ind,~]=unique(scan_td);
    
    write_td=write_td(filter2_ind);
    radar_id=radar_id(filter2_ind);
    scan_td=scan_td(filter2_ind);
    module=module(filter2_ind);
    message=message(filter2_ind);    
    
else
    %empty file, blank output
    write_td=[];
    radar_id=[];
    scan_td=[];
    module={};
    message={};
end

fclose(fid);
