%inverts date list to create a list of days not in target days

%load data
load('ARCH_Days_NC.mat');
sb_days=target_days;

%set output fn
output_fn='ARCH_Days_NC_invert.mat';

%create full date list
first_date = datenum('01-07-1997','dd-mm-yyyy');
last_date  = datenum('31-06-2014','dd-mm-yyyy');

last_date=max(sb_days);
full_date_list=first_date:last_date;

%invert
no_sb_days=setdiff(full_date_list,sb_days);

%save to file
target_days=no_sb_days;
save(output_fn,'target_days');