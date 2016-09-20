function rename_file

path='/media/meso/radar_data2/2012/download/';
listing=dir(path);
listing(1:2)=[];

for i=1:length(listing)
        filename=listing(i).name;
        fn_date=filename(1:8);
        fn_site=filename(10:end-6);

        system(['mv ',path,filename,' ',path,'radar.',fn_site,'.',fn_date,'.VOL'])
end



