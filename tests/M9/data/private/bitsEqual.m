function [ok, n, where] = bitsEqual(a, b, path)
%BITSEQUAL  Walk two values (structs, cells, numbers, text, logicals) and compare
%   EVERY double bit for bit (typecast to uint64; any NaN equals any NaN, since
%   MATLAB does not preserve NaN payloads), sizes, classes and text exactly.
%   [ok, n, where] = bitsEqual(a, b): n = number of doubles compared; where = the
%   first path that differs ('' if none).
if nargin < 3, path = 'root'; end
ok = true; n = 0; where = '';
if ~strcmp(class(a), class(b)) || ~isequal(size(a), size(b))
    ok = false; where = sprintf('%s (class %s %s vs %s %s)', path, class(a), mat2str(size(a)), class(b), mat2str(size(b)));
    return
end
if isstruct(a)
    fa = sort(fieldnames(a)); fb = sort(fieldnames(b));
    if ~isequal(fa, fb)
        ok = false; where = [path ' (fields differ)']; return
    end
    for i = 1:numel(a)
        for f = fa.'
            [ok, m, where] = bitsEqual(a(i).(f{1}), b(i).(f{1}), sprintf('%s(%d).%s', path, i, f{1}));
            n = n + m;
            if ~ok, return; end
        end
    end
elseif iscell(a)
    for i = 1:numel(a)
        [ok, m, where] = bitsEqual(a{i}, b{i}, sprintf('%s{%d}', path, i));
        n = n + m;
        if ~ok, return; end
    end
elseif isa(a, 'double')
    n = numel(a);
    na = isnan(a(:)); nb = isnan(b(:));
    if n == 0, return; end
    if ~isequal(na, nb) || ~isequal(typecast(reshape(a(~na), [], 1), 'uint64'), typecast(reshape(b(~nb), [], 1), 'uint64'))
        ok = false; where = [path ' (double bits differ)'];
    end
elseif isa(a, 'function_handle')
    ok = strcmp(func2str(a), func2str(b));
    if ~ok, where = [path ' (function handle)']; end
else
    ok = isequal(a, b);
    if ~ok, where = [path ' (value differs)']; end
end
end
