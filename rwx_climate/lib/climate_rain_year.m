function rain_year = climate_rain_year(dt_num,start_month)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: calculate the rain year for each date num entry. Example 2010 rain year runs
%from 1/7/2010 to 31/6/2011
% INPUTS
% dt_num: vector of datenums (str)
% start_month: starting month of rain year (double)
% RETURNS: rain_year: rain year of each dt_num
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%init, extract calendar year
dt_vec    = datevec(dt_num);
rain_year = dt_vec(:,1);
%loop through every date num
for i=1:length(dt_num)
    %change rain_years if month is between Jan-June
    if dt_vec(i,2)<=start_month
        %case: Jan-June, use year before
        rain_year(i)=dt_vec(i,1)-1;
    end
end
