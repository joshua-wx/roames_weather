function read_site_info(site_info_fn)

%WHAT: Reads site_info.txt and converts it to a mat file called
%open site_info.txt in the config folder
try
    fid       = fopen(site_info_fn);
    site_info = textscan(fid,'%f %s %f %f %f %*f %*s %*f','CommentStyle','#','HeaderLines',2);
    fclose(fid);
    %set variables
    radar_id_list     = site_info{1};
    radar_name_list   = site_info{2};
    radar_lat_list    = -cell2mat(site_info(3));
    radar_lon_list    = cell2mat(site_info(4));
    radar_elv_list    = cell2mat(site_info(5));
    radar_centroid    = [radar_lat_list,radar_lon_list,radar_elv_list];
    
    for i=1:length(radar_name_list)
        %remove trailing _
        while ~isletter(radar_name_list{i}(end))
            radar_name_list{i} = radar_name_list{i}(1:end-1);
        end
        %replace / spacing with _
        radar_name_list{i} = strrep(radar_name_list{i}, '/', '_');
    end
    
    %write to file
    save(['tmp/',site_info_fn,'.mat'],'radar_id_list','radar_name_list','radar_lat_list','radar_lon_list','radar_elv_list','radar_centroid')
catch
    disp('site_info.txt not found or no tmp folder')
    return
end    
