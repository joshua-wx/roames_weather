function svg_path_write(svg_struct,out_ffn)

%WHAT: write groups in svg_struct of polygons to outffn
%svg_struct contains n groups of polygons, where each group contains an id
%and multiple storm swaths

%svg_struct.group##.id
%svg_struct.group##.path##.id
%svg_struct.group##.path##.fill_c
%svg_struct.group##.path##.fill_o
%svg_struct.group##.path##.stroke_c
%svg_struct.group##.path##.stroke_w
%svg_struct.group##.path##.stroke_o
%svg_struct.group##.path##.path_wkt
%<path d="M 100,50 200,150 100,100 z" fill="none" stroke="black"/>

%init svg header and footer
svg_header = [...
'<?xml version="1.0" encoding="UTF-8" standalone="no"?>',10,...
'<svg',10,...
   9,'xmlns:svg="http://www.w3.org/2000/svg"',10,...
   9,'xmlns="http://www.w3.org/2000/svg"',10,...
   9,'version="1.1"',10,...
   9,'id="svg2"',10,...
   9,'viewBox="0 0 1 1">',10];
svg_footer = '</svg>';
g_f = fieldnames(svg_struct); %group field names

svg_str = '';
%loop through groups
for i = 1:length(g_f)
    %init group header and footer
    group_id     = g_f{i};
    group_str    = '';
    group_header = [9,'<g',10,9,9,'id="',group_id,'">',10];
    group_footer = [9,'</g>',10];
    %loop through paths
    p_f          = fieldnames(svg_struct.(group_id)); %path field names
    for j = 1:length(p_f)
        %init path header and footer
        path_id     = p_f{j};
        path_header = [9,9,'<path',10];
        path_footer = [' />',10];
        %styling
        fill_c      = svg_struct.(group_id).(path_id).fill_c;
        fill_o      = svg_struct.(group_id).(path_id).fill_o;
        stroke_c    = svg_struct.(group_id).(path_id).stroke_c;
        stroke_w    = svg_struct.(group_id).(path_id).stroke_w;
        stroke_o    = svg_struct.(group_id).(path_id).stroke_o;
        style_str   = [9,9,9,'style=','"fill:',fill_c,';fill-opacity:',fill_o,';stroke:',stroke_c,';stroke-width:',stroke_w,';stroke-opacity:',stroke_o,'"',10];
        %path id
        path_id_str = [9,9,9,'id="',path_id,'"',10];
        %path wkt
        path_str    = [9,9,9,'d="M ',svg_struct.(group_id).(path_id).path_wkt,' z"',10];
        %append to group str
        tmp_str     = [path_header,style_str,path_id_str,path_str,path_footer];
        group_str   = [group_str,tmp_str];
    end
    %append group header and footer
    tmp_str = [group_header,group_str,group_footer];
    %append to svg str
    svg_str = [svg_str,tmp_str];
end
%append svg header and footer
svg_str = [svg_header,svg_str,svg_footer];

%write to file
fid = fopen(out_ffn,'wt');
fprintf(fid,'%s',svg_str);
fclose(fid);


