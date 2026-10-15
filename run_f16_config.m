%RUN_F16_CONFIG  Build the F-16 aircraft setup (the AC struct) with settings you
%   choose, print it in familiar units, and (optionally) trim it.
%
%   HOW TO USE: edit the values in the "SETTINGS" block below, save, and run
%       run_f16_config
%   It is a SCRIPT: AC (and trimResult, if trimmed) stay in the workspace, so
%   you can open them in the Variables editor.
%
%   The setup itself is built by vital.aircraft.f16.config (help
%   vital.aircraft.f16.config lists every option). Nothing here changes NASA's
%   data; the multipliers below only scale terms of NASA's tables.

% ============================== SETTINGS ====================================
CG_pct_MAC = 25;          % CG position, % mean aerodynamic chord (NASA: 25)

% Aerodynamic multipliers (1 = NASA's data unchanged). Examples: 0.8 = 20 % less.
aero.Cm_q      = 1;       % pitch damping
aero.Cl_p      = 1;       % roll damping
aero.Cn_r      = 1;       % yaw damping
aero.Cnt_table = 1;       % directional stability (sideslip yawing-moment table)
aero.Cl_table  = 1;       % dihedral effect (sideslip rolling-moment table)
aero.Cm_basic  = 1;       % static pitching moment (table at zero elevator)
aero.Cm_de     = 1;       % elevator power (elevator increment of the pitching-moment table)

% Optional: trim the aircraft at a flight condition (set doTrim = false to skip)
doTrim   = true;
V_ftps   = 565.6854;      % true airspeed, ft/s (NASA: 565.6854)
h_ft     = 10013;         % altitude, ft (NASA: 10,013)
gamma_deg = 0;            % flight-path angle, deg (0 = level, >0 = climb)
% ============================================================================

addpath(fileparts(mfilename('fullpath')));
startup_vital;

% keep only the multipliers that differ from 1 (1 leaves NASA's model untouched)
f = fieldnames(aero); scale = struct();
for k = 1:numel(f)
    if aero.(f{k}) ~= 1, scale.(f{k}) = aero.(f{k}); end
end

AC = vital.aircraft.f16.config('CG_PCT_MAC', CG_pct_MAC, 'AeroScale', scale);

% ---- print the setup in familiar units -------------------------------------
k = vital.units.constants();
fprintf('\n%s\n', AC.name);
fprintf('  CG                %.1f %% MAC  (%.3f ft ahead of the 35 %% MAC reference point)\n', ...
    AC.cgPctMac, AC.r_cg(1) / k.ft);
fprintf('  wing area S       %.1f ft^2   span b %.1f ft   chord cbar %.2f ft\n', ...
    AC.S / k.ft^2, AC.b / k.ft, AC.cbar / k.ft);
fprintf('  mass              %.2f slug  (weight %.0f lbf at g = 32.174 ft/s^2)\n', ...
    AC.mass / k.slug, AC.mass / k.slug * 32.174);
Jft = AC.J / (k.slug * k.ft^2);
fprintf('  inertia (slug ft^2)  Ixx %.0f  Iyy %.0f  Izz %.0f  Ixz %.0f\n', ...
    Jft(1, 1), Jft(2, 2), Jft(3, 3), -Jft(1, 3));
fprintf('  controls          %s\n', strjoin(AC.controlNames, ', '));
if isempty(fieldnames(scale))
    fprintf('  aero multipliers  none (NASA data unchanged)\n');
else
    s = fieldnames(scale);
    fprintf('  aero multipliers  %s\n', strjoin(cellfun(@(n) sprintf('%s x %g', n, scale.(n)), s, 'UniformOutput', false), ', '));
end
fprintf('  control limits:\n'); disp(AC.limits);

% ---- optional trim ------------------------------------------------------------
if doTrim
    % trims THIS AC (including any multipliers above)
    env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
    if gamma_deg == 0, ttype = 'level'; else, ttype = 'climb'; end
    cond = struct('type', ttype, 'V', V_ftps * k.ft, 'h', h_ft * k.ft, 'gamma', deg2rad(gamma_deg), 'psi', 0);
    trimResult = vital.trim.solve(AC, env, cond);
    fprintf('Trim at %.1f ft/s, %.0f ft, gamma %.1f deg: %s\n', V_ftps, h_ft, gamma_deg, trimResult.status);
    if strcmp(trimResult.status, 'OK')
        fprintf('  alpha %.4f deg   pitch %.4f deg   elevator %.4f deg   throttle %.3f %%   Mach %.3f\n', ...
            rad2deg(trimResult.alpha), rad2deg(trimResult.theta), rad2deg(trimResult.u(1)), ...
            100 * trimResult.u(4), trimResult.y.mach);
    else
        fprintf('  reason: %s\n', trimResult.reason);
    end
    clear env cond ttype
end
clear f k s Jft
