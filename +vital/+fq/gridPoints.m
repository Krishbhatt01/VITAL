function pts = gridPoints(C)
%GRIDPOINTS  Enumerate (and validate) the points of a condition space.
%   pts = vital.fq.gridPoints(C)
%   C.axes   struct array {name, values}: values numeric, finite, non-empty and
%            strictly increasing; names distinct valid field names
%   C.fixed  struct of values added to every point (optional)
%   pts      struct array, one per grid point, the FIRST axis varying fastest;
%            fields: the axis names, then the fixed fields
%   Errors: vital:fq:badConditions.
arguments
    C (1,1) struct
end
if ~isfield(C, 'axes') || ~isstruct(C.axes) || isempty(C.axes) || ~all(isfield(C.axes, {'name', 'values'}))
    error('vital:fq:badConditions', 'conditions need a non-empty axes struct array with name and values.');
end
names = {C.axes.name};
if numel(unique(names)) < numel(names) || ~all(cellfun(@isvarname, names))
    error('vital:fq:badConditions', 'axis names must be distinct valid names.');
end
vals = cell(1, numel(names));
for k = 1:numel(names)
    v = C.axes(k).values;
    if ~isnumeric(v) || isempty(v) || ~all(isfinite(v(:))) || any(diff(v(:)) <= 0)
        error('vital:fq:badConditions', 'axis "%s": values must be finite, non-empty and strictly increasing.', names{k});
    end
    vals{k} = double(v(:).');
end
fixed = struct();
if isfield(C, 'fixed') && isstruct(C.fixed), fixed = C.fixed; end
for f = fieldnames(fixed).'
    if any(strcmp(f{1}, names)), error('vital:fq:badConditions', '"%s" is both an axis and fixed.', f{1}); end
end
n = cellfun(@numel, vals);
N = prod(n);
sub = cell(1, numel(n));
for i = N:-1:1
    [sub{:}] = ind2sub([n 1], i);
    p = struct();
    for k = 1:numel(names), p.(names{k}) = vals{k}(sub{k}); end
    for f = fieldnames(fixed).', p.(f{1}) = fixed.(f{1}); end
    pts(i) = p;
end
end
