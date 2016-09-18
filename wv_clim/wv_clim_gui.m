function varargout = wv_clim_gui(varargin)
% WV_CLIM_GUI MATLAB code for wv_clim_gui.fig
%      WV_CLIM_GUI, by itself, creates a new WV_CLIM_GUI or raises the existing
%      singleton*.
%
%      H = WV_CLIM_GUI returns the handle to a new WV_CLIM_GUI or the handle to
%      the existing singleton*.
%
%      WV_CLIM_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WV_CLIM_GUI.M with the given input arguments.
%
%      WV_CLIM_GUI('Property','Value',...) creates a new WV_CLIM_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before wv_clim_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to wv_clim_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help wv_clim_gui

% Last Modified by GUIDE v2.5 17-Apr-2015 13:38:25

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @wv_clim_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @wv_clim_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before wv_clim_gui is made visible.
function wv_clim_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to wv_clim_gui (see VARARGIN)
addpath('../libraries/functions','../libraries/ge_functions','../config_files');

% LOAD ZONE DATA INTO GUI
if exist('site_info.mat','file')~=2
    read_site_info
end
load('site_info.mat')
for i=1:length(site_s_name_list)
    site_s_name_list{i}=['IDR_',num2str(site_id_list(i)),'_',site_s_name_list{i}];
end

set(handles.site_dlg,'string',site_s_name_list)

%LOAD GUI CONFIG
if exist('clim_gui_config.mat','file')~=2
    msgbox('clim_gui_config.mat not found, creating default config file')
    %src data
    arch_dir        = '/media/meso/storage/wv_proced_arch/';
    snd_ffn        = 'snd_data/UA02D_fzh_97-14_uniq_morn.mat';
    %time domain
    date_start      = '01/07/1997'; %UTC TIME
    date_stop       = '31/06/2014';
    date_list_ffn      = '';
    time_start      = '00:00';
    time_stop       = '12:00';
    month_selection = '1,2,3,4,5,6,7,8,9,10,11,12';
    %site selection
    site_selection  = 50;
    latlon          = '';
    %layer options
    grid_opt        = 1;
    dir_opt         = 1;
    ci_opt          = 0;
    ce_opt          = 0;
    %Processing options
    type_opt        = 1;
    min_track_cells = '2';
    grid_lower      = '20';
    grid_upper      = 'nan';
    grid_c_lim      = 'nan';
    days_normalise  = 1;
    ce_diff         = 8;
    cent_grid       = 5000;
    years_normalise  = 0;
    %clim output
    clim_dir        = '~/Dropbox/PhD/wv_clim_out/';
    ge_save         = 1;
    td_mat          = 1;
    log_stats       = 0;
    image_save      = 1;
    
    %save to file
    save('clim_gui_config.mat',...
        'arch_dir','snd_ffn',...
        'date_start','date_stop','date_list_ffn','time_start','time_stop','month_selection',...
        'site_selection','latlon',...
        'grid_opt','dir_opt','ci_opt','ce_opt',...
        'type_opt','min_track_cells','grid_lower','grid_upper','grid_c_lim','days_normalise','ce_diff','cent_grid','years_normalise',...
        'clim_dir','ge_save','td_mat','log_stats','image_save');
end

%load from file
load clim_gui_config.mat
%src data
set(handles.arch_dir_txt,'string',arch_dir);
set(handles.snd_ffn_txt,'string',snd_ffn);
%time domain
set(handles.date_start_txt,'string',date_start);
set(handles.date_stop_txt,'string',date_stop);
set(handles.date_list_ffn_txt,'string',date_list_ffn);
set(handles.time_start_txt,'string',time_start);
set(handles.time_stop_txt,'string',time_stop);
set(handles.month_selection_txt,'string',month_selection);
%site options
set(handles.site_dlg,'value',site_selection);
set(handles.latlon_txt,'string',latlon);
%layer options
set(handles.grid_opt_dlg,'value',grid_opt);
set(handles.dir_opt_chk,'value',dir_opt);
set(handles.ci_opt_chk,'value',ci_opt);
set(handles.ce_opt_chk,'value',ce_opt);
%processing options
set(handles.type_opt_dlg,'value',type_opt);
set(handles.min_track_cells_txt,'string',min_track_cells);
set(handles.grid_lower_txt,'string',grid_lower);
set(handles.grid_upper_txt,'string',grid_upper);
set(handles.grid_c_lim_txt,'string',grid_c_lim);
set(handles.day_normalise_chk,'value',days_normalise);
set(handles.ce_diff_txt,'string',ce_diff);
set(handles.cent_grid_txt,'string',cent_grid);
set(handles.years_normalise_chk,'value',years_normalise);
%clim output
set(handles.clim_dir_txt,'string',clim_dir);
set(handles.ge_save_chk,'value',ge_save);
set(handles.td_mat_chk,'value',td_mat);
set(handles.log_stats_chk,'value',log_stats);
set(handles.image_save_chk,'value',image_save);

% Choose default command line output for wv_clim_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
% UIWAIT makes wv_clim_gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = wv_clim_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in kml_out_chk.
function kml_out_chk_Callback(hObject, eventdata, handles)
% hObject    handle to kml_out_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of kml_out_chk


% --- Executes on button press in bttn.
function bttn_Callback(hObject, eventdata, handles)
% hObject    handle to bttn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%% Load GUI variables
load('site_info.mat')
%src data
arch_dir        = get(handles.arch_dir_txt,'string');
snd_ffn        = get(handles.snd_ffn_txt,'string');
%time domain
date_start      = get(handles.date_start_txt,'string');
date_stop       = get(handles.date_stop_txt,'string');
date_list_ffn   = get(handles.date_list_ffn_txt,'string');
time_start      = get(handles.time_start_txt,'string');
time_stop       = get(handles.time_stop_txt,'string');
month_selection = get(handles.month_selection_txt,'string');
%site options
site_selection  = get(handles.site_dlg,'value');
latlon          = get(handles.latlon_txt,'string');
%layer options
grid_opt        = get(handles.grid_opt_dlg,'value');
dir_opt         = get(handles.dir_opt_chk,'value');
ci_opt          = get(handles.ci_opt_chk,'value');
ce_opt          = get(handles.ce_opt_chk,'value');
%processing options
type_opt        = get(handles.type_opt_dlg,'value');
min_track_cells = get(handles.min_track_cells_txt,'string');
grid_lower      = get(handles.grid_lower_txt,'string');
grid_upper      = get(handles.grid_upper_txt,'string');
grid_c_lim      = get(handles.grid_c_lim_txt,'string');
days_normalise  = get(handles.day_normalise_chk,'value');
ce_diff         = get(handles.ce_diff_txt,'string');
cent_grid       = get(handles.cent_grid_txt,'string');
years_normalise = get(handles.years_normalise_chk,'value');

%clim output
clim_dir        = get(handles.clim_dir_txt,'string');
ge_save         = get(handles.ge_save_chk,'value');
td_mat          = get(handles.td_mat_chk,'value');
log_stats       = get(handles.log_stats_chk,'value');
image_save      = get(handles.image_save_chk,'value');

%% save GUI variables to file
save('clim_gui_config.mat',...
    'arch_dir','snd_ffn',...
    'date_start','date_stop','date_list_ffn','time_start','time_stop','month_selection',...
    'site_selection','latlon',...
    'grid_opt','dir_opt','ci_opt','ce_opt',...
    'type_opt','min_track_cells','grid_lower','grid_upper','grid_c_lim','days_normalise','ce_diff','cent_grid','years_normalise',...
    'clim_dir','ge_save','td_mat','log_stats','image_save');

%% prepare GUI variables for clim app

if isempty(min_track_cells) || isempty(grid_lower) || isempty(grid_upper) || isempty(grid_c_lim)
    msgbox('a textbox in processing options is empty')
    return
end

if isempty(time_start) || isempty(time_stop) || isempty(date_start) || isempty(date_stop)
    msgbox('a textbox in time options is empty')
    return
end

if ci_opt && ce_opt
    msgbox('Both ci and ce options are selected')
    return
end

if years_normalise && days_normalise
    msgbox('Both years_normalise and days_normalise cannot be selected')
    return
end

%extract site_id
site_id         = site_id_list(site_selection);
if ~isempty(latlon)
    latlon_box = str2num(latlon);
else
    latlon_box=[];
end
        
%collate options
proc_opt        = [str2num(min_track_cells),str2num(grid_lower),str2num(grid_upper),str2num(grid_c_lim),days_normalise,str2num(ce_diff),str2num(cent_grid),years_normalise];
output_opt      = [td_mat,log_stats,image_save,ge_save];

%build clim dir with gui options saved to a text file
clim_dir=[clim_dir,'Climatology_for_IDR',num2str(site_id),'_@_',datestr(now,'dd-mm-yy_HHMMSS'),'/'];
%check status of clim_dir
if ~isdir(clim_dir)
    mkdir(clim_dir);
end

%save options to config file
fid = fopen([clim_dir,'config.txt'],'wt');
fprintf(fid,'%s\n\n',['GUI Parameter list used for climatology']);

fprintf(fid,'%s\n',['Generation Time: ',datestr(now)]);
fprintf(fid,'%s\n',['snd_ffn: ',        snd_ffn]);
fprintf(fid,'%s\n',['date_start: ',     date_start]);
fprintf(fid,'%s\n',['date_stop: ',      date_stop]);
fprintf(fid,'%s\n',['date_list_ffn: ',  date_list_ffn]);
fprintf(fid,'%s\n',['time_start: ',     time_start]);
fprintf(fid,'%s\n',['time_stop: ',      time_stop]);
fprintf(fid,'%s\n',['month_selection: ',month_selection]);
fprintf(fid,'%s\n',['site_selection: ', num2str(site_selection)]);
fprintf(fid,'%s\n',['latlon: ',         latlon]);
fprintf(fid,'%s\n',['grid_opt: ',       num2str(grid_opt)]);
fprintf(fid,'%s\n',['dir_opt: ',        num2str(dir_opt)]);
fprintf(fid,'%s\n',['ci_opt: ',         num2str(ci_opt)]);
fprintf(fid,'%s\n',['ce_opt: ',         num2str(ce_opt)]);
fprintf(fid,'%s\n',['type_opt: ',       num2str(type_opt)]);
fprintf(fid,'%s\n',['min_track_cells: ',min_track_cells]);
fprintf(fid,'%s\n',['grid_lower: ',     grid_lower]);
fprintf(fid,'%s\n',['grid_upper: ',     grid_upper]);
fprintf(fid,'%s\n',['grid_c_lim: ',     grid_c_lim]);
fprintf(fid,'%s\n',['days_normalise: ', num2str(days_normalise)]);
fprintf(fid,'%s\n',['ce diff: ',        ce_diff]);
fprintf(fid,'%s\n',['cent grid: ',      cent_grid]);
fprintf(fid,'%s\n',['years_normalise: ', num2str(years_normalise)]);

fclose(fid);

%time
time_start  = datenum(time_start);
time_stop   = datenum(time_stop);
time_start  = time_start-floor(time_start);
time_stop   = time_stop-floor(time_stop);

%date
date_start = datenum(date_start,'dd/mm/yy');
date_stop = datenum(date_stop,'dd/mm/yy');
td_opt   = [date_start,date_stop,time_start,time_stop];

%create struct
opt_struct      = struct('grid_opt',grid_opt,'ci_opt',ci_opt,'ce_opt',ce_opt,'dir_opt',dir_opt,...
    'type_opt',type_opt,'proc_opt',proc_opt,...
    'output_opt',output_opt,'td_opt',td_opt,'month_selection',month_selection,...
    'date_list_ffn',date_list_ffn,'site_id',site_id,'snd_ffn',snd_ffn,'latlon_box',latlon_box,...
    'clim_dir',clim_dir,'arch_dir',arch_dir);

%close figure
close(gcf)
%pass to wv_control
wv_clim(opt_struct);


function arch_dir_txt_Callback(hObject, eventdata, handles)
% hObject    handle to arch_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of arch_dir_txt as text
%        str2double(get(hObject,'String')) returns contents of arch_dir_txt as a double


% --- Executes during object creation, after setting all properties.
function arch_dir_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to arch_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in all_chk.
function all_chk_Callback(hObject, eventdata, handles)
% hObject    handle to all_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of all_chk


% --- Executes on selection change in site_dlg.
function site_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to site_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns site_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from site_dlg


% --- Executes during object creation, after setting all properties.
function site_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to site_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function site_no_txt_Callback(hObject, eventdata, handles)
% hObject    handle to site_no_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of site_no_txt as text
%        str2double(get(hObject,'String')) returns contents of site_no_txt as a double


% --- Executes during object creation, after setting all properties.
function site_no_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to site_no_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function date_start_txt_Callback(hObject, eventdata, handles)
% hObject    handle to date_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of date_start_txt as text
%        str2double(get(hObject,'String')) returns contents of date_start_txt as a double


% --- Executes during object creation, after setting all properties.
function date_start_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to date_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function date_stop_txt_Callback(hObject, eventdata, handles)
% hObject    handle to date_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of date_start_txt as text
%        str2double(get(hObject,'String')) returns contents of date_start_txt as a double


% --- Executes during object creation, after setting all properties.
function date_stop_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to date_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function clim_dir_txt_Callback(hObject, eventdata, handles)
% hObject    handle to clim_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of clim_dir_txt as text
%        str2double(get(hObject,'String')) returns contents of clim_dir_txt as a double


% --- Executes during object creation, after setting all properties.
function clim_dir_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clim_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2


% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in density_chk.
function density_chk_Callback(hObject, eventdata, handles)
% hObject    handle to density_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of density_chk


% --- Executes on button press in vild_chk.
function vild_chk_Callback(hObject, eventdata, handles)
% hObject    handle to vild_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of vild_chk


% --- Executes on button press in tops_chk.
function tops_chk_Callback(hObject, eventdata, handles)
% hObject    handle to tops_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tops_chk


% --- Executes on button press in dbz_chk.
function dbz_chk_Callback(hObject, eventdata, handles)
% hObject    handle to dbz_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dbz_chk


% --- Executes on button press in fifty_chk.
function fifty_chk_Callback(hObject, eventdata, handles)
% hObject    handle to fifty_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fifty_chk


% --- Executes on button press in checkbox19.
function checkbox19_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox19 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox19


% --- Executes on button press in checkbox20.
function checkbox20_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox20 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox20


% --- Executes on button press in checkbox21.
function checkbox21_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox21


% --- Executes on button press in volume_chk.
function volume_chk_Callback(hObject, eventdata, handles)
% hObject    handle to volume_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of volume_chk


% --- Executes on button press in area_chk.
function area_chk_Callback(hObject, eventdata, handles)
% hObject    handle to area_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of area_chk


% --- Executes on button press in avg_rr_chk.
function avg_rr_chk_Callback(hObject, eventdata, handles)
% hObject    handle to avg_rr_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of avg_rr_chk


% --- Executes on button press in max_rr_chk.
function max_rr_chk_Callback(hObject, eventdata, handles)
% hObject    handle to max_rr_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of max_rr_chk


% --- Executes on button press in max_dbz_h_chk.
function max_dbz_h_chk_Callback(hObject, eventdata, handles)
% hObject    handle to max_dbz_h_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of max_dbz_h_chk


% --- Executes on button press in avg_dbz_chk.
function avg_dbz_chk_Callback(hObject, eventdata, handles)
% hObject    handle to avg_dbz_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of avg_dbz_chk


% --- Executes on button press in g_vild_chk.
function g_vild_chk_Callback(hObject, eventdata, handles)
% hObject    handle to g_vild_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of g_vild_chk


% --- Executes on button press in mass_chk.
function mass_chk_Callback(hObject, eventdata, handles)
% hObject    handle to mass_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mass_chk


% --- Executes on button press in max_50dbz_h_chk.
function max_50dbz_h_chk_Callback(hObject, eventdata, handles)
% hObject    handle to max_50dbz_h_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of max_50dbz_h_chk


% --- Executes on button press in c_vild_chk.
function c_vild_chk_Callback(hObject, eventdata, handles)
% hObject    handle to c_vild_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of c_vild_chk


% --- Executes on button press in c_tilt_chk.
function c_tilt_chk_Callback(hObject, eventdata, handles)
% hObject    handle to c_tilt_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of c_tilt_chk


% --- Executes on button press in c_orient_chk.
function c_orient_chk_Callback(hObject, eventdata, handles)
% hObject    handle to c_orient_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of c_orient_chk


% --- Executes on button press in density_chk.
function swaths_chk_Callback(hObject, eventdata, handles)
% hObject    handle to density_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of density_chk



function min_track_cells_txt_Callback(hObject, eventdata, handles)
% hObject    handle to min_track_cells_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of min_track_cells_txt as text
%        str2double(get(hObject,'String')) returns contents of min_track_cells_txt as a double


% --- Executes during object creation, after setting all properties.
function min_track_cells_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to min_track_cells_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function min_50dbz_h_txt_Callback(hObject, eventdata, handles)
% hObject    handle to min_50dbz_h_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of min_50dbz_h_txt as text
%        str2double(get(hObject,'String')) returns contents of min_50dbz_h_txt as a double


% --- Executes during object creation, after setting all properties.
function min_50dbz_h_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to min_50dbz_h_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function max_track_cells_txt_Callback(hObject, eventdata, handles)
% hObject    handle to max_track_cells_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of max_track_cells_txt as text
%        str2double(get(hObject,'String')) returns contents of max_track_cells_txt as a double


% --- Executes during object creation, after setting all properties.
function max_track_cells_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to max_track_cells_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function month_selection_txt_Callback(hObject, eventdata, handles)
% hObject    handle to month_selection_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of month_selection_txt as text
%        str2double(get(hObject,'String')) returns contents of month_selection_txt as a double


% --- Executes during object creation, after setting all properties.
function month_selection_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to month_selection_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function time_stop_txt_Callback(hObject, eventdata, handles)
% hObject    handle to time_stop_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of time_stop_txt as text
%        str2double(get(hObject,'String')) returns contents of time_stop_txt as a double


% --- Executes during object creation, after setting all properties.
function time_stop_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to time_stop_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function time_start_txt_Callback(hObject, eventdata, handles)
% hObject    handle to time_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of time_start_txt as text
%        str2double(get(hObject,'String')) returns contents of time_start_txt as a double


% --- Executes during object creation, after setting all properties.
function time_start_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to time_start_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function date_list_ffn_txt_Callback(hObject, eventdata, handles)
% hObject    handle to date_list_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of date_list_ffn_txt as text
%        str2double(get(hObject,'String')) returns contents of date_list_ffn_txt as a double


% --- Executes during object creation, after setting all properties.
function date_list_ffn_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to date_list_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in direction_chk.
function direction_chk_Callback(hObject, eventdata, handles)
% hObject    handle to direction_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of direction_chk


% --- Executes on button press in ci_chk.
function ci_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ci_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ci_chk



function latlonbox_txt_Callback(hObject, eventdata, handles)
% hObject    handle to latlonbox_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of latlonbox_txt as text
%        str2double(get(hObject,'String')) returns contents of latlonbox_txt as a double


% --- Executes during object creation, after setting all properties.
function latlonbox_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to latlonbox_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function snd_ffn_txt_Callback(hObject, eventdata, handles)
% hObject    handle to snd_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of snd_ffn_txt as text
%        str2double(get(hObject,'String')) returns contents of snd_ffn_txt as a double


% --- Executes during object creation, after setting all properties.
function snd_ffn_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to snd_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ge_save_chk.
function ge_save_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ge_save_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ge_save_chk


% --- Executes on button press in td_mat_chk.
function td_mat_chk_Callback(hObject, eventdata, handles)
% hObject    handle to td_mat_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of td_mat_chk


% --- Executes on button press in log_stats_chk.
function log_stats_chk_Callback(hObject, eventdata, handles)
% hObject    handle to log_stats_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of log_stats_chk


% --- Executes on button press in image_chk.
function image_chk_Callback(hObject, eventdata, handles)
% hObject    handle to image_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of image_chk


% --- Executes on button press in sts_only_chk.
function sts_only_chk_Callback(hObject, eventdata, handles)
% hObject    handle to sts_only_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of sts_only_chk


% --- Executes on button press in ts_only_chk.
function ts_only_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ts_only_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ts_only_chk


% --- Executes on button press in thresh_cel_plot_rado.
function thresh_cel_plot_rado_Callback(hObject, eventdata, handles)
% hObject    handle to thresh_cel_plot_rado (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of thresh_cel_plot_rado


% --- Executes on button press in ts_cells_plot_rado.
function ts_cells_plot_rado_Callback(hObject, eventdata, handles)
% hObject    handle to ts_cells_plot_rado (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ts_cells_plot_rado



function grid_upper_txt_Callback(hObject, eventdata, handles)
% hObject    handle to grid_upper_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of grid_upper_txt as text
%        str2double(get(hObject,'String')) returns contents of grid_upper_txt as a double


% --- Executes during object creation, after setting all properties.
function grid_upper_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grid_upper_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in day_normalise_chk.
function day_normalise_chk_Callback(hObject, eventdata, handles)
% hObject    handle to day_normalise_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of day_normalise_chk



function grid_c_lim_txt_Callback(hObject, eventdata, handles)
% hObject    handle to grid_c_lim_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of grid_c_lim_txt as text
%        str2double(get(hObject,'String')) returns contents of grid_c_lim_txt as a double


% --- Executes during object creation, after setting all properties.
function grid_c_lim_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grid_c_lim_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in image_save_chk.
function image_save_chk_Callback(hObject, eventdata, handles)
% hObject    handle to image_save_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of image_save_chk



function edit27_Callback(hObject, eventdata, handles)
% hObject    handle to snd_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of snd_ffn_txt as text
%        str2double(get(hObject,'String')) returns contents of snd_ffn_txt as a double


% --- Executes during object creation, after setting all properties.
function edit27_CreateFcn(hObject, eventdata, handles)
% hObject    handle to snd_ffn_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in dir_opt_chk.
function dir_opt_chk_Callback(hObject, eventdata, handles)
% hObject    handle to dir_opt_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dir_opt_chk


% --- Executes on selection change in dir_mask_dlg.
function dir_mask_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to dir_mask_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dir_mask_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dir_mask_dlg


% --- Executes during object creation, after setting all properties.
function dir_mask_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dir_mask_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in grid_opt_dlg.
function grid_opt_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to grid_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns grid_opt_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from grid_opt_dlg


% --- Executes during object creation, after setting all properties.
function grid_opt_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grid_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in random_panel.
function plot_opt_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to random_panel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns random_panel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from random_panel


% --- Executes during object creation, after setting all properties.
function random_panel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to random_panel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in mask_opt_dlg.
function mask_opt_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to mask_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns mask_opt_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from mask_opt_dlg


% --- Executes during object creation, after setting all properties.
function mask_opt_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mask_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in type_opt_dlg.
function type_opt_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to type_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns type_opt_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from type_opt_dlg


% --- Executes during object creation, after setting all properties.
function type_opt_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to type_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in random_panel.
function popupmenu11_Callback(hObject, eventdata, handles)
% hObject    handle to random_panel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns random_panel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from random_panel


% --- Executes during object creation, after setting all properties.
function popupmenu11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to random_panel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function plot_opt_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plot_opt_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function grid_lower_txt_Callback(hObject, eventdata, handles)
% hObject    handle to grid_lower_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of grid_lower_txt as text
%        str2double(get(hObject,'String')) returns contents of grid_lower_txt as a double


% --- Executes during object creation, after setting all properties.
function grid_lower_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grid_lower_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ci_opt_chk.
function ci_opt_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ci_opt_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ci_opt_chk



function ce_diff_txt_Callback(hObject, eventdata, handles)
% hObject    handle to ce_diff_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ce_diff_txt as text
%        str2double(get(hObject,'String')) returns contents of ce_diff_txt as a double


% --- Executes during object creation, after setting all properties.
function ce_diff_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ce_diff_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ce_opt_chk.
function ce_opt_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ce_opt_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ce_opt_chk


% --- Executes on button press in plot_cent_chk.
function plot_cent_chk_Callback(hObject, eventdata, handles)
% hObject    handle to plot_cent_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of plot_cent_chk



function cent_grid_txt_Callback(hObject, eventdata, handles)
% hObject    handle to cent_grid_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cent_grid_txt as text
%        str2double(get(hObject,'String')) returns contents of cent_grid_txt as a double


% --- Executes during object creation, after setting all properties.
function cent_grid_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cent_grid_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in years_normalise_chk.
function years_normalise_chk_Callback(hObject, eventdata, handles)
% hObject    handle to years_normalise_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of years_normalise_chk



function latlon_txt_Callback(hObject, eventdata, handles)
% hObject    handle to latlon_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of latlon_txt as text
%        str2double(get(hObject,'String')) returns contents of latlon_txt as a double


% --- Executes during object creation, after setting all properties.
function latlon_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to latlon_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
