function impact_output(radar_id_list,newest_timestamp)

%WHAT: Collates wind and mesh impact maps into a single image for each
%radar. Output images are transfered to s3.
%Also removes impact files using newest_timestamp and impact_hrs

%load radar colormap and global config
load('global.config.mat')
load([site_info_fn,'.mat'])
load('vis.config.mat')

for i=1:length(radar_id_list)
    
    %check radar id against impact radar id list
    radar_id = radar_id_list(i);
    if ~ismember(radar_id,impact_radar_id)
		continue
    end
    
    %hail
    %check local path exists
    local_path = [impact_tmp_root,'hail/',num2str(radar_id,'%02.0f'),'/'];
    local_dir  = dir(local_path); local_dir{1:2} = [];
    if ~isempty(local_dir)
        %list impact files
        local_fn_list = {local_dir.name};
        remove_idx    = [];
        %build fn datetimes and filter
        for j=1:length(local_fn_list)
            [~,fn,ext] = fileparts(local_fn_list{j});
            if ~strcmp(ext,'.nc')
                remove_idx = [remove_idx,j];
                continue
            end
            fn_datelist = datenum(fn,r_tfmt);
            if fn_datelist<addtodate(newest_timestamp,-impact_hrs,'hour')
                remove_idx = [remove_idx,j];
            end
        end
        %clear out old files from local path and list
        for j=1:length(remove_idx)
            delete([local_path,local_fn_list(remove_idx(j))])
        end
        local_fn_list(remove_idx) = [];
        %collate
        for j=1:length(local_fn_list)
            load(local_fn_list)
            if j == 1
                master_grid = impact_grid;
            else
                master_grid = master_grid + impact_grid;
            end
        end
        %write grid out
        tmp_image_ffn = [tempdir,'impact_img_out.png'];
        
        %todo
        %change singledop output to produce easier to ingest files
        %code to produce maps
        %modify for wind
        
    end
end
    
    