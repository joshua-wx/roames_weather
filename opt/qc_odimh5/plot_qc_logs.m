function plot_qc_logs

%WHAT: generated monthly summary images from qc_odim log files
close all
%paths
log_root = '/home/meso/Dropbox/academic/open_radar/odimh5_logs/';
log_ids  = [1:79];

for k=1:length(log_ids)
    
    %extract data from file
    ffn = [log_root,'vol_count_',num2str(log_ids(k),'%02.0f'),'.log'];
    if exist(ffn,'file')~=2
        continue
    end
    dlm_data   = dlmread(ffn);
    vol_count1 = dlm_data(:,2);
    vol_count2 = dlm_data(:,3);
    vol_sample = dlm_data(:,4);
    vol_szvar  = dlm_data(:,5);
    vol_level  = dlm_data(:,6);
    
    %convert date
    log_date   = zeros(length(dlm_data),1);
    for i=1:length(log_date)
        log_date(i) = datenum(num2str(dlm_data(i,1)),'yyyymmdd');
    end

    %generate unique list of month dates
    date_vec      = datevec(log_date);
    date_vec_m    = unique(date_vec(:,1:2),'rows');
    vol_compl_m   = zeros(size(date_vec_m,1),1);
    vol_sample_m  = nan(size(date_vec_m,1),1);
    vol_level_m   = nan(size(date_vec_m,1),1);
    
    %loop for each month
    for i=1:length(date_vec_m)
        %for each year and month combination
        year_num  = date_vec_m(i,1);
        month_num = date_vec_m(i,2);
        ndays     = eomday(year_num,month_num);
        %find in original data log
        find_idx  = find(date_vec(:,1) == year_num & date_vec(:,2) == month_num);
        %generate monthly stats
        %number of volumes per month
        monthly_count   = sum(vol_count2(find_idx));
        monthly_step    = mode(vol_sample(find_idx));
        if monthly_count == 0 | monthly_step==0
            continue
        end
        %mode volume time
        vol_sample_m(i) = monthly_step;
        %maximum monthly volume count
        vol_max_count   = 60/vol_sample_m(i)*24*ndays;
        %completeness
        vol_compl_m(i)  = monthly_count/vol_max_count;
        
        vol_level_m(i)  = max(vol_level(find_idx));
    end

    %generate monthly datenum list
    date_num_m = datenum([date_vec_m,ones(size(date_vec_m,1),1)]);

    %plot
    h=figure('pos',[10 10 1200 750]);
    subplot(2,2,1)
    plot(date_num_m,floor(vol_compl_m.*100),'r.'); datetick('x'); ylabel('monthly completeness (%)')
    ylim([0 100])
    axis tight
    subplot(2,2,2)
    semilogy(log_date,vol_szvar,'b.'); datetick('x'); ylabel('mean daily difference in sequential file size (B)')
    axis tight
    subplot(2,2,3)
    plot(date_num_m,vol_sample_m,'r.'); datetick('x'); ylabel('mode monthly sampling (min)')
    ylim([0 10])
    axis tight
    subplot(2,2,4)
    ax1 = plot(date_num_m,vol_level_m,'r.'); ylim([0 256]); ylabel('monthly video level')
    yyaxis right
    ax2 = plot(date_num_m,vol_sample_m,'b.'); ylim([0 12]); ylabel('mode monthly sampling (min)')
    datetick('x');
    axis tight
    print(h,[log_root,num2str(log_ids(k),'%02.0f'),'monthly_stats.png'],'-dpng');
    close(h)
end

