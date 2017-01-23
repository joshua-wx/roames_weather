function [newAngle] = polar2compass(oldAngle)
%WHAT: Program to convert angles measured counter-clockwise from the x-axis to
%angles on the compass (measured clockwise from North)
%
%Soupy Alexander (2/4/2)

newAngle = (360 - oldAngle) + 90;
newAngle(newAngle > 360) = newAngle(newAngle > 360) - 360;

%for index = 1:length(oldAngle);
%    newAngle(index) = (360 - oldAngle(index)) + 90;
%    if newAngle(index) > 360;
%        newAngle(index) = newAngle(index) - 360;
%    end
%end


        
