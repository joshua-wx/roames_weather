function [eout] = rapic_to_odim_wrapper(input_ffn,output_path,output_fn)

%WHAT: Batch script for rapid_odim in matlab. Needs to be converted to
%bash. Does not support subdirectories. Requires rapic_to_odim utility
%installed. Attempts from correction of corrupt files (missing \n
%character)

eout          = [];

%set output_ffn
output_ffn = [output_path,output_fn];

%push through rapic_to_odim
[sout,eout] = unix(['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',input_ffn,' ',output_ffn]); %note, reset lD path from matlab to system default
if sout==1
    display(eout)
    display('attempting fix')
    
    %read in file
    fid = fopen(input_ffn);
    tline = fgets(fid);
    rapic_str = '';
    while ischar(tline)
        rapic_str = [rapic_str,tline];
        tline = fgets(fid);
    end
    fclose(fid);
    
    %check for missing line ends after %
    ind1 = strfind(rapic_str,[char(0),'%'])+1;
    ind2 = strfind(rapic_str,'%');
    repair_ind = setxor(ind1,ind2);
    %repair as needed
    if ~isempty(repair_ind)
        display('missing line end characters, repairing')
        for j=1:length(repair_ind)
            rapic_str = [rapic_str(1:repair_ind(j)-1),char(0),rapic_str(repair_ind(j):end)];
            %move everything forward one with new character
            repair_ind=repair_ind+1;
        end
        %write back to temp file
        temp_fn = '/tmp/temp.rapic';
        fid = fopen(temp_fn,'wt');
        fprintf(fid,'%s',rapic_str);
        fclose(fid);
        %try and convert again
        [sout,eout] = unix(['export LD_LIBRARY_PATH=/usr/lib; rapic_to_odim ',temp_fn,' ',output_ffn]); %note, reset lD path from matlab to system default
        if sout == 1
            display('missing line end characters fix failed')
            display(eout)
        else
            display('fix worked')
        end
        delete(temp_fn)
    else
        display('###############likely a ray too large is causing this error, no fix is implemented')
    end
    %remaining issue: The second file fails because of an extremely long run length provided on the ray corresponding to 326 degrees.  The ASCII data mentioned above can perform run length encoding for file compression.  In this case the offending fragment is "JA849:M".  The letters/punctuation decode to absolute levels (reflectivities) while the numbers indicate a number of times to repeat the previous level.  In this fragment A (level 0 == -30dBZ) is followed by 849 indicating that there should 850 range bins in a row of -30.  Since the scan only has 480 range bins this is a corrupt ray.
end