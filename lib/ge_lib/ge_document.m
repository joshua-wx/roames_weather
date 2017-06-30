function kml_out=ge_document(kml_in,name)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Applies/wraps the document kml header and footer to the kml input
% INPUTS
% kml_str: string containing kml
% name: name for document wrapper
% RETURNS
% kml_str: string containing kml
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

kml_out=     ['<Document>',10,...
                    '<name>',name,'</name>',10,...
                    kml_in,...
             '</Document>',10];   
         
         
