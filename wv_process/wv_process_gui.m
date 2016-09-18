function varargout = wv_process_gui(varargin)
% WV_PROCESS_GUI MATLAB code for wv_process_gui.fig
%      WV_PROCESS_GUI, by itself, creates a new WV_PROCESS_GUI or raises the existing
%      singleton*.
%
%      H = WV_PROCESS_GUI returns the handle to a new WV_PROCESS_GUI or the handle to
%      the existing singleton*.
%
%      WV_PROCESS_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WV_PROCESS_GUI.M with the given input arguments.
%
%      WV_PROCESS_GUI('Property','Value',...) creates a new WV_PROCESS_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before wv_process_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to wv_process_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help wv_process_gui

% Last Modified by GUIDE v2.5 21-Jun-2014 22:07:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @wv_process_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @wv_process_gui_OutputFcn, ...
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

% --- Executes just before wv_process_gui is made visible.
function wv_process_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to wv_process_gui (see VARARGIN)

global zones_names

%add paths
addpath('../libraries/functions','../config_files');

% LOAD ZONE DATA INTO GUI
if exist('wv_zones.csv','file')==2
    zones_raw=importdata('wv_zones.csv',';');
    zones_names=zones_raw.textdata(1,2:end);
    set(handles.zone_dlg,'string',zones_names)
else
    msgbox('wv_zones.csv not found')
    keyboard
end

%create gui config file from defaults if non existant
if exist('process_gui_config.mat','file')~=2
    msgbox('process_gui_config.mat not found, creating default config file')
    src_dir        = '~/wv_testing/radar_arch/';
    dest_dir       = '~/wv_testing/proced_arch/';
    oldest_opt     = datestr(addtodate(utc_time,-2,'hour'),'dd-mm-yy_HH:MM');
    newest_opt     = datestr(addtodate(utc_time,0,'hour'),'dd-mm-yy_HH:MM');
    zone_selection = 1;
    site_no        = '50';
    historical_chk = 1;
    ftp_chk        = 0;
    other_chk      = 0;
    h5_chk         = 0;
    cts_loop_chk   = 0;
    snd_ffn        = '/snd_data/UA02D_fzh_97-14_uniq_morn.mat';
    save('process_gui_config.mat','src_dir','dest_dir','oldest_opt',...
        'newest_opt','zone_selection','site_no','historical_chk',...
        'ftp_chk','other_chk','h5_chk','cts_loop_chk','snd_ffn');
end

%load variables into GUI objects
load process_gui_config.mat
set(handles.src_dir_txt,'string',src_dir);
set(handles.dest_dir_txt,'string',dest_dir);
set(handles.oldest_txt,'string',oldest_opt);
set(handles.newest_txt,'string',newest_opt);
set(handles.zone_dlg,'value',zone_selection);
set(handles.site_no_txt,'string',site_no);
set(handles.historical_fmt_chk,'value',historical_chk);
set(handles.ftp_fmt_chk,'value',ftp_chk);
set(handles.h5_chk,'value',h5_chk);
set(handles.other_fmt_chk,'value',other_chk);
set(handles.cts_loop_chk,'value',cts_loop_chk);
set(handles.snd_ffn_txt,'string',snd_ffn);
% Choose default command line output for wv_process_gui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = wv_process_gui_OutputFcn(hObject, eventdata, handles) 
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

%Load GUI variables from GUI objects
src_dir        = get(handles.src_dir_txt,'string');
dest_dir       = get(handles.dest_dir_txt,'string');
historical_chk = get(handles.historical_fmt_chk,'value');
ftp_chk        = get(handles.ftp_fmt_chk,'value');
other_chk      = get(handles.other_fmt_chk,'value');
h5_chk         = get(handles.h5_chk,'value');
oldest_opt     = get(handles.oldest_txt,'string');
newest_opt     = get(handles.newest_txt,'string');
cts_loop_chk   = get(handles.cts_loop_chk,'value');
zone_selection = get(handles.zone_dlg,'value');
site_no        = get(handles.site_no_txt,'string');
snd_ffn        = get(handles.snd_ffn_txt,'string');
%save GUI variables to gui config file
    save('process_gui_config.mat','src_dir','dest_dir','oldest_opt',...
        'newest_opt','zone_selection','site_no','historical_chk',...
        'ftp_chk','other_chk','h5_chk','cts_loop_chk','snd_ffn');
    
%determine file format from GUI varibales
if historical_chk==1
    file_fmt='historical';
elseif ftp_chk==1
    file_fmt='ftp';
elseif other_chk==1
    file_fmt ='other';
elseif h5_chk==1
    file_fmt='h5.tar';
end

%convert time options to correction format
if isempty(strfind(oldest_opt,'_'))
    oldest_opt=str2num(oldest_opt);
end
if isempty(strfind(newest_opt,'_'))
    newest_opt=str2num(newest_opt);
end

%convert zone/site_no objects to the correction vairables
zone=zones_names{zone_selection};
site_no=str2num(site_no);

% %Correct time formats
% if isnan(oldest_opt) %NaN=0
%     oldest_time=datenum('01-01-00_00:00','dd-mm-yy_HH:MM');
% elseif isnumeric(oldest_opt) %offset from now
%     oldest_time=addtodate(utc_time,oldest_opt,'minute');
% else %specific time
%     oldest_time=datenum(oldest_opt,'dd-mm-yy_HH:MM');
% end
% 
% if isnan(newest_opt) %NaN=now
%     newest_time=utc_time;
% elseif isnumeric(newest_opt) %offset from now
%     newest_time=addtodate(utc_time,newest_opt,'minute');
% else %specific time
%     newest_time=datenum(newest_opt,'dd-mm-yy_HH:MM');
% end

%close figure
close(gcf)
%pass to wv_control
wv_process(src_dir,dest_dir,file_fmt,oldest_opt,newest_opt,cts_loop_chk,zone,site_no,snd_ffn,'');


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



function src_dir_txt_Callback(hObject, eventdata, handles)
% hObject    handle to src_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of src_dir_txt as text
%        str2double(get(hObject,'String')) returns contents of src_dir_txt as a double


% --- Executes during object creation, after setting all properties.
function src_dir_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to src_dir_txt (see GCBO)
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



function dest_dir_txt_Callback(hObject, eventdata, handles)
% hObject    handle to dest_dir_txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dest_dir_txt as text
%        str2double(get(hObject,'String')) returns contents of dest_dir_txt as a double


% --- Executes during object creation, after setting all properties.
function dest_dir_txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dest_dir_txt (see GCBO)
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
