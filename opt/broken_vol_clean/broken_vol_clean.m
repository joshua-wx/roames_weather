function broken_vol_clean

%start parallel processing pool
%delete(myPool)
%myPool = parpool();

%% init

%disable warnings that are triggered from using string replace on integers
warning('off','all')

%init paths
prefix_cmd        = 'export LD_LIBRARY_PATH=/usr/lib; ';
brokenvol_s3_path = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';
odim_s3_path      = 's3://roames-weather-odimh5/odimh5_archive/';
%init dir
mkdir('tmp')
%init libs
if ~isdeployed
    addpath('../../lib/m_lib')
    addpath('/home/meso/dev/roames_weather/etc');
end

%read config
config_fn = 'clean.config';
read_config(config_fn,[config_fn,'.mat'])
load([config_fn,'.mat'])
%parse 'all' radars into integer list
if strcmp(radar_id_list,'all')
    radar_id_list = 1:79;
else
    radar_id_list = str2num(radar_id_list);
end


%MAIN FUNCTION
%for each radar id, attempt correction
try
for z = 1:length(radar_id_list)
    
    %target radar id
    radar_id       = radar_id_list(z);
    
    %s3 file list
    temp_s3_path   = [brokenvol_s3_path,num2str(radar_id,'%02.0f'),'/'];
    load('fn_list.mat')
    %fn_list        = s3_listing(prefix_cmd,temp_s3_path);
    
    %logs file init
    log_ffn        = ['tmp/',num2str(radar_id,'%02.0f'),'broken_vol_clean.log'];
    
    for i = 1884:length(fn_list)
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
        vol_struct = vol_to_struct(input_ffn,radar_id);
        vol_struct = qc_vol(vol_struct);
        
        if isempty(vol_struct)
            disp('cleaned volume empty')
            delete(input_ffn)
            file_rm(s3_ffn,0,1)
            continue
        end
        
        write_rapic_file(mod_rapic_ffn,vol_struct);
        
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
            file_rm(s3_ffn,0,1)
            continue
        else
            err_str = ['error occured: ',uout] %fatal exception: level exceeding threshold table size encountered

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

    
    
function rapicdata = read_rapic_binary(ffn)
    %WHAT: reads rapic file without converting into strings
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    rapicdata = rapicdata';    


function vol_struct = vol_to_struct(ffn,r_id)
    %WHAT: reads rapicdata into tiltcells for later processing
    
    %read rapic data
    rapicdata   = read_rapic_binary(ffn);
    
    %% Corrupt rapic data
    %search and remove messages
    mssg_start_idx = strfind(rapicdata,double('MSSG'));
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
    %search and replace EFBFBD unicode replacement character with null (41)
    rapicdata = strrep(rapicdata,[239,191,189],41);
    
    %% init for line by line processing
    %find line breaks
    break_idx   = find(rapicdata == 0 | rapicdata == 10);
    line_count  = length(break_idx);

    %init vars
    scan_flag   = false; %used to indicate whether is scan is being record
    ray_flag    = false; %used to indicate start of ray block
    start_idx   = 1;
    rapic_tilt  = [];
    ray_list    = [];
    vol_struct  = [];
    
    %for each line
    for i=1:line_count+1
        
        %extract line
        if i == line_count+1
            %for last line
            rapic_line  = rapicdata(start_idx:break_idx(end));
        else
            %for not last line
            rapic_line  = rapicdata(start_idx:break_idx(i));
            start_idx   = break_idx(i)+1;
        end

        %% Corrupt rapic line
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
        
        %% collate ray
        %collate ray entries if currently processing scan (and continue)
        if scan_flag && rapic_line(1) == 37 %37 = '%'
            if ~ray_flag
                %qc tilt header
                [tilt_struct,scan_flag,encoding] = qc_tilt_header(tilt_struct,r_id);
            end
            %enforce ray number uniqueness (error fix)
            ray_number = str2num(char(rapic_line(2:4)));
            if scan_flag && ~any(ray_list==ray_number)
                ray_list   = [ray_list,ray_number];
                rapic_line = qc_ray(rapic_line,tilt_struct,encoding);
                rapic_tilt = [rapic_tilt,rapic_line];
                ray_flag   = true;
            end
            continue
        end
        
        %parse atts
        ts_out = textscan(char(rapic_line),'%s','Delimiter',':'); ts_out = ts_out{1};
        if isempty(ts_out{1})
            continue
        end
        if length(ts_out) == 2
            att_name = deblank(ts_out{1}); 
            att_val  = deblank(ts_out{2});
        else
            att_name = deblank(ts_out{1});
        end
        %start new tilt on COUNTRY att_name
        if strcmp(att_name,'COUNTRY')
            %reset
            scan_flag   = true;
            ray_flag    = false;
            ray_list    = [];
            tilt_struct = struct;
            %collate first line and country attribute
            rapic_tilt  = rapic_line;
            tilt_struct.atts.(att_name) = att_val;
            continue
            
        %stop tilt on END RADAR IMAGE att_name and append
        elseif strcmp(att_name,'END RADAR IMAGE') && scan_flag
            scan_flag  = false;
            rapic_tilt = [rapic_tilt,rapic_line];
            %check if empty
            if isempty(rapic_tilt)
                tilt_struct = [];
            else
                %append to tilt
                tilt_struct.rapicdata = rapic_tilt;
            end
            %append
            if isempty(vol_struct)
                vol_struct = tilt_struct;
            else
                vol_struct = [vol_struct,tilt_struct];
            end
            continue
            
        end
        %other header atts entries
        if scan_flag && ~ray_flag
            %if header att, parse into struct
            if isfield(tilt_struct.atts,att_name) %if duplicates exist
                scan_flag = false; %halt recording tilt
            else
                try
                    tilt_struct.atts.(att_name) = att_val;
                catch
                    disp('error pasing attribute name into struct')
                    continue
                end
                %remove invalid timestamps from rapicdata
                if strcmp(att_name,'TIMESTAMP')
                    if length(att_val)~=14
                        disp('timestamp corrupt')
                        rapic_line = '';
                    end
                end
            end
            %collate
            rapic_tilt = [rapic_tilt,rapic_line];
        end
    end
    

function [tilt_struct,scan_flag,encoding] = qc_tilt_header(tilt_struct,r_id)
    %check if range res is missing
    header_err = false;
    scan_flag  = true;
    encoding   = [];
    if any(~isfield(tilt_struct.atts,{'PRODUCT','STNID','RNGRES','ENDRNG','STARTRNG','ANGRES','VIDRES','TIMESTAMP'}))
        header_err = true;
    else
        %check station id matched target radar id
        stn_id      = str2num(tilt_struct.atts.STNID);
        if stn_id ~= r_id
            disp('station id does not match target radar id')
            header_err = true;
        end
        %check product is volumetric
        product_str = tilt_struct.atts.PRODUCT;
        if ~strncmp(product_str,'VOLUMETRIC',10)
            disp('product not volumetric')
            header_err = true;
        end
        %extract videores
        videores = tilt_struct.atts.VIDRES;
        if any(str2num(videores)==[16,32,64,160])
            f_name = ['vr',videores];
            encoding                  = rapic_encoding;
            tilt_struct.atts.vr_ref   = encoding.(f_name);
        else
            disp('video res extract error')
            header_err = true;
        end
        %extract number of bins
        try
            start_rng = str2num(tilt_struct.atts.STARTRNG);
            end_rng   = str2num(tilt_struct.atts.ENDRNG);
            rng_res   = str2num(tilt_struct.atts.RNGRES);
            n_bins    = (end_rng-start_rng)/rng_res;
            tilt_struct.atts.n_bins = n_bins;
        catch
            disp('num_bins calc error')
            header_err = true;
        end
    end
    
    %on any error, erase tilt_struct and halt scan
    if header_err
        tilt_struct = [];
        scan_flag   = false;
    end
    
function rapic_line = qc_ray(rapic_line,tilt_struct,encoding)
%     %% so basically we need to do a full decode
%     encoded_rapic = rapic_line(5:end);
%     decoded_rapic = [];
%     for i=1:length(encoded_rapic)
%         e_val = encoded_rapic(i);
%         %check if abs
%         abs_mask = e_val == encoding;
%         if any(abs_mask)
%             d_val = find(abs_mask)-1;
%             decoded_rapic = [decoded_rapic,d_val];
%             continue
%         end
%         %check dev
%         dev_mask = e_val == encoding.dev_encoding;
%         if any(dev_mask)
%             d_val1 = decoded_rapic(end) + encoding.dev_decoding1(abs_mask);
%             d_val2 = d_val1 + encoding.dev_decoding2(abs_mask);
%             decoded_rapic = [decoded_rapic,d_val1,d_val2];
%             continue
%         end
%         %check rle
%         rle_mask = e_val == encoding.run_encoding
%         if any(rle_mask)
%             rle_va
            
        
    
    
    %% video level check
    vr_ref = tilt_struct.atts.vr_ref;
    %check samples against vr_ref table
    data_sample = rapic_line(5:end);
    %compare videores to max values
    exceed_sum = sum(data_sample>max(vr_ref));
    if exceed_sum > 50
        keyboard
    end
    err_mask  = [repmat(false,1,4),~ismember(data_sample,vr_ref)];
    %remove invalid value if they exist
    if any(err_mask)
        disp('corrupt characters removed')
        rapic_line(err_mask) = [];
    end
    %% scan overflow check
    ray_len = 0;
    data_len = zeros(length(data_sample),1);
    %assign abs values to lengeth of one
    abs_mask = ismember(data_sample,encoding.abs); data_len(abs_mask) = 1;
    %assign dev values to a length of two
    dev_mask = ismember(data_sample,encoding.dev); data_len(dev_mask) = 2;
    %find rle encoding
    rle_mask = ismember(data_sample,encoding.rle);
    temp_rle = [];
    %collate integers and calculate length
    for i=1:length(rle_mask)
        if rle_mask(i)
            temp_rle = [temp_rle,data_sample(i)];
            if i == length(rle_mask)
                data_len(i) = str2num(char(temp_rle));
            elseif ~rle_mask(i+1)
                data_len(i) = str2num(char(temp_rle));
                temp_rle = [];
            end
        end
    end
    %check if overflow exists
    csum_data_len = cumsum(data_len);
    overflow_mask = csum_data_len>tilt_struct.atts.n_bins;
    %trim ray
    if any(overflow_mask)
        data_sample(overflow_mask) = [];
        rapic_line = [rapic_line(1:4),data_sample,0]; %preserve ray %### and null
    end


    

function vol_struct = qc_vol(vol_struct)

    
    %remove duplicated elevations
    elev_list = zeros(length(vol_struct),1);
    for i = 1:length(vol_struct)
        if isfield(vol_struct(i).atts,'ELEV')
            elev_list(i) = str2num(vol_struct(i).atts.ELEV);
        end
    end
    [~,uniq_idx,~] = unique(elev_list);
    vol_struct = vol_struct(uniq_idx);
    
    %delete volume if it has less than 10 tilts
    if length(vol_struct)<10
        vol_struct = [];
        disp('volume has less than 10 tilts, erased')
    end

    
    
    
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
     
function write_rapic_file(mod_rapic_ffn,vol_struct)
    rapicdata = [];
    for i=1:length(vol_struct)
        rapicdata = [rapicdata,vol_struct(i).rapicdata];
    end
    fid = fopen(mod_rapic_ffn,'w');
    fwrite(fid,rapicdata);
    fclose(fid);