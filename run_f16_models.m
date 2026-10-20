%RUN_F16_MODELS  Evaluate NASA's five F-16 models (aero, prop, inertia, control,
%   gnc) at the NESC trim point and leave every input and output in the
%   WORKSPACE, so they can be inspected in the Variables editor.
%
%   Run:  run_f16_models          (a SCRIPT: the variables stay in the workspace)
%
%   Workspace variables after the run:
%     trim                       VITAL trim at 565.6854 ft/s, 10,013 ft, CG 25 % MAC
%     aeroIn,    aeroOut         F16_aero.dml    (degrees, ft/s, rad/s as NASA declares)
%     propIn,    propOut         F16_prop.dml    (PWR %, ALT ft, RMACH)
%     inertiaIn, inertiaOut      F16_inertia.dml (mass slug, inertia slug ft^2, CG offset)
%     controlIn, controlOut      F16_control.dml (SAS on, autopilot off)
%     gncIn,     gncOut          F16_gnc.dml     (SAS on, autopilot off)
%   Units are those declared in each NASA file (the generated functions in
%   +vital/+models/+f16 use them unchanged). Every model is NASA's, compiled
%   from the DAVE-ML files; nothing here is retyped.
addpath(fileparts(mfilename('fullpath')));
startup_vital;

% ---- operating point: VITAL's trim of NASA's README condition --------------
V_ftps = 565.6854; h_ft = 10013; cg = 25;
trim = vital.aircraft.f16.trimLevel(V_ftps, h_ft, 'CG', cg);
fprintf('trim %s: alpha %.4f deg, elevator %.4f deg, throttle %.3f %%\n', ...
    trim.status, trim.alpha_deg, trim.elevator_deg, trim.throttle_pct);

% ---- aerodynamics (F16_aero.dml) --------------------------------------------
aeroIn = struct('vt', V_ftps, 'alpha', trim.alpha_deg, 'beta', 0, ...
    'p', 0, 'q', 0, 'r', 0, ...                         % body rates, rad/s
    'el', trim.elevator_deg, 'ail', 0, 'rdr', 0);       % surfaces, deg
aeroOut = vital.models.f16.aero(aeroIn);

% ---- propulsion (F16_prop.dml) -----------------------------------------------
atm = vital.env.atmosphere(h_ft * 0.3048);
propIn = struct('PWR', trim.throttle_pct, 'ALT', h_ft, 'RMACH', V_ftps * 0.3048 / atm.a);
propOut = vital.models.f16.prop(propIn);

% ---- mass and inertia (F16_inertia.dml) --------------------------------------
inertiaIn = struct('CG_PCT_MAC', cg);
inertiaOut = vital.models.f16.inertia(inertiaIn);

% ---- control law and GNC (F16_control.dml, F16_gnc.dml) ----------------------
keas = V_ftps * 0.3048 * sqrt(atm.rho / vital.env.atmosphere(0).rho) / (1852 / 3600);
controlIn = struct('Vequiv', keas, 'alpha', trim.alpha_deg, 'beta', 0, ...
    'theta', trim.theta_deg, 'phi', 0, 'psi', 0, 'pb', 0, 'qb', 0, 'rb', 0, ...
    'altMsl', h_ft, 'altCmd', h_ft, 'keasCmd', keas, 'baseChiCmd', 0, 'latOffset', 0, ...
    'longStk', 0, 'latStk', 0, 'pedal', 0, 'throttle', trim.throttle_pct / 100, ...
    'longStkTrim', -trim.elevator_deg / 25, 'throttleTrim', trim.throttle_pct / 100, ...
    'sasOn', 1, 'apOn', 0);
controlOut = vital.models.f16.control(controlIn);

gncIn = rmfield(controlIn, {'baseChiCmd', 'latOffset'});
gncIn.circlePoleSW = 0; gncIn.ownshipN_deg = 36; gncIn.ownshipE_deg = -75;
gncOut = vital.models.f16.gnc(gncIn);

% ---- short summary ------------------------------------------------------------
fprintf('aero:    CX %.5f  CY %.5f  CZ %.5f  Cl %.5f  Cm %.5f  Cn %.5f\n', ...
    aeroOut.cx, aeroOut.cy, aeroOut.cz, aeroOut.cl, aeroOut.cm, aeroOut.cn);
fprintf('prop:    thrust FEX %.1f lbf\n', propOut.FEX);
f = fieldnames(inertiaOut);
fprintf('inertia: %s\n', strjoin(f(1:min(8, end))', ', '));
fprintf('control: %d outputs, gnc: %d outputs (open controlOut / gncOut)\n', ...
    numel(fieldnames(controlOut)), numel(fieldnames(gncOut)));
fprintf('All inputs and outputs are in the workspace: aeroIn/aeroOut, propIn/propOut, inertiaIn/inertiaOut, controlIn/controlOut, gncIn/gncOut, trim.\n');
clear f V_ftps h_ft cg atm keas
