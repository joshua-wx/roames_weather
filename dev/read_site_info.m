function read_site_info(site_info_fn)

%WHAT: Reads site_info.txt and converts it to a mat file called
%open site_info.txt in the config folder
try
    fid       = fopen(site_info_fn);
    site_info = textscan(fid,'%f %s %f %f %f %*f %*s %*f','CommentStyle','#','HeaderLines',2);
    fclose(fid);
    %set variables
    r_id_list     = site_info{1};
    r_name_list   = site_info{2};
    r_lat_list    = -cell2mat(site_info(3));
    r_lon_list    = cell2mat(site_info(4));
    r_elv_list    = cell2mat(site_info(5));
    r_centroid    = [r_lat_list,r_lon_list,r_elv_list];
    
    for i=1:length(r_name_list)
        %remove trailing _
        while ~isletter(r_name_list{i}(end))
            r_name_list{i} = r_name_list{i}(1:end-1);
        end
        %replace / spacing with _
        r_name_list{i} = strrep(r_name_list{i}, '/', '_');
    end
    
    %write to file
    save([tempdir,site_info_fn,'.mat'],'r_id_list','r_name_list','r_lat_list','r_lon_list','r_elv_list','r_centroid')
catch
    disp('site_info.txt not found or no tmp folder')
    return
end    
