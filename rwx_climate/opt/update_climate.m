function update_climate
%runs both the sync, climate and compile scripts
addpath('../')
sync_database;
climate;
compile_kmz;