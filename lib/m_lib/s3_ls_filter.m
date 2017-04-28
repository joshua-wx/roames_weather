function [h5_ffn_list] = s3_ls_filter(s3_bucket,start_datetime,stop_datetime,radar_id_list)

%WHAT: generates a list of h5_ffn_list form s3_bucket a given date range and radar id list.
%s3_bucket must have the structure: s3_bucket/ID/year/month/day/ID_yyyymmdd_HHMMSS.h5

%init
h5_ffn_list = {};
date_list   = floor(start_datetime):floor(stop_datetime);
prefix_cmd  = 'export LD_LIBRARY_PATH=/usr/lib; ';

%loop throgh range list list
for i = 1:length(radar_id_list)
	%loop through date list
	for j = 1:length(date_list)
		%build path
		date_vec = datevec(date_list(j));
		sub_path  = [num2str(radar_id_list(i),'%02.0f'),'/',num2str(date_vec(1)),'/',num2str(date_vec(2),'%02.0f'),'/',num2str(date_vec(3),'%02.0f'),'/'];
		full_path = [s3_bucket,sub_path];
		%run s3 ls command
		cmd         = [prefix_cmd,'aws s3 ls ',full_path];
		[sout,eout] = unix(cmd);
    	if isempty(eout)
        	return
    	end
    	%clean list
    	C = textscan(eout,'%*s %*s %*f %s'); h5_name = C{1};
		%loop through each file name and check date
		for k = 1:length(h5_name)
			%extract fileparts
			h5_ffn      = [s3_bucket,h5_name{k}];
			[~,h5_fn,~] = fileparts(h5_ffn);
			%extract file date
			h5_dt       = datenum(h5_fn(4:end),'yyyymmdd_HHMMSS');
			%filter
			if h5_dt>=start_datetime && h5_dt<=stop_datetime
				h5_ffn_list = [h5_ffn_list;h5_ffn];
			end
		end
	end

end

