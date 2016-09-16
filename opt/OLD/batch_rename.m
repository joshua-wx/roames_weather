function batch_rename

root_path='/media/meso/radar_data2/extra_data/';

file_list=getAllFiles(root_path);

%read site_info
[site_id_list,site_s_name_list]=read_site_info;

for i=1:length(file_list)
    temp_ffn=file_list{i};
    [pathstr, fn, ext] = fileparts(temp_ffn);
    if strcmp(fn(7:9),'IDR')
        disp([fn,' already IDR'])
        continue
    end
    if ~strcmp(ext,'.lz4')
        keyboard
    end
        
    radar_name=fn(7:end-13);
    if strcmp(radar_name,'CampRd'); radar_name='Camp'; end
    if strcmp(radar_name,'E_Sale'); radar_name='EastSale'; end
    if strcmp(radar_name,'Namoi'); radar_name='Tamwrth'; end
    if strcmp(radar_name,'BrisA_P'); radar_name='BrisA/P'; end
    if strcmp(radar_name,'R_hmptn'); radar_name='R/hmptn'; end
    site_index=find(strcmp(radar_name,site_s_name_list));
    if isempty(site_index)
        keyboard
    end
    radar_id=site_id_list(site_index);
    system(['mv ',temp_ffn,' ',pathstr,'/radar.IDR',num2str(radar_id, '%02.0f'),fn(end-12:end),ext]);
    disp(['completed ',fn])
end




