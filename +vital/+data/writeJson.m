function writeJson(file, s)
%WRITEJSON  Write a struct as JSON with EVERY double kept bit for bit (D1, criterion 5).
%   vital.data.writeJson(file, s)
%   Doubles are written with sprintf('%.17g'), which round-trips every double
%   exactly (17 significant digits; jsondecode is correctly rounded, tested in
%   tests/M9/data/tDataJson.m):
%     scalar          a JSON number                (NaN, Inf, -Inf as "NaN", "Inf", "-Inf")
%     other arrays    {"size": [r, c, ...], "values": [column-major list]}
%   Text, logicals, structs and cells are written by jsonencode (PrettyPrint).
%   Never num2str or jsonencode's own number formatting (15 digits).
arguments
    file (1,:) char
    s
end
nums = {};
[s, nums] = tokenize(s, nums);
txt = jsonencode(s, 'PrettyPrint', true);
[parts, tok] = regexp(txt, '"@@N(\d+)@@"', 'split', 'tokens');
out = cell(1, 2 * numel(parts) - 1);
out(1:2:end) = parts;
for k = 1:numel(tok)
    out{2 * k} = encode(nums{str2double(tok{k}{1})});
end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0, error('vital:data:cannotWrite', 'cannot write %s', file); end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', strjoin(out, ''));
end

function [x, nums] = tokenize(x, nums)
if isstruct(x)
    for i = 1:numel(x)
        for f = fieldnames(x).'
            [x(i).(f{1}), nums] = tokenize(x(i).(f{1}), nums);
        end
    end
elseif iscell(x)
    for i = 1:numel(x)
        [x{i}, nums] = tokenize(x{i}, nums);
    end
elseif isnumeric(x)
    if ~isa(x, 'double') || ~isreal(x)
        error('vital:data:badNumber', 'only real doubles are written (got %s).', class(x));
    end
    nums{end+1} = x;
    x = sprintf('@@N%d@@', numel(nums));
end
end

function t = encode(x)
if isscalar(x)
    t = fmt(x);
else
    v = arrayfun(@fmt, x(:).', 'UniformOutput', false);
    t = sprintf('{"size": [%s], "values": [%s]}', strjoin(arrayfun(@(n) sprintf('%d', n), size(x), 'UniformOutput', false), ', '), ...
        strjoin(v, ', '));
end
end

function s = fmt(v)
if isfinite(v)
    s = sprintf('%.17g', v);
elseif isnan(v)
    s = '"NaN"';
elseif v > 0
    s = '"Inf"';
else
    s = '"-Inf"';
end
end
