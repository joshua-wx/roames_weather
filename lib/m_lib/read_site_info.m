function warning_flag = read_site_info(site_info_fn,old_site_info_fn,startdate,stopdate,radar_id_list,collate_flag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Reads site_info.txt, if argin>1, it checks for overlapping entries
% in radar_id_list and old_site_info (for id and date range) and updates
% these entries in the output vars. If argin date range overlaps between
% new and old date ranges, then it throws an error.
% the collate_flag combined the output from both new and old site lists
% (containing multiple entries from the same site). the start times of new
% sites is updated to the stop time of old sites to ensure no overlap.
% INPUTS
% site_info_fn: filename of site info
% old_site_info_fn: filename of old site info list
% startdate: starting date of target dataset
% enddate: ending date of target dataset
% RETURNS: 
% warning_flag, if argin date range is outside old site date range
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%WHAT: Reads site_info.txt and converts it to a mat file called
%open site_info.txt in the config folder
fid          = fopen(site_info_fn);
siteinfo_raw = textscan(fid,'%f %s %f %f %f %*f %*s %*f','CommentStyle','#','HeaderLines',2);
fclose(fid);
%set variables
siteinfo_id_list     = siteinfo_raw{1};
siteinfo_name_list   = siteinfo_raw{2};
siteinfo_lat_list    = -cell2mat(siteinfo_raw(3));
siteinfo_lon_list    = cell2mat(siteinfo_raw(4));
siteinfo_alt_list    = cell2mat(siteinfo_raw(5));
siteinfo_start_list  = repmat(datenum('19900101','yyyymmdd'),length(siteinfo_id_list),1);
siteinfo_stop_list   = repmat(floor(now),length(siteinfo_id_list),1);
warning_flag         = 0;

for i=1:length(siteinfo_name_list)
    %remove trailing _
    while ~isletter(siteinfo_name_list{i}(end))
        siteinfo_name_list{i} = siteinfo_name_list{i}(1:end-1);
    end
    %replace / spacing with _
    siteinfo_name_list{i} = strrep(siteinfo_name_list{i}, '/', '_');
end

%if there is more than one argument, run old site info filtering
if nargin>1
    %read old site info
    fid          = fopen(old_site_info_fn);
    oldinfo_raw = textscan(fid,'%f %s %f %f %f %*s %s %s','CommentStyle','#');
    fclose(fid);
    %extract to variables
    oldinfo_id_list     = oldinfo_raw{1};
    oldinfo_name_list   = oldinfo_raw{2};
    oldinfo_lat_list    = -cell2mat(oldinfo_raw(3));
    oldinfo_lon_list    = cell2mat(oldinfo_raw(4));
    oldinfo_alt_list    = cell2mat(oldinfo_raw(5));
    oldinfo_start_list  = datenum(oldinfo_raw{6},'yyyymmdd');
    oldinfo_stop_list   = datenum(oldinfo_raw{7},'yyyymmdd');
    if collate_flag == 1
        %update start times on new sites using stop times of old sites
        for i=1:length(oldinfo_id_list)
            target_id  = oldinfo_id_list(i);
            new_idx    = find(target_id == siteinfo_id_list);
            if ~isempty(new_idx)
                siteinfo_start_list(new_idx) = siteinfo_stop_list(i);
            end
        end
        %collate both new and old sites
        siteinfo_id_list     = [siteinfo_id_list;oldinfo_id_list];
        siteinfo_name_list   = [siteinfo_name_list;oldinfo_name_list];
        siteinfo_lat_list    = [siteinfo_lat_list;oldinfo_lat_list];
        siteinfo_lon_list    = [siteinfo_lon_list;oldinfo_lon_list];
        siteinfo_alt_list    = [siteinfo_alt_list;oldinfo_alt_list];
        siteinfo_start_list  = [siteinfo_start_list;oldinfo_start_list];
        siteinfo_stop_list   = [siteinfo_stop_list;oldinfo_stop_list];
    else
        %for each radar id in argin
        for i=1:length(radar_id_list)
            target_id  = radar_id_list(i);
            %check for the index in old site list
            old_idx    = find(target_id == oldinfo_id_list);
            %if index exists
            if ~isempty(old_idx)
                old_start = oldinfo_start_list(old_idx);
                old_stop  = oldinfo_stop_list(old_idx);
                %continue if arin date range is all newer than old site date
                %range
                if startdate > old_stop && stopdate > old_stop
                    continue
                %if argin date range within old date range, reassign siteinfo
                %values to old site
                elseif startdate >= old_start || stopdate <= old_stop
                    new_idx = find(target_id == siteinfo_id_list);
                    siteinfo_name_list(new_idx)  = oldinfo_name_list(old_idx);
                    siteinfo_lat_list(new_idx)   = oldinfo_lat_list(old_idx);
                    siteinfo_lon_list(new_idx)   = oldinfo_lon_list(old_idx);
                    siteinfo_alt_list(new_idx)   = oldinfo_alt_list(old_idx);
                    siteinfo_start_list(new_idx) = oldinfo_start_list(old_idx);
                    siteinfo_end_list(new_idx)   = oldinfo_end_list(old_idx);
                %halt if argin date range is outside old site range
                else
                    %set warning flag
                    warning_flag = 1;
                    %halt
                    return
                end
            end
        end
    end
end

%write to file
save(['tmp/',site_info_fn,'.mat'],'siteinfo_id_list','siteinfo_name_list','siteinfo_lat_list','siteinfo_lon_list','siteinfo_alt_list','siteinfo_start_list','siteinfo_stop_list')
