function remove_corrupt_tilts

%start parallel processing pool
%delete(myPool)
%myPool = parpool();
  
prefix_cmd        = 'export LD_LIBRARY_PATH=/usr/lib; ';
brokenvol_s3_path = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';
odim_s3_path      = 's3://roames-weather-odimh5/odimh5_archive/';
mkdir('tmp')
radar_id = 0;
if ~isdeployed
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
        rapic_cell    = rapic_to_cell(input_ffn);
        rapic_cell    = clean_ray(rapic_cell);
        write_rapic_file(mod_rapic_ffn,rapic_cell);
        
        %inital conversion for error detection (remove converted file immediately, as we
        %know it's already broken)
        [sout,uout] = convert(prefix_cmd,mod_rapic_ffn,output_ffn);
        delete(mod_rapic_ffn)
        if sout == 0 && exist(output_ffn,'file')==2
            %output odimh5 to archive
            disp('success')
            err_str = 'successful conversion, rays cleaned only';
            err_str = output_odimh5(output_ffn,err_str,s3_ffn,radar_id,odim_s3_path,prefix_cmd)
            utility_log_write(log_ffn,s3_ffn,err_str,'')
            continue
        end
        
        %for a max of three tried (3 removed tilts)
        for j = 1:3
            
            %extract number of problem pass
            idx         = strfind(uout,'pass: ');
            if isempty(idx)
                err_str = 'error is not related to a tilt'
                uout
                break
            end            
            target_tilt = str2num(uout(idx+6:idx+7));
            
            %index start of all scans
            start_index = find(strcmp(rapic_cell,'COUNTRY: 036'));
            stop_index  = find(strcmp(rapic_cell,'END RADAR IMAGE'));
            tilt_index  = find(strncmp(rapic_cell,'PASS',4));
            if length(start_index) ~= length(stop_index); err_str = 'indexing failure of file'
                break; end
            if length(tilt_index)  ~= length(stop_index); err_str = 'indexing failure of file'
                break; end
            
            %build list of tilt index numbers
            tilt_list = [];
            for k=1:length(tilt_index)
                tilt_list(k) = str2num(rapic_cell{tilt_index(k)}(7:8));
            end
            
            %remove tilt
            remove_idx = find(tilt_list==target_tilt);
            rapic_cell(start_index(remove_idx):stop_index(remove_idx)) = [];
            
            %write to file
            write_rapic_file(mod_rapic_ffn,rapic_cell);
            
            %attempt reconversion
            [sout,uout] = convert(prefix_cmd,mod_rapic_ffn,output_ffn);
            if sout == 0 && exist(output_ffn,'file')==2
                %output odimh5 to archive
                disp('success')
                err_str = 'successful conversion, tilt removed';
                err_str = output_odimh5(output_ffn,err_str,s3_ffn,radar_id,odim_s3_path,prefix_cmd)
                break
            else
                %continue loop
                err_str = ['try ',num2str(j),' of three failed']
            end
            
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
    [sout,uout] = unix(['export HDF5_DISABLE_VERSION_CHECK=1; ',prefix_cmd,'rapic_to_odim ',input_ffn,' ',output_ffn]);

function rapic_cell = rapic_to_cell(ffn)
    %read file
    fid = fopen(ffn,'r','n','ISO-8859-1');
    uout = [];
    tline = ' ';
    while ischar(tline)
    tline = fgets(fid);
        uout  = [uout,tline];
    end
    %%%%
    %split text
    rapic_cell  = strsplit(uout, {char(0),char(10)});
    %remove image header
    header_end = find(strcmp(rapic_cell,'/IMAGEHEADER END:'));
    rapic_cell(1:header_end) = [];
    
function rapic_cell = clean_ray(rapic_cell)
    %remove appended rays rays
    find_out = strfind(rapic_cell,'%');
    err_idx  = find(cellfun(@length,find_out)>1);
    rapic_cell(err_idx) = [];
    %remove rays containing error messages
    find_out = strfind(rapic_cell,'MSSG');
    err_idx  = find(cellfun(@length,find_out)>0);
    rapic_cell(err_idx) = [];
    %containing rays containing header info (identified only by spaces)
    find_out    = strfind(rapic_cell,'%');
    ray_mask    = ~cellfun(@isempty,find_out);
    find_out    = strfind(rapic_cell,' ');
    header_mask = ~cellfun(@isempty,find_out);
    err_idx     = find(ray_mask & header_mask);
    rapic_cell(err_idx) = [];
    
    
    %remove tilts with too many rays
    start_index = find(strcmp(rapic_cell,'COUNTRY: 036'));
    stop_index  = find(strcmp(rapic_cell,'END RADAR IMAGE'));
    if length(start_index) == length(stop_index)
        %split rapic data into tilts
        tilt_cell = cell(length(start_index),1);
        for i=1:length(start_index)
            tilt_cell{i} = rapic_cell(start_index(i):stop_index(i));
        end
        %check if more than 360 rays are present
        for i=1:length(start_index)
            find_out = strfind(tilt_cell{i},'%');
            ray_idx  = find(~cellfun(@isempty,find_out));
            if length(ray_idx)>360
                tilt_cell{i}(ray_idx(361):ray_idx(end)) = [];
            end
        end
        %unpack tilts
        rapic_cell = [tilt_cell{:}];
    end
    

function write_rapic_file(rapic_ffn,rapic_cell)
    fid = fopen(rapic_ffn,'w','n','ISO-8859-1');
    rapic_text_out = strjoin(rapic_cell, char(0));
    fprintf(fid,'%s',rapic_text_out);
    fclose(fid);
    
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
     
     %remove s3 file
     file_rm(s3_ffn,0,1)