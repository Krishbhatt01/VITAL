%
% Invoke this script to create the corresponding model
%

% Create the system (either model or library) and open it

new_system('F16_prop','Model');
load_system('simulink');
open_system('F16_prop');
set_param('F16_prop','Location', [70, 200, 670, 480]);
% pause(0.1); - disabled with R2006b/7.3; causes typeahead buffer overflow

% Execute the setup script to create the data structure
% in the model workspace for clarity

mws = get_param('F16_prop','modelworkspace');
if ~exist('mws')
  error('Unable to open model workspace - aborting');
end
mws.clear;
mws.evalin('F16_prop_data','F16_prop_setup');
clear mws;

% Create the subsystem with proper size to accomodate in/out ports

add_block('built-in/subsystem','F16_prop/F16_prop','Position',[210, 50, 390, 230]);

% Flesh out subsystem with internal blocks

    add_block('built-in/Constant','F16_prop/F16_prop/const_12','ShowName','off','Value','100.0','Position',[30,32,90,62]);
    add_block('built-in/Sum','F16_prop/F16_prop/minus_12','IconShape','rectangular','Inputs','+-','Position',[140,28,170,67]);
    add_block('built-in/Product','F16_prop/F16_prop/divide_8','Multiplication','Element-wise(.*)','SaturateOnIntegerOverflow','on','Inputs','*/','Position',[450,28,480,67]);
    add_block('built-in/Sum','F16_prop/F16_prop/plus_7','IconShape','rectangular','Inputs','++','Position',[520,28,550,67]);
    add_block('built-in/Switch','F16_prop/F16_prop/switch_1','Threshold','0.5','Position',[590,20,620,74]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyForce_X','Position',[660,40,690,54]);
    add_block('built-in/Inport','F16_prop/F16_prop/powerLeverAngle','Position',[45,114,75,128]);
    add_block('built-in/Product','F16_prop/F16_prop/times_4','Multiplication','Element-wise(.*)','SaturateOnIntegerOverflow','on','Inputs','2','Position',[380,94,410,133]);
    add_block('built-in/Product','F16_prop/F16_prop/divide_3','Multiplication','Element-wise(.*)','SaturateOnIntegerOverflow','on','Inputs','*/','Position',[450,94,480,133]);
    add_block('built-in/Sum','F16_prop/F16_prop/plus_2','IconShape','rectangular','Inputs','++','Position',[520,94,550,133]);
    add_block('built-in/RelationalOperator','F16_prop/F16_prop/lt_6','Position',[140,153,170,192],'Operator','<');
    add_block('built-in/Sum','F16_prop/F16_prop/minus_10','IconShape','rectangular','Inputs','+-','Position',[140,212,170,251]);
    add_block('built-in/Product','F16_prop/F16_prop/times_9','Multiplication','Element-wise(.*)','SaturateOnIntegerOverflow','on','Inputs','2','Position',[380,212,410,251]);
    add_block('built-in/Inport','F16_prop/F16_prop/altitudeMSL','Position',[45,298,75,312]);
    add_block('simulink/Lookup Tables/PreLookup Index Search','F16_prop/F16_prop/ALT_PTS','FontSize',10,'Position',[130,271,180,323]);
    pts_vec = 'F16_prop_data.ALT_PTS_pts';
    set_param('F16_prop/F16_prop/ALT_PTS','MaskValues',{pts_vec,'Binary Search','on','off','uint32','Linear Extrapolation','None'});
    clear pts_vec
    add_block('simulink/Lookup Tables/Interpolation (n-D) using PreLookup','F16_prop/F16_prop/T_IDLE_fn_defn','FontSize',10,'Position',[220,272,270,322]);
    set_param('F16_prop/F16_prop/T_IDLE_fn_defn','MaskValues',{'2','2','F16_prop_data.T_IDLE_table','Linear','None - Clip','None','0'});
    add_block('built-in/Sum','F16_prop/F16_prop/minus_5','IconShape','rectangular','Inputs','+-','Position',[310,343,340,382]);
    add_block('simulink/Lookup Tables/Interpolation (n-D) using PreLookup','F16_prop/F16_prop/T_MIL_fn_defn','FontSize',10,'Position',[220,402,270,452]);
    set_param('F16_prop/F16_prop/T_MIL_fn_defn','MaskValues',{'2','2','F16_prop_data.T_MIL_table','Linear','None - Clip','None','0'});
    add_block('built-in/Sum','F16_prop/F16_prop/minus_11','IconShape','rectangular','Inputs','+-','Position',[310,472,340,511]);
    add_block('simulink/Lookup Tables/Interpolation (n-D) using PreLookup','F16_prop/F16_prop/T_MAX_fn_defn','FontSize',10,'Position',[220,531,270,581]);
    set_param('F16_prop/F16_prop/T_MAX_fn_defn','MaskValues',{'2','2','F16_prop_data.T_MAX_table','Linear','None - Clip','None','0'});
    add_block('built-in/Inport','F16_prop/F16_prop/mach','Position',[45,628,75,642]);
    add_block('simulink/Lookup Tables/PreLookup Index Search','F16_prop/F16_prop/MACH_PTS','FontSize',10,'Position',[130,601,180,653]);
    pts_vec = 'F16_prop_data.MACH_PTS_pts';
    set_param('F16_prop/F16_prop/MACH_PTS','MaskValues',{pts_vec,'Binary Search','on','off','uint32','Linear Extrapolation','None'});
    clear pts_vec
    add_block('built-in/Constant','F16_prop/F16_prop/const_21','ShowName','off','Value','50.0','Position',[30,673,90,703]);
    add_block('built-in/Constant','F16_prop/F16_prop/const_23','ShowName','off','Value','0.0','Position',[30,723,90,753]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyForce_Y','Position',[140,731,170,745]);
    add_block('built-in/Constant','F16_prop/F16_prop/const_25','ShowName','off','Value','0.0','Position',[30,773,90,803]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyForce_Z','Position',[140,781,170,795]);
    add_block('built-in/Constant','F16_prop/F16_prop/const_27','ShowName','off','Value','0.0','Position',[30,823,90,853]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyMoment_Roll','Position',[140,831,170,845]);
    add_block('built-in/Constant','F16_prop/F16_prop/const_29','ShowName','off','Value','0.0','Position',[30,873,90,903]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyMoment_Pitch','Position',[140,881,170,895]);
    add_block('built-in/Constant','F16_prop/F16_prop/const_31','ShowName','off','Value','0.0','Position',[30,923,90,953]);
    add_block('built-in/Outport','F16_prop/F16_prop/thrustBodyMoment_Yaw','Position',[140,931,170,945]);
    h=add_line('F16_prop/F16_prop','powerLeverAngle/1','times_4/1','autorouting','on');
    set_param(h,'Name','powerLeverAngle');
    h=add_line('F16_prop/F16_prop','powerLeverAngle/1','lt_6/1','autorouting','on');
    set_param(h,'Name','powerLeverAngle');
    h=add_line('F16_prop/F16_prop','powerLeverAngle/1','minus_10/1','autorouting','on');
    set_param(h,'Name','powerLeverAngle');
    h=add_line('F16_prop/F16_prop','altitudeMSL/1','ALT_PTS/1','autorouting','on');
    set_param(h,'Name','altitudeMSL');
    h=add_line('F16_prop/F16_prop','mach/1','MACH_PTS/1','autorouting','on');
    set_param(h,'Name','mach');
    h=add_line('F16_prop/F16_prop','const_21/1','divide_3/2','autorouting','on');
    set_param(h,'Name','milPwr');
    h=add_line('F16_prop/F16_prop','const_21/1','lt_6/2','autorouting','on');
    set_param(h,'Name','milPwr');
    h=add_line('F16_prop/F16_prop','const_21/1','minus_10/2','autorouting','on');
    set_param(h,'Name','milPwr');
    h=add_line('F16_prop/F16_prop','const_21/1','minus_12/2','autorouting','on');
    set_param(h,'Name','milPwr');
    h=add_line('F16_prop/F16_prop','T_IDLE_fn_defn/1','plus_2/1','autorouting','on');
    set_param(h,'Name','idleThrust');
    h=add_line('F16_prop/F16_prop','T_IDLE_fn_defn/1','minus_5/2','autorouting','on');
    set_param(h,'Name','idleThrust');
    h=add_line('F16_prop/F16_prop','T_MIL_fn_defn/1','minus_5/1','autorouting','on');
    set_param(h,'Name','militaryThrust');
    h=add_line('F16_prop/F16_prop','T_MIL_fn_defn/1','plus_7/1','autorouting','on');
    set_param(h,'Name','militaryThrust');
    h=add_line('F16_prop/F16_prop','T_MIL_fn_defn/1','minus_11/2','autorouting','on');
    set_param(h,'Name','militaryThrust');
    h=add_line('F16_prop/F16_prop','T_MAX_fn_defn/1','minus_11/1','autorouting','on');
    set_param(h,'Name','maxThrust');
    h=add_line('F16_prop/F16_prop','switch_1/1','thrustBodyForce_X/1','autorouting','on');
    set_param(h,'Name','thrustBodyForce_X');
    h=add_line('F16_prop/F16_prop','plus_2/1','switch_1/1','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','divide_3/1','plus_2/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','times_4/1','divide_3/1','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','minus_5/1','times_4/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','lt_6/1','switch_1/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','plus_7/1','switch_1/3','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','divide_8/1','plus_7/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','times_9/1','divide_8/1','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','minus_10/1','times_9/1','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','minus_11/1','times_9/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','minus_12/1','divide_8/2','autorouting','on');
    set_param(h,'Name','unnamed');
    h=add_line('F16_prop/F16_prop','const_12/1','minus_12/1','autorouting','on');
    set_param(h,'Name','const_12');
    h=add_line('F16_prop/F16_prop','const_23/1','thrustBodyForce_Y/1','autorouting','on');
    set_param(h,'Name','thrustBodyForce_Y');
    h=add_line('F16_prop/F16_prop','const_25/1','thrustBodyForce_Z/1','autorouting','on');
    set_param(h,'Name','thrustBodyForce_Z');
    h=add_line('F16_prop/F16_prop','const_27/1','thrustBodyMoment_Roll/1','autorouting','on');
    set_param(h,'Name','thrustBodyMoment_Roll');
    h=add_line('F16_prop/F16_prop','const_29/1','thrustBodyMoment_Pitch/1','autorouting','on');
    set_param(h,'Name','thrustBodyMoment_Pitch');
    h=add_line('F16_prop/F16_prop','const_31/1','thrustBodyMoment_Yaw/1','autorouting','on');
    set_param(h,'Name','thrustBodyMoment_Yaw');
    h=add_line('F16_prop/F16_prop','MACH_PTS/1','T_IDLE_fn_defn/1','autorouting','on');
    set_param(h,'Name','mach_by_MACH_PTS');
    h=add_line('F16_prop/F16_prop','MACH_PTS/1','T_MIL_fn_defn/1','autorouting','on');
    set_param(h,'Name','mach_by_MACH_PTS');
    h=add_line('F16_prop/F16_prop','MACH_PTS/1','T_MAX_fn_defn/1','autorouting','on');
    set_param(h,'Name','mach_by_MACH_PTS');
    h=add_line('F16_prop/F16_prop','ALT_PTS/1','T_IDLE_fn_defn/2','autorouting','on');
    set_param(h,'Name','altitudeMSL_by_ALT_PTS');
    h=add_line('F16_prop/F16_prop','ALT_PTS/1','T_MIL_fn_defn/2','autorouting','on');
    set_param(h,'Name','altitudeMSL_by_ALT_PTS');
    h=add_line('F16_prop/F16_prop','ALT_PTS/1','T_MAX_fn_defn/2','autorouting','on');
    set_param(h,'Name','altitudeMSL_by_ALT_PTS');
    
    % Correct output numbers
    
    set_param('F16_prop/F16_prop/thrustBodyForce_X','Port','1');
    set_param('F16_prop/F16_prop/thrustBodyForce_Y','Port','2');
    set_param('F16_prop/F16_prop/thrustBodyForce_Z','Port','3');
    set_param('F16_prop/F16_prop/thrustBodyMoment_Roll','Port','4');
    set_param('F16_prop/F16_prop/thrustBodyMoment_Pitch','Port','5');
    set_param('F16_prop/F16_prop/thrustBodyMoment_Yaw','Port','6');

% Top-level inports and lines

add_block('built-in/Inport','F16_prop/powerLeverAngle','Position',[90, 63, 120, 77]);
add_line('F16_prop','powerLeverAngle/1','F16_prop/1');
add_block('built-in/Inport','F16_prop/altitudeMSL','Position',[90, 133, 120, 147]);
add_line('F16_prop','altitudeMSL/1','F16_prop/2');
add_block('built-in/Inport','F16_prop/mach','Position',[90, 203, 120, 217]);
add_line('F16_prop','mach/1','F16_prop/3');

% Top-level outports and lines

add_block('built-in/Outport','F16_prop/thrustBodyForce_X','Position',[480, 58, 510, 72]);
add_line('F16_prop','F16_prop/1','thrustBodyForce_X/1');
add_block('built-in/Outport','F16_prop/thrustBodyForce_Y','Position',[480, 88, 510, 102]);
add_line('F16_prop','F16_prop/2','thrustBodyForce_Y/1');
add_block('built-in/Outport','F16_prop/thrustBodyForce_Z','Position',[480, 118, 510, 132]);
add_line('F16_prop','F16_prop/3','thrustBodyForce_Z/1');
add_block('built-in/Outport','F16_prop/thrustBodyMoment_Roll','Position',[480, 148, 510, 162]);
add_line('F16_prop','F16_prop/4','thrustBodyMoment_Roll/1');
add_block('built-in/Outport','F16_prop/thrustBodyMoment_Pitch','Position',[480, 178, 510, 192]);
add_line('F16_prop','F16_prop/5','thrustBodyMoment_Pitch/1');
add_block('built-in/Outport','F16_prop/thrustBodyMoment_Yaw','Position',[480, 208, 510, 222]);
add_line('F16_prop','F16_prop/6','thrustBodyMoment_Yaw/1');

% Add annotation

add_block('built-in/Note','F16_prop/Auto-generated by DAVE2SL version 0.9.5b (2013-06-04)','Position',[300, 22]);

clear h;  % remove handle used for naming lines

% Pause so window can be drawn prior to verification

% pause(0.5); - disabled with R2006b/7.3; causes typeahead buffer overflow
if exist('F16_prop_verify') == 2
  if F16_prop_verify
    save_system('F16_prop','F16_prop');
    fprintf('\n"F16_prop" model verified and saved.\n')
  else
    fprintf('\n"F16_prop" model NOT VERIFIED; model has NOT been saved.\n')
  end
else
  save_system('F16_prop','F16_prop');
  fprintf('\n"F16_prop" model saved.\n')
end

% F16_prop model-building script was auto-generated 
% by DAVE2SL version 0.9.5b (2013-06-04)
% on Thu Jun 6 08:53:32 2013.
