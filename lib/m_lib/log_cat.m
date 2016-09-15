function cated_log=log_cat(arch_dir,date_list,curr_radar_id)
%WHAT: Search arch dir for db of type db_name which fall between oldest and
%newest time. These databases are then joined, allowing a database to span
%across dats.

%INPUT
%arch_dir: path of processed data directort
%oldest_time: lower time limit (datenum)
%newest_time: upper time limit (datenum)
%db_name: database type (intp_db, ident_db, track_db)

%list of dates
cated_write_td=[];
cated_radar_id=[];
cated_scan_td=[];
cated_module={};
cated_message={};


%loop through each date list
for i=1:length(date_list)
    for j=1:length(date_list{i})
        %build path to db_name for that date
        date_tag=datevec(date_list{i}(j));
        log_path=[arch_dir,'IDR',num2str(curr_radar_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/'];
        if exist([log_path,'procd_log.txt'],'file')==2
            %if exists, read and cat to cated_log
            [write_td,radar_id,scan_td,module,message]=log_read('procd_log.txt',log_path);
            cated_write_td=[cated_write_td;write_td];
            cated_radar_id=[cated_radar_id;radar_id];
            cated_scan_td=[cated_scan_td;scan_td];
            cated_module=[cated_module;module];
            cated_message=[cated_message;message];
        else
            %report database missing for that day
            disp(['process log file missing for ',datestr(date_list{i}(j),'dd-mm-yyyy')]);
        end
    end
end

cated_log={cated_write_td,cated_radar_id,cated_scan_td,cated_module,cated_message};