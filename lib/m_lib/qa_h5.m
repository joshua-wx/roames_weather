function [qa_flag,no_groups,radar_id,vel_flag]=qa_h5(h5_ffn,min_n_groups,site_list)
%WHAT:
%Checks the h5 file is readable and contains atleast 8 scan levels

%INPUT:
%h5 filename

%OUTPUT:
%qa_flag: quality control flag
%no_groups: number of scans in h5_file

%check a continous list of datasets is present within the h5 file
qa_flag        = 0;
no_groups      = [];
vel_flag       = '';
start_timedate = [];
radar_id       = [];
%load no_groups using old_hdf5info function (much faster than newer one)
try
    %read h5_info
    h5_info=h5info(h5_ffn);
    %read scan startdate
    start_date = h5readatt(h5_ffn,strcat('/dataset',num2str(1),'/what/'),'startdate');
    start_time = h5readatt(h5_ffn,strcat('/dataset',num2str(1),'/what/'),'starttime');
    start_timedate=datenum(strcat(num2str(start_date),num2str(start_time)),'yyyymmddHHMMSS');
    %read radar id
    source = h5readatt(h5_ffn,'/what','source'); %source text tag (contains radar id)
    radar_id=str2num(source(7:8));
catch err
    %catch failed read
    log_cmd_write('log.qa',h5_ffn,'reading time/source atts',err.message);
    return
end

if ~ismember(radar_id,site_list)
    %catch corrupted file
    log_cmd_write('log.qa',h5_ffn,'radar_id from h5 file not in site_list',num2str(radar_id));
    return 
end

%read scan groups
group_list={h5_info.Groups(1:end-3).Name};
%read data groups in the first scan
data_list={h5_info.Groups(1).Groups(1:end-3).Name};
%if there are two data group, then mark as vel
if length(data_list)==2
    vel_flag = 1;
end
%save number of groups
no_groups = length(group_list);
%convert group name into number by removing 'dataset'
group_no_list = [];
for i=1:no_groups
    group_no_list=[group_no_list,str2num(group_list{i}(9:end))];
end
%sort group numbers
group_no_list_sorted=sort(group_no_list);
%check for missing scans
for i=1:length(group_no_list_sorted)
    if i~=group_no_list_sorted(i)
        log_cmd_write('log.qa',h5_ffn,'missing elevation at tilt',num2str(i));
        return
    end
end
%check for a min number of groups and doubled scans (normally 14 levels)
if length(group_no_list)<min_n_groups || length(group_no_list)>20 
    log_cmd_write('log.qa',h5_ffn,'insufficent number of scans at',num2str(group_no_list));
    return
end

%passed all tests
qa_flag = 1;