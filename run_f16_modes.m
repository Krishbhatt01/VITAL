function r = run_f16_modes(V_ftps, h_ft, opts)
%RUN_F16_MODES  Trim, linearize and list the flight modes of the NESC F-16
%   (the entry point for users).
%
%   run_f16_modes                          NESC README condition: 565.6854 ft/s, 10,013 ft
%   run_f16_modes(700, 15000)              any airspeed (ft/s, true) and altitude (ft)
%   run_f16_modes(700, 15000, 'CG', 30)    other CG (% MAC); also 'g_ftps2', 'gamma_deg'
%                                          as in vital.aircraft.f16.trimLevel
%   r = run_f16_modes(...)                 returns the results instead of printing
%
%   Prints the trim and linearization status and a table of modes: name,
%   eigenvalue (1/s), natural frequency wn (rad/s), damping ratio zeta, period (s),
%   time to half / double amplitude (s), time constant tau = -1/lambda of real
%   roots (s), dominant states (by participation factor) and the mode status
%   (OK | NOT_OSCILLATORY | UNCLASSIFIED; docs/CONVENTIONS.md, vital.linear.modes).
%   A trim that is not OK (e.g. INFEASIBLE, stall-limited) is reported and NOT
%   linearized. A linearization that is not OK (FC-506) is reported. The modes
%   are still computed when the columns they use converged (e.g. at 20,000 ft
%   only the altitude column sits on a thrust-table breakpoint; review R1 M1).
%   The mode table is the 8-state contract model. The phugoid WITH the altitude
%   coupling (density and thrust gradients; the one the nonlinear aircraft
%   flies, and the one M6 phugoid rules use) is printed below it, labelled
%   'phugoid (with h)', together with the 'height' mode. It is shown only when
%   the altitude column converged (review R1 M5).
%
%   r fields: status (trim status, or the linearization status when the trim
%   is OK), reason, V_ftps, h_ft, cg_pct_mac, gamma_deg, trim (trimLevel
%   result), lin (vital.linear.linearize) or [], modes (vital.linear.modes,
%   8 states) or [], table (vital.linear.modeTable of modes) or [],
%   modesHeight (vital.linear.modes(lin, 'IncludeHeight', true)) or [] when
%   column 12 did not converge.
%
%   Works from any MATLAB session: it puts VITAL on the path itself.
arguments
    V_ftps (1,1) double = 565.6854
    h_ft (1,1) double = 10013
    opts.CG (1,1) double = 25
    opts.g_ftps2 (1,1) double = 32.174
    opts.gamma_deg (1,1) double = 0
end
addpath(fileparts(mfilename('fullpath')));
ft = 0.3048;
t = vital.aircraft.f16.trimLevel(V_ftps, h_ft, 'CG', opts.CG, 'g_ftps2', opts.g_ftps2, 'gamma_deg', opts.gamma_deg);
res = struct('status', t.status, 'reason', t.reason, 'V_ftps', V_ftps, 'h_ft', h_ft, ...
    'cg_pct_mac', opts.CG, 'gamma_deg', opts.gamma_deg, 'trim', t, 'lin', [], 'modes', [], 'table', [], ...
    'modesHeight', []);
if strcmp(t.status, 'OK')
    % the same aircraft and environment as trimLevel
    AC = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG);
    env = struct('g', opts.g_ftps2 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
    lin = vital.linear.linearize(AC, env, t.trim);
    res.lin = lin;
    res.status = lin.status;
    res.reason = lin.reason;
    colOK = strcmp(lin.columnStatus, 'OK');
    if all(colOK(1:8))
        res.modes = vital.linear.modes(lin);
        res.table = vital.linear.modeTable(res.modes);
        if colOK(12)
            res.modesHeight = vital.linear.modes(lin, 'IncludeHeight', true);
        end
    end
end
if nargout > 0
    r = res;
    return
end
fprintf('F-16 flight modes  V = %.4f ft/s  h = %.0f ft  CG = %.1f %% MAC  gamma = %.2f deg  g = %.4f ft/s^2\n', ...
    V_ftps, h_ft, opts.CG, opts.gamma_deg, opts.g_ftps2);
fprintf('  trim status           %s %s\n', t.status, t.reason);
if ~strcmp(t.status, 'OK')
    fprintf('  not linearized: only an OK trim may be analysed.\n');
    return
end
fprintf('  trim                  alpha %.4f deg, theta %.4f deg, elevator %.4f deg, throttle %.4f %%\n', ...
    t.alpha_deg, t.theta_deg, t.elevator_deg, t.throttle_pct);
fprintf('  linearization status  %s %s\n', res.lin.status, res.lin.reason);
if isempty(res.modes)
    fprintf('  no modal analysis: a column used by the modes (1-8) is not converged.\n');
    return
end
if ~strcmp(res.lin.status, 'OK')
    fprintf('  (the failed columns are not used by the 8-state modes below)\n');
end
fprintf('  n/alpha (MIL-F-8785C, steady state) %.4f g/rad (%s); alpha partial n_alpha %.4f g/rad\n\n', ...
    res.lin.n_alpha_ss, res.lin.n_alpha_ss_status, res.lin.n_alpha);
T = res.table;
fprintf('  %-13s %-22s %9s %8s %9s %9s %9s %9s  %-18s %s\n', 'mode', 'eigenvalue (1/s)', 'wn rad/s', 'zeta', ...
    'period s', 't_half s', 't_dbl s', 'tau s', 'dominant', 'status');
for k = 1:height(T)
    fprintf('  %-13s %-22s %9.4f %8.4f %9.3f %9.3f %9.3f %9.4f  %-18s %s\n', T.mode(k), T.eigenvalue(k), ...
        T.wn_rad_s(k), T.zeta(k), T.period_s(k), T.tHalf_s(k), T.tDouble_s(k), T.tau_s(k), T.dominant(k), T.status(k));
end
fprintf('  (NaN = not defined for that mode; participation-factor states u v w p q r phi theta)\n');
if isempty(res.modesHeight)
    fprintf('  phugoid (with h): not available - column 12 (h) of the linear model did not converge.\n');
else
    fprintf('  with the altitude coupling (9 states; used by the M6 phugoid rules):\n');
    for nm = {'phugoid', 'height'}
        e = res.modesHeight(strcmp({res.modesHeight.name}, nm{1}));
        for k = 1:numel(e)
            lbl = nm{1}; if strcmp(lbl, 'phugoid'), lbl = 'phugoid (with h)'; end
            if e(k).oscillatory
                fprintf('  %-17s %8.4f +/- %.4fi  wn %.4f rad/s  zeta %.4f  period %.3f s  %s\n', lbl, ...
                    real(e(k).eigenvalue), imag(e(k).eigenvalue), e(k).wn, e(k).zeta, e(k).period, e(k).status);
            else
                fprintf('  %-17s %8.4f  tau %.3f s  %s\n', lbl, real(e(k).eigenvalue), e(k).tau, e(k).status);
            end
        end
    end
end
end
