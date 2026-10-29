function c = asList(v)
%ASLIST  A JSON array of objects as a 1xN cell of structs: jsondecode returns a
%   struct ARRAY when all objects have the same fields and a cell otherwise; []
%   (an empty JSON array) gives {}.
if isempty(v)
    c = {};
elseif iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = reshape(num2cell(v), 1, []);
else
    c = {v};
end
end
