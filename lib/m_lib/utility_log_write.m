function utility_log_write(log_ffn,efile,cmd,eout)

%formatting of timedate string
td_format='HH:MM_dd-mm-yy';

%open/create file and read size
fid = fopen(log_ffn, 'at');

%write output
fprintf(fid,'%s\n',[datestr(now,td_format),' ',efile,' ',cmd,' ',eout]);
fclose(fid);

    

