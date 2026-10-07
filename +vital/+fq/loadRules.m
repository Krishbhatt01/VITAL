function R = loadRules(folder)
%LOADRULES  Load and validate curated rule records (one JSON file each).
%   R = vital.fq.loadRules()          rules/mil_f_8785c/records
%   R = vital.fq.loadRules(folder)
%
%   Every *.json file in the folder is one record (one sub-paragraph, metric,
%   Level and Category; rules/schema/RULE_SCHEMA.md). Each must pass
%   vital.io.validateRule and, for the engine, have:
%     criterion.type 'levels' with exactly ONE levels entry {level, category,
%     min?, max?, strict?, approximate?}, a 'group' (paragraph + Category, the
%     unit whose Level is reported) and a metric of vital.fq.metricNames.
%   Optional: 'increment' {metric, threshold, slope, quote} raising the lower
%   bound to min + slope*max(0, x - threshold) (Table VI), 'phase_subset',
%   source.candidate_id, source.extract_quote.
%
%   R (struct array, one per file, in file-name order) fields:
%     id, title, class, paragraph, page, group, subset, category, level, metric,
%     lo, hi (-Inf/Inf when absent), strict, approximate, scale, incr (has,
%     metric, threshold, slope, quote), candidate_id, quote, file, record (raw)
%   Errors: vital:fq:noRules (no record files), vital:rule:missingField and
%   vital:rule:badValue (schema), vital:fq:unknownMetric, vital:fq:badRule
%   (not exactly one Level entry, no group, bad increment, duplicate id).
arguments
    folder (1,:) char = fullfile(vital.paths('rules'), 'mil_f_8785c', 'records')
end
files = dir(fullfile(folder, '*.json'));
if isempty(files)
    error('vital:fq:noRules', 'no rule records (*.json) in %s.', folder);
end
[~, o] = sort({files.name});
files = files(o);
names = vital.fq.metricNames();
tmpl = struct('id', '', 'title', '', 'class', '', 'paragraph', '', 'page', '', 'group', '', 'subset', '', ...
    'category', '', 'level', NaN, 'metric', '', 'lo', -Inf, 'hi', Inf, 'strict', false, 'approximate', false, ...
    'scale', NaN, 'incr', struct('has', false, 'metric', '', 'threshold', NaN, 'slope', NaN, 'quote', ''), ...
    'candidate_id', '', 'quote', '', 'file', '', 'record', struct());
R = repmat(tmpl, 1, numel(files));
for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    rec = jsondecode(fileread(f));
    vital.io.validateRule(rec);
    if ~strcmp(rec.criterion.type, 'levels') || numel(rec.criterion.levels) ~= 1
        error('vital:fq:badRule', '%s: the engine needs criterion.type "levels" with exactly one Level entry.', files(k).name);
    end
    if ~isfield(rec, 'group') || isempty(rec.group)
        error('vital:fq:badRule', '%s: record has no "group".', files(k).name);
    end
    if ~any(strcmp(rec.metric, names))
        error('vital:fq:unknownMetric', '%s: metric "%s" has no extractor (vital.fq.metricNames).', files(k).name, rec.metric);
    end
    L = rec.criterion.levels;
    r = tmpl;
    r.id = rec.id; r.title = rec.title; r.class = rec.class;
    r.paragraph = rec.source.paragraph; r.page = rec.source.page;
    r.group = rec.group;
    if isfield(rec, 'phase_subset'), r.subset = rec.phase_subset; end
    r.category = L.category; r.level = double(L.level); r.metric = rec.metric;
    if isfield(L, 'min') && ~isempty(L.min), r.lo = double(L.min); end
    if isfield(L, 'max') && ~isempty(L.max), r.hi = double(L.max); end
    if isfield(L, 'strict') && ~isempty(L.strict), r.strict = logical(L.strict); end
    if isfield(L, 'approximate') && ~isempty(L.approximate), r.approximate = logical(L.approximate); end
    r.scale = double(rec.scale);
    if isfield(rec, 'increment') && ~isempty(rec.increment)
        in = rec.increment;
        if ~all(isfield(in, {'metric', 'threshold', 'slope'})) || ~any(strcmp(in.metric, names)) || ...
                ~isfinite(in.threshold) || ~isfinite(in.slope) || in.slope < 0 || ~isfinite(r.lo)
            error('vital:fq:badRule', '%s: increment needs a known metric, a finite threshold and slope >= 0, and a lower bound.', files(k).name);
        end
        r.incr = struct('has', true, 'metric', in.metric, 'threshold', double(in.threshold), ...
            'slope', double(in.slope), 'quote', '');
        if isfield(in, 'quote'), r.incr.quote = in.quote; end
    end
    if isfield(rec.source, 'candidate_id'), r.candidate_id = rec.source.candidate_id; end
    if isfield(rec.source, 'extract_quote'), r.quote = rec.source.extract_quote; end
    r.file = f;
    r.record = rec;
    R(k) = r;
end
[u, ~, j] = unique({R.id});
if numel(u) < numel(R)
    d = u(accumarray(j(:), 1) > 1);
    error('vital:fq:badRule', 'duplicate record id(s): %s.', strjoin(d, ', '));
end
end
