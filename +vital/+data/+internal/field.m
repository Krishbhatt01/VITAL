function v = field(s, name, default)
%FIELD  s.(name) if the struct has the field, else default (for hand-authored
%   .vital.json files, where optional fields may be left out).
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end
