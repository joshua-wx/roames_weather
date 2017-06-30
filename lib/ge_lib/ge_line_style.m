function kml_str=ge_line_style(kml_str,Style_id,LineColor,LineWidth)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Generates a line style (colour and width) kml string
% INPUTS
% kml_str: string containing kml
% Style_id: style name containing a # (string)
% LineColor: line colour as a html hex string
% LineWidth: line width as a number (number)
% RETURNS
% kml_str: string containing kml
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

out=['<Style id="',Style_id,'">',10,...
        '<LineStyle>',10,...
            '<width>',num2str(LineWidth),'</width>',10,...
            '<color>',LineColor,'</color>',10,...
        '</LineStyle>',10,...
    '</Style>',10];

kml_str=[kml_str,out];
