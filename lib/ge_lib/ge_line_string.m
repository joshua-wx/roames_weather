function kml_out=ge_line_string(kml_in,vis,name,timeSpanStart,timeSpanStop,styleUrl,relative_altitude,altitudeMode,extrude,tessellate,start_lat_vec,start_lon_vec,end_lat_vec,end_lon_vec)
%WHAT: Creates a kml string in the line sereies format using a start and
%end point approach.

kml_out=[''];

%build timekml if values inputted, otherwise blank
if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

header=['<Placemark>',10,...
            '<name>',name,'</name>',10,...
            '<visibility>',num2str(vis),'</visibility>',10,...
            timekml,...
            '<styleUrl>',styleUrl,'</styleUrl>',10,...
            '<LineString>',10,...
                '<tessellate>',num2str(tessellate),'</tessellate>',10,...
                '<extrude>',num2str(extrude),'</extrude>',10,...
                '<altitudeMode>',altitudeMode,'</altitudeMode>',10,...
                '<coordinates>',10];
            
footer=        ['</coordinates>',10,...
            '</LineString>',10,...
        '</Placemark>',10];

    
line_str = '';
 for i=1:length(start_lat_vec)
     line_str=[line_str,...
         sprintf('%.6f,%.6f,%.6f', start_lon_vec(i), start_lat_vec(i), relative_altitude),10];
 end
 
 line_str=[line_str,sprintf('%.6f,%.6f,%.6f', end_lon_vec(i), end_lat_vec(i), relative_altitude),10];
 
 kml_out=[kml_out,header,line_str,footer];
 
 
 kml_out=[kml_in,kml_out];