function rapic_cell = rapic_to_cell(ffn)
    %read file
    fid       = fopen(ffn);
    rapicdata = fread(fid);
    %search and destory messages
    mssg_start_idx = strfind([char(rapicdata)'],'MSSG');
    mssg_mask      = false(length(rapicdata),1);
    %remove messages
    break_idx = find(rapicdata == 0);
    if ~isempty(mssg_start_idx)
        for i=1:length(mssg_start_idx)
            mssg_stop_idx = find(break_idx>mssg_start_idx(i),1,first);
            mssg_mask(mssg_start_idx(i):mssg_stop_idx) = true;
        end
    end
    rapicdata(mssg_mask) = [];
    keyboard
    %find breaks
    break_idx = find(rapicdata == 0);
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
