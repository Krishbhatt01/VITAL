function h = treeHash(folder, opts)
%TREEHASH  SHA-256 over every file (relative path + bytes) under FOLDER.
%   Deterministic: files are processed in sorted relative-path order and
%   path separators are normalised to '/'. 'Exclude' lists top-level
%   folder names to skip (e.g. {'data','reports'}).
arguments
    folder (1,:) char
    opts.Exclude cell = {}
end
folder = regexprep(folder, '[\\/]+$', '');   % drop trailing separators
files = dir(fullfile(folder, '**', '*'));
files = files(~[files.isdir]);
rel = strings(numel(files), 1);
for k = 1:numel(files)
    full = fullfile(files(k).folder, files(k).name);
    rel(k) = strrep(string(full(numel(folder)+2:end)), '\', '/');
end
if ~isempty(opts.Exclude)
    top = extractBefore(rel + "/", "/");
    keep = ~ismember(top, string(opts.Exclude));
    rel = rel(keep);
end
rel = sort(rel);
md = java.security.MessageDigest.getInstance('SHA-256');
for k = 1:numel(rel)
    md.update(typecast(unicode2native(char(rel(k)), 'UTF-8'), 'int8'));
    md.update(int8(0));
    fid = fopen(fullfile(folder, rel(k)), 'r');
    bytes = fread(fid, Inf, '*uint8');
    fclose(fid);
    if ~isempty(bytes), md.update(typecast(bytes, 'int8')); end
    md.update(int8(0));
end
h = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2)', 1, []));
end
