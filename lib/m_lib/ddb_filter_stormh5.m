function [ffn_list] = ddb_filter_stormh5(stormh5_ddb_table,datetime_list,radarid_list)
%WHAT: filters files in stormh5_ddb using date and radarid lists, outputs
%stormh5 filenames

%INPUT
%stormh5_ddb_table
%datetime_list: list of matlab datenums of length n
%radarid_list:  list of radar ids of length n

%OUTPUT
%ffn_list: updated list of storm.h5 files

%init pending_list
ffn_list      = {};

%read staging index
p_exp            = 'data_ffn'; %attributes to return

for i=1:length(datetime_list)
    tmp_date    = datetime_list(i);
    tmp_radarid = radarid_list(i);
    date_id     = datestr(tmp_date,'ddmmyyyy');
    sort_id     = [datestr(tmp_date,'yyyy-mm-ddTHH:MM:SS'),'_',num2str(tmp_radarid,'%02.0f')];
    jstruct     = ddb_query_begins('date_id',date_id,'sort_id',sort_id,p_exp,stormh5_ddb_table);
    tmp_ffnlist = jstruct_to_mat([jstruct.data_ffn],'S');
    ffn_list    = [ffn_list;tmp_ffnlist];
end

%preserve unqiue filenames (stormh5 contains cells, which are stored in a
%single storm.h5 file)
ffn_list = unique(ffn_list);