function [tag, values] = envelopeTag(c, ac, validity)
%ENVELOPETAG  Tag a condition point IN or EXTRAPOLATED against a validity region.
%   [tag, values] = vital.fq.envelopeTag(c, ac, validity)
%   c         condition point (vital.fq.gridPoints)
%   ac        aircraft-factory output for c (e.g. vital.fq.f16Factory: keas)
%   validity  struct with field bounds: struct array {quantity, min, max}
%             (inclusive); a quantity is looked up in c first, then in ac
%   tag       'IN' if every quantity lies within its bounds, else 'EXTRAPOLATED'
%   values    struct quantity -> value used
%   Errors: vital:fq:badConditions (no bounds, a quantity found nowhere, or
%   a non-finite value or bound).
arguments
    c (1,1) struct
    ac (1,1) struct
    validity (1,1) struct
end
if ~isfield(validity, 'bounds') || isempty(validity.bounds) || ~all(isfield(validity.bounds, {'quantity', 'min', 'max'}))
    error('vital:fq:badConditions', 'validity needs bounds {quantity, min, max}.');
end
tag = 'IN';
values = struct();
for b = reshape(validity.bounds, 1, [])
    q = b.quantity;
    if isfield(c, q)
        v = c.(q);
    elseif isfield(ac, q)
        v = ac.(q);
    else
        error('vital:fq:badConditions', 'validity quantity "%s" is neither a condition axis nor an aircraft-factory output.', q);
    end
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && isfinite(b.min) && isfinite(b.max) && b.min <= b.max)
        error('vital:fq:badConditions', 'validity quantity "%s": non-finite value or bad bounds.', q);
    end
    values.(q) = v;
    if v < b.min || v > b.max
        tag = 'EXTRAPOLATED';
    end
end
end
