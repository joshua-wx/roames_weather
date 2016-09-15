function batch_rename_VOL

root_path='/media/meso/radar_data1/1999/';

file_list=getAllFiles(root_path);

%read site_info
[site_id_list,site_s_name_list]=old_read_site_info;

for i=1:length(file_list)
    temp_ffn=file_list{i};
    [pathstr, fn, ext] = fileparts(temp_ffn);
    if strcmp(ext,'.VOL0') || strcmp(ext,'.VOL1')
        system(['mv ',temp_ffn,' ',pathstr,'/',fn,'.VOL']);
        disp(['completed ',fn])
    elseif ~strcmp(ext,'.lz4') && ~strcmp(ext,'.VOL')
        keyboard
    end


end




