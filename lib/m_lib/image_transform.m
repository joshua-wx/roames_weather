function data_out = image_transform(data_in,type,min_value)

%find no data regions
data_alpha = logical(data_in==min_value);
%scale to true value using transformation constants
if strcmp(type,'refl');
        %scale for colormapping
        data_out = (data_in-min_value)*2+1;
        %enforce no data regions
        data_out(data_alpha) = 1;
else strcmp(type,'vel');
        %scale for colormapping
        data_out = (data_in-min_value)+1;
        %enforce no data regions
        data_out(data_alpha) = 1;
end