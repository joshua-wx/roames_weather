function cated_db=db_cat(arch_dir,oldest_time,newest_time,site_no_selection,db_name,mode)
%WHAT: Search arch dir for db of type db_name which fall between oldest and
%newest time. These databases are then joined, allowing a database to span
%across dats.

%INPUT
%arch_dir: path of processed data directort
%oldest_time: lower time limit (datenum)
%newest_time: upper time limit (datenum)
%db_name: database type (intp_db, ident_db, track_db)


%round time down to the day (remove decimal)
newest_time=floor(newest_time);
oldest_time=floor(oldest_time);

%list of dates
date_list=oldest_time:newest_time;
if mode==0
    cated_db=[];
elseif mode==1
    cated_db={};
end

%loop through each date list
for i=1:length(date_list)
    %build path to db_name for that date
    date_tag=datevec(date_list(i));
    for j=1:length(site_no_selection)
        db_path=[arch_dir,'IDR',num2str(site_no_selection(j)),'/',num2str(date_tag(1)),'/',num2str(date_tag(2)),'/',num2str(date_tag(3)),'/',db_name,'_',datestr(date_list(i),'dd-mm-yyyy'),'.mat'];
        if exist(db_path,'file')==2
            %if exists, read and cat to cated_db
            out=mat_wrapper(db_path,db_name);
            if mode==1
                %for tracks, cat into daily cells
                cated_db=[cated_db,{out}];
            else
                try
                cated_db=[cated_db, out];
                catch
                    keyboard
                end
            end
        else
            %report database missing for that day
            disp([db_name,' database missing for ',datestr(date_list(i),'dd-mm-yyyy')]);
            if mode==1
                cated_db=[cated_db,{[]}];
            end
        end
    end
end