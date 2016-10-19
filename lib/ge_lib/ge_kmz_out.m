function ge_kmz_out(kmzfilename,kml_str,destination_folder,cappi_path)
%HELP
%Writes doc.kml containing kml_str to tempdir, then zips and
%renames the extension to kmz and moves it to the destination folder.
%INPUTS
%kmzfilename: filename string without the extension for the kmz file
%kml_str: kml code for doc.kml
%destination_folder: path to copy kmz file to
%cappi_path: the file path to the cappi image file, can be run without this

%create header and footer
header = ['<?xml version="1.0" encoding="UTF-8"?>',10,...
    '<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">',10,...
    '<Document>',10,...
    '<name>',kmzfilename,'</name>',10];

footer = [10,'</Document>',10,...
    '</kml>',10];

%create filename with extension and create/open kml file
kmlfilename = strcat('doc.kml');
kmzfilename = strcat(kmzfilename,'.kmz');
fid = fopen( [tempdir,kmlfilename], 'wt');

%write header, kml_data and footer to kml_file
fprintf(fid,'%s',header);
fprintf(fid,'%s',kml_str);
fprintf(fid,'%s',footer);
    
fclose('all');

%zip and remove .zip extension when moving to destination folder, additonal
%step is there is an image path.
if isempty(cappi_path)
    zip([tempdir,kmzfilename],[tempdir,kmlfilename]);
    delete([tempdir,kmlfilename]);
else
    if iscell(cappi_path)
        zip([tempdir,kmzfilename],{[tempdir,kmlfilename],cappi_path{:}});
%         for i=1:length(cappi_path)
%             delete(cappi_path{i});
%         end
    else
        zip([tempdir,kmzfilename],{[tempdir,kmlfilename],cappi_path});
%        delete(cappi_path);
    end
    delete([tempdir,kmlfilename]);
end
    
movefile([tempdir,kmzfilename,'.zip'],[destination_folder,kmzfilename]);

