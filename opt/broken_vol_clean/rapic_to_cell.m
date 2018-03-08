function rapic_cell = rapic_to_cell(ffn)
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    %find breaks
    break_idx = find(rapicdata == 0 | rapicdata == 10);
    %build rapic cell
    break_count = length(break_idx);
    rapic_cell  = cell(break_count+1,1);
    start_idx   = 1;
    %collate into cells using breaks
    for i=1:break_count
        rapic_cell{i} = rapicdata(start_idx:break_idx(i));
        start_idx     = break_idx(i)+1;
    end
    rapic_cell{end}   = rapicdata(start_idx:break_idx(end));
