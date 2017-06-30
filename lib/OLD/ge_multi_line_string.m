function kml_out=ge_multi_line_string(kml_in,vis,name,styleUrl,relative_altitude,altitudeMode,extrude,tessellate,timeSpanStart,timeSpanStop,vec_cellarray)
%written to convert streamline data into kml

if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

kml_out=[''];

line_header=['<LineString>',10,...
            '<tessellate>',num2str(tessellate),'</tessellate>',10,...
            '<extrude>',num2str(extrude),'</extrude>',10,...
            '<altitudeMode>',altitudeMode,'</altitudeMode>',10,...
            '<coordinates>',10];

line_footer=['</coordinates>',10,...
            '</LineString>',10];

%loop through cellarray of vector data groups
for i=1:length(vec_cellarray)
    vec_data=vec_cellarray{i};
    if ~isempty(vec_data)
        temp_kml='';
        for j=1:size(vec_data,1)
            temp_kml=[temp_kml,sprintf('%.6f,%.6f,%.6f', vec_data(j,1), vec_data(j,2), relative_altitude),10];
        end
        kml_out=[kml_out,line_header,temp_kml,line_footer];
    end
end

%create custom header for multigeometry
group_header=['<Placemark>',10,...
                '<name>',name,'</name>',10,...
                '<visibility>',num2str(vis),'</visibility>',10,...
                timekml,...
                '<styleUrl>',styleUrl,'</styleUrl>',10,...
                '<MultiGeometry>',10];

%create custom footer
group_footer=['</MultiGeometry>',10,...
                '</Placemark>',10];

kml_out=[kml_in,group_header,kml_out,group_footer];