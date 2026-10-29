function c = asCellstr(v)
%ASCELLSTR  A 1xN cellstr from a cellstr, a char row, a string array or [] / {}.
if isempty(v)
    c = cell(1, 0);
elseif ischar(v)
    c = {v};
elseif isstring(v)
    c = reshape(cellstr(v), 1, []);
else
    c = reshape(cellfun(@char, v, 'UniformOutput', false), 1, []);
end
end
