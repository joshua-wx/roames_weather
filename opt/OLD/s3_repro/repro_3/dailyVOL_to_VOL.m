function vol_fn_out = dailyVOL_to_VOL(input_ffn,out_path,log_fn)

%WHAT: Breaks concat'ed rapic volumes (ascii) into individual volumes.

if ~isdeployed
    addpath('/home/meso/dev/roames_weather/etc')
    addpath('/home/meso/dev/roames_weather/lib/m_lib')
end

site_info_fn = 'site_info.txt';
read_site_info(site_info_fn); load([site_info_fn,'.mat']);


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
    if length(tline)>7
        if strcmp(tline(1:7),'/IMAGE:')
            try
                r_id   = tline(11:12);
                dt_num = datenum(tline(13:23),'yymmddHHMM');
                if any(isstrprop(r_id,'alpha'))
                    %skip if radar id contains any alpha chars
                    continue
                end
            catch
                %skip
                write_log(log_fn,'datenum','corrupt header')
                continue
                r_id   = '';
                dt_num = '';
            end
        elseif strcmp(tline(1:7),'COUNTRY') || strcmp(tline(1:4),'NAME')
            if isempty(r_id) || isempty(dt_num)
                display('missing datetime and r_id data')
                %no header info
                continue
            end
            k = strfind(tline,'VOLUMETRIC');
            if isempty(k)
                continue
            end
            %create header items if required
            if strcmp(tline(1:4),'NAME')
                r_idx = find(str2num(r_id)==site_id_list);
                r_lat = num2str(-site_lat_list(r_idx));
                r_lon = num2str(site_lon_list(r_idx));
                r_alt = num2str(site_elv_list(r_idx));
                start_range = num2str(2000);
                end_range   = num2str(256000);
                country     = '036';
                timestamp   = datestr(dt_num,'yyyymmddHHMMSS');
                %build header
                header = ['COUNTRY: ',country,13,...
                    'LATITUDE: ',r_lat,13,...
                    'LONGITUDE: ',r_lon,13,...
                    'HEIGHT: ',r_alt,13,...
                    'STARTRNG: ',start_range,13,...
                    'ENDRNG: ',end_range,13,...
                    'TIMESTAMP: ',timestamp,13,...
                    'VIDEO: Refl',13,...
                    'NAME:'];
                header_ffn = [tempdir,'header.txt'];
                header_fid = fopen(header_ffn,'w');
                fprintf(header_fid,'%s',header);
                fclose(header_fid);
            end
            %open output file
            out_fn  = [r_id,'_',datestr(dt_num,'yyyymmdd'),'_',datestr(dt_num,'HHMMSS'),'.rapic'];
            out_ffn = [out_path,out_fn];
            cmd = ['head -n ',num2str(file_idx),' ',input_ffn,' | sed ''s/MSSG: 30 Status information following - 3D-Rapic TxDevice//g''  | tail -n 1 > ',out_ffn];
            %f_idx_s = num2str(file_idx);
            %cmd = ['sed -n ''',f_idx_s,',',f_idx_s,'p'' ',input_ffn,' | sed -e "s/MSSG: 30 Status information following - 3D-Rapic TxDevice//g" -e "s/NAME:/$(cat /tmp/header.txt)/g" | tail -n 1 > ',out_ffn];
            %cmd = ['sed -n ''',f_idx_s,',',f_idx_s,'p'' ',input_ffn,' | sed -e "s/MSSG: 30 Status information following - 3D-Rapic TxDevice//g" -e "s/NAME:/',header,'/g" | tail -n 1 > ',out_ffn];
            [sout,eout] = unix(cmd);
            if sout ~= 0
                msg = [cmd,' returned ',eout];
                write_log(log_fn,'sed',msg)
                continue
            elseif exist(out_ffn,'file')==2
                vol_fn_out = [vol_fn_out,out_fn];
            end
            %clear radar id and datenum number
            r_id   = '';
            dt_num = '';           
        end
    end
end

%log each error and pass file to brokenVOL archive
function write_log(log_fn,type,msg)
log_fid = fopen(log_fn,'a');
display(msg)
fprintf(log_fid,'%s %s %s\n',datestr(now),type,msg);
fclose(log_fid);

function out = extend_header(r_id)
