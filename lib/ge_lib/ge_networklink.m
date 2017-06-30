function kml_str=ge_networklink(kml_str,name,Link,flyToView,refreshVisibility,refreshtime,region,timeSpanStart,timeSpanStop,visible)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Generates a network link kml string to a kml/kmz file
% INPUTS
% kml_str: string containing master kml
% name: string containing places kml (to wrap)
% Link: link to kml object (string)
% flyToView: flag for fly to view kml object (binary)
% refreshVisibility: flag to refresh visibility on a time interval (binary)
% refreshtime: refresh time interval (integer)
% region: region kml to apply regionation (string) generated for ge_region
% timeSpanStart: starting time for kml time span (GE timestamp) (str)
% timeSpanStop: stoping time for kml time span (GE timestamp) (str)
% visible: flag for visbility (binary)
% RETURNS
% kml_folders_str: string containing kml
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%Generates a network link kml string for a kml/kmz file.

if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end

if isempty(refreshtime)
    refresh_kml='';
else
    refresh_kml=['<refreshMode>onInterval</refreshMode>',10,...
                 '<refreshInterval>',num2str(refreshtime),'</refreshInterval>',10];
end
%wrap and output
out=['<NetworkLink>',10,...
        '<name>',name,'</name>',10,...
        '<visibility>',num2str(visible),'</visibility>',10,...   
        region,...
        timekml,...
        '<refreshVisibility>',num2str(refreshVisibility),'</refreshVisibility>',10,...
        '<flyToView>',num2str(flyToView),'</flyToView>',10,...
        '<Link>',10,...
            '<href>',Link,'</href>',10,...
            refresh_kml,...
        '</Link>',10,...
     '</NetworkLink>',10];
    
kml_str=[kml_str,out];
    
