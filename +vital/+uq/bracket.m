function b = bracket(p, theta, sideFcn, opts)
%BRACKET  Breakpoint bracketing of a linearization failure (M8 amendment R4b,
%   R4-7; docs/PLAN_M5_M8.md "Amendment R4b"; generic, no aircraft).
%   b = vital.uq.bracket(p, theta, sideFcn)
%   b = vital.uq.bracket(p, theta, sideFcn, 'Breakpoints', bp, 'Proximity', 0.01,
%                        'Steps', [1e-3 2e-3 5e-3 1e-2])
%
%   Why: the NESC aero tables are piecewise linear in alpha and el. A trim that
%   lands within round-off of a breakpoint has no derivative there, so the
%   step study of vital.linear.linearize finds no plateau (NOT_CONVERGED). The
%   model has two one-sided linearizations at such a point; the requirement
%   must hold for both.
%   p        the point: p.status, p.stage (vital.fq.evaluatePoint), p.alpha_deg,
%            p.de_deg (its trim alpha and elevator, deg)
%   theta    1 x d parameter vector of the point
%   sideFcn  s = f(theta_side): the same evaluation at another parameter vector
%            (s.status, s.stage, s.alpha_deg, s.de_deg)
%   Rule:
%   - ELIGIBLE only when the linearization is NOT_CONVERGED (p.status
%     'NOT_CONVERGED' and p.stage 'linearize') and the trim alpha or elevator
%     lies within Proximity (deg, inclusive) of a breakpoint of that variable
%     (bp = vital.uq.breakpoints(): read from the generated model). Otherwise
%     'NOT_ELIGIBLE' and sideFcn is never called: physical failures (trim
%     INFEASIBLE or NOT_CONVERGED, DIVERGENT, non-classical modes, errors) are
%     never bracketed.
%   - For each d in Steps (1e-3 first, larger only if needed): the sides
%     theta x (1 - d) and theta x (1 + d) are evaluated. 'BRACKETED' when both
%     are OK and, for EVERY breakpoint within Proximity of the point, the two
%     sides' values of that variable lie strictly on opposite sides of it.
%     A side that is a physical failure (stage 'trim', or a status other than
%     OK and NOT_CONVERGED) stops: 'NOT_BRACKETED'. Sides that are OK but do not
%     straddle, or whose linearization is NOT_CONVERGED, move on to the next d.
%   - The margin of a bracketed point is the WORSE of the two sides
%     (vital.uq.F16Evaluator.worseOf); this function only decides.
%   b fields: eligible, status ('BRACKETED' | 'NOT_BRACKETED' | 'NOT_ELIGIBLE'),
%     label ('BRACKETED' or ''), reason, variable ('alpha' | 'el', the nearest
%     breakpoint), breakpoint, d (NaN unless bracketed), near (struct array:
%     variable, breakpoint, distance), sides (1 x 2: factor, theta, status,
%     stage, alpha_deg, de_deg, point), tries (every d tried).
%   Errors: vital:badInput (Proximity not finite > 0; Steps empty, not strictly
%   increasing, or outside (0, 1e-2]).
arguments
    p (1,1) struct
    theta (1,:) double
    sideFcn function_handle
    opts.Breakpoints struct = struct([])
    opts.Proximity (1,1) double = 0.01
    opts.Steps (1,:) double = [1e-3 2e-3 5e-3 1e-2]
end
if ~(isfinite(opts.Proximity) && opts.Proximity > 0)
    error('vital:badInput', 'Proximity must be finite and > 0 (deg).');
end
st = opts.Steps;
if isempty(st) || any(~isfinite(st)) || any(st <= 0) || any(st > 1e-2 * (1 + 1e-12)) || any(diff(st) <= 0)
    error('vital:badInput', 'Steps must be strictly increasing values in (0, 1e-2] (R4-7: d = 1e-3 up to 1e-2).');
end
bp = opts.Breakpoints;
if isempty(bp), bp = vital.uq.breakpoints(); end
sideT = struct('factor', {}, 'theta', {}, 'status', {}, 'stage', {}, 'alpha_deg', {}, 'de_deg', {}, 'point', {});
b = struct('eligible', false, 'status', 'NOT_ELIGIBLE', 'label', '', 'reason', '', 'variable', '', 'breakpoint', NaN, ...
    'd', NaN, 'near', struct('variable', {}, 'breakpoint', {}, 'distance', {}), 'sides', sideT, 'tries', zeros(1, 0));
if ~(strcmp(p.status, 'NOT_CONVERGED') && strcmp(p.stage, 'linearize'))
    b.reason = sprintf(['not a linearization failure (status %s at stage %s): only a NOT_CONVERGED linearization is ' ...
        'bracketed; physical failures never are'], p.status, p.stage);
    return
end
vars = {'alpha', 'el'};
vals = [val(p, 'alpha_deg'), val(p, 'de_deg')];
lists = {bp.alpha_deg, bp.el_deg};
for iv = 1:2
    if ~isfinite(vals(iv)), continue; end
    dist = abs(lists{iv} - vals(iv));
    for k = find(dist <= opts.Proximity + 1e-12)
        b.near(end+1) = struct('variable', vars{iv}, 'breakpoint', lists{iv}(k), 'distance', dist(k));
    end
end
if isempty(b.near)
    b.reason = sprintf(['linearization NOT_CONVERGED, but the trim alpha %.6f deg and elevator %.6f deg are not ' ...
        'within %g deg of a NESC aero-table breakpoint'], vals(1), vals(2), opts.Proximity);
    return
end
[~, k] = min([b.near.distance]);
b.variable = b.near(k).variable;
b.breakpoint = b.near(k).breakpoint;
b.eligible = true;
b.status = 'NOT_BRACKETED';
why = '';
for d = st
    b.tries(end+1) = d;
    f = [1 - d, 1 + d];
    S = sideT;
    for j = 1:2
        th = theta * f(j);
        s = sideFcn(th);
        S(j) = struct('factor', f(j), 'theta', th, 'status', s.status, 'stage', s.stage, ...
            'alpha_deg', val(s, 'alpha_deg'), 'de_deg', val(s, 'de_deg'), 'point', s);
    end
    b.sides = S;
    phys = arrayfun(@(x) ~strcmp(x.status, 'OK') && (strcmp(x.stage, 'trim') || ~strcmp(x.status, 'NOT_CONVERGED')), S);
    if any(phys)
        x = S(find(phys, 1));
        b.reason = sprintf(['a side is a physical failure (%s at stage %s, factor %.4g, d = %g): the point is never ' ...
            'bracketed'], x.status, x.stage, x.factor, d);
        return
    end
    if ~all(strcmp({S.status}, 'OK'))
        why = sprintf('d = %g: a side linearization is not OK (%s / %s)', d, S(1).status, S(2).status);
        continue
    end
    ok = true;
    for n = b.near(:).'
        if strcmp(n.variable, 'alpha'), v = [S.alpha_deg]; else, v = [S.de_deg]; end
        if ~((v(1) - n.breakpoint) * (v(2) - n.breakpoint) < 0)
            ok = false;
            why = sprintf(['d = %g: the sides'' %s (%.6f, %.6f deg) do not lie on opposite sides of the breakpoint ' ...
                '%g deg'], d, n.variable, v(1), v(2), n.breakpoint);
            break
        end
    end
    if ok
        b.status = 'BRACKETED';
        b.label = 'BRACKETED';
        b.d = d;
        b.reason = sprintf(['BRACKETED: linearization NOT_CONVERGED at %s = %.6f deg, %.3g deg from the breakpoint %g; ' ...
            'the sides theta x (1 -/+ %g) trim at %s = %.6f / %.6f deg (opposite sides) and both are OK; the margin ' ...
            'is the worse of the two'], b.variable, vals(strcmp(vars, b.variable)), b.near(k).distance, b.breakpoint, ...
            d, b.variable, sideVal(S(1), b.variable), sideVal(S(2), b.variable));
        return
    end
end
b.reason = sprintf('NOT_BRACKETED after d = %s: %s', mat2str(b.tries), why);
if contains(why, 'do not lie on opposite sides')
    b.reason = [b.reason ' (the sides must lie on opposite sides of the breakpoint)'];
end
end

function v = val(s, f)
if isfield(s, f) && ~isempty(s.(f)), v = double(s.(f)); else, v = NaN; end
end

function v = sideVal(s, variable)
if strcmp(variable, 'alpha'), v = s.alpha_deg; else, v = s.de_deg; end
end
