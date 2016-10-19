function odimh5_vol_stat

%WHAT: scans s3 database to check for missing files for a radar site

%init vars
radar_id       = 50;
radar_int      = 10; %minutes
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';
s3_odimh5_root = 's3://roames-wxradar-archive/odimh5_archive/';
s3_bucket      = 's3://roames-wxradar-archive/';
s3_odimh5_path = [s3_odimh5_root,num2str(radar_id,'%02.0f'),'/'];
log_fn         = ['broken_vol.',num2str(radar_id,'%02.0f'),'.log'];
start_date     = '1997-07-01';
end_date       = '2014-12-31';
datelist       = datenum(start_date,'yyyy-mm-dd'):datenum(end_date,'yyyy-mm-dd');
year_list      = 1997:2014;

% %init vol calc
% vol_per_day    = 60/10*24;
% h5fn_datelist  = [];
% for i=1:length(year_list)
%     cur_year      = year_list(i);
%     %ls s3 path
%     display(['s3 ls for radar_id: ',num2str(radar_id,'%02.0f'),' for year ',num2str(cur_year)])
%     cmd           = [prefix_cmd,'aws s3 ls --recursive ',s3_odimh5_path,num2str(cur_year),'/'];
%     [sout,eout]   = unix(cmd);
%     C             = textscan(eout,'%*s %*s %*u %s');
%     h5fn_list     = C{1};
%     for j=1:length(h5fn_list)
%         %colllate date list
%         h5fn_datelist = [h5fn_datelist;datenum(h5fn_list{j}(end-17:end-3),'yyyymmdd_HHMMSS')];
%     end
% end
% 
% %save date list to file
% save(['odimh5_vol_stat.',num2str(radar_id,'%02.0f'),'.mat'],'h5fn_datelist');

%load for stats
load(['odimh5_vol_stat.',num2str(radar_id,'%02.0f'),'.mat'])
h5fn_datelist   = floor(h5fn_datelist);
exp_daily_vol   = 60/radar_int*24;

%daily stats
exp_daily_vol   = 60/radar_int*24;
daily_vol_count = zeros(length(datelist),1);
date_vec        = datevec(datelist);
for i =1:length(datelist)
    cur_day = datelist(i);
    daily_vol_count(i) = sum(h5fn_datelist==cur_day);
end

%monthly stats
exp_daily_vol     = 60/radar_int*24*365/12;
date_vec          = datevec(datelist);
unique_months     = unique([date_vec(:,1),date_vec(:,2)],'rows');
monthly_vol_count = zeros(length(unique_months),1);
h5fn_year         = year(h5fn_datelist);
h5fn_month        = month(h5fn_datelist);

for i = 1:length(unique_months)
    cur_year  = unique_months(i,1);
    cur_month = unique_months(i,2);
    monthly_vol_count(i) = sum(cur_year==h5fn_year & cur_month==h5fn_month);
end

plot_month_datenum = datenum([unique_months,ones(length(unique_months),1)]);
plot(plot_month_datenum,monthly_vol_count,'k')
hold on
plot(plot_month_datenum,ones(length(unique_months),1)*exp_daily_vol,'r')
datetick
legend('Monthly count','Expected count')
xlabel('Date')
ylabel('Monthly Count')
keyboard




