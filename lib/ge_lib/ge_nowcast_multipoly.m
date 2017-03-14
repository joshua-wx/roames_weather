function kml_places_str=ge_nowcast_multipoly(kml_places_str,Style_id,name,timeSpanStart,timeSpanStop,altitudeMode,tessellate,X_cell,Y_cell,Z_cell,ballon_struct)
%generates a multi geometry polygon placemark kml for nowcasting polygons
%including an intergrates ballon data using balloon_struct. Note, if z_cell is empty, is
%prefilled with zeros

%setup balloon graph datasets
%write matrices to text format for 3 datasets
x_data  = sprintf('%4.2f,',ballon_struct.x_data); x_data=x_data(1:end-1);
y_data1 = sprintf('%4.2f,',ballon_struct.y_data1); y_data1=y_data1(1:end-1);
y_data2 = sprintf('%4.2f,',ballon_struct.y_data2); y_data2=y_data2(1:end-1);
y_data3 = sprintf('%4.2f,',ballon_struct.y_data3); y_data3=y_data3(1:end-1);

%timestamp kml string
if isempty(timeSpanStart)
    timekml = '';
else
    timekml = ['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

%setup polygon header and footer to increase speed and preallocate cells.
poly_header=['<Polygon>',...
                '<altitudeMode>',altitudeMode,'</altitudeMode>',...
                '<tessellate>',num2str(tessellate),'</tessellate>',10,...
                '<outerBoundaryIs>',...
                    '<LinearRing>',...
                        '<coordinates>'];
poly_footer=['</coordinates>',...
        '</LinearRing>',...
        '</outerBoundaryIs>',...
        '</Polygon>'];
%create cell for storing coord strings
poly_cell=cell(1,length(X_cell)*3);    
for i = 1:length(X_cell)
    X_vec = X_cell{i};
    Y_vec = Y_cell{i};
    if ~isempty(Z_cell)
        Z_vec = Z_cell{i};
    else
        Z_vec = zeros(size(X_vec));
    end
    coord=[];
    for j=1:length(X_vec)
        %X    Y    Z
        coord = [coord,...
            sprintf('%.6f,%.6f,%.6f ', X_vec(j), Y_vec(j), Z_vec(j))];
    end
    %append to cell array as a vector
    poly_cell{(i-1)*3+1} = poly_header;
    poly_cell{(i-1)*3+2} = coord;
    poly_cell{(i-1)*3+3} = poly_footer;
end
%convert poly cell to char
poly_string=[poly_cell{:}];
%create custom header for multigeometry
header=['<Placemark>',10,...
    '<name>',name,'</name>',10,...
    timekml,...
    '<styleUrl>',Style_id,'</styleUrl>',10,...
    '<ExtendedData>',10,...
        '<Data name="table_html">',10,...
            '<value>',ballon_struct.table_html,'</value>',10,...
        '</Data>',10,...
        '<Data name="x_data1">',10,...
            '<value>',x_data,'</value>',10,...
        '</Data>',10,...
        '<Data name="y_data1">',10,...
            '<value>',y_data1,'</value>',10,...
        '</Data>',10,...
        '<Data name="ctitle1">',10,...
            '<value>',ballon_struct.ctitle1,'</value>',10,...
        '</Data>',10,...
        '<Data name="x_data2">',10,...
            '<value>',x_data,'</value>',10,...
        '</Data>',10,...
        '<Data name="y_data2">',10,...
            '<value>',y_data2,'</value>',10,...
        '</Data>',10,...
        '<Data name="ctitle2">',10,...
            '<value>',ballon_struct.ctitle2,'</value>',10,...
        '</Data>',10,...
        '<Data name="x_data3">',10,...
            '<value>',x_data,'</value>',10,...
        '</Data>',10,...
        '<Data name="y_data3">',10,...
            '<value>',y_data3,'</value>',10,...
        '</Data>',10,...
        '<Data name="ctitle3">',10,...
            '<value>',ballon_struct.ctitle3,'</value>',10,...
        '</Data>',10,...
    '</ExtendedData>',10,...
    '<MultiGeometry>',10];

%create custom footer
footer=[    '</MultiGeometry>',10,...
    '</Placemark>',10];

kml_places_str=[kml_places_str,header,poly_string,10,footer];


    
    