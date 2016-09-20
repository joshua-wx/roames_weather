function plot_track(track_db,ident_db,storm_ind)
init_id = track_db{storm_ind}(:,1);
finl_id = track_db{storm_ind}(:,2);
init_ind = find_db_ind(init_id,{ident_db.ident_id},1);
finl_ind = find_db_ind(finl_id,{ident_db.ident_id},1);

for i=1:length(init_id)
    temp1_sslon=ident_db(init_ind(i)).subset_lon_edge;
    temp1_sslat=ident_db(init_ind(i)).subset_lat_edge;
    temp2_sslon=ident_db(finl_ind(i)).subset_lon_edge;
    temp2_sslat=ident_db(finl_ind(i)).subset_lat_edge;
    temp1_c=ident_db(init_ind(i)).subset_latloncent;
    temp2_c=ident_db(finl_ind(i)).subset_latloncent;
    
    time1=ident_db(init_ind(i)).start_timedate;
    time2=ident_db(finl_ind(i)).start_timedate;
    
    %plot(temp1_sslon,temp1_sslat,'m-');
    %plot(temp2_sslon,temp2_sslat,'m-');
    plot([temp1_c(2),temp2_c(2)],[temp1_c(1),temp2_c(1)],'m*--','LineWidth',2);

    text(temp1_c(2),temp1_c(1),datestr(time1,'HHMM'));
    text(temp2_c(2),temp2_c(1),datestr(time2,'HHMM'));
end