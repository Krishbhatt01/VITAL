function r = loadsReport(V_ftps, h_ft, opts)
%LOADSREPORT  Force and moment breakdown of the NESC F-16, in published units.
%   r = vital.aircraft.f16.loadsReport(V_ftps, h_ft)
%       trims wings-level (vital.aircraft.f16.trimLevel conditions) and breaks
%       the loads at the trim down into aero, thrust and gravity
%   r = vital.aircraft.f16.loadsReport(V_ftps, h_ft, 'alpha_deg', 8, 'elevator_deg', 0, 'throttle_pct', 50)
%       evaluates a SPECIFIED wings-level state instead (zero body rates,
%       theta = alpha + gamma). It is not a trim: the totals do not balance,
%       and r.accel shows where the aircraft would accelerate.
%   Other options: 'CG' (% MAC, 25), 'g_ftps2' (32.174), 'gamma_deg' (0).
%
%   r.loads   table, rows Aero / Thrust / Gravity / Total, columns
%             X_lbf Y_lbf Z_lbf (body axes: x forward, y right, z down) and
%             L_ftlbf M_ftlbf N_ftlbf (roll, pitch, yaw moments ABOUT THE CG).
%             Aero moments are published about the MRC (35 % MAC) and moved
%             here to the CG: M_cg = M_mrc + (r_mrc - r_cg) x F.
%             The Total row is the plant's own total (vital.plant.derivatives).
%   r.lift_lbf, r.drag_lbf, r.side_lbf   aero force in wind axes
%   r.weight_lbf, r.thrust_lbf, r.coeff (CX CY CZ Cl Cm Cn), r.qbar_psf, r.mach
%   r.accel   body accelerations udot vdot wdot (ft/s^2), pdot qdot rdot (deg/s^2)
%   r.status  trim status (CONVENTIONS 9), or SPECIFIED; r.trimmed is true only for OK
%   r.si      plant values in SI: x, u, xdot, F_b, M_cg
%   Called without an output, it prints the breakdown.
%   Errors: vital:trim:badCondition (bad trim condition), vital:badInput (a
%   specified state that is incomplete or not finite).
arguments
    V_ftps (1,1) double
    h_ft (1,1) double
    opts.CG (1,1) double = 25
    opts.g_ftps2 (1,1) double = 32.174
    opts.gamma_deg (1,1) double = 0
    opts.alpha_deg double = []
    opts.elevator_deg double = []
    opts.throttle_pct double = []
end
k = vital.units.constants();
ft = k.ft; lbf = k.lbf; ftlbf = k.lbf * k.ft;
given = [~isempty(opts.alpha_deg), ~isempty(opts.elevator_deg), ~isempty(opts.throttle_pct)];
specified = any(given);
AC = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG);
env = struct('g', opts.g_ftps2 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
gam = deg2rad(opts.gamma_deg);

r.V_ftps = V_ftps; r.h_ft = h_ft; r.cg_pct_mac = opts.CG; r.gamma_deg = opts.gamma_deg;
r.g_ftps2 = opts.g_ftps2;
if specified
    if ~all(given)
        error('vital:badInput', 'a specified state needs all of alpha_deg, elevator_deg and throttle_pct.');
    end
    vital.validate.finite([opts.alpha_deg, opts.elevator_deg, opts.throttle_pct, V_ftps, h_ft, gam], 'specified state');
    if ~isscalar(opts.alpha_deg) || ~isscalar(opts.elevator_deg) || ~isscalar(opts.throttle_pct)
        error('vital:badInput', 'alpha_deg, elevator_deg and throttle_pct must be scalars.');
    end
    if V_ftps <= 0
        error('vital:badInput', 'airspeed must be positive, got %g ft/s.', V_ftps);
    end
    a = deg2rad(opts.alpha_deg); th = a + gam;
    x = [V_ftps * ft * [cos(a); 0; sin(a)]; 0; 0; 0; vital.frames.eul2quat(0, th, 0); 0; 0; -h_ft * ft];
    u = [deg2rad(opts.elevator_deg); 0; 0; opts.throttle_pct / 100];
    r.status = 'SPECIFIED';
    r.reason = 'a state you specified';
else
    if gam == 0, type = 'level'; else, type = 'climb'; end
    cond = struct('type', type, 'V', V_ftps * ft, 'h', h_ft * ft, 'gamma', gam, 'psi', 0);
    tr = vital.trim.solve(AC, env, cond);
    r.status = tr.status;
    r.reason = tr.reason;
    if ~isfield(tr, 'x')
        r.trimmed = false;
        r.loads = [];
        if nargout == 0, fprintf('F-16 loads: status %s %s\n', r.status, r.reason); clear r; end
        return
    end
    x = tr.x; u = tr.u;
end
r.trimmed = strcmp(r.status, 'OK');

[xdot, y] = vital.plant.derivatives(x, u, AC, env);
C = vital.frames.quat2dcm(x(7:10));
d = AC.r_mrc - AC.r_cg;                          % MRC relative to the CG
F_a = y.F_aero; M_a = y.M_aero + cross(d, F_a);
F_p = y.F_prop; M_p = y.M_prop + cross(d, F_p);
F_g = AC.mass * C * [0; 0; env.g];
rows = [F_a.' / lbf, M_a.' / ftlbf;
        F_p.' / lbf, M_p.' / ftlbf;
        F_g.' / lbf, 0 0 0;
        y.F_b.' / lbf, y.M_cg.' / ftlbf];
r.loads = array2table(rows, 'RowNames', {'Aero', 'Thrust', 'Gravity', 'Total'}, ...
    'VariableNames', {'X_lbf', 'Y_lbf', 'Z_lbf', 'L_ftlbf', 'M_ftlbf', 'N_ftlbf'});

al = y.alpha; be = y.beta;
C_wb = [ cos(al)*cos(be),  sin(be),  sin(al)*cos(be);
        -cos(al)*sin(be),  cos(be), -sin(al)*sin(be);
        -sin(al),          0,        cos(al)];
F_aw = C_wb * F_a / lbf;
r.lift_lbf = -F_aw(3);
r.drag_lbf = -F_aw(1);
r.side_lbf = F_aw(2);
r.weight_lbf = AC.mass * env.g / lbf;
r.thrust_lbf = y.thrust_lbf;
c = y.coeff;
r.coeff = struct('CX', c(1), 'CY', c(2), 'CZ', c(3), 'Cl', c(4), 'Cm', c(5), 'Cn', c(6));
r.alpha_deg = rad2deg(al);
r.theta_deg = rad2deg(al + gam);
r.elevator_deg = rad2deg(u(1));
r.throttle_pct = 100 * u(4);
r.mach = y.mach;
r.qbar_psf = y.qbar / k.psf;
r.outOfEnvelope = y.outOfEnvelope;
r.accel = struct('udot', xdot(1) / ft, 'vdot', xdot(2) / ft, 'wdot', xdot(3) / ft, ...
    'pdot', rad2deg(xdot(4)), 'qdot', rad2deg(xdot(5)), 'rdot', rad2deg(xdot(6)));
r.si = struct('x', x, 'u', u, 'xdot', xdot, 'F_b', y.F_b, 'M_cg', y.M_cg);

if nargout == 0
    printReport(r);
    clear r
end
end

function printReport(r)
fprintf('F-16 loads  V = %.4f ft/s  h = %.0f ft  CG = %.1f %% MAC  gamma = %.2f deg  g = %.4f ft/s^2\n', ...
    r.V_ftps, r.h_ft, r.cg_pct_mac, r.gamma_deg, r.g_ftps2);
if r.trimmed
    fprintf('  status  OK: trimmed, so every Total is zero to solver tolerance\n');
else
    fprintf('  status  %s: NOT a trim (%s); the totals do not balance\n', r.status, r.reason);
end
fprintf('  alpha %.4f deg   theta %.4f deg   elevator %.4f deg (+TED)   throttle %.4f %%\n', ...
    r.alpha_deg, r.theta_deg, r.elevator_deg, r.throttle_pct);
fprintf('  Mach %.4f   qbar %.2f psf\n', r.mach, r.qbar_psf);
c = r.coeff;
fprintf('  coefficients  CX %.5f  CY %.5f  CZ %.5f  Cl %.5f  Cm %.5f  Cn %.5f\n', c.CX, c.CY, c.CZ, c.Cl, c.Cm, c.Cn);
fprintf('\n  Body axes (x forward, y right, z down). Forces in lbf, moments about the CG in ft lbf\n');
fprintf('  %-8s %11s %11s %11s %13s %13s %13s\n', '', 'X', 'Y', 'Z', 'L (roll)', 'M (pitch)', 'N (yaw)');
names = r.loads.Properties.RowNames;
for i = 1:numel(names)
    v = r.loads{i, :};
    if i == numel(names), fprintf('  %s\n', repmat('-', 1, 84)); end
    fprintf('  %-8s %11.2f %11.2f %11.2f %13.2f %13.2f %13.2f\n', names{i}, v);
end
fprintf('\n  Wind axes (aero only): Lift %.1f lbf   Drag %.1f lbf   Side %.1f lbf   L/D %.2f\n', ...
    r.lift_lbf, r.drag_lbf, r.side_lbf, r.lift_lbf / r.drag_lbf);
fprintf('  Weight %.1f lbf   Thrust %.1f lbf\n', r.weight_lbf, r.thrust_lbf);
a = r.accel;
fprintf('  Accelerations  udot %.4g  vdot %.4g  wdot %.4g ft/s^2   pdot %.4g  qdot %.4g  rdot %.4g deg/s^2\n', ...
    a.udot, a.vdot, a.wdot, a.pdot, a.qdot, a.rdot);
if r.outOfEnvelope
    fprintf('  WARNING: a table input was clamped to the NASA data limits.\n');
end
end
