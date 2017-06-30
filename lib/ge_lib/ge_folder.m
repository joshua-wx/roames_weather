function kml_folders_str=ge_folder(kml_folders_str,kml_places_str,name,description,visible)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: wraps the kml_places_str in a folder with name, description and
% visibility
% INPUTS
% kml_folders_str: string containing master kml
% kml_places_str: string containing places kml (to wrap)
% name: name tag for place
% description: description tag for place
% visible: visibile tag for place
% RETURNS
% kml_folders_str: string containing kml
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%wrap kml
out=        ['<Folder>',10,...
                    '<name>',name,'</name>',10,...
                    '<visibility>',num2str(visible),'</visibility>',10,... 
                    '<description>',description,'</description>',10,...
                    kml_places_str,...
             '</Folder>',10];
         
kml_folders_str=[kml_folders_str,out];        
         
         
