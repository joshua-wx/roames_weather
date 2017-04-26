function odimh5_vol_stat

%WHAT: scans s3 database to check for missing files for a radar site

%init vars
radar_id_list  = [50];
start_date     = '1999-01-01';
end_date       = '2016-12-31';
s3_odimh5_root = 's3://roames-weather-odimh5/odimh5_archive/';
prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';

%build complete list
if strcmp(radar_id_list,'all')
    radar_id_list = [1:80];
end

%build date and year list
datelist       = datenum(start_date,'yyyy-mm-dd'):datenum(end_date,'yyyy-mm-dd');
yearlist       = unique(year(datelist);

for i=1:length(radar_id_list)
    s3_odimh5_path = [s3_odimh5_root,num2str(radar_id,'%02.0f'),'/'];
    log_fn         = ['missing_vol.',num2str(radar_id,'%02.0f'),'.log'];
    for j=1:length(year_list)

%init vol calc
vol_per_day    = 60/10*24;
h5fn_datelist  = [];
for i=1:length(year_list)
    cur_year      = year_list(i);
    %ls s3 path
    display(['s3 ls for radar_id: ',num2str(radar_id,'%02.0f'),' for year ',num2str(cur_year)])
    cmd           = [prefix_cmd,'aws s3 ls --recursive ',s3_odimh5_path,num2str(cur_year),'/'];
    [sout,eout]   = unix(cmd);
    C             = textscan(eout,'%*s %*s %*u %s');
    h5fn_list     = C{1};
    for j=1:length(h5fn_list)
        %colllate date list
        h5fn_datelist = [h5fn_datelist;datenum(h5fn_list{j}(end-17:end-3),'yyyymmdd_HHMMSS')];
    end
end

%save date list to file
save(['odimh5_vol_stat.',num2str(radar_id,'%02.0f'),'.mat'],'h5fn_datelist');

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




