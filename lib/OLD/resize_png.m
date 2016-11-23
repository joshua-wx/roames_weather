function resize_png(ffn_in,scale)

%WHAT: loads png image,colourmap,transparency... resizes using scale...
%outputs back to where it was

[ppi_img,ppi_map,~] = imread(ffn_in,'png');
ppi_trans           = ones(length(ppi_map),1); ppi_trans(1) = 0;
[ppi_img,ppi_map]   = imresize(ppi_img,ppi_map,scale,'Colormap','original');
imwrite(ppi_img,ppi_map,ffn_in,'Transparency',ppi_trans);

