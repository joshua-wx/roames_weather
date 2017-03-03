function [snd_datenum,snd_fifty_dbz_min_h]=calc_freezing_h(snd_path)

%WHAT: Finds the freezing levels from processes sounding data. Applies the
%nomogram formula from Nicholas Campbell (2012) to the freezing level data
%to calculate the 50dbz threshold.

snd_datenum=[];
snd_fifty_dbz_min_h=[];

if exist(snd_path,'file')~=2 && ~isempty(snd_path)
    msgbox('sounding path does not exist')
    keyboard
end

%check is path is a file
if exist(snd_path,'file')==2
    %load mat file
    load(snd_path)
    fz_h=[];
    
    %loop through morning index vector
    for i=1:length(morning_ind)
        %load cooresponding morning temp and gph vectors for morning i
        cur_snd_temp=snd_temp{morning_ind(i)};
        cur_snd_gph=snd_gph{morning_ind(i)};

        %remove all nan rows
        cur_snd_nan=~isnan(cur_snd_temp.*cur_snd_gph);
        cur_snd_temp=cur_snd_temp(cur_snd_nan);
        cur_snd_gph=cur_snd_gph(cur_snd_nan);
        
        %find the indices of entries above and below the fz level
        fz_lt_ind=find(cur_snd_temp<0,1,'first');
        fz_ge_ind=find(cur_snd_temp>=0,1,'last');

        %check if these values exist
        if isempty(fz_lt_ind) | isempty(fz_ge_ind)
            continue
        end
        
        %subset around 0
        temp_sset=[cur_snd_temp(fz_ge_ind),cur_snd_temp(fz_lt_ind)];
        gph_sset=[cur_snd_gph(fz_ge_ind),cur_snd_gph(fz_lt_ind)];
        %interpolate
        out=interp1(temp_sset,gph_sset,0);
        %reject crazy values
        if out<1000
            continue
        end
        %save
        fz_h=[fz_h,out];
        snd_datenum=[snd_datenum,morning_snd_date(i)];
    end
    %convert meters to feet
    fz_h=fz_h.*3.2808399;
    %apply formula and convert back then km (ouput is in m...)
    snd_fifty_dbz_min_h=(17.536*fz_h.^(.662))./1000;
end