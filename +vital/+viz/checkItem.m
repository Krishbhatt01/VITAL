function c = checkItem(what, value, expected, tol, ref)
%CHECKITEM  One numeric check of an axis-check case.
%   c = vital.viz.checkItem(what, value, expected, tol, ref)
%     what      short description shown on the figure
%     value     what VITAL produced
%     expected  the INDEPENDENT reference value (never the same code path)
%     tol       absolute tolerance on max |value - expected| (0 for logical checks)
%     ref       'ANALYTIC' (closed form built in the check) or 'INDEP' (an
%               independent implementation, e.g. the Aerospace Toolbox)
%   c.pass is true only if every value is finite and within tol. A logical
%   check (value and expected logical) passes only when they are equal.
%   Errors: vital:badInput for an unknown reference tag.
if ~ismember(ref, {'ANALYTIC', 'INDEP'})
    error('vital:badInput', 'reference tag must be ANALYTIC or INDEP, got "%s".', ref);
end
if islogical(value) || islogical(expected)
    pass = isequal(logical(value), logical(expected));
    err = double(~pass);
else
    v = double(value(:)); e = double(expected(:));
    pass = numel(v) == numel(e) && all(isfinite(v)) && max(abs(v - e)) <= tol;
    if numel(v) == numel(e), err = max(abs(v - e)); else, err = NaN; end
end
c = struct('what', what, 'value', value, 'expected', expected, 'tol', tol, ...
    'error', err, 'ref', ref, 'pass', logical(pass));
end
