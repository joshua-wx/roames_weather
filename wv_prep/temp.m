path = '/home/meso/Downloads/nick_20131017/nick_cf_20131017/71_cfradial/';

path_dir = dir(path); path_dir(1:2) = [];

name_list = {path_dir.name};

for i=1:length(name_list)
    r_id   = '02';
    r_date = name_list{i}(1:8);
    r_time = [name_list{i}(9:12),'00'];
    new_fn = [r_id,'_',r_date,'_',r_time,'.nc'];
    movefile([path,name_list{i}],[path,new_fn]);
    
end