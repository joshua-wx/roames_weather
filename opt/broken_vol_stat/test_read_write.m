ffn        = 'IDR71VOL.201706020237.01_28.txt';
prefix_cmd = 'export LD_LIBRARY_PATH=/usr/lib; ';

fid = fopen(ffn,'r','n','ISO-8859-1');

uout = [];
tline = ' ';
while ischar(tline)
    tline = fgets(fid);
    uout  = [uout,tline];
end

fid = fopen('test.rapic','w','n','ISO-8859-1');
fprintf(fid,'%c',[uout,char(10)]);
fclose(fid);

[sout,uout] = unix(['export HDF5_DISABLE_VERSION_CHECK=1; ',prefix_cmd,'rapic_to_odim ','test.rapic',' ','test.h5'])