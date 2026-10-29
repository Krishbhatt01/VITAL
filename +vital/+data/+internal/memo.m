function d = memo(key, fcn)
%MEMO  d = fcn(), remembered by key for the MATLAB session (at most 32 entries).
%   Used by the aircraft data builders: the key contains the builder options AND the
%   SHA-256 of every source file (checked against data/MANIFEST.json before the
%   lookup), so a changed file is never served from memory. Data objects are value
%   objects, so a remembered one cannot be modified by a caller.
persistent keys vals
if isempty(keys), keys = {}; vals = {}; end
k = find(strcmp(keys, key), 1);
if ~isempty(k)
    d = vals{k};
    return
end
d = fcn();
keys{end+1} = key;
vals{end+1} = d;
if numel(keys) > 32
    keys(1) = []; vals(1) = [];
end
end
