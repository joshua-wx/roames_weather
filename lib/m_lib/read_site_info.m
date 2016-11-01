function read_site_info(site_info_fn)

%WHAT: Reads site_info.txt and converts it to a mat file called
%open site_info.txt in the config folder
try
    fid       = fopen(site_info_fn);
    site_info = textscan(fid,'%f %s %f %f %f %*f %*s %*f','CommentStyle','#','HeaderLines',2);
    fclose(fid);
    %set variables
    site_id_list     = site_info{1};
    site_s_name_list = site_info{2};
    site_lat_list    = -cell2mat(site_info(3));
    site_lon_list    = cell2mat(site_info(4));
    site_elv_list    = cell2mat(site_info(5));
    site_centroid    = [site_lat_list,site_lon_list,site_elv_list];
    
    for i=1:length(site_s_name_list)
        %remove trailing _
        while ~isletter(site_s_name_list{i}(end))
            site_s_name_list{i} = site_s_name_list{i}(1:end-1);
        end
        %replace / spacing with _
        site_s_name_list{i} = strrep(site_s_name_list{i}, '/', '_');
    end
    
    %write to file
    save(['tmp/',site_info_fn,'.mat'],'site_id_list','site_s_name_list','site_lat_list','site_lon_list','site_elv_list','site_centroid')
catch
    disp('site_info.txt not found or no tmp folder')
    return
end    
