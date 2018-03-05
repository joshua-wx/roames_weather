fn = '~/broken_vol.50.log';

fid = fopen(fn);
C   = textscan(fid,'%s %s %s','Delimiter',',')
fclose(fid)

error_fn        = C{1};
error_msg       = C{2};
error_msg_short = C{3};

[uniq_msg,ia,ic] = unique(error_msg_short);

uniq_msg_count = zeros(length(uniq_msg),1);
for i=1:length(uniq_msg)
    uniq_msg_count(i) = sum(ic==i);
end
[uniq_msg_count,sort_idx] = sort(uniq_msg_count,'descend');
uniq_msg                  = uniq_msg(sort_idx);

fid2 = fopen('stats.out','wt')
for i=1:length(uniq_msg)
    fprintf(fid2,'%s \n',[num2str(uniq_msg_count(i)),',',uniq_msg{i}]);
end
fclose(fid2)

keyboard
