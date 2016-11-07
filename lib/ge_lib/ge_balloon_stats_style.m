function kml_str=ge_balloon_stats_style(kml_str,Style_id)
%WHAT: Generates the style kml for the storm stats ballon with the extended
%data template and the icon http link

out=['<Style id="',Style_id,'">',10,...
        '<BalloonStyle>',10,...
            '<text>',10,...
            '<![CDATA[',10,...
                'VILD: $[vild] g/m^3',10,...
                'MaxExpHailSize: $[mesh] mm',10,...
                'EchoTopHeight: $[tops] m',10,...
                'Ident Id:     $[ident_id]',10,...
            ']]>',10,...
            '</text>',10,...
       '</BalloonStyle>',10,...
       '<IconStyle>',10,...
			'<Icon>',10,...
				'<href>http://www.myiconfinder.com/uploads/iconsets/256-256-bcfd5fd1da3195cb34be5b122393d83d-thunder.png</href>',10,...
			'</Icon>',10,...
		'</IconStyle>',10,...
        '<LabelStyle>',10,...
            '<scale>0</scale>',10,...
        '</LabelStyle>',10,...    
    '</Style>',10];

kml_str=[kml_str,out];