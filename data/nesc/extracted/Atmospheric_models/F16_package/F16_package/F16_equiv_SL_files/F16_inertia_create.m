%
% Invoke this script to create the corresponding model
%

% Create the system (either model or library) and open it

new_system('F16_inertia','Model');
load_system('simulink');
open_system('F16_inertia');
set_param('F16_inertia','Location', [70, 200, 670, 600]);
% pause(0.1); - disabled with R2006b/7.3; causes typeahead buffer overflow

% Execute the setup script to create the data structure
% in the model workspace for clarity

mws = get_param('F16_inertia','modelworkspace');
if ~exist('mws')
  error('Unable to open model workspace - aborting');
end
mws.clear;
mws.evalin('F16_inertia_data','F16_inertia_setup');
clear mws;

% Create the subsystem with proper size to accomodate in/out ports

add_block('built-in/subsystem','F16_inertia/F16_inertia','Position',[210, 50, 390, 350]);

% Flesh out subsystem with internal blocks

    add_block('built-in/Constant','F16_inertia/F16_inertia/const_1','ShowName','off','Value','0.01','Position',[30,32,90,62]);
    add_block('built-in/Product','F16_inertia/F16_inertia/times_1','Multiplication','Element-wise(.*)','SaturateOnIntegerOverflow','on','Inputs','3','Position',[200,20,230,74]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_X','Position',[270,40,300,54]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_3','ShowName','off','Value','35','Position',[30,98,90,128]);
    add_block('built-in/Sum','F16_inertia/F16_inertia/minus_3','IconShape','rectangular','Inputs','+-','Position',[130,94,160,133]);
    add_block('built-in/Inport','F16_inertia/F16_inertia/vrsPositionOfCM','Position',[45,161,75,175]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_5','ShowName','off','Value','11.32','Position',[30,187,90,217]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_6','ShowName','off','Value','9496.0','Position',[30,237,90,267]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyMomentOfInertia_Roll','Position',[130,245,160,259]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_8','ShowName','off','Value','55814.0','Position',[30,287,90,317]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyMomentOfInertia_Pitch','Position',[130,295,160,309]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_10','ShowName','off','Value','63100.0','Position',[30,337,90,367]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyMomentOfInertia_Yaw','Position',[130,345,160,359]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_12','ShowName','off','Value','982.0','Position',[30,387,90,417]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyProductOfInertia_ZX','Position',[130,395,160,409]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_14','ShowName','off','Value','0.0','Position',[30,437,90,467]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyProductOfInertia_XY','Position',[130,445,160,459]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_16','ShowName','off','Value','0.0','Position',[30,487,90,517]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyProductOfInertia_YZ','Position',[130,495,160,509]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_18','ShowName','off','Value','637.1595','Position',[30,537,90,567]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/totalMass','Position',[130,545,160,559]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_20','ShowName','off','Value','0','Position',[30,587,90,617]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_Y','Position',[130,595,160,609]);
    add_block('built-in/Constant','F16_inertia/F16_inertia/const_22','ShowName','off','Value','0.','Position',[30,637,90,667]);
    add_block('built-in/Outport','F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_Z','Position',[130,645,160,659]);
    h=add_line('F16_inertia/F16_inertia','vrsPositionOfCM/1','minus_3/2','autorouting','on');
    set_param(h,'Name','vrsPositionOfCM');
    h=add_line('F16_inertia/F16_inertia','const_5/1','times_1/2','autorouting','on');
    set_param(h,'Name','referenceWingChord');
    h=add_line('F16_inertia/F16_inertia','const_6/1','bodyMomentOfInertia_Roll/1','autorouting','on');
    set_param(h,'Name','bodyMomentOfInertia_Roll');
    h=add_line('F16_inertia/F16_inertia','const_8/1','bodyMomentOfInertia_Pitch/1','autorouting','on');
    set_param(h,'Name','bodyMomentOfInertia_Pitch');
    h=add_line('F16_inertia/F16_inertia','const_10/1','bodyMomentOfInertia_Yaw/1','autorouting','on');
    set_param(h,'Name','bodyMomentOfInertia_Yaw');
    h=add_line('F16_inertia/F16_inertia','const_12/1','bodyProductOfInertia_ZX/1','autorouting','on');
    set_param(h,'Name','bodyProductOfInertia_ZX');
    h=add_line('F16_inertia/F16_inertia','const_14/1','bodyProductOfInertia_XY/1','autorouting','on');
    set_param(h,'Name','bodyProductOfInertia_XY');
    h=add_line('F16_inertia/F16_inertia','const_16/1','bodyProductOfInertia_YZ/1','autorouting','on');
    set_param(h,'Name','bodyProductOfInertia_YZ');
    h=add_line('F16_inertia/F16_inertia','const_18/1','totalMass/1','autorouting','on');
    set_param(h,'Name','totalMass');
    h=add_line('F16_inertia/F16_inertia','const_20/1','bodyPositionOfCmWrtMrc_Y/1','autorouting','on');
    set_param(h,'Name','bodyPositionOfCmWrtMrc_Y');
    h=add_line('F16_inertia/F16_inertia','const_22/1','bodyPositionOfCmWrtMrc_Z/1','autorouting','on');
    set_param(h,'Name','bodyPositionOfCmWrtMrc_Z');
    h=add_line('F16_inertia/F16_inertia','times_1/1','bodyPositionOfCmWrtMrc_X/1','autorouting','on');
    set_param(h,'Name','bodyPositionOfCmWrtMrc_X');
    h=add_line('F16_inertia/F16_inertia','const_1/1','times_1/1','autorouting','on');
    set_param(h,'Name','const_1');
    h=add_line('F16_inertia/F16_inertia','minus_3/1','times_1/3','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_inertia/F16_inertia','const_3/1','minus_3/1','autorouting','on');
    set_param(h,'Name','const_3');
    
    % Correct output numbers
    
    set_param('F16_inertia/F16_inertia/bodyMomentOfInertia_Roll','Port','1');
    set_param('F16_inertia/F16_inertia/bodyMomentOfInertia_Pitch','Port','2');
    set_param('F16_inertia/F16_inertia/bodyMomentOfInertia_Yaw','Port','3');
    set_param('F16_inertia/F16_inertia/bodyProductOfInertia_ZX','Port','4');
    set_param('F16_inertia/F16_inertia/bodyProductOfInertia_XY','Port','5');
    set_param('F16_inertia/F16_inertia/bodyProductOfInertia_YZ','Port','6');
    set_param('F16_inertia/F16_inertia/totalMass','Port','7');
    set_param('F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_Y','Port','8');
    set_param('F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_Z','Port','9');
    set_param('F16_inertia/F16_inertia/bodyPositionOfCmWrtMrc_X','Port','10');

% Top-level inports and lines

add_block('built-in/Inport','F16_inertia/vrsPositionOfCM','Position',[90, 193, 120, 207]);
add_line('F16_inertia','vrsPositionOfCM/1','F16_inertia/1');

% Top-level outports and lines

add_block('built-in/Outport','F16_inertia/bodyMomentOfInertia_Roll','Position',[480, 58, 510, 72]);
add_line('F16_inertia','F16_inertia/1','bodyMomentOfInertia_Roll/1');
add_block('built-in/Outport','F16_inertia/bodyMomentOfInertia_Pitch','Position',[480, 88, 510, 102]);
add_line('F16_inertia','F16_inertia/2','bodyMomentOfInertia_Pitch/1');
add_block('built-in/Outport','F16_inertia/bodyMomentOfInertia_Yaw','Position',[480, 118, 510, 132]);
add_line('F16_inertia','F16_inertia/3','bodyMomentOfInertia_Yaw/1');
add_block('built-in/Outport','F16_inertia/bodyProductOfInertia_ZX','Position',[480, 148, 510, 162]);
add_line('F16_inertia','F16_inertia/4','bodyProductOfInertia_ZX/1');
add_block('built-in/Outport','F16_inertia/bodyProductOfInertia_XY','Position',[480, 178, 510, 192]);
add_line('F16_inertia','F16_inertia/5','bodyProductOfInertia_XY/1');
add_block('built-in/Outport','F16_inertia/bodyProductOfInertia_YZ','Position',[480, 208, 510, 222]);
add_line('F16_inertia','F16_inertia/6','bodyProductOfInertia_YZ/1');
add_block('built-in/Outport','F16_inertia/totalMass','Position',[480, 238, 510, 252]);
add_line('F16_inertia','F16_inertia/7','totalMass/1');
add_block('built-in/Outport','F16_inertia/bodyPositionOfCmWrtMrc_Y','Position',[480, 268, 510, 282]);
add_line('F16_inertia','F16_inertia/8','bodyPositionOfCmWrtMrc_Y/1');
add_block('built-in/Outport','F16_inertia/bodyPositionOfCmWrtMrc_Z','Position',[480, 298, 510, 312]);
add_line('F16_inertia','F16_inertia/9','bodyPositionOfCmWrtMrc_Z/1');
add_block('built-in/Outport','F16_inertia/bodyPositionOfCmWrtMrc_X','Position',[480, 328, 510, 342]);
add_line('F16_inertia','F16_inertia/10','bodyPositionOfCmWrtMrc_X/1');

% Add annotation

add_block('built-in/Note','F16_inertia/Auto-generated by DAVE2SL version 0.9.5b (2013-06-04)','Position',[300, 22]);

clear h;  % remove handle used for naming lines

% Pause so window can be drawn prior to verification

% pause(0.5); - disabled with R2006b/7.3; causes typeahead buffer overflow
if exist('F16_inertia_verify') == 2
  if F16_inertia_verify
    save_system('F16_inertia','F16_inertia');
    fprintf('\n"F16_inertia" model verified and saved.\n')
  else
    fprintf('\n"F16_inertia" model NOT VERIFIED; model has NOT been saved.\n')
  end
else
  save_system('F16_inertia','F16_inertia');
  fprintf('\n"F16_inertia" model saved.\n')
end

% F16_inertia model-building script was auto-generated 
% by DAVE2SL version 0.9.5b (2013-06-04)
% on Thu Jun 6 08:53:37 2013.
