function [f_poly_dist,f_poly_az_x,f_poly_az_y,f_poly_stats]=storm_history_fit(hist_dist,hist_az_x,hist_az_y,hist_stats,hist_min,max_hist_cells)
%WHAT: Fits a polynomial to the historical data of the supplied weighted
%storm data (contains multiple tracks which are seperated into cells of the
%input)

%INPUTS: Outputs of storm_weighted_history
%max_hist_cells: from global config: maximum number of cells to use for the
%polynomial fit

%OUTPUT: Polynomial coefficents (max first order) of the input y data sets

%blank poly variables
f_poly_dist     = [];
f_poly_az_x     = [];
f_poly_az_y     = [];
f_poly_stats    = [];

%loop though the tracks in the historical data (cell arrays)
for i=1:length(hist_dist);
    %pass x,y data to linear fit and the order
    f_poly_dist     = [f_poly_dist;linear_fit(hist_dist{i},hist_min{i},1,max_hist_cells)]; %1st order
    f_poly_az_x     = [f_poly_az_x;linear_fit(hist_az_x{i},hist_min{i}(2:end),0,max_hist_cells)]; %0th order
    f_poly_az_y     = [f_poly_az_y;linear_fit(hist_az_y{i},hist_min{i}(2:end),0,max_hist_cells)]; %0th order
    f_poly_stats    = [f_poly_stats;{linear_fit(hist_stats{i},hist_min{i},1,max_hist_cells)}]; %1st order
end

function polycoef=linear_fit(y_data,td,order,max_hist_cells)
%WHAT: calculates the polynomial coefficients for the x and y data (using
%order). Length of input data is limited by max_hist cells)

%INPUT:
%y_data: matrix/vec with the same number of rows as td
%td: timeseries x data in datenum
%order: polynomial order to interpolate
%max_hist_cell: from global config, maximum length of input data

%OUTPUT:
%polycoef: col1: 1st order coef, col2: 0th order coef

polycoef=[];
%loop through the colums of y_data
for i=1:size(y_data,2)
    %select column
    y_vec=y_data(:,i);
    %crop the length of the input data if required
    if length(y_vec)>max_hist_cells
        y_vec=y_vec(1:max_hist_cells);
        td=td(1:max_hist_cells);
    end
    %check for non NaN vaules
    nan_mask=~isnan(y_vec);
    if length(unique(td(nan_mask)))==1
        %only unique td point to fit polynomial, use 0th order by taking the mean of
        %non nan y_vec values
        polycoef=[polycoef;[0,mean(y_vec(nan_mask))]];
        continue
    elseif length(y_vec(nan_mask))==0
        %no values to fit polynomial, use 0,0
        polycoef=[polycoef;[0,0]];
        continue
    end
    %more than 1 data point, use polyfit
        %warning('')
    p=polyfit(td(nan_mask),y_vec(nan_mask),order);
        %if ~isempty(lastwarn)
        %    keyboard
        %end
    %append a 1st order value to 0th order outputs of polyfit
    if order==0
        p=[0,p]; %add a 1st order value of 0
    end
    %append polyfit output to polycoef
    polycoef=[polycoef;p];
end
