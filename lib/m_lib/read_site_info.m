function read_site_info(site_info_fn)

%WHAT: Reads site_info.txt and converts it to a mat file called
%open site_info.txt in the config folder
try
    fid          = fopen(site_info_fn);
    siteinfo_raw = textscan(fid,'%f %s %f %f %f %*f %*s %*f','CommentStyle','#','HeaderLines',2);
    fclose(fid);
    %set variables
    siteinfo_id_list     = siteinfo_raw{1};
    siteinfo_name_list   = siteinfo_raw{2};
    siteinfo_lat_list    = -cell2mat(siteinfo_raw(3));
    siteinfo_lon_list    = cell2mat(siteinfo_raw(4));
    siteinfo_alt_list    = cell2mat(siteinfo_raw(5));
    siteinfo_centroid    = [siteinfo_lat_list,siteinfo_lon_list,siteinfo_alt_list];
    
    for i=1:length(siteinfo_name_list)
        %remove trailing _
        while ~isletter(siteinfo_name_list{i}(end))
            siteinfo_name_list{i} = siteinfo_name_list{i}(1:end-1);
        end
        %replace / spacing with _
        siteinfo_name_list{i} = strrep(siteinfo_name_list{i}, '/', '_');
    end
    
    %write to file
    save(['tmp/',site_info_fn,'.mat'],'siteinfo_id_list','siteinfo_name_list','siteinfo_lat_list','siteinfo_lon_list','siteinfo_alt_list','siteinfo_centroid')
catch
    disp('site_info.txt not found or no tmp folder')
    return
end    
