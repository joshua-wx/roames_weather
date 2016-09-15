function vol_fn_out = dailyVOL_to_VOL(input_ffn,out_path,log_fn)

%WHAT: Breaks concat'ed rapic volumes (ascii) into individual volumes.

%open input file
fid1       = fopen(input_ffn,'r');
%setup loop vars
tline      = 'random';
file_idx   = 0;
vol_fn_out = {};
%loop through file
while ischar(tline)
    %load new line
    tline    = fgets(fid1);
    file_idx = file_idx+1;
    %if tline is end image line, move text dump into file and clear
    if length(tline)>7
        if strcmp(tline(1:7),'COUNTRY')
            %read parts **NEEDS TO BE HARDENED USING AN ADAPTIVE APPROACH
            k = strfind(tline, 'STNID');
            if isempty(k)
                %no station ID
                continue
            end
            r_id   = tline(k(1)+7:k(1)+8);
            k = strfind(tline, 'TIMESTAMP');
            try
                %if corrupt
                dt_num = datenum(tline(k(1)+11:k(1)+24),'yyyymmddHHMMSS');
            catch
                %skip
                write_log(log_fn,'datenum','corrupt header')
                continue
            end
            %open output file
            out_fn  = [r_id,'_',datestr(dt_num,'yyyymmdd'),'_',datestr(dt_num,'HHMMSS'),'.rapic'];
            out_ffn = [out_path,out_fn];
            %cmd = ['head -n ',num2str(file_idx),' ',input_ffn,' | sed ''s/MSSG: 30 Status information following - 3D-Rapic TxDevice//g''  | tail -n 1 > ',out_ffn];
            f_idx_s = num2str(file_idx);
            cmd = ['sed -n ''',f_idx_s,',',f_idx_s,'p'' ',input_ffn,' | sed ''s/MSSG: 30 Status information following - 3D-Rapic TxDevice//g''  | tail -n 1 > ',out_ffn];
            [sout,eout] = unix(cmd);
            if sout ~= 0
                msg = [cmd,' returned ',eout];
                write_log(log_fn,'sed',msg)
                continue
            elseif exist(out_ffn,'file')==2
                vol_fn_out = [vol_fn_out,out_fn];
            end
        end
    end
end

%log each error and pass file to brokenVOL archive
function write_log(log_fn,type,msg)
log_fid = fopen(log_fn,'a');
display(msg)
fprintf(log_fid,'%s %s %s\n',datestr(now),type,msg);
fclose(log_fid);