function [kml_style,kml_object]=kml_contour(refvec , z, varargin)
%MODIFIED TO USE CONTOURM AND CLABELM, OUTPUT TO TEXT
% KML_CONTOUR      overlay MATLAB contour lines onto Google Earth
%
% Syntax:
%     KML_CONTOUR(LON,LAT,Z) writes contour lines in the same format as
%     matlab's CONTOUR(LON,LAT,Z) or CONTOURC(LON,LAT,Z).
%     KML_CONTOUR(LON,LAT,Z,N) draws N contour lines, overriding the
%     automatic value
%     KML_CONTOUR(LON,LAT,Z,V) draws LENGTH(V) contour lines at the values
%     specified in the vector V
%     KML_CONTOUR(LON,LAT,Z,[v v]) computes a single contour at the level v
%
% Input:
%     LON: This can be either a matrix the same size as Z or a vector with
%     length the same as the number of columns in Z.
%     LAT: This can be either a matrix the same size as Z or a vector with
%     length the same as the number of rows in Z.
%     Z: Matrix of elevations
%
% Output:
%     This function creates a kml file called 'doc.kml' in the current
%     working directory
%

%
% Cameron Sparr - Nov. 10, 2011
% cameronsparr@gmail.com
%
    
    % STYLES:
    % Edit the width, color, and labelsize as you see fit.
    %       color: MATLAB color value (default is 'w')
    %       width: int or float (default is 1)
    %       labelsize: size of text contour labels (default is 0.9)
    color = ge_color('k');
    width = 1;
    labelsize = 0.9;
    
    % FEEL FREE TO PLAY AROUND WITH THE VALUES SPECIFIED BELOW FOR
    % 'labellimit', 'labelspace', and 'contourlimit'
    %
    % Limit to how many points on a contour line are required for the
    % function to place an altitude label:
    labellimit = round(sqrt(sqrt(numel(z))));
    % Spacing between altitude labels:
    labelspace = labellimit * 8;
    % Contour lines with length below the following limit will not be drawn
    contourlimit = round(labellimit / 3);
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
    % output kml file:
    kml_object='';
    [c, h] = contourm(z, refvec,varargin{:});
    
    % specifies position in the 'c' matrix returned from MATLAB's CONTOUR
    % function. 
    ind = 1;
    
    % begin writing kml file:
    kml_style=kml_begin(labelsize, color, width);
    
    kml_line_object='';
    while ind < length(c)
        % altitude of current contour line
        zz = c(1,ind);
        % length of current contour line
        s = c(2,ind);
        
        % current contour line
        clon = c(1, ind+1 : ind+s);
        clat = c(2, ind+1 : ind+s);

        kml_line_object=line_begin(kml_line_object, zz);
        for i = 1:numel(clon)
            lon = num2str(clon(i), 8);
            lat = num2str(clat(i), 8);
            kml_line_object=[kml_line_object,lon,',',lat,',',num2str(zz),10];
        end
        kml_line_object=line_end(kml_line_object);

        % move ind up to the next contour line.
        ind = ind + s + 1;
    end
    
    disp('Using MATLAB native contour label positions');
    % use matlab positions for contour labels.
    lh = clabelm(c,h);
    pos = get(lh, 'position');
    height = get(lh, 'UserData');
    close(gcf);
    kml_text_object='';
    for ii = 1:length(pos)
        mlon = pos{ii}(1);
        mlat = pos{ii}(2);
        zzz = height{ii}(1);
        kml_text_object=place_label(kml_text_object, mlon, mlat, zzz, 0);
    end
    
    kml_object=ge_folder(kml_object,kml_text_object,'Contour Heights','units: m',0);
    kml_object=ge_folder(kml_object,kml_line_object,'Contours','50m interval',1);
end




function kml_style=kml_begin(labelsize, color, width)
    kml_style=['<Style id="sn_noicon">',10,...
                    '<IconStyle>',10,...
                        '<Icon>',10,...
                        '</Icon>',10,...
                    '</IconStyle>',10,...
                    '<LabelStyle>',10,...
                        '<scale>',...
                            num2str(labelsize),...
                        '</scale>',10,...
                    '</LabelStyle>',10,...
                '</Style>',10,...
                '<Style id="linestyle">',10,...
                    '<LineStyle>',10,...
                        '<color>#FF',...
                            color,...
                        '</color>',10,...
                        '<width>',...
                            num2str(width),...
                        '</width>',10,...
                    '</LineStyle>',10,...
                '</Style>',10];
end

function kml_object=line_begin(kml_object, zz)
    kml_object=[kml_object,'<Placemark>',10,...
                                '<name>', num2str(zz),'</name>',10,...
                                '<styleUrl>#linestyle</styleUrl>',10,...
                                '<LineString>',10,...
                                    '<tessellate>1</tessellate>',10,...
                                    '<altitudeMode>clampToGround</altitudeMode>',10,...
                                    '<coordinates>',10];
end

%<gx:altitudeMode>clampToGround</gx:altitudeMode>\n');

function kml_object=line_end(kml_object)
    kml_object=[kml_object,'</coordinates>',10,...
                    '</LineString>',10,...
            '</Placemark>',10];
end

function kml_object=place_label(kml_object, plon, plat, z, visible)
    z = round(z);
kml_object=[kml_object,'<Placemark>',10,...
                            '<name>', num2str(z),'</name>',10,...
                            '<styleUrl>#sn_noicon</styleUrl>',10,...
                            '<visibility>',num2str(visible),'</visibility>',10,... 
                            '<Point>',10,...
                                '<altitudeMode>clampToGround</altitudeMode>',10,...
                                '<coordinates>',num2str(plon, 8),',',num2str(plat, 8),',0</coordinates>',10,...
                            '</Point>',10,...
                       '</Placemark>',10];
end

function clrstr=ge_color(c,varargin)
%Jarrell Smith
%3/4/2008
    opacity=1;
    cspec=[0,0,0];

    nargchk(nargin,1,2);
    if nargin==2,
       mode='both';
       opacity=varargin{1};
       if length(opacity)>1 || ~isnumeric(opacity),
          error('Opacity must be numeric and length 1')
       elseif opacity>1 || opacity<0,
          error('Opacity must be between 0-1')
       end
    else
       mode='color';
    end
    if ischar(c), %process as color
       switch lower(c)
          case {'y','yellow'}
             cspec=[1,1,0];
          case {'m','magenta'}
             cspec=[1,0,1];
          case {'c','cyan'}
             cspec=[0,1,1];
          case {'r','red'}
             cspec=[1,0,0];
          case {'g','green'}
             cspec=[0,1,0];
          case {'b','blue'}
             cspec=[0,0,1];
          case {'w','white'}
             cspec=[1,1,1];
          case {'k','black'}
             cspec=[0,0,0];
          otherwise
             error('%s is an invalid Matlab ColorSpec.',c)
       end
    elseif isnumeric(c) && ndims(c)==2, %Determine if Color or Opacity
       if  all(size(c)==[1,1]), %Input is Opacity
          if c>1 || c<0
             error('Opacity must be scalar quantity between 0 to 1')
          end
          opacity=c;
          mode='opacity';
       %color
       elseif all(size(c)==[1,3]) %Input is Color
          if any(c<0|c>1)
             error('Numeric ColorSpec must be size [1,3] with values btw 0 to 1.')
          end
          cspec=c;
       else
          error('Incorrect size of first input argument.  Size must be [1,3] or [1,1].')
       end
    else
       error('Incorrect size of first input argument.  Size must be [1,3] or [1,1].')
    end
    opacity=round(opacity*255); %transparency (Matlab format->KML format)
    cspec=round(fliplr(cspec)*255); %color (Matlab format->KML format)
    switch mode
       case 'color'
          clrstr=sprintf('%s%s%s',dec2hex(cspec,2)');
       case 'opacity'
          clrstr=sprintf('%s',dec2hex(opacity,2));
       case 'both'
          clrstr=sprintf('%s%s%s%s',dec2hex(opacity,2),dec2hex(cspec,2)');
    end
end