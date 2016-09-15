function kml_str=ge_screenoverlay(kml_str,name,path,screen_x,screen_y,size_x,size_y,timeSpanStart,timeSpanStop)
%WHAT: generates the kml string for overlaying logos on the screen.

%INPUT:
%screen_x,screen_y: location as a fraction from bottom left corner
%size_x,size_y: size of overlay as a fraction of the size of the screen.
%value:0 keep aspect ratio

%NOTE:
%ALWAYS ANCHORS TO THE BOTTOM LEFT OF THE IMAGE, overlay XY set =0

%build timekml if values inputted, otherwise blank
if isempty(timeSpanStart)
    timekml='';
else
    timekml=['<TimeSpan><begin>' timeSpanStart '</begin><end>' timeSpanStop '</end></TimeSpan>',10];
end


out='';

out=['<ScreenOverlay>',10,...
        '<name>',name,'</name>',10,...
        timekml,...
        '<Icon>',10,...
             '<href>',path,'</href>',10,...
        '</Icon>',10,...
        '<overlayXY x="0" y="0" xunits="fraction" yunits="fraction"/>',10,...
        '<screenXY x="',num2str(screen_x),'" y="',num2str(screen_y),'" xunits="fraction" yunits="fraction"/>',10,...
        '<size x="',num2str(size_x),'" y="',num2str(size_y),'" xunits="fraction" yunits="fraction"/>',10,...
      '</ScreenOverlay>',10];
  
  
kml_str=[out,kml_str];