function varargout = wv_kml_gui(varargin)
% WV_KML_GUI MATLAB code for wv_kml_gui.fig
%      WV_KML_GUI, by itself, creates a new WV_KML_GUI or raises the existing
%      singleton*.
%
%      H = WV_KML_GUI returns the handle to a new WV_KML_GUI or the handle to
%      the existing singleton*.
%
%      WV_KML_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WV_KML_GUI.M with the given input arguments.
%
%      WV_KML_GUI('Property','Value',...) creates a new WV_KML_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before wv_kml_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to wv_kml_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help wv_kml_gui

% Last Modified by GUIDE v2.5 29-Jul-2013 17:13:41

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @wv_kml_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @wv_kml_gui_OutputFcn, ...
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


% --- Executes just before wv_kml_gui is made visible.
function wv_kml_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to wv_kml_gui (see VARARGIN)
clc
addpath('../libraries/functions','../libraries/ge_functions','../config_files');

% LOAD ZONE DATA INTO GUI
if exist('wv_zones.csv','file')==2
    zones_raw=importdata('wv_zones.csv',';');
    global zones_names
    zones_names=zones_raw.textdata(1,2:end);
    set(handles.zone_dlg,'string',zones_names)
else
    msgbox('wv_zones.csv not found')
    keyboard
end

%LOAD GUI CONFIG
if exist('kml_gui_config.mat','file')~=2
    msgbox('kml_gui_config.mat not found, creating default config file')
    arch_dir='/WeatherShare/procd-archive/';
    kml_dir='~/Dropbox/Public/WeatherVis/';
    nl_path='https://s3-ap-southeast-2.amazonaws.com/roames-weathervis/realtime-kml/doc.kml';
    oldest_opt='-60';
    newest_opt='NaN';
    zone_selection=1;
    site_no='NaN';
    cts_loop_chk=0;
    scan1_refl_chk=0;
    scan2_refl_chk=1;
    scan1_vel_chk=1;
    scan2_vel_chk=1;
    refl_xsec_chk=0;
    vel_xsec_chk=0;
    xsec_levels_txt='10,20';
    inner_iso_chk=1;
    outer_iso_chk=1;
    storm_stats_chk=0;
    tracks_chk=0;
    swaths_chk=0;
    forecast_chk=0;
    rebuild_rad=1;
    s3sync_chk=0;
    save('kml_gui_config.mat','arch_dir','kml_dir','nl_path','oldest_opt','newest_opt','zone_selection','site_no','cts_loop_chk','scan1_refl_chk','scan2_refl_chk','scan1_vel_chk','scan2_vel_chk','refl_xsec_chk','vel_xsec_chk','xsec_levels_txt','inner_iso_chk','outer_iso_chk','storm_stats_chk','tracks_chk','swaths_chk','forecast_chk','rebuild_rad','s3sync_chk');
end
load kml_gui_config.mat
set(handles.arch_dir_txt,'string',arch_dir);
set(handles.kml_dir_txt,'string',kml_dir);
set(handles.nl_txt,'string',nl_path);
set(handles.oldest_txt,'string',oldest_opt);
set(handles.newest_txt,'string',newest_opt);
set(handles.cts_loop_chk,'value',cts_loop_chk);
set(handles.zone_dlg,'value',zone_selection);
set(handles.site_no_txt,'string',site_no);
set(handles.scan1_refl_chk,'value',scan1_refl_chk);
set(handles.scan2_refl_chk,'value',scan2_refl_chk);
set(handles.scan1_vel_chk,'value',scan1_vel_chk);
set(handles.scan2_vel_chk,'value',scan2_vel_chk);
set(handles.refl_xsec_chk,'value',refl_xsec_chk);
set(handles.vel_xsec_chk,'value',vel_xsec_chk);
set(handles.xsec_levels_txt,'string',xsec_levels_txt);
set(handles.inner_iso_chk,'value',inner_iso_chk);
set(handles.outer_iso_chk,'value',outer_iso_chk);
set(handles.storm_stats_chk,'value',storm_stats_chk);
set(handles.tracks_chk,'value',tracks_chk);
set(handles.swaths_chk,'value',swaths_chk);
set(handles.forecast_chk,'value',forecast_chk);
set(handles.rebuild_rad,'value',rebuild_rad);
set(handles.s3sync_chk,'value',s3sync_chk);

% Choose default command line output for wv_kml_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
% UIWAIT makes wv_kml_gui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = wv_kml_gui_OutputFcn(hObject, eventdata, handles) 
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

global zones_names

%Load GUI variables
arch_dir=get(handles.arch_dir_txt,'string');
kml_dir=get(handles.kml_dir_txt,'string');
nl_path=get(handles.nl_txt,'string');
oldest_opt=get(handles.oldest_txt,'string');
newest_opt=get(handles.newest_txt,'string');
cts_loop_chk=get(handles.cts_loop_chk,'value');
zone_selection=get(handles.zone_dlg,'value');
site_no=get(handles.site_no_txt,'string');
scan1_refl_chk=get(handles.scan1_refl_chk,'value');
scan2_refl_chk=get(handles.scan2_refl_chk,'value');
scan1_vel_chk=get(handles.scan1_vel_chk,'value');
scan2_vel_chk=get(handles.scan2_vel_chk,'value');
refl_xsec_chk=get(handles.refl_xsec_chk,'value');
vel_xsec_chk=get(handles.vel_xsec_chk,'value');
xsec_levels_txt=get(handles.xsec_levels_txt,'string');
inner_iso_chk=get(handles.inner_iso_chk,'value');
outer_iso_chk=get(handles.outer_iso_chk,'value');
storm_stats_chk=get(handles.storm_stats_chk,'value');
tracks_chk=get(handles.tracks_chk,'value');
swaths_chk=get(handles.swaths_chk,'value');
forecast_chk=get(handles.forecast_chk,'value');
rebuild_rad=get(handles.rebuild_rad,'value');
s3sync_chk=get(handles.s3sync_chk,'value');

%save GUI variables to file
save('kml_gui_config.mat','arch_dir','kml_dir','nl_path','oldest_opt','newest_opt','zone_selection','site_no','cts_loop_chk','scan1_refl_chk','scan2_refl_chk','scan1_vel_chk','scan2_vel_chk','refl_xsec_chk','vel_xsec_chk','xsec_levels_txt','inner_iso_chk','outer_iso_chk','storm_stats_chk','tracks_chk','swaths_chk','forecast_chk','rebuild_rad','s3sync_chk');

%convert/collate variables for transfer
if isempty(strfind(oldest_opt,'_'))
    oldest_opt=str2num(oldest_opt);
end
if isempty(strfind(newest_opt,'_'))
    newest_opt=str2num(newest_opt);
end
zone=zones_names{zone_selection};
site_no=str2num(site_no);
xsec_levels_txt=str2num(xsec_levels_txt);
%note: xsec_levels_txt has variable length of 15:end
options=[scan1_refl_chk,scan2_refl_chk,scan1_vel_chk,scan2_vel_chk,refl_xsec_chk,vel_xsec_chk,inner_iso_chk,outer_iso_chk,storm_stats_chk,tracks_chk,swaths_chk,forecast_chk,0,rebuild_rad,xsec_levels_txt];

%close figure
close(gcf)
%pass to wv_control
%profile on
wv_kml(arch_dir,kml_dir,oldest_opt,newest_opt,cts_loop_chk,zone,site_no,nl_path,s3sync_chk,options)
% p = profile('info');
% profsave(p,'profile_results')


function data_src_txt_Callback(hObject, eventdata, handles)
% hObject    handle to data_src_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of data_src_txt as text
%        str2double(get(hObject,'String')) returns contents of data_src_txt as a double


% --- Executes during object creation, after setting all properties.
function data_src_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to data_src_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



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


% --- Executes on selection change in zone_dlg.
function zone_dlg_Callback(hObject, eventdata, handles)
% hObject    handle to zone_dlg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns zone_dlg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from zone_dlg


% --- Executes during object creation, after setting all properties.
function zone_dlg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zone_dlg (see GCBO)
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

function oldest_txt_Callback(hObject, eventdata, handles)
% hObject    handle to oldest_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of oldest_txt as text
%        str2double(get(hObject,'String')) returns contents of oldest_txt as a double


% --- Executes during object creation, after setting all properties.
function oldest_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to oldest_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function newest_txt_Callback(hObject, eventdata, handles)
% hObject    handle to newest_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of newest_txt as text
%        str2double(get(hObject,'String')) returns contents of newest_txt as a double


% --- Executes during object creation, after setting all properties.
function newest_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to newest_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cts_loop_chk.
function cts_loop_chk_Callback(hObject, eventdata, handles)
% hObject    handle to cts_loop_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cts_loop_chk



function kml_dir_txt_Callback(hObject, eventdata, handles)
% hObject    handle to kml_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of kml_dir_txt as text
%        str2double(get(hObject,'String')) returns contents of kml_dir_txt as a double


% --- Executes during object creation, after setting all properties.
function kml_dir_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to kml_dir_txt (see GCBO)
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


% --- Executes on button press in scan1_refl_chk.
function scan1_refl_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan1_refl_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan1_refl_chk


% --- Executes on button press in inner_iso_chk.
function inner_iso_chk_Callback(hObject, eventdata, handles)
% hObject    handle to inner_iso_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of inner_iso_chk


% --- Executes on button press in refl_xsec_chk.
function refl_xsec_chk_Callback(hObject, eventdata, handles)
% hObject    handle to refl_xsec_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of refl_xsec_chk


% --- Executes on button press in storm_stats_chk.
function storm_stats_chk_Callback(hObject, eventdata, handles)
% hObject    handle to storm_stats_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of storm_stats_chk


% --- Executes on button press in rebuild_rad.
function rebuild_rad_Callback(hObject, eventdata, handles)
% hObject    handle to rebuild_rad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rebuild_rad


% --- Executes on button press in cappi_chk.
function cappi_chk_Callback(hObject, eventdata, handles)
% hObject    handle to cappi_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cappi_chk


% --- Executes on button press in tracks_chk.
function tracks_chk_Callback(hObject, eventdata, handles)
% hObject    handle to tracks_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tracks_chk


% --- Executes on button press in swaths_chk.
function swaths_chk_Callback(hObject, eventdata, handles)
% hObject    handle to swaths_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of swaths_chk



function nl_txt_Callback(hObject, eventdata, handles)
% hObject    handle to nl_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nl_txt as text
%        str2double(get(hObject,'String')) returns contents of nl_txt as a double


% --- Executes during object creation, after setting all properties.
function nl_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nl_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in priority_chk.
function priority_chk_Callback(hObject, eventdata, handles)
% hObject    handle to priority_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of priority_chk


% --- Executes on button press in forecast_chk.
function forecast_chk_Callback(hObject, eventdata, handles)
% hObject    handle to forecast_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of forecast_chk


% --- Executes on button press in scan2_refl_chk.
function scan2_refl_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan2_refl_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan2_refl_chk


% --- Executes on button press in scan1_vel_chk.
function scan1_vel_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan1_vel_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan1_vel_chk


% --- Executes on button press in scan2_vel_chk.
function scan2_vel_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan2_vel_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan2_vel_chk


% --- Executes on button press in checkbox20.
function checkbox20_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox20 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox20


% --- Executes on button press in outer_iso_chk.
function outer_iso_chk_Callback(hObject, eventdata, handles)
% hObject    handle to outer_iso_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of outer_iso_chk


% --- Executes on button press in vel_xsec_chk.
function vel_xsec_chk_Callback(hObject, eventdata, handles)
% hObject    handle to vel_xsec_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of vel_xsec_chk


% --- Executes on button press in scan1_vel_chk.
function scan1_vel_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan1_vel_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan1_vel_chk


% --- Executes on button press in scan2_vel_chk.
function scan2_vel_chk_Callback(hObject, eventdata, handles)
% hObject    handle to scan2_vel_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scan2_vel_chk



function xsec_levels_txt_Callback(hObject, eventdata, handles)
% hObject    handle to xsec_levels_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xsec_levels_txt as text
%        str2double(get(hObject,'String')) returns contents of xsec_levels_txt as a double


% --- Executes during object creation, after setting all properties.
function xsec_levels_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xsec_levels_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in s3sync_chk.
function s3sync_chk_Callback(hObject, eventdata, handles)
% hObject    handle to s3sync_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of s3sync_chk
