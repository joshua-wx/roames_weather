function log_stats(clim_dir,cated_log,oldest_time,newest_time,site_id)

%round time down to the day (remove decimal)
newest_time=floor(newest_time);
oldest_time=floor(oldest_time);

%list of dates
date_list=[oldest_time:newest_time]';

%blank vars
present_vec=zeros(length(date_list),1);
error_vec=zeros(length(date_list),1);
missing_vec=ones(length(date_list),1).*100;

%extract vars from cated_log
log_td=cated_log{3};
log_message=cated_log{5};

%need to work out average number of scans per day
refresh_time=mode(minute(log_td(2:end)-log_td(1:end-1)));
max_count=ceil(24*60/refresh_time);

%loop through each date list
for i=1:length(date_list)
    %build path to db_name for that date
    curr_date=date_list(i);
    filter_ind=find(log_td>=curr_date & log_td<curr_date+1);
    if ~isempty(filter_ind)
        %count number of successful data entries
        present_count=sum(strcmp(log_message(filter_ind),'success'));
        %account for slight variations in total number of daily scans
        if present_count>max_count
            present_count=max_count;
        end
        %count number of errored data entries
        error_count=sum(strcmp(log_message(filter_ind),'corrupt'));
        %adjust for overlapping cappi scan which pass as corrupt
        if present_count+error_count>max_count
            error_count=max_count-present_count;
        end
        %count missing data entires
        missing_count=max_count-present_count-error_count;
        if missing_count<0
            missing_count=0;
        end
        %convert to percentage
        present_vec(i)=present_count/max_count*100;
        error_vec(i)=error_count/max_count*100;
        missing_vec(i)=missing_count/max_count*100;
    end
end

fn='log_stats.mat';

save(fn,'date_list','present_vec','error_vec','missing_vec')

% %write to comma delimited text file
% fn=['Log Stats ',radar_name,' ',datestr(oldest_time,'dd-mm-yy'),'_',datestr(newest_time,'dd-mm-yy'),'.txt'];
% fid=fopen([clim_dir,fn],'wt');
% fprintf(fid,'%s\n','date,present,error,missing');
% 
% for i=1:length(date_list)
%     fprintf(fid,'%6.0f,%3.2f,%3.2f,%3.2f\n',[m2xdate(date_list(i)),present_vec(i),error_vec(i),missing_vec(i)]);
% end
% 
% total_max=max_count*length(date_list);
% total_present=sum(present_vec);
% total_error=sum(error_vec);
% total_missing=sum(missing_vec);
% 
% fprintf(fid,'\n\n%s','Totals,');
% fprintf(fid,'%3.2f,%3.2f,%3.2f',[total_present/total_max*100,total_error/total_max*100,total_missing/total_max*100]);
% 
% fclose(fid)