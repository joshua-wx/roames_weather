function plot_qc_logs

%WHAT: generated monthly summary images from qc_odim log files
close all
%paths
log_root = '/home/meso/Dropbox/academic/open_radar/odimh5_logs/';
log_ids  = 28;
out_acc  = zeros(length(log_ids),1);
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
    log_date_vec    = datevec(log_date);
    date_vec        = datevec(log_date(1):log_date(end));
    date_vec_m      = unique(date_vec(:,1:2),'rows');
    vol_count_m     = zeros(size(date_vec_m,1),1);
    vol_exp_count_m = zeros(size(date_vec_m,1),1);
    vol_compl_m     = zeros(size(date_vec_m,1),1);
    vol_step_m      = zeros(size(date_vec_m,1),1);
    vol_level_m     = nan(size(date_vec_m,1),1);
    vol_acc_m       = zeros(size(date_vec_m,1),1);
    vol_exp_acc_m   = zeros(size(date_vec_m,1),1);
    vol_ndays       = zeros(size(date_vec_m,1),1);
    
    %% loop for month stats
    for i=1:length(date_vec_m)
        %for each year and month combination
        year_num     = date_vec_m(i,1);
        month_num    = date_vec_m(i,2);
        vol_ndays(i) = eomday(year_num,month_num);
        %find in original data log
        find_idx     = find(log_date_vec(:,1) == year_num & log_date_vec(:,2) == month_num);
        %generate monthly stats
        %number of volumes per month
        vol_count_m(i)     = sum(vol_count2(find_idx));
        vol_step_m(i)      = mode(vol_sample(find_idx));
        vol_exp_count_m(i) = 60/vol_step_m(i)*24*vol_ndays(i);
        if vol_count_m(i) == 0 || vol_step_m(i)==0
            vol_exp_count_m(i) = 0;
            continue
        end
        %completeness
        vol_compl_m(i)  = vol_count_m(i)/vol_exp_count_m(i);
        %video level (use max)
        vol_level_m(i)  = max(vol_level(find_idx));      
    end
    
    %% loop for accumulation counts
    %find index of first and last valid count entry
    first_idx = find(vol_compl_m>0,1,'first');
    last_idx  = find(vol_compl_m>0,1,'last');
    for i=first_idx:last_idx
        %expected number of volumes
        if vol_exp_count_m(i)==0
            last_idx = find(vol_exp_count_m(first_idx:i)>0,1,'last');
            if isempty(last_idx)
                exp_acc = 60/10*24*vol_ndays(i); %use 10min as default
            else
                subset  = vol_exp_count_m(first_idx:i);
                exp_acc = subset(last_idx);
            end
        else
            exp_acc = vol_exp_count_m(i);
        end
        prev_idx        = i-1;
        if prev_idx > 0
            vol_acc_m(i)     = vol_acc_m(prev_idx) + vol_count_m(i);
            vol_exp_acc_m(i) = vol_exp_acc_m(prev_idx) + exp_acc;
        else
            vol_acc_m(i)     = vol_count_m(i);
            vol_exp_acc_m(i) = vol_exp_count_m(i);
        end
    end
    %calculate percentage
    vol_acc_perc = vol_acc_m./vol_exp_acc_m*100;
    %keep last percentage
    last_acc_idx = find(~isnan(vol_acc_perc),1,'last');
    if ~isempty(last_acc_idx)
        out_acc(k) = vol_acc_perc(last_acc_idx);
    end
    %generate monthly datenum list
    date_num_m = datenum([date_vec_m,ones(size(date_vec_m,1),1)]);

    %% ploting
    h=figure('pos',[10 10 1200 750]);
    
    %monthly complete
    ax1 = subplot(2,2,1);
    plot(date_num_m,floor(vol_compl_m.*100),'r.'); ylim([0 100])
    datetick('x'); ylabel('monthly completeness (%)');
    
    %file diff
    ax2 = subplot(2,2,2);
    semilogy(log_date,vol_szvar,'b.'); 
    datetick('x'); ylabel('mean daily difference in sequential file size (B)');
    
    %total complete
    ax3 = subplot(2,2,3);
    plot(date_num_m,vol_acc_perc,'r-','linewidth',1.5); ylim([0 100]);
    datetick('x'); ylabel('acc completeness (%)');
    
    %video levels and steps
    ax4 = subplot(2,2,4);
    plot(date_num_m,vol_level_m,'r.'); ylabel('monthly video level')
    yyaxis right
    plot(date_num_m,vol_step_m,'b.'); ylabel('mode monthly sampling (min)')
    datetick('x');
    ax4.YAxis(1).Limits = ([0, 160]); ax4.YAxis(1).Color = 'r';
    ax4.YAxis(1).TickValues = [0,16,32,64,160];
    ax4.YAxis(2).Limits = ([0, 10]);  ax4.YAxis(2).Color = 'b';
    ax4.YAxis(2).TickValues = [0,5,6,10];
    grid on
    print(h,[log_root,num2str(log_ids(k),'%02.0f'),'monthly_stats.png'],'-dpng');
    close(h)
end
%save final accumulation percentage to file
dlmwrite([log_root,'acc_out.csv'],[log_ids',out_acc])

