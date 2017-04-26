function file_s3sync(src_root,dest_folder,radar_id,year,month,day)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: runs the aws cli sync command to rapidly sync an s3 folder to a
% local folder. Designed to run on the storm and odimh5 s3 buckets with
% struct radar_id/yyyy/mm/dd/. Can be run for an entire radar (syncs dates)
% or for a single date (user supplies date to build path).
% INPUTS
% src_root: source root on s3 (str)
% dest_folder: local destination folder (str)
% timestamp: timestamp for building local directory structure when
% syncing a single date (date num, double)
% radar_id: radar_id to build radar_id folder in dest root (int)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%setup flags
%init vars
prefix_cmd   = 'export LD_LIBRARY_PATH=/usr/lib; ';

%build command
if ~isempty(year) && ~isempty(month) && ~isempty(day)
	src_path     = [src_root,num2str(radar_id,'%02.0f'),'/',num2str(year),'/',num2str(month,'%02.0f'),'/',num2str(day,'%02.0f')];
elseif ~isempty(year) && ~isempty(month)
	src_path     = [src_root,num2str(radar_id,'%02.0f'),'/',num2str(year),'/',num2str(month,'%02.0f')];
elseif ~isempty(year)
	src_path     = [src_root,num2str(radar_id,'%02.0f'),'/',num2str(year)];
else
	src_path     = [src_root,num2str(radar_id,'%02.0f')];
end

cmd          = ['export LD_LIBRARY_PATH=/usr/lib; aws s3 sync ',src_path,' ',dest_folder];

%run command
[sout,eout] = unix(cmd);
%write error as needed
if isempty(eout)
    log_cmd_write('tmp/log.sync',src_path,cmd,eout)
end
