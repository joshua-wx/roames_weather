function kml_places_str=ge_poly_placemark(kml_places_str,Style_id,name,timeSpanStart,timeSpanStop,altitudeMode,tessellate,X,Y,Z)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT:  creates a single polygon from x=long, y=lat, z=alt
% INPUTS
% kml_str: string containing kml
% Style_id: style name containing a # (string)
% name: name for kml object (String)
% timeSpanStart: starting time for kml time span (GE timestamp) (str)
% timeSpanStop: stoping time for kml time span (GE timestamp) (str)
% altitudemode: string containing an acceptable altitudemode clamped/absolute
% tessellate: smooth line using tesselation (binary)
% X: array containing lon coordinates for rapid string generation (matrix)
% Y: array containing lat coordinates for rapid string generation (matrix)
% Z: array containing alt coordinates for rapid string generation (matrix)
% RETURNS
% kml_str: string containing kml
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%WHAT: creates a single polygon from x=long, y=lat, z=alt

coord=[];
for i=1:length(X)
    coord=[coord,...
        sprintf('%.6f,%.6f,%.6f ', X(i), Y(i), Z(i))];
end

%build timekml if values inputted, otherwise blank
if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

%create custom header for multigeometry
header=['<Placemark>',10,...
            '<name>',name,'</name>',10,...
            '<styleUrl>',Style_id,'</styleUrl>',10,...
            timekml];
        
%create custom footer
footer=['</Placemark>',10];

poly=  ['<Polygon>',10,...
			'<altitudeMode>',altitudeMode,'</altitudeMode>',10,...
            '<tessellate>',num2str(tessellate),'</tessellate>',10,...
			'<outerBoundaryIs>',10,...
				'<LinearRing>',10,...
					'<coordinates>',10,...
						coord,10,...	
					'</coordinates>',10,...
				'</LinearRing>',10,...	
			'</outerBoundaryIs>',10,...
		'</Polygon>',10];
    
kml_places_str=[kml_places_str,header,poly,footer];
