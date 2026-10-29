function x = num(v)
%NUM  A double array from its .vital.json form (vital.data.writeJson):
%   a JSON number                       -> that scalar
%   a JSON array of numbers             -> a ROW vector (hand-authored files; jsondecode
%                                          gives a column, which becomes a row; a
%                                          matrix passed in memory is unchanged)
%   "NaN", "Inf", "-Inf"                -> the non-finite value
%   {"size": [...], "values": [...]}    -> reshape(values, size) (column-major; the
%                                          values may contain the strings above)
%   true/false                          -> 1/0
%   [] -> zeros(0, 0). Anything else: vital:data:badNumber.
if isstruct(v) && isscalar(v) && isfield(v, 'size') && isfield(v, 'values') && numel(fieldnames(v)) == 2
    sz = double(v.size(:).');
    vals = v.values;
    if iscell(vals), vals = cellfun(@vital.data.internal.num, vals); end
    if ischar(vals) || isstring(vals), vals = vital.data.internal.num(vals); end
    vals = double(vals(:));
    if numel(vals) ~= prod(sz)
        error('vital:data:badNumber', '%d values for an array of size %s.', numel(vals), mat2str(sz));
    end
    if numel(sz) == 1, sz = [sz 1]; end
    x = reshape(vals, sz);
elseif isnumeric(v) || islogical(v)
    x = double(v);
    if iscolumn(x) && ~isscalar(x), x = reshape(x, 1, []); end   % a JSON array (jsondecode: a column) -> row
elseif ischar(v) || (isstring(v) && isscalar(v))
    switch char(v)
        case 'NaN', x = NaN;
        case 'Inf', x = Inf;
        case '-Inf', x = -Inf;
        otherwise, error('vital:data:badNumber', '"%s" is not a number.', char(v));
    end
elseif iscell(v)
    x = reshape(cellfun(@vital.data.internal.num, v), 1, []);
else
    error('vital:data:badNumber', 'a %s is not a number.', class(v));
end
end
