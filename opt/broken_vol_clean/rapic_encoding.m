function encoding = rapic_encoding

%absolute encoding
                %0    1    2    3    4    5    6    7    8    9
abs_encoding = {'41','42','43','44','45','46','47','48','49','4a',... %000-009
                '4b','4c','4d','4e','4f','50','22','27','2a','2c',... %010-019
                '3a','3b','3d','3f','51','52','5a','5e','5f','7a',... %020-029
                '7c','7e','80','81','82','83','84','85','86','87',... %030-039
                '88','89','8a','8b','8c','8d','8e','8f','90','91',... %040-049
                '92','93','94','95','96','97','98','99','9a','9b',... %050-059
                '9c','9d','9e','9f','a0','a1','a2','a3','a4','a5',... %060-069
                'a6','a7','a8','a9','aa','ab','ac','ad','ae','af',... %070-079
                'b0','b1','b2','b3','b4','b5','b6','b7','b8','b9',... %080-089
                'ba','bb','bc','bd','be','bf','c0','c1','c2','c3',... %090-099
                'c4','c5','c6','c7','c8','c9','ca','cb','cc','cd',... %100-109
                'ce','cf','d0','d1','d2','d3','d4','d5','d6','d7',... %110-119
                'd8','d9','da','db','dc','dd','de','df','e0','e1',... %120-129
                'e2','e3','e4','e5','e6','e7','e8','e9','ea','eb',... %130-139
                'ec','ed','ee','ef','f0','f1','f2','f3','f4','f5',... %140-149
                'f6','f7','f8','f9','fa','fb','fc','fd','fe','ff'};   %150-159    
abs_encoding  = hex2dec(abs_encoding)';

%deviation encoding
dev_encoding = ['![abc]@',...
                '/defgh\',...
                'ijk<lmn',...
                'op-.+qr',...
                'stu>vwx',...
                '(ySTUV)',...
                '${WXY}&'];
dev_encoding = double(dev_encoding);            

%run length encoding
run_encoding = '0123456789';
run_encoding = double(run_encoding);

%build encodings
encoding = struct;
encoding.vr16  = [abs_encoding(1:16),dev_encoding,run_encoding,0];
encoding.vr32  = [abs_encoding(1:32),dev_encoding,run_encoding,0];
encoding.vr64  = [abs_encoding(1:64),dev_encoding,run_encoding,0];
encoding.vr160 = [abs_encoding(1:160),dev_encoding,run_encoding,0];
encoding.null  = abs_encoding(1);