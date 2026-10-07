function sab = loadSabotageSet(folder, opts)
%LOADSABOTAGESET  Read every sabotage file of a milestone folder and merge them.
%   sab = vital.test.loadSabotageSet(folder)
%   sab = vital.test.loadSabotageSet(folder, 'Parts', {'main', 'A'})
%
%   Files: sabotages.json (part 'main') and sabotages_<part>.json. Parallel
%   increments each own one part file, so no two ever edit the same file.
%   Each entry is validated by vital.test.loadSabotages and gets a 'part' field.
%   Errors sabotage:badDefinition when no file is found, a requested part is
%   missing, or two entries share an id.
arguments
    folder (1,:) char
    opts.Parts cell = {}
end
d = dir(fullfile(folder, 'sabotages*.json'));
names = {d.name};
parts = regexprep(names, '^sabotages_?(.*)\.json$', '$1');
parts(strcmp(parts, '')) = {'main'};
ok = matches(names, regexpPattern('^sabotages(_[A-Za-z0-9]+)?\.json$'));
names = names(ok); parts = parts(ok);
if ~isempty(opts.Parts)
    missing = setdiff(opts.Parts, parts);
    if ~isempty(missing)
        error('sabotage:badDefinition', 'no sabotage file for part(s) %s in %s', strjoin(missing, ', '), folder);
    end
    keep = ismember(parts, opts.Parts);
    names = names(keep); parts = parts(keep);
end
if isempty(names)
    error('sabotage:badDefinition', 'no sabotages*.json in %s', folder);
end
sab = [];
for k = 1:numel(names)
    s = vital.test.loadSabotages(fullfile(folder, names{k}));
    [s.part] = deal(parts{k});
    s = orderfields(s);
    if isempty(sab), sab = s(:)'; else, sab = [sab, orderfields(s(:)', sab)]; end %#ok<AGROW>
end
[u, ~, j] = unique({sab.id});
dup = u(accumarray(j(:), 1) > 1);
if ~isempty(dup)
    error('sabotage:badDefinition', 'duplicate sabotage id(s) in %s: %s', folder, strjoin(dup, ', '));
end
end
