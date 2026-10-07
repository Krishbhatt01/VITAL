function tr = solve(AC, env, cond, opts)
%SOLVE  Trim an aircraft: find controls and attitude that zero the accelerations.
%   tr = vital.trim.solve(AC, env, cond)
%   tr = vital.trim.solve(AC, env, cond, 'Name', value, ...)
%
%   cond   type   'level' (gamma = 0) or 'climb' (gamma given)
%          V      true airspeed (m/s, > 0)       h      geometric altitude (m)
%          gamma  air-relative flight-path angle (rad; default 0)
%          psi    heading (rad; default 0)
%   Wings level and beta = 0, so theta = alpha + gamma (CONVENTIONS 9).
%
%   Options
%     'Unknowns'      default {'alpha','de','throttle'}
%     'Residuals'     default {'udot','wdot','qdot'}; must be as many as unknowns
%                     (vital:trim:notSquare otherwise; FC-504)
%     'Bounds'        struct overriding AC.limits, e.g. struct('de_deg', [-10 10])
%     'MaxIterations' per attempt (default 400); 'Retries' extra starting points (default 3)
%     'Tol'           acceptance on the scaled residual (default 1e-9): linear
%                     accelerations / g, angular accelerations in rad/s^2
%
%   tr.status  OK                    residual < Tol and every table input inside its data
%              OUT_OF_DATA_ENVELOPE  residual < Tol but a table input was clamped (FC-508)
%              INFEASIBLE            not trimmable: an unknown sits on a bound with
%                                    residual >= Tol (e.g. alpha at the 45 deg data
%                                    limit = stall-limited; a control at its limit)
%              NOT_CONVERGED         residual >= Tol away from all bounds, after retries
%              ERROR                 the plant raised an error during the solve
%   Only OK may be used as a trim point for further analysis.
%   tr.reason explains any status other than OK. Other fields: alpha, theta,
%   u = [de; da; dr; throttle], x (13-state), xdot, residual, tol, iterations,
%   outOfEnvelope, y (plant diagnostics), cond.
arguments
    AC (1,1) struct
    env (1,1) struct
    cond (1,1) struct
    opts.Unknowns cell = {'alpha', 'de', 'throttle'}
    opts.Residuals cell = {'udot', 'wdot', 'qdot'}
    opts.Bounds (1,1) struct = struct()
    opts.MaxIterations (1,1) double {mustBePositive, mustBeInteger} = 400
    opts.Retries (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    opts.Tol (1,1) double {mustBePositive} = 1e-9
end
cond = checkCondition(cond);
UNKNOWNS = {'alpha', 'de', 'throttle'};
RESID = struct('udot', 1, 'vdot', 2, 'wdot', 3, 'pdot', 4, 'qdot', 5, 'rdot', 6);
bad = setdiff(opts.Unknowns, UNKNOWNS);
if ~isempty(bad)
    error('vital:trim:badCondition', 'unsupported trim unknown(s): %s (supported: %s).', strjoin(bad, ', '), strjoin(UNKNOWNS, ', '));
end
badR = setdiff(opts.Residuals, fieldnames(RESID));
if ~isempty(badR)
    error('vital:trim:badCondition', 'unsupported residual(s): %s.', strjoin(badR, ', '));
end
if numel(opts.Unknowns) ~= numel(opts.Residuals)
    error('vital:trim:notSquare', '%d unknowns (%s) but %d residuals (%s): the trim problem must be square.', ...
        numel(opts.Unknowns), strjoin(opts.Unknowns, ', '), numel(opts.Residuals), strjoin(opts.Residuals, ', '));
end
if ~all(ismember(UNKNOWNS, opts.Unknowns))
    error('vital:trim:badCondition', 'wings-level trim needs alpha, de and throttle as unknowns.');
end
ridx = cellfun(@(r) RESID.(r), opts.Residuals);

lim = AC.limits;
for f = fieldnames(opts.Bounds).'
    lim.(f{1}) = opts.Bounds.(f{1});
end
lb = [deg2rad(lim.alpha_deg(1)); deg2rad(lim.de_deg(1)); lim.throttle(1)];
ub = [deg2rad(lim.alpha_deg(2)); deg2rad(lim.de_deg(2)); lim.throttle(2)];
names = {'alpha', 'de', 'throttle'};
units = {'deg', 'deg', ''};
scale = [180/pi, 180/pi, 1];
g = env.g;

starts = [deg2rad([2 0]), 0.3;
          deg2rad([8 -5]), 0.5;
          deg2rad([0.5 2]), 0.1;
          deg2rad([15 -10]), 0.8];
starts = starts(1:min(size(starts, 1), 1 + opts.Retries), :);
optsLsq = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-16, ...
    'StepTolerance', 1e-14, 'OptimalityTolerance', 1e-14, 'MaxIterations', opts.MaxIterations, ...
    'MaxFunctionEvaluations', 20 * opts.MaxIterations);

best = struct('z', [], 'res', Inf, 'iter', 0, 'flag', NaN);
tr = struct('status', '', 'reason', '');
try
    for k = 1:size(starts, 1)
        z0 = min(max(starts(k, :).', lb), ub);
        [z, ~, ~, flag, out] = lsqnonlin(@residual, z0, lb, ub, optsLsq);
        r = max(abs(residual(z)));
        if r < best.res
            best = struct('z', z, 'res', r, 'iter', out.iterations, 'flag', flag);
        end
        if r < opts.Tol, break; end
    end
catch err
    tr.status = 'ERROR';
    tr.reason = sprintf('%s: %s', err.identifier, err.message);
    tr.cond = cond; tr.tol = opts.Tol;
    return
end

z = best.z;
[x, u] = build(z);
[xdot, y] = vital.plant.derivatives(x, u, AC, env);
tr.alpha = z(1);
tr.theta = z(1) + cond.gamma;
tr.u = u;
tr.x = x;
tr.xdot = xdot;
tr.residual = best.res;
tr.tol = opts.Tol;
tr.iterations = best.iter;
tr.exitflag = best.flag;
tr.outOfEnvelope = y.outOfEnvelope;
tr.y = y;
tr.cond = cond;
tr.unknowns = names;
atLo = abs(z - lb) <= 1e-7 * max(1, abs(lb));
atHi = abs(z - ub) <= 1e-7 * max(1, abs(ub));
if best.res < opts.Tol
    if y.outOfEnvelope
        tr.status = 'OUT_OF_DATA_ENVELOPE';
        tr.reason = 'converged, but at least one aero/propulsion table input was clamped to its data limits';
    else
        tr.status = 'OK';
        tr.reason = '';
    end
elseif any(atLo | atHi)
    tr.status = 'INFEASIBLE';
    parts = {};
    for i = find(atLo | atHi).'
        if atHi(i), side = 'upper'; val = ub(i); else, side = 'lower'; val = lb(i); end
        txt = sprintf('%s at %s bound %.6g %s', names{i}, side, val * scale(i), units{i});
        if i == 1 && atHi(i)
            txt = [txt ' (stall-limited: beyond the aerodynamic data)']; %#ok<AGROW>
        end
        parts{end+1} = txt; %#ok<AGROW>
    end
    tr.reason = sprintf('not trimmable (residual %.3g): %s', best.res, strjoin(parts, '; '));
else
    tr.status = 'NOT_CONVERGED';
    tr.reason = sprintf('residual %.3g after %d attempt(s) is above the tolerance %.3g, with no unknown on a bound', ...
        best.res, size(starts, 1), opts.Tol);
end

    function r = residual(zz)
        [xx, uu] = build(zz);
        d = vital.plant.derivatives(xx, uu, AC, env);
        acc = [d(1:3) / g; d(4:6)];
        r = acc(ridx);
    end

    function [xx, uu] = build(zz)
        a = zz(1); th = a + cond.gamma;
        C = vital.frames.dcm321(0, th, cond.psi);
        v_b = cond.V * [cos(a); 0; sin(a)] + C * env.wind_n(:);
        xx = [v_b; 0; 0; 0; vital.frames.eul2quat(0, th, cond.psi); 0; 0; -cond.h];
        uu = [zz(2); 0; 0; zz(3)];
    end
end

function cond = checkCondition(cond)
if ~isfield(cond, 'type') || ~any(strcmp(cond.type, {'level', 'climb'}))
    t = ''; if isfield(cond, 'type'), t = char(cond.type); end
    error('vital:trim:badCondition', 'trim type "%s" is not supported (use ''level'' or ''climb'').', t);
end
if ~isfield(cond, 'V') || ~isscalar(cond.V) || ~isfinite(cond.V) || cond.V <= 0
    error('vital:trim:badCondition', 'airspeed V must be a finite positive scalar (m/s).');
end
if ~isfield(cond, 'h') || ~isscalar(cond.h) || ~isfinite(cond.h)
    error('vital:trim:badCondition', 'altitude h must be a finite scalar (m).');
end
if ~isfield(cond, 'gamma'), cond.gamma = 0; end
if ~isfield(cond, 'psi'), cond.psi = 0; end
if strcmp(cond.type, 'level') && cond.gamma ~= 0
    error('vital:trim:badCondition', 'level trim requires gamma = 0; use type ''climb''.');
end
if ~isfinite(cond.gamma) || ~isfinite(cond.psi) || abs(cond.gamma) >= pi/2
    error('vital:trim:badCondition', 'gamma and psi must be finite, |gamma| < 90 deg.');
end
end
