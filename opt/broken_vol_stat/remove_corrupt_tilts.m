function remove_corrupt_tilts

prefix_cmd     = 'export LD_LIBRARY_PATH=/usr/lib; ';

%file list
listing = dir('/home/meso/radar_temp'); listing(1:2) = [];
listing(1:2) = [];
fn_list = {listing.name};

success_count = 0;
for i = 1:length(fn_list)
    %setup
    input_ffn  = ['/home/meso/radar_temp/',fn_list{i}];
    output_ffn = [tempdir,fn_list{i},'.h5'];
    disp(['processing file ',num2str(i),' of ',num2str(length(fn_list))])
    %check file size
    out = dir(input_ffn);
    file_sz = out.bytes/1000;
    if file_sz < 20
        disp('too small to be volume')
        continue
    end
    %convert rapic to cell for analysis
    rapic_cell  = rapic_to_cell(input_ffn);
    %write back to temp file (removes headers)
    mod_rapic_ffn = tempname;
    write_rapic_file(mod_rapic_ffn,rapic_cell);
    %first pass for error detection
    [sout,uout] = convert(prefix_cmd,mod_rapic_ffn,output_ffn);
    delete(mod_rapic_ffn)
    %extract failed pass index
    idx = strfind(uout,'pass: ');
    if isempty(idx)
        disp('error is not a tilt issue')
        uout
        continue
    end
    %convert rapic to cell for analysis
    rapic_cell  = rapic_to_cell(input_ffn);
    %remove a maximum of three tilts
    for j = 1:3
        %extract number of problem pass
        idx         = strfind(uout,'pass: ');
        if isempty(idx)
            disp('error is no longer a tilt issue')
            break
        end            
        target_tilt = str2num(uout(idx+6:idx+7));
        %index start of all scans
        start_index = find(strcmp(rapic_cell,'COUNTRY: 036'));
        stop_index  = find(strcmp(rapic_cell,'END RADAR IMAGE'));
        tilt_index  = find(strncmp(rapic_cell,'PASS',4));
        if length(start_index) ~= length(stop_index); disp('indexing failure of file'); break; end
        if length(tilt_index)  ~= length(stop_index); disp('indexing failure of file'); break; end
        %build list of tilt index numbers
        tilt_list = [];
        for k=1:length(tilt_index)
            tilt_list(k) = str2num(rapic_cell{tilt_index(k)}(7:8));
        end
        %remove tilt
        remove_idx = find(tilt_list==target_tilt);
        rapic_cell(start_index(remove_idx):stop_index(remove_idx)) = [];
        %write to file
        mod_rapic_ffn = tempname;
        write_rapic_file(mod_rapic_ffn,rapic_cell);
        %attempt reconversion
        [sout,uout] = convert(prefix_cmd,mod_rapic_ffn,output_ffn);
        delete(tempname)
        if sout == 0
            %break loop, it worked!
            disp('success')
            success_count = success_count+1;
            break
        else
            %continue loop
            disp(['try ',num2str(j),' of three failed'])
        end
    end
end


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
    

function write_rapic_file(rapic_ffn,rapic_cell)
    fid = fopen(rapic_ffn,'w','n','ISO-8859-1');
    rapic_text_out = strjoin(rapic_cell, char(0));
    fprintf(fid,'%s',rapic_text_out);
    fclose(fid);