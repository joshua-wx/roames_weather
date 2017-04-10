function tc

%load radar files to temp
%provide an inital guess for the first radar image
close all
%% init

%vars
tc_config_fn      = 'tc.config';
global_config_fn  = 'global.config';
site_info_fn      = 'site_info.txt';
local_tmp_path    = 'tmp/';
download_path     = [tempdir,'tc_download/'];
transform_path    = [local_tmp_path,'transforms/'];

%create paths
if exist(local_tmp_path,'file') ~= 7
    mkdir(local_tmp_path)
    mkdir(transform_path)
end

%init download path
if exist(download_path,'file')~=7
    mkdir(download_path)
end

%add libs
addpath('/home/meso/dev/roames_weather/lib/m_lib');
addpath('/home/meso/dev/roames_weather/etc')
addpath('etc')
addpath('tmp')

% load tc_config
read_config(tc_config_fn);
load([local_tmp_path,tc_config_fn,'.mat'])

% Load global config files
read_config(global_config_fn);
load([local_tmp_path,global_config_fn,'.mat']);

% site_info.txt
read_site_info(site_info_fn);
load([local_tmp_path,site_info_fn,'.mat']);

% Preallocate regridding coordinates
preallocate_radar_grid(radar_id_list,transform_path,force_transform_update)

%% load datasets

%generate datasets
oldest_time      = datenum(hist_oldest,ddb_tfmt);
newest_time      = datenum(hist_newest,ddb_tfmt);
download_s3_list = ddb_filter_index(odimh5_ddb_table,'radar_id',radar_id_list,'start_timestamp',oldest_time,newest_time,radar_id_list);
for i=1:length(download_s3_list)
    %download data file and untar into download_path
    display(['s3 cp of ',download_s3_list{i}])
    file_cp(download_s3_list{i},download_path,0,1);
end
%wait for aws processes to finish
wait_aws_finish

%% organise into composite sets

%preallocate
download_fn_list    = cell(length(download_s3_list),1);
download_r_id_list  = zeros(length(download_s3_list),1);
download_date_list  = zeros(length(download_s3_list),1);
%read filename parts
for i=1:length(download_s3_list)
    [~,download_fn,ext]    = fileparts(download_s3_list{i});
    download_fn_list{i}    = [download_fn,ext];
    download_r_id_list(i)  = str2num(download_fn(1:2));
    download_date_list(i)  = datenum(download_fn(4:18),r_tfmt);
end

%find dates of master radar id for composite
master_mask       = download_r_id_list == master_r_id;
master_date_list  = download_date_list(master_mask);
%preallocate
composite_fn_list   = cell(length(master_date_list),1);
composite_date_list = zeros(length(master_date_list),1);
%loop through composite dates
for i=1:length(master_date_list)
    %init target date and fn list for target date
    composite_date = master_date_list(i);
    temp_fn_list   = {};
    %loop through each radar id
    for j=1:length(radar_id_list)
        %find index of target radar id
        target_r_id = radar_id_list(j);
        %find index for current radar id
        temp_ind = find(download_r_id_list == target_r_id);
        %find difference between current radar if times and composite time
        [time_diff,min_ind] = min(abs(composite_date-download_date_list(temp_ind)));
        %convert time difference to minutes
        time_diff = floor(time_diff*24*60);
        %check if diff is less than threshold
        if time_diff <= max_time_diff
            %assign to cell list
            temp_fn_list = [temp_fn_list,download_fn_list(temp_ind(min_ind))];
        end
    end
    %add to composite list
    composite_fn_list{i}   = temp_fn_list;
    composite_date_list(i) = composite_date;
end 

%% composite grid
%build compoite grid
%preallocate
composite_lon_vec = [];
composite_lat_vec = [];
%read lat/lon for each radar
for i = 1:length(radar_id_list)
    transform_fn = [transform_path,'regrid_transform_',num2str(radar_id_list(i),'%02.0f'),'.mat'];
    load(transform_fn,'geo_coords');
    composite_lon_vec = [composite_lon_vec,geo_coords.radar_lon_vec];
    composite_lat_vec = [composite_lat_vec,geo_coords.radar_lat_vec];
end
composite_lon_vec = unique(composite_lon_vec);
composite_lat_vec = unique(composite_lat_vec);
comp_R            = makerefmat(composite_lon_vec(1), composite_lat_vec(1), h_grid, h_grid);

%generate bounding boxes for each radar grid in the composite grid
%preallocate
radar_bbox_list = zeros(length(radar_id_list),4);
%loop through each radar id
for i = 1:length(radar_id_list)
    %load geocords
    transform_fn = [transform_path,'regrid_transform_',num2str(radar_id_list(i),'%02.0f'),'.mat'];
    load(transform_fn,'geo_coords');
    %find min/max lat/lon of radar domain
    r_min_lat = min(geo_coords.radar_lat_vec);
    r_max_lat = max(geo_coords.radar_lat_vec);
    r_min_lon = min(geo_coords.radar_lon_vec);
    r_max_lon = max(geo_coords.radar_lon_vec);
    %find index of min/max lat/lon radar domain in the composite domain
    [~,min_lat_ind] = min(abs(r_min_lat-composite_lat_vec));
    [~,max_lat_ind] = min(abs(r_max_lat-composite_lat_vec));
    [~,min_lon_ind] = min(abs(r_min_lon-composite_lon_vec));
    [~,max_lon_ind] = min(abs(r_max_lon-composite_lon_vec));    
    %assign
    radar_bbox_list(i,:) = [min_lat_ind,max_lat_ind,min_lon_ind,max_lon_ind];
end 

%% regrid
%loop through composite list
for i=1:length(composite_fn_list)
    %setup composite grid
    blank_grid  = ones(length(composite_lat_vec),length(composite_lon_vec)).*min_dbzh;
    comp_grid   = blank_grid;
    %loop through files in each composite pair
    for j=1:length(composite_fn_list{i})
        %extract target odimh5 and set local path
        target_odim_fn = composite_fn_list{i}{j};
        targer_r_id    = str2num(target_odim_fn(1:2));
        odimh5_ffn     = [download_path,target_odim_fn];
        %extract img coords from transform
        transform_fn   = [transform_path,'regrid_transform_',target_odim_fn(1:2),'.mat'];
        load(transform_fn,'img_azi','img_rng')
        %struct up atts
        img_atts       = struct('img_azi',img_azi,'img_rng',img_rng);
        %regrid into cartesian
        ppi_struct                  = process_read_ppi_data(odimh5_ffn,ppi_sweep); %read ppi struct
        [ppi_azi_grid,ppi_rng_grid] = meshgrid(ppi_struct.atts.azi_vec,ppi_struct.atts.rng_vec); %grid for dims
        ppi_data                    = ppi_struct.data1.data; %extract dbzh data
        ppi_img                     = interp2(ppi_azi_grid,ppi_rng_grid,ppi_data,img_atts.img_azi,img_atts.img_rng,'linear');
        %extract bbox for current radar
        bbox_ind                    = find(radar_id_list==targer_r_id);
        radar_bbox                  = radar_bbox_list(bbox_ind,:);
        %assign to temp grid
        temp_grid                                                          = blank_grid;
        temp_grid(radar_bbox(1):radar_bbox(2),radar_bbox(3):radar_bbox(4)) = flipud(ppi_img);
        %cat and max with comp grid
        comp_grid      = max(cat(3,temp_grid,comp_grid),[],3);
    end
    %create figure
    h = figure('color','w','position',[1 1 700 700]); hold on;
    %set limits
    ax=axesm('mercator','MapLatLimit',[min(composite_lat_vec) max(composite_lat_vec)],'MapLonLimit',[min(composite_lon_vec) max(composite_lon_vec)]);
    mlabel on; plabel on; framem on; axis off;
    setm(ax, 'MLabelLocation', 1, 'PLabelLocation', 1,'MLabelRound',0,'PLabelRound',0,'LabelUnits','degrees','Fontsize',10)
    gridm('MLineLocation',1,'PLineLocation',1)
    axis tight
    geoshow(comp_grid,comp_R,'DisplayType','texturemap','CDataMapping','scaled'); %geoshow assumes xy coords, so need to flip ij data_grid
    %assign colourmap
    caxis([0 65]);
    cmap = colormap(jet(128));
    colormap([[1,1,1];cmap]);
    h = colorbar;
    ylabel(h, 'Reflectivity (dBZ)');
    
    
    S = shaperead(coast_ffn);
    coast_lat = S(state_id).Y;
    coast_lon = S(state_id).X;
    linem(coast_lat,coast_lon,'k');
    
end

