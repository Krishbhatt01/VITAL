function r = trimLevel(V_ftps, h_ft, opts)
%TRIMLEVEL  Trim the NESC F-16 in wings-level flight, in published units.
%   r = vital.aircraft.f16.trimLevel(V_ftps, h_ft)
%   r = vital.aircraft.f16.trimLevel(V_ftps, h_ft, 'CG', 25, 'g_ftps2', 32.174, 'gamma_deg', 0)
%
%   V_ftps     true airspeed, ft/s          h_ft      altitude (geometric), ft
%   CG         % MAC (default 25, the NESC value)
%   g_ftps2    flat-earth gravity (default 32.174, the NESC README value)
%   gamma_deg  flight-path angle (default 0 = level)
%
%   r fields: status, reason, theta_deg, alpha_deg, elevator_deg (+TED),
%   throttle_pct (power lever angle, 0-100; 50 = MIL, 100 = MAX), mach,
%   qbar_psf, thrust_lbf, and trim (the full vital.trim.solve result).
%   Called without an output, it prints a summary.
%
%   Example (reproduces NESC README Table 11):
%       vital.aircraft.f16.trimLevel(565.6854, 10013)
arguments
    V_ftps (1,1) double
    h_ft (1,1) double
    opts.CG (1,1) double = 25
    opts.g_ftps2 (1,1) double = 32.174
    opts.gamma_deg (1,1) double = 0
end
ft = 0.3048;
AC = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG);
env = struct('g', opts.g_ftps2 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
if opts.gamma_deg == 0, type = 'level'; else, type = 'climb'; end
cond = struct('type', type, 'V', V_ftps * ft, 'h', h_ft * ft, 'gamma', deg2rad(opts.gamma_deg), 'psi', 0);
tr = vital.trim.solve(AC, env, cond);
r.status = tr.status;
r.reason = tr.reason;
r.V_ftps = V_ftps; r.h_ft = h_ft; r.cg_pct_mac = opts.CG; r.gamma_deg = opts.gamma_deg;
if isfield(tr, 'u')
    r.theta_deg = rad2deg(tr.theta);
    r.alpha_deg = rad2deg(tr.alpha);
    r.elevator_deg = rad2deg(tr.u(1));
    r.throttle_pct = 100 * tr.u(4);
    r.mach = tr.y.mach;
    r.qbar_psf = tr.y.qbar / vital.units.constants().psf;
    r.thrust_lbf = tr.y.thrust_lbf;
    r.residual = tr.residual;
else
    [r.theta_deg, r.alpha_deg, r.elevator_deg, r.throttle_pct, r.mach, r.qbar_psf, r.thrust_lbf, r.residual] = deal(NaN);
end
r.trim = tr;
if nargout == 0
    fprintf('F-16 trim  V = %.4f ft/s  h = %.0f ft  CG = %.1f %% MAC  gamma = %.2f deg  g = %.4f ft/s^2\n', ...
        V_ftps, h_ft, opts.CG, opts.gamma_deg, opts.g_ftps2);
    fprintf('  status        %s %s\n', r.status, r.reason);
    fprintf('  theta         %9.4f deg\n  alpha         %9.4f deg\n  elevator      %9.4f deg (+TED)\n', ...
        r.theta_deg, r.alpha_deg, r.elevator_deg);
    fprintf('  throttle/PLA  %9.4f %%\n  Mach          %9.4f\n  thrust        %9.1f lbf\n  residual      %9.2e\n', ...
        r.throttle_pct, r.mach, r.thrust_lbf, r.residual);
    clear r
end
end
