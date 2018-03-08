function remove_archive_section

mkdir('tmp')

%add path to filerm
addpath('../../lib/m_lib')

%s3root
s3root = 's3://roames-weather-odimh5/odimh5_archive/broken_vols/';

%radar list
radarid_list = [01:79];

%set rm list
rm_datelist= {'200707';...
              '200708';...
              '200709';...
              '200710';...
              '200711';...
              '200712';...
              '200801';...
              '200802';...
              '200803'};
%loop
for i=1:length(radarid_list)
    s3_odimh5_path = [s3root,num2str(radarid_list(i),'%02.0f'),'/'];
    rapic_fn_list  = s3_listing(s3_odimh5_path);
    rm_idx         = find(contains(rapic_fn_list,rm_datelist));
    for j=1:length(rm_idx)
        s3_path = [s3_odimh5_path,rapic_fn_list{rm_idx(j)}]
        file_rm(s3_path,1,1);
        pause(0.2)
    end
end


function rapic_fn_list = s3_listing(s3_odimh5_path)
    prefix_cmd    = 'export LD_LIBRARY_PATH=/usr/lib; ';
    rapic_fn_list = {};
    %ls s3 path
    cmd         = [prefix_cmd,'aws s3 ls ',s3_odimh5_path];
    [sout,uout] = unix(cmd);
    %read text
    if ~isempty(uout)
        C             = textscan(uout,'%*s %*s %*u %s');
        rapic_fn_list = C{1};
    end
    
    
          
          
              