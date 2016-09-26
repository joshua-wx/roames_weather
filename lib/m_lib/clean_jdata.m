function out = clean_jdata(in,type)



if strcmp(type,'N')
    out = vertcat(in.(type));
    out = str2num(out);
else
    out = {in.(type)}';
end



%determine type (string or number)
