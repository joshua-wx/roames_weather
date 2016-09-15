function kml_places_str=ge_multi_poly_placemark2(kml_places_str,Style_id,place_id,visibility,faces,vertices,timeSpanStart,timeSpanStop)
%generates a multi geometry polygon placemark kml file fir the faces and
%vertices matrices listed (see matlab patch help).

if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

%setup polygon header and footer to increase speed and preallocate cells.
poly_cell=cell(1,length(faces)*3);
poly_header=['<Polygon>',...
                '<altitudeMode>','absolute','</altitudeMode>',...
                '<outerBoundaryIs>',...
                    '<LinearRing>',...
                        '<coordinates>'];
poly_footer=['</coordinates>',...
				'</LinearRing>',...	
			'</outerBoundaryIs>',...
		'</Polygon>'];

if ~isempty(faces)
    for i = 0:length(faces)-1
                   %X    Y    Z
        coord=sprintf('%.6f,%.6f,%.6f \n%.6f,%.6f,%.6f \n%.6f,%.6f,%.6f \n%.6f,%.6f,%.6f ',vertices(faces(i+1,:),:)');
        poly_cell{i*3+1}=poly_header;
        poly_cell{i*3+2}=coord;
        poly_cell{i*3+3}=poly_footer;
    end
    %convert poly cell to char
     poly_string=[poly_cell{:}];
    %create custom header for multigeometry
    header=['<Placemark>',10,...
                '<name>',place_id,'</name>',10,...
                '<visibility>',num2str(visibility),'</visibility>',10,... 
                timekml,...
                '<styleUrl>',Style_id,'</styleUrl>',10,...
                '<MultiGeometry>',10];

    %create custom footer
    footer=[    '</MultiGeometry>',10,...
            '</Placemark>',10];

    kml_places_str=[kml_places_str,header,poly_string,10,footer];
end

    
    