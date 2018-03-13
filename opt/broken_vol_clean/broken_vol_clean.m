function broken_vol_clean

%start parallel processing pool
%delete(myPool)
%myPool = parpool();
  
prefix_cmd        = 'export LD_LIBRARY_PATH=/usr/lib; ';
brokenvol_s3_path = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';
odim_s3_path      = 's3://roames-weather-odimh5/odimh5_archive/';
mkdir('tmp')
if ~isdeployed
    addpath('bin')
    addpath('../../lib/m_lib')
    addpath('/home/meso/dev/roames_weather/etc');
end

%read config
config_fn = 'clean.config';
read_config(config_fn,[config_fn,'.mat'])
load([config_fn,'.mat'])
if strcmp(radar_id_list,'all')
    radar_id_list = 1:79;
else
    radar_id_list = str2num(radar_id_list);
end

try
%loop through radar id list
for z = 1:length(radar_id_list)
    
    %target radar id
    radar_id       = radar_id_list(z);
    
    %s3 file list
    temp_s3_path   = [brokenvol_s3_path,num2str(radar_id,'%02.0f'),'/'];
    load('fn_list.mat')
    %fn_list        = s3_listing(prefix_cmd,temp_s3_path);
    
    %logs file init
    log_ffn        = ['tmp/',num2str(radar_id,'%02.0f'),'broken_vol_clean.log'];
    
    for i = 1:length(fn_list)
        %init file paths
        s3_ffn        = [temp_s3_path,fn_list{i}];
        input_ffn     = tempname;
        mod_rapic_ffn = tempname;
        output_ffn    = [tempdir,fn_list{i},'.h5'];
        disp(['processing ',fn_list{i},' file ',num2str(i),' of ',num2str(length(fn_list))])
        
        %transfer from s3 to local disk
        file_cp(s3_ffn,input_ffn,0,0)
        
        %check file size
        out = dir(input_ffn);
        if isempty(out); continue; end
        file_sz = out.bytes/1000;
        if file_sz < 20
            disp('too small to be volume')
            delete(input_ffn)
            file_rm(s3_ffn,0,1)
            continue
        end
        
        %use routines to remove headers and clean rays
        vol_struct = vol_to_struct(input_ffn);
        vol_struct = qc(vol_struct,radar_id);
        
        if isempty(rapic_cell)
            disp('cleaned volume empty')
            delete(input_ffn)
            file_rm(s3_ffn,0,1)
            continue
        end
        write_rapic_file(mod_rapic_ffn,rapic_cell);
        
        %inital conversion for error detection (remove converted file immediately, as we
        %know it's already broken)
        %export LD_LIBRARY_PATH=/usr/local/MATLAB/R2016b/bin/glnxa64; ./rapic2ODIMH5_64bit
        [sout,uout] = convert(prefix_cmd,mod_rapic_ffn,output_ffn);
        delete(mod_rapic_ffn)
        if sout == 0 && exist(output_ffn,'file')==2
            %output odimh5 to archive
            disp('success')
            err_str = 'successful conversion, rays cleaned only';
            err_str = output_odimh5(output_ffn,err_str,s3_ffn,radar_id,odim_s3_path,prefix_cmd)
            utility_log_write(log_ffn,s3_ffn,err_str,'')
                 
            %remove s3 file
            %file_rm(s3_ffn,0,1)
            continue
        else
            err_str = ['error is was not removed: ',uout]
        end
        
        %write log
        utility_log_write(log_ffn,s3_ffn,err_str,'')
        
        %clear staging fies
        if exist(input_ffn,'file') == 2;     delete(input_ffn);     end
        if exist(output_ffn,'file') == 2;    delete(output_ffn);    end
        if exist(mod_rapic_ffn,'file') == 2; delete(mod_rapic_ffn); end
    end
    
end
catch err
    %utility_pushover('remove_corrupt tilts',['crashed for ',num2str(radar_id)])
    rethrow(err)
end
%utility_pushover('remove_corrupt tilts',['complete for ',num2str(radar_id)])




function [sout,uout] = convert(prefix_cmd,input_ffn,output_ffn)
    [sout,uout] = unix([prefix_cmd,'rapic_to_odim ',input_ffn,' ',output_ffn]);

    
    
function rapicdata = rapic_to_cell(ffn)
    %WHAT: reads rapic file without converting into strings
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    rapicdata = rapicdata';
    %search and destory messages
    mssg_start_idx = strfind([char(rapicdata)],'MSSG');
    mssg_mask      = false(length(rapicdata),1);
    %remove MSSG (including stop) - error (1)
    break_idx = find(rapicdata == 0 | rapicdata == 10);
    if ~isempty(mssg_start_idx)
        for i=1:length(mssg_start_idx)
            stop_idx = find(break_idx>mssg_start_idx(i),1,'first');
            mssg_mask(mssg_start_idx(i):break_idx(stop_idx)) = true;
        end
    end
    rapicdata(mssg_mask) = [];
    


function vol_struct = vol_to_struct(ffn)
    %WHAT: reads rapicdata into tiltcells for later processing
    
    rapicdata   = rapic_to_cell(ffn);
    break_idx   = find(rapicdata == 0 | rapicdata == 10);
    line_count  = length(break_idx);

    %init
    scan_flag   = false;
    start_idx   = 1;
    rapic_tilt  = [];
    ray_list    = [];
    vol_struct  = [];
    %while reading
    for i=1:line_count+1
        
        %extract next line
        if i == line_count+1
            rapic_line  = rapicdata(start_idx:break_idx(end));
        else
            rapic_line  = rapicdata(start_idx:break_idx(i));
            start_idx   = break_idx(i)+1;
        end

        %skip empty entries
        if length(rapic_line) < 4
            continue
        end
        
        %skip header table
        if rapic_line(1) == 47 %47 = '/'
            continue
        end
        
        %skip corrupt data (double % use case)
        if sum(rapic_line == 37)>1
            continue
        end
        
        %skip corrupt data (combine % and space in same entry)
        if rapic_line(1) == 37 && any(rapic_line == 32)
            continue
        end
        
        %skip corrupt data (neither % and space in same entry)
        if rapic_line(1) ~= 37 && ~any(rapic_line == 32)
            continue
        end
        
        %collate ray entries if currently processing scan (and continue)
        if scan_flag && rapic_line(1) == 37 %37 = '%'
            %enforce ray number uniqueness (error fix)
            ray_number = str2num(char(rapic_line(2:4)));
            if ~any(ray_list==ray_number)
                ray_list   = [ray_list,ray_number];
                rapic_tilt = [rapic_tilt,rapic_line];
                continue
            end
        end
        
        %parse atts
        ts_out = textscan(char(rapic_line),'%s','Delimiter',':'); ts_out = ts_out{1};
        if length(ts_out) == 2
            att_name = deblank(ts_out{1}); 
            att_val  = deblank(ts_out{2});
        else
            att_name = deblank(ts_out{1});
        end
        %start new tilt on COUNTRY att_name
        if strcmp(att_name,'COUNTRY')
            rapic_tilt  = rapic_line;
            tilt_struct.atts.(att_name) = att_val;
            scan_flag   = true;
            ray_list    = [];
            continue
        %stop tilt on END RADAR IMAGE att_name and append
        elseif strcmp(att_name,'END RADAR IMAGE')
            scan_flag  = false;
            rapic_tilt = [rapic_tilt,rapic_line];
            %append to tilt
            tilt_struct.rapicdata = rapic_tilt;
            if isempty(vol_struct)
                vol_struct = tilt_struct;
            else
                vol_struct = [vol_struct,tilt_struct];
            end
            continue
        end
        %other att entries
        if scan_flag
            %collate
            rapic_tilt = [rapic_tilt,rapic_line];
            if ~isfield(att_name,tilt_struct.atts) %removes duplicated headers after main section
                tilt_struct.atts.(att_name) = att_val;
            end
            
        end
    end
    
    
    
function vol_struct = qc(vol_struct,r_id)
    
    %(1) remove non volumetric scans
    vol_flag = false(length(vol_struct),1);
    for i = 1:length(vol_struct)
        if isfield(vol_struct(i).atts,'PRODUCT')
            product_val = vol_struct(i).atts.PRODUCT;
            if strncmp(product_val,'VOLUMETRIC',10)
                vol_flag(i) = true;
            end
        end
    end
    vol_struct = vol_struct(vol_flag);
    
    %(2) remove other radars
    stnid_list = zeros(length(vol_struct),1);
    for i = 1:length(vol_struct)
        if isfield(vol_struct(i).atts,'STNID')
            stnid_list(i) = str2num(vol_struct(i).atts.STNID);
        end
    end
    vol_struct = vol_struct(stnid_list==r_id);
    
    %(3) remove duplicated elevations
    elev_list = zeros(length(vol_struct),1);
    for i = 1:length(vol_struct)
        if isfield(vol_struct(i).atts,'ELEV')
            elev_list(i) = str2num(vol_struct(i).atts.ELEV);
        end
    end
    [~,uniq_idx,~] = unique(elev_list);
    vol_struct = vol_struct(uniq_idx);
    
    %(3) check samples for videores
    %load encodings
    encoding = rapic_encoding;
    
    %(4) remove headers in sample block
    
function [rapic_cell,timestamp] = clean_rapic(rapic_cell,radar_id)
    
    %load encodings
    encoding = rapic_encoding;
    
    %extract timestamp
    ts_idx = find(strncmp(rapic_cell,'TIMESTAMP: ',11),1,'first');
    timestamp = datenum(rapic_cell{ts_idx}(12:end),'yyyymmddHHMMSS');
    
    %extract rays, enforcing set standards
    tilt_cell      = {};
    elev_list      = [];
    start_idx_list = find(strcmp(rapic_cell,['STNID: ',num2str(radar_id,'%02.0f')])); %(6) enforce correct radar id
    stop_idx_list  = find(strncmp(rapic_cell,'END RADAR',9));
    for i=1:length(start_idx_list)
        
        %extract tilt
        start_idx     = start_idx_list(i);
        stop_idx      = stop_idx_list(find(stop_idx_list>start_idx,1,'first'));
        temp_tilt     = rapic_cell(start_idx:stop_idx);
        
        %skip if tilt is not volumetric
        prod_idx  = find(strncmp(temp_tilt,'PRODUCT: VOLUMETRIC',19),1);
        if isempty(prod_idx)
            continue
        end
        
        %find elevation value
        elev_idx  = find(strncmp(temp_tilt,'ELEV: ',6));
        if isempty(elev_idx)
            continue
        end
        elev_list  = [elev_list,str2num(temp_tilt{elev_idx}(7:end))];
        
        %extract video level
        vr_idx   = find(strncmp(rapic_cell,'VIDRES: ',8),1,'first');
        videores = str2num(rapic_cell{vr_idx}(9:end));
        %extract reference values
        if videores == 16
            vr_ref = encoding.vr16;
        elseif videores == 32
            vr_ref = encoding.vr32;
        elseif videores == 64
            vr_ref = encoding.vr64;
        elseif videores == 160
            vr_ref = encoding.vr160;
        else
            continue
        end
            
                    
        %check video levels
        first_r_idx = find(contains(temp_tilt,'%'),1,'first');
        for j=first_r_idx:length(temp_tilt)-1
            %(6) remove non rays inside ray block
            if ~strcmp(temp_tilt{j}(1),'%')
                temp_tilt{j} = '';
            end
            if length(temp_tilt{j}) == 4
                continue
            end
            %
            sample_char = temp_tilt{j}(5:end);
            sample_num  = double(sample_char);
            err_mask    = [false,false,false,false,~ismember(sample_num,vr_ref)];
            if any(err_mask)
                temp_tilt{j}(err_mask)='';
                %last things to try before removing rays, if there's a
                %bunch of invalid chars then replace them all with nothing
            end
            %
        end
        
        
        
        %abs encodings
        %level 159 = 255
        %level 63  = 159
        %level 31  = 126
        %level 15  = (overlaps with other encodings)
        
        %remove empty entries
        rm_idx = cellfun(@isempty,temp_tilt);
        temp_tilt(rm_idx) = [];
        
        %parse header strings (including rays and title blocks)
        h_str       = cell(length(temp_tilt),1);
        for j=1:length(temp_tilt)
            if strcmp(temp_tilt{j}(1),'%')
                h_str{j}   = temp_tilt{j}(1:4);
            else
                strend_idx = strfind(temp_tilt{j},' ');
                h_str{j}   = temp_tilt{j}(1:strend_idx);
            end
        end
        
        %remove header and ray duplicates (target second duplicate)
        %(7,8) this prevents ray overflow and duplicated headers
        uh_str  = unique(h_str);
        rm_mask = false(length(h_str),1);
        for j=1:length(uh_str)
            find_idx = find(strcmp(uh_str{j},h_str));
            if length(find_idx)>1
                rm_mask(find_idx(2:end)) = true;
            end
        end
        h_str(rm_mask)     = [];
        temp_tilt(rm_mask) = [];

        %assign to tilt_cell
        tilt_cell = [tilt_cell,{temp_tilt}];
    end
    
    % (8) remove duplicated tilts (using elevation
    uelev_list = unique(elev_list);
    rm_idx     = [];
    for j=1:length(uelev_list)
        find_idx = find(elev_list == uelev_list(j));
        if length(find_idx) > 1
            rm_idx = [rm_idx,find_idx(2:end)];
        end
    end
    tilt_cell(rm_idx) = [];
    
    %unpack tilts
    rapic_cell = [tilt_cell{:}];
    
function rapic_fn_list = s3_listing(prefix_cmd,s3_odimh5_path)
    rapic_fn_list = {};
    %ls s3 path
    cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path];
    [sout,uout] = unix(cmd);
    %read text
    if ~isempty(uout)
        C             = textscan(uout,'%*s %*s %*u %s');
        rapic_fn_list = C{1};
    end

    
 function err_str = output_odimh5(output_ffn,err_str,s3_ffn,radar_id,odim_s3_path,prefix_cmd)
    
     %odimh5 archive h5 file paths
     h5_date = deblank(h5readatt(output_ffn,'/what','date'));
     h5_time = deblank(h5readatt(output_ffn,'/what','time'));
     h5_dvec = datevec([h5_date,'_',h5_time],'yyyymmdd_HHMMSS');
     h5_path = [num2str(radar_id,'%02.0f'),'/',num2str(h5_dvec(1)),...
         '/',num2str(h5_dvec(2),'%02.0f'),'/',num2str(h5_dvec(3),'%02.0f'),'/'];
     h5_fn   = [num2str(radar_id,'%02.0f'),'_',h5_date,'_',h5_time,'.h5'];
     h5_ffn  = [odim_s3_path,h5_path,h5_fn];
     
     %check if it exists (if it does, do not replace)
     rapic_fn_list = s3_listing(prefix_cmd,h5_ffn);
     if ~isempty(rapic_fn_list)
         err_str = 'successful conversion, but file is already in archive';
     else
         %copy if new file
         file_cp(output_ffn,h5_ffn,0,1)
     end
