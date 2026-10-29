function [path, sha, entry] = sourceFile(relPath, opts)
%SOURCEFILE  A reference-data file, checked against data/MANIFEST.json (D1, criterion 7).
%   [path, sha, entry] = vital.data.sourceFile(relPath)
%   [path, sha, entry] = vital.data.sourceFile(relPath, 'DataRoot', root)
%     relPath  path relative to the data root, as listed in MANIFEST.json
%     root     where the file is read (default vital.paths('data')); the MANIFEST is
%              ALWAYS the one of vital.paths('data'), so a copy elsewhere must have
%              the same bytes
%     path     the absolute path read;  sha  its SHA-256 (= the manifest's)
%   Errors: vital:data:notInManifest (no entry for relPath),
%           vital:data:fileNotFound, vital:data:hashMismatch (the file's SHA-256
%           differs from the manifest: a changed file is never used).
arguments
    relPath (1,:) char
    opts.DataRoot (1,:) char = ''
end
relPath = strrep(relPath, '\', '/');
if isempty(opts.DataRoot), opts.DataRoot = vital.paths('data'); end
mf = manifestFiles();
k = find(cellfun(@(e) strcmp(e.path, relPath), mf), 1);
if isempty(k)
    error('vital:data:notInManifest', '%s is not listed in data/MANIFEST.json.', relPath);
end
entry = mf{k};
path = fullfile(opts.DataRoot, strrep(relPath, '/', filesep));
if ~isfile(path)
    error('vital:data:fileNotFound', 'reference file not found: %s', path);
end
sha = vital.io.sha256File(path);
if ~strcmp(sha, entry.sha256)
    error('vital:data:hashMismatch', '%s: SHA-256 %s differs from data/MANIFEST.json (%s); the file was changed.', ...
        path, sha, entry.sha256);
end
end

function mf = manifestFiles()
persistent cache key
f = fullfile(vital.paths('data'), 'MANIFEST.json');
d = dir(f);
k = sprintf('%s|%d|%f', f, d.bytes, d.datenum);
if isempty(cache) || ~strcmp(key, k)
    s = jsondecode(fileread(f));
    cache = vital.data.internal.asList(s.files);
    key = k;
end
mf = cache;
end
