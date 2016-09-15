function ge_kml_out(filename,name,kml_str)
%WHAT: Saves kml string to file


header = ['<?xml version="1.0" encoding="UTF-8"?>',10,...
    '<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">',10,...
    '<Document>',10,...
    '<name>',name,'</name>',10];

footer = [10,'</Document>',10,...
    '</kml>',10];


kmlfilename = strcat(filename,'.kml');

fid = fopen( kmlfilename, 'wt');

    fprintf(fid,'%s',header);
    fprintf(fid,'%s',kml_str);
    fprintf(fid,'%s',footer);  
    
fclose(fid);

%disp(['Building ' filename '...Done']) 
