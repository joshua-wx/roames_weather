function str=html_color(trans,map)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: converts a colormap in the format [0,1] [r,g,b] and trans [0,1] into a hex
% html string
% INPUTS
% trans: transparency factor (0->1 double)
% map:   RGB 1x3 vector (0->1 double)
% RETURNS
% str: string containing html colour string [transparency,b,g,r] (str)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%WHAT:
%converts a colormap in the format [0,1] [r,g,b] and trans [0,1] into a hex
%html string

%convert to 255 colormap
map=round(255.*map);
trans=round(255*trans);
%restructure into b,g,r format in hex
str=[ dec2hex(trans,2),dec2hex(map(3),2),dec2hex(map(2),2),dec2hex(map(1),2) ];