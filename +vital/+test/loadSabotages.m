function sab = loadSabotages(file)
%LOADSABOTAGES  Read and validate a milestone's sabotage definitions (JSON).
%   Each entry: id, file (relative to the tree root), pattern (must occur
%   exactly once), replacement, targets ("TestClass/method" list that must
%   turn RED), rationale. Errors sabotage:badDefinition otherwise.
REQUIRED = {'id','file','pattern','replacement','targets','rationale'};
raw = jsondecode(fileread(file));
if iscell(raw), raw = [raw{:}]; end
if ~isstruct(raw) || isempty(raw)
    error('sabotage:badDefinition', '%s must hold a non-empty JSON array of objects', file);
end
for k = 1:numel(raw)
    missing = setdiff(REQUIRED, fieldnames(raw(k)));
    if ~isempty(missing)
        error('sabotage:badDefinition', '%s entry %d lacks: %s', file, k, strjoin(missing, ', '));
    end
end
sab = raw;
for k = 1:numel(sab)
    t = sab(k).targets;
    if ischar(t) || isstring(t), t = cellstr(t); end
    sab(k).targets = t(:)';
    if isempty(sab(k).targets) || isempty(sab(k).pattern)
        error('sabotage:badDefinition', '%s entry %s: empty pattern or targets', file, sab(k).id);
    end
end
end
