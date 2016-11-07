function cated_db=db_cat2(arch_dir,site_no_selection,db_name,mode,oldest_time,newest_time)
%WHAT: Joins intp and indent dbs across many dates. For idents dbs,
%preserves unique simple_id and complex_id across all dates.
%Also filters out elements between the time intervals

%INPUT
%arch_dir: path of processed data directort
%oldest_time: lower time limit (datenum)
%newest_time: upper time limit (datenum)
%db_name: database type (intp_db, ident_db, track_db)
%mode: 0: used to not ident_db, 0:used for ident_id to ensure simple_id
%remains unique

%OUTPUT:
%cated_db is a cell array where each entry contains cated_dbs for one radar

%list of dates
date_list=floor(oldest_time):floor(newest_time);
cated_db=[];

%loop through each date list
for i=1:length(site_no_selection)
    %build path to db_name for that date
    site_id=site_no_selection(i);
    temp_cated_db=[];
    for j=1:length(date_list)
        date_tag=datevec(date_list(j));
        db_path=[arch_dir,'IDR',num2str(site_id,'%02.0f'),'/',num2str(date_tag(1)),'/',num2str(date_tag(2),'%02.0f'),'/',num2str(date_tag(3),'%02.0f'),'/',db_name,'_',datestr(date_list(j),'dd-mm-yyyy'),'.mat'];
        
        if exist(db_path,'file')==2
            %if exists, read and cat to cated_db
            out=mat_wrapper2('wv_db',db_path,db_name);
            
            %filter out by timedate
            if ~isempty(out)
                %radar_select=ismember([cated_ident_db.radar_id],site_no_selection);
                ind=find([out.stop_timedate]<oldest_time | [out.start_timedate]>newest_time);
                out(ind)=[];
            end
            
            
            if mode==1 && ~isempty(temp_cated_db)
                %for tracks, cat into daily cells
                max_simple_id=max(vertcat(temp_cated_db.simple_id));
                max_complex_id=max(vertcat(temp_cated_db.complex_id));
                for k=1:length(out)
                    out(k).simple_id=out(k).simple_id+max_simple_id;
                    out(k).complex_id=out(k).complex_id+max_complex_id;
                end
                temp_cated_db=[temp_cated_db, out];
  
            else
                temp_cated_db=[temp_cated_db, out];
            end
        else
            %report database missing for that day
            disp([db_path,' database missing']);
        end
    end
   
    cated_db=[cated_db, temp_cated_db];
end