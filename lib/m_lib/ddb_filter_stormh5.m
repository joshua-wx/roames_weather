function [ffn_list] = ddb_filter_stormh5(ddb_table,datetime_list,radarid_list)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: filters files in stormh5_ddb using date and radarid lists, outputs
%stormh5 filenames
% INPUTS
% ddb_table: ddb table name (str)
% datetime_list: list of dates (in datenum, int)
% radar_id_list: list of radar ids (int)
% RETURNS
% ffn_list: list of storm.h5 files (cell array of strings)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%init pending_list
ffn_list      = {};

%read staging index
p_exp            = 'data_ffn'; %attributes to return

%loop through date list, running ddb query for each date
for i=1:length(datetime_list)
    tmp_date    = datetime_list(i);
    tmp_radarid = radarid_list(i);
    date_id     = datestr(tmp_date,'ddmmyyyy');
    sort_id     = [datestr(tmp_date,'yyyy-mm-ddTHH:MM:SS'),'_',num2str(tmp_radarid,'%02.0f')];
    jstruct     = ddb_query_begins('date_id',date_id,'sort_id',sort_id,p_exp,ddb_table);
    %if ddb exists, append ffn to list
    if ~isempty(jstruct)
        tmp_ffnlist = jstruct_to_mat([jstruct.data_ffn],'S');
        ffn_list    = [ffn_list;tmp_ffnlist];
    end
end

%preserve unqiue filenames (stormh5 contains cells, which are stored in a
%single storm.h5 file)
ffn_list = unique(ffn_list);