function c = invarianceCheck(qfun, th0, ths, opts)
%INVARIANCECHECK  Is a quantity unchanged when some parameters move? (M8
%   amendment R4b, R4-9: the runtime gate of a lateral group that does not
%   search Cm_q).
%   c = vital.uq.invarianceCheck(qfun, th0, ths)
%   c = vital.uq.invarianceCheck(qfun, th0, ths, 'RelTol', 1e-9)
%   q = qfun(theta): q.status ('OK' or not), q.value
%   th0  1 x d reference parameters; ths  n x d moved parameters
%   c.passed is true when q is OK at th0 and at every row of ths and every value
%   equals the reference value within RelTol relative (exactly when the
%   reference is 0, Inf or NaN). c fields: passed, reason, value0, values,
%   maxRel, theta0, thetas.
%   Errors: vital:badInput (ths without the columns of th0, RelTol not >= 0).
arguments
    qfun function_handle
    th0 (1,:) double
    ths (:,:) double
    opts.RelTol (1,1) double = 1e-9
end
if size(ths, 2) ~= numel(th0) || ~(opts.RelTol >= 0)
    error('vital:badInput', 'ths must have %d columns and RelTol must be >= 0.', numel(th0));
end
c = struct('passed', false, 'reason', '', 'value0', NaN, 'values', NaN(size(ths, 1), 1), 'maxRel', 0, ...
    'theta0', th0, 'thetas', ths);
q0 = qfun(th0);
c.value0 = q0.value;
if ~strcmp(q0.status, 'OK')
    c.reason = sprintf('the reference point is not OK: %s at theta %s', q0.status, mat2str(th0, 6));
    return
end
v0 = q0.value;
for k = 1:size(ths, 1)
    q = qfun(ths(k, :));
    c.values(k) = q.value;
    if ~strcmp(q.status, 'OK')
        c.reason = sprintf('a moved point is not OK: %s at theta %s', q.status, mat2str(ths(k, :), 6));
        return
    end
    v = q.value;
    if isequaln(v, v0)
        continue
    end
    if isfinite(v0) && v0 ~= 0 && isfinite(v)
        r = abs(v - v0) / abs(v0);
        c.maxRel = max(c.maxRel, r);
        if r <= opts.RelTol, continue; end
        c.reason = sprintf('value %.10g vs %.10g at theta %s: relative difference %.3g > %g', v, v0, ...
            mat2str(ths(k, :), 6), r, opts.RelTol);
    else
        c.reason = sprintf('value %.10g vs %.10g at theta %s (not equal; relative tolerance %g)', v, v0, ...
            mat2str(ths(k, :), 6), opts.RelTol);
    end
    return
end
c.passed = true;
c.reason = sprintf('value %.10g unchanged at %d moved point(s) within %g relative (largest %.3g)', v0, size(ths, 1), ...
    opts.RelTol, c.maxRel);
end
