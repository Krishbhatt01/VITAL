function s = buildTrim6dof(opts)
%BUILDTRIM6DOF  Generate models/F16Trim6DOF.slx: the NESC F-16 flown by the
%   Aerospace Blockset 6DOF (Quaternion) block (tests/M9/tF16Trim6dof.m).
%   s = vital.slx.buildTrim6dof()                  writes models/F16Trim6DOF.slx
%   s = vital.slx.buildTrim6dof('Folder', d)       writes d/F16Trim6DOF.slx
%   s.file, s.name
%
%   The loop (left to right in the diagram):
%     u = u_trim + du                         Constant + From Workspace (held per step)
%     F-16 loads (VITAL, NASA data)           MATLAB Function -> vital.slx.f16LoadsCg:
%                                             aero + thrust about the CG, body axes
%     Weight in body axes                     DCM_be * [0 0 m g]'   (Product, Matrix)
%     Net force                               F_aero+prop + W_b
%     6DOF (Quaternion)                       MathWorks equations of motion, fixed
%                                             mass m, inertia J (with Ixz), metric;
%                                             outputs V_e, X_e, euler, quaternion,
%                                             DCM_be, V_b, w_b
%     back into the loads                     V_b, w_b, DCM_be, X_e  (the feedback)
%     Air data (Aerospace Blockset)       Incidence, Sideslip & Airspeed (V_b);
%                                         ISA Atmosphere at the geopotential height of
%                                         -X_e(3); Mach Number; Dynamic Pressure
%     Flight-test signals                 one logged vector (To Workspace 'sim6dof'):
%                                         V alpha beta Mach qbar h hdot phi theta psi
%                                         p q r xN xE de da dr throttle Fx Fy Fz L M N
%                                         (SI, rad), all Simulink signals
%   Parameters come from the base-workspace struct P6dof (vital.slx.trim6dofSetup:
%   the trim is computed ONCE there, from the NASA data objects; Simulink holds u
%   and integrates, it never re-trims). InitFcn creates the default P6dof if it is
%   missing, so the model runs by opening it and pressing Run (after startup_vital).
%   Solver ode4, step P6dof.dt, stop P6dof.tFinal. While it runs, the scope
%   'Live: change from trim' shows dV, dalpha, dtheta, dh, q and phi on fixed
%   bands (a trimmed aircraft draws flat lines at 0). At the end the StopFcn draws
%   the result figures from the logged Simulink data (vital.slx.plotTrim6dof).
arguments
    opts.Folder (1,:) char = ''
end
name = 'F16Trim6DOF';
if isempty(opts.Folder), opts.Folder = fullfile(vital.paths('root'), 'models'); end
if ~isfolder(opts.Folder), mkdir(opts.Folder); end
file = fullfile(opts.Folder, [name '.slx']);
if bdIsLoaded(name), close_system(name, 0); end
new_system(name);
cleanup = onCleanup(@() closeIfLoaded(name));
m = name;
load_system('aerolib6dof2');

% ---- controls --------------------------------------------------------------------
add_block('simulink/Sources/Constant', [m '/u_trim'], 'Value', 'P6dof.u_trim', ...
    'Position', [30 60 110 90]);
add_block('simulink/Sources/From Workspace', [m '/du (perturbation)'], 'VariableName', 'P6dof.du', ...
    'SampleTime', 'P6dof.dt', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', ...
    'Position', [30 120 110 150]);
add_block('simulink/Math Operations/Sum', [m '/u = u_trim + du'], 'Inputs', '++', ...
    'Position', [160 80 180 130]);

% ---- forces and moments ------------------------------------------------------------
add_block('simulink/User-Defined Functions/MATLAB Function', [m '/F-16 loads (VITAL, NASA data)'], ...
    'Position', [300 40 470 220]);
add_block('simulink/Sources/Constant', [m '/m g in NED'], ...
    'Value', '[0; 0; P6dof.m * P6dof.g * P6dof.weightOn]', 'Position', [300 280 400 310]);
add_block('simulink/Math Operations/Product', [m '/Weight in body axes'], 'Inputs', '**', ...
    'Multiplication', 'Matrix(*)', 'Position', [430 260 470 320]);
add_block('simulink/Math Operations/Sum', [m '/Net force'], 'Inputs', '++', ...
    'Position', [530 70 550 130]);

% ---- equations of motion (MathWorks) -----------------------------------------------
add_block('aerolib6dof2/6DOF (Quaternion)', [m '/6DOF (Quaternion)'], ...
    'Position', [620 60 800 300]);
set_param([m '/6DOF (Quaternion)'], 'units', 'Metric (MKS)', 'mtype', 'Fixed', ...
    'xme_0', 'P6dof.Xe0''', 'Vm_0', 'P6dof.Vb0''', 'eul_0', 'P6dof.eul0''', 'pm_0', 'P6dof.w0''', ...
    'mass_0', 'P6dof.m', 'inertia', 'P6dof.J');

% ---- outputs (logged) and scopes ---------------------------------------------------
outs = {'V_b', 'w_b', 'DCM_be', 'X_e', 'euler', 'F_total', 'M_cg', 'air', 'u', 'quat'};
for k = 1:numel(outs)
    add_block('simulink/Sinks/Out1', [m '/' outs{k}], 'Port', num2str(k), ...
        'Position', [1000 20 + 40 * k 1030 34 + 40 * k]);
end

% ---- air data from the 6DOF states (Aerospace Blockset blocks) --------------------
load_system('aerolibasang'); load_system('aerolibatmos');
add_block('simulink/User-Defined Functions/Fcn', [m '/Geopotential height'], ...
    'Expr', '6356766 * (-u(3)) / (6356766 - u(3))', 'Position', [620 380 720 410]);
add_block('aerolibatmos/ISA Atmosphere Model', [m '/ISA Atmosphere'], 'Position', [760 370 860 450]);
add_block('aerolibasang/Incidence, Sideslip, & Airspeed', [m '/Incidence, Sideslip & Airspeed'], ...
    'Position', [760 480 860 540]);
add_block('aerolibasang/Mach Number', [m '/Mach Number'], 'Position', [900 480 980 520]);
add_block('aerolibasang/Dynamic Pressure', [m '/Dynamic Pressure'], 'Position', [900 540 980 580]);
add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Flight-test signals'], ...
    'Position', [1040 380 1200 640]);
add_block('simulink/Sinks/To Workspace', [m '/sim6dof'], 'VariableName', 'sim6dof', ...
    'SaveFormat', 'Structure With Time', 'Position', [1260 400 1330 430]);
add_block('simulink/Sinks/Scope', [m '/Live: change from trim'], 'Position', [1260 460 1300 640]);
add_block('simulink/Sinks/Scope', [m '/Live: position NED'], 'Position', [880 160 910 190]);
% ---- MATLAB Function code ------------------------------------------------------------
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [m '/F-16 loads (VITAL, NASA data)']);
ch.Script = loadsScript();
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [m '/Flight-test signals']);
ch.Script = signalsScript();

% ---- wiring (port numbers of 6DOF (Quaternion): out 1 V_e, 2 X_e, 3 euler,
%      4 quaternion, 5 DCM_be, 6 V_b, 7 w_b; in 1 F_xyz, 2 M_xyz) ----------------
L = @(a, b) add_line(m, a, b, 'autorouting', 'on');
L('u_trim/1', 'u = u_trim + du/1');
L('du (perturbation)/1', 'u = u_trim + du/2');
L('6DOF (Quaternion)/6', 'F-16 loads (VITAL, NASA data)/1');
L('6DOF (Quaternion)/7', 'F-16 loads (VITAL, NASA data)/2');
L('6DOF (Quaternion)/5', 'F-16 loads (VITAL, NASA data)/3');
L('6DOF (Quaternion)/2', 'F-16 loads (VITAL, NASA data)/4');
L('u = u_trim + du/1', 'F-16 loads (VITAL, NASA data)/5');
L('6DOF (Quaternion)/5', 'Weight in body axes/1');
L('m g in NED/1', 'Weight in body axes/2');
L('F-16 loads (VITAL, NASA data)/1', 'Net force/1');
L('Weight in body axes/1', 'Net force/2');
L('Net force/1', '6DOF (Quaternion)/1');
L('F-16 loads (VITAL, NASA data)/2', '6DOF (Quaternion)/2');
L('6DOF (Quaternion)/6', 'V_b/1');
L('6DOF (Quaternion)/7', 'w_b/1');
L('6DOF (Quaternion)/5', 'DCM_be/1');
L('6DOF (Quaternion)/2', 'X_e/1');
L('6DOF (Quaternion)/3', 'euler/1');
L('Net force/1', 'F_total/1');
L('F-16 loads (VITAL, NASA data)/2', 'M_cg/1');
L('F-16 loads (VITAL, NASA data)/3', 'air/1');
L('u = u_trim + du/1', 'u/1');
L('6DOF (Quaternion)/4', 'quat/1');
L('6DOF (Quaternion)/2', 'Live: position NED/1');
L('6DOF (Quaternion)/2', 'Geopotential height/1');
L('Geopotential height/1', 'ISA Atmosphere/1');
L('6DOF (Quaternion)/6', 'Incidence, Sideslip & Airspeed/1');
L('6DOF (Quaternion)/6', 'Mach Number/1');
L('ISA Atmosphere/2', 'Mach Number/2');
L('6DOF (Quaternion)/6', 'Dynamic Pressure/1');
L('ISA Atmosphere/4', 'Dynamic Pressure/2');
fts = 'Flight-test signals';
L('Incidence, Sideslip & Airspeed/3', [fts '/1']);
L('Incidence, Sideslip & Airspeed/1', [fts '/2']);
L('Incidence, Sideslip & Airspeed/2', [fts '/3']);
L('Mach Number/1', [fts '/4']);
L('Dynamic Pressure/1', [fts '/5']);
L('6DOF (Quaternion)/2', [fts '/6']);
L('6DOF (Quaternion)/1', [fts '/7']);
L('6DOF (Quaternion)/3', [fts '/8']);
L('6DOF (Quaternion)/7', [fts '/9']);
L('u = u_trim + du/1', [fts '/10']);
L('Net force/1', [fts '/11']);
L('F-16 loads (VITAL, NASA data)/2', [fts '/12']);
add_block('simulink/Sources/Constant', [m '/trim reference'], 'Value', 'P6dof.trimRef', ...
    'Position', [940 600 1010 630]);
L('trim reference/1', [fts '/13']);
L([fts '/1'], 'sim6dof/1');
configureScope([m '/Live: change from trim']);
for k = 1:6
    L(sprintf('%s/%d', fts, k + 1), sprintf('Live: change from trim/%d', k));
end
% ---- solver, logging, callbacks ----------------------------------------------------
set_param(m, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'P6dof.dt', ...
    'StartTime', '0', 'StopTime', 'P6dof.tFinal', ...
    'SaveTime', 'on', 'TimeSaveName', 'tout', 'SaveOutput', 'on', 'OutputSaveName', 'yout', ...
    'SaveFormat', 'StructureWithTime', 'SaveState', 'off', 'SignalLogging', 'off', ...
    'LimitDataPoints', 'off', 'Decimation', '1', 'ReturnWorkspaceOutputs', 'on', ...
    'AlgebraicLoopMsg', 'error');
set_param(m, 'ReturnWorkspaceOutputs', 'off');   % pressing Run: results to the base workspace, for the StopFcn
set_param(m, 'StopFcn', ['if exist(''sim6dof'', ''var'') && exist(''P6dof'', ''var'') && P6dof.plot' newline ...
    '    vital.slx.plotTrim6dof(sim6dof, P6dof);' newline 'end']);
set_param(m, 'InitFcn', ['if ~exist(''P6dof'', ''var''), P6dof = vital.slx.trim6dofSetup(); end' newline ...
    'vital.slx.f16LoadsCg(''setup'', P6dof);']);
try
    a = Simulink.Annotation(m, ['NESC F-16 trim check (tests/M9/tF16Trim6dof.m). ' ...
        'State from the MathWorks 6DOF block -> VITAL F-16 loads from the NASA DAVE-ML data (about the CG) ' ...
        '+ weight -> 6DOF -> state. At the trim point x-bar, u-bar every state except the position stays constant.']);
    a.Position = [30 340 560 380];
catch
end
save_system(m, file);
s = struct('file', file, 'name', name);
end

function t = loadsScript()
t = sprintf(['function [F_b, M_cg, air] = loads(V_b, w_b, DCM_be, X_e, u)\n' ...
    '%%LOADS  Aero + thrust of the NESC F-16 about the CG, body axes (no weight).\n' ...
    '%%   vital.slx.f16LoadsCg evaluates the VITAL AircraftModel built from the NASA\n' ...
    '%%   DAVE-ML data objects. air = [V alpha beta Mach qbar h].\n' ...
    'coder.extrinsic(''vital.slx.f16LoadsCg'');\n' ...
    'F_b = zeros(3, 1); M_cg = zeros(3, 1); air = zeros(6, 1);\n' ...
    '[F_b, M_cg, air] = vital.slx.f16LoadsCg(V_b, w_b, DCM_be, X_e, u);\n' ...
    'end\n']);
end

function t = signalsScript()
t = strjoin({
    'function [sig, dV, dalpha, dtheta, dh, q, phi] = signals(V, alpha, beta, mach, qbar, X_e, V_e, euler, w_b, u, F, M, trimRef)'
    '%SIGNALS  The flight-test signals of this run, all from Simulink blocks (SI, rad):'
    '%   sig = [V alpha beta Mach qbar h hdot phi theta psi p q r xN xE de da dr throttle Fx Fy Fz L M N]'
    '%   and, for the live scope, the change from the trim value trimRef = [V alpha theta h]'
    '%   (ft/s, deg, deg, ft) plus q (deg/s) and phi (deg).'
    'h = -X_e(3); hdot = -V_e(3);'
    'sig = [V; alpha; beta; mach; qbar; h; hdot; euler(:); w_b(:); X_e(1); X_e(2); u(:); F(:); M(:)];'
    'dV = (V - trimRef(1)) / 0.3048; dalpha = (alpha - trimRef(2)) * 180 / pi;'
    'dtheta = (euler(2) - trimRef(3)) * 180 / pi; dh = (h - trimRef(4)) / 0.3048;'
    'q = w_b(2) * 180 / pi; phi = euler(1) * 180 / pi;'
    'end'}, newline);
end

function configureScope(blk)
sc = get_param(blk, 'ScopeConfiguration');
sc.NumInputPorts = '6';
sc.LayoutDimensions = [3 2];
names = {'dV (ft/s)', 'd alpha (deg)', 'd theta (deg)', 'dh (ft)', 'q (deg/s)', 'phi (deg)'};
band = [1 0.5 0.5 10 0.5 0.5];
for k = 1:6
    sc.ActiveDisplay = k;
    sc.YLimits = [-1 1] * band(k);
    sc.Title = ['change from trim: ' names{k}];
    sc.ShowGrid = true;
end
sc.ActiveDisplay = 1;
end

function closeIfLoaded(name)
if bdIsLoaded(name), close_system(name, 0); end
end
