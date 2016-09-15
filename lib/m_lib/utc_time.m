function utc_datenum=utc_time
% WHAT
% returns the utc time in datenum format

%convert java utc time into utc datenum
java_time   = java.lang.System.currentTimeMillis;
utc_datenum = addtodate(datenum(1970,01,01,0,0,0), java_time, 'millisecond');

%remove second value
t_vec=datevec(utc_datenum); t_vec(6)=0;
%convert to local datenum then utc datenum
utc_datenum=datenum(t_vec);