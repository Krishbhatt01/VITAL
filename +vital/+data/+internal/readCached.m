function [m, L] = readCached(file, sha)
%READCACHED  vital.daveml.read(file) and vital.data.internal.locate(file), cached
%   by (path, SHA-256): the caller has already checked the hash against
%   data/MANIFEST.json (vital.data.sourceFile), so a changed file is never served
%   from the cache. Parsing F16_aero.dml takes about a second; the F-16 builder
%   is called by many tests.
persistent cache
if isempty(cache), cache = struct('file', {}, 'sha', {}, 'm', {}, 'L', {}); end
k = find(strcmp({cache.file}, file) & strcmp({cache.sha}, sha), 1);
if ~isempty(k)
    m = cache(k).m; L = cache(k).L;
    return
end
m = vital.daveml.read(file);
if ~strcmp(m.sha256, sha)
    error('vital:data:hashMismatch', '%s changed while it was read (SHA-256 %s, expected %s).', file, m.sha256, sha);
end
L = vital.data.internal.locate(file);
cache(end+1) = struct('file', file, 'sha', sha, 'm', m, 'L', L);
end
