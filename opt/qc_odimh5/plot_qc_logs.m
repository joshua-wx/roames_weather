function plot_qc_logs

%WHAT: generated monthly summary images from qc_odim log files

%paths
log_root = '/home/meso/GC_Dec2017_contract/archive_logs/';
log_ids  = {'02','03','04','08','28','40','50','64','70','76'}


for k=1:length(log_ids)
    %extract data from file
    dlm_data   = dlmread([log_root,'vol_count_',log_ids{k},'.log']);
    vol_count1 = dlm_data(:,2);
    vol_count2 = dlm_data(:,3);
    vol_sample = dlm_data(:,4);
    vol_szvar  = dlm_data(:,5);
    log_date   = zeros(length(dlm_data),1);
    for i=1:length(log_date)
        log_date(i) = datenum(num2str(dlm_data(i,1)),'yyyymmdd');
    end

    %generate unique list of month dates
    date_vec      = datevec(log_date);
    date_vec_m    = unique(date_vec(:,1:2),'rows');
    vol_count_m   = zeros(size(date_vec_m,1),1);
    vol_sample_m  = zeros(size(date_vec_m,1),1);

    for i=1:length(date_vec_m)
        %for each year and month combination
        year_num  = date_vec_m(i,1);
        month_num = date_vec_m(i,2);
        %find in original data log
        find_idx  = find(date_vec(:,1) == year_num & date_vec(:,2) == month_num);
        %generate monthly stats
        vol_count_m(i)  = sum(vol_count2(find_idx));
        vol_sample_m(i) = mode(vol_sample(find_idx));
    end

    %generate monthly datenum list
    date_num_m = datenum([date_vec_m,ones(size(date_vec_m,1),1)]);

    %plot
    h=figure('pos',[10 10 1100 400]);
    subplot(1,2,1)
    plot(date_num_m,vol_count_m,'b-','linewidth',1.5); datetick('x'); ylabel('number of volumes/month')
    axis tight
    subplot(1,2,2)
    plot(date_num_m,vol_sample_m,'r-','linewidth',1.5); datetick('x'); ylabel('mode monthly sampling (min)')
    axis tight
    print(h,[log_root,log_ids{k},'monthly_stats.png'],'-dpng');
    close(h)
end

