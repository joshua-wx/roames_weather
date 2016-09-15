function [dist,ang] = pos2dist(lat1,lon1,lat2,lon2)
% function dist = pos2dist(lat1,lon1,lat2,lon2,method)
% calculate distance between two points on earth's surface
% given by their latitude-longitude pair.
% Input lat1,lon1,lat2,lon2 are in degrees, without 'NSWE' indicators.
% Method calculates sphereic geodesic distance for points farther apart,
% but ignores flattening of the earth:
% d =
% R_aver * acos(cos(lat1)cos(lat2)cos(lon1-lon2)+sin(lat1)sin(lat2))
% Output dist is in km.
% Returns -99999 if input argument(s) is/are incorrect.
% Flora Sun, University of Toronto, Jun 12, 2004.

if nargin < 4
    dist = -99999;
    disp('Number of input arguments error! distance = -99999');
    return;
end
%wrap lon
if lon1 < 0
    lon1 = lon1 + 360;
end
lon2(lon2<0) = lon2(lon2<0) + 360;

if abs(lat1)>90 | sum(abs(lat2)>90)~=0 | abs(lon1)>360 | sum(abs(lon2)>360)~=0
    dist = [dist;-99999];
    disp('Degree(s) illegal! distance = -99999');
    return;
end

lat1=repmat(lat1,size(lat2,1),size(lat2,2));
lon1=repmat(lon1,size(lon2,1),size(lon2,2));

R_aver = 6374;
deg2rad = pi/180;
lat1 = lat1.*deg2rad;
lon1 = lon1.*deg2rad;
lat2 = lat2.*deg2rad;
lon2 = lon2.*deg2rad;
dist = R_aver.*acos(cos(lat1).*cos(lat2).*cos(lon1-lon2) + sin(lat1).*sin(lat2));

