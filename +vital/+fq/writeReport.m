function files = writeReport(res, folder, name)
%WRITEREPORT  Write a vital.fq.assess result as JSON and Markdown.
%   files = vital.fq.writeReport(res, folder)          fq_report.json / .md
%   files = vital.fq.writeReport(res, folder, name)
%   JSON: the whole result. Inf and -Inf (e.g. the time to double of a mode
%   that does not diverge) are written as the strings "Inf" / "-Inf", since
%   JSON has no infinity; NaN is null. Markdown: conditions, category policy
%   and validity envelope; the HEADLINE group table over the points inside the
%   validity envelope; a separately labelled EXTRAPOLATED group table; the
%   all-points group table; the record table; the coverage table; the point
%   table with the envelope tag and the 3.1.12 equivalent-system notes.
%   files: struct(json, md) with the full paths.
arguments
    res (1,1) struct
    folder (1,:) char
    name (1,:) char = 'fq_report'
end
if ~isfolder(folder), mkdir(folder); end
files.json = fullfile(folder, [name '.json']);
files.md = fullfile(folder, [name '.md']);
out = res;
out.files = files;
fid = fopen(files.json, 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(sanitize(out), 'PrettyPrint', true));
fclose(fid);

ax = {res.conditions.axes.name};
L = strings(0);
L(end+1) = "# MIL-F-8785C flying-qualities assessment";
if ~isempty(res.label), L(end+1) = string(res.label); end
L(end+1) = "";
L(end+1) = sprintf('Condition space `%s`, grid `%s`: %d points evaluated (%d refinement), %.1f s, %.3f s per point.', ...
    res.conditions.id, res.conditions.grid, numel(res.points), sum([res.points.refine]), res.timing.total_s, res.timing.perPoint_s);
for k = 1:numel(res.conditions.axes)
    L(end+1) = sprintf('- axis `%s`: %s', ax{k}, mat2str(res.conditions.axes(k).values, 8)); %#ok<AGROW>
end
pol = res.conditions.categoryPolicy;
if isstruct(pol)
    for c = fieldnames(pol).'
        e = pol.(c{1}); s = 'assessed'; if isfield(e, 'assess') && ~e.assess, s = 'NOT ASSESSED'; end
        r = ''; if isfield(e, 'reason'), r = e.reason; end
        L(end+1) = sprintf('- Category %s: %s. %s', c{1}, s, r); %#ok<AGROW>
    end
end
nIn = sum(strcmp({res.points.envelope}, 'IN'));
v = res.conditions.validity;
if isempty(v)
    L(end+1) = "- Validity envelope: none registered (every point counts as IN).";
else
    L(end+1) = sprintf('- Validity envelope: %s', v.description);
    L(end+1) = sprintf('  - %s', v.judgment);
    for b = reshape(v.bounds, 1, [])
        L(end+1) = sprintf('  - %s in [%g, %g]', b.quantity, b.min, b.max); %#ok<AGROW>
    end
end
L(end+1) = sprintf('- Points IN the envelope: %d; EXTRAPOLATED: %d.', nIn, numel(res.points) - nIn);
L(end+1) = "";
L(end+1) = "Level: the best Level whose boundaries all hold (MIL-F-8785C 6.7.1); 4 = worse than Level 3. Worst Level over the rated points. ""or worse (k of n points unrated)"": k points could not be rated (trim, linearization or mode not OK), so the Level is not established (review R2 B2). Margin: normalized margin to the boundary of the Level achieved at the critical condition (m > 0 satisfies); one scale per record, so the upper side of a two-sided bound is also divided by the lower bound's magnitude. A DIVERGENT point (an unstable real root where an oscillation is required) fails every Level.";
L(end+1) = "Interpretations: Table VI Category A, CO/GA use the ""A (CO and GA)"" row only, other Category A phases the ""A"" row (extract 6.2 item 8; the stricter both-rows reading is not encoded); 3.3.1.4 also prohibits a coupled roll-spiral mode in Category A phases other than CO/GA; see the records' source.interpretation.";
L = [L, groupTable('HEADLINE: points inside the NESC model validity envelope', res.groups, 'inEnvelope', ax)];
L = [L, groupTable('EXTRAPOLATED: points outside the NESC model validity envelope (indicative only)', res.groups, 'extrapolated', ax)];
L = [L, groupTable('All points (inside and outside the envelope)', res.groups, '', ax)];
L(end+1) = "";
L(end+1) = "## Records (one Level boundary each), all points";
L(end+1) = "| id | Level | metric | bounds | critical value | min margin | verdict | critical condition | envelope | status | used/excl/n.a. |";
L(end+1) = "|---|---|---|---|---|---|---|---|---|---|---|";
for r = res.rules(:).'
    b = sprintf('[%s, %s]', num(r.lo), num(r.hi)); if r.strict, b = [b ' strict']; end
    L(end+1) = sprintf('| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %d/%d/%d |', r.id, r.level, r.metric, b, ...
        num(r.criticalValue), num(r.minMargin), r.verdict, condStr(r.critical, ax), envOf(res, r.criticalIndex), ...
        r.status, r.nOK, r.nExcluded, r.nNotApplicable); %#ok<AGROW>
end
if ~isempty(res.coverage)
    L(end+1) = "";
    L(end+1) = "## Criteria not assessed (coverage)";
    L(end+1) = "| class | paragraph | metric | reason | candidates |";
    L(end+1) = "|---|---|---|---|---|";
    for c = res.coverage(:).'
        L(end+1) = sprintf('| %s | %s | %s | %s | %d |', c.class, c.paragraph, c.metric, c.reason, numel(c.candidate_ids)); %#ok<AGROW>
    end
end
L(end+1) = "";
L(end+1) = "## Points";
L(end+1) = "| # | condition | envelope | refine | status | reason | notes (3.1.12 equivalent-system doubts) |";
L(end+1) = "|---|---|---|---|---|---|---|";
for i = 1:numel(res.points)
    p = res.points(i);
    nt = '';
    if isfield(p.info, 'notes') && ~isempty(p.info.notes), nt = strjoin(p.info.notes, ' / '); end
    L(end+1) = sprintf('| %d | %s | %s | %d | %s | %s | %s |', i, condStr(p.cond, ax), p.envelope, p.refine, p.status, ...
        strrep(char(p.reason), '|', '/'), strrep(nt, '|', '/')); %#ok<AGROW>
end
fid = fopen(files.md, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', L);
fclose(fid);
end

function L = groupTable(title, groups, sub, ax)
L = strings(0);
L(end+1) = "";
L(end+1) = "## " + title;
L(end+1) = "| group | paragraph | Cat | metrics | Level | margin | critical condition | status | unrated (excluded) |";
L(end+1) = "|---|---|---|---|---|---|---|---|---|";
for g = groups(:).'
    if isempty(sub), s = g; else, s = g.(sub); end
    L(end+1) = sprintf('| %s | %s | %s | %s | %s | %s | %s | %s | %s |', g.group, g.paragraph, g.category, ...
        strjoin(g.metrics, ', '), lvl(s), num(s.criticalMargin), condStr(s.critical, ax), s.status, exStr(s.excludedBy)); %#ok<AGROW>
end
end

function e = envOf(res, k)
if isempty(k), e = '-'; else, e = res.points(k).envelope; end
end

function x = sanitize(x)
if isstruct(x)
    if isempty(x), return; end
    f = fieldnames(x);
    y = x;
    for i = 1:numel(x)
        for k = 1:numel(f), y(i).(f{k}) = sanitize(x(i).(f{k})); end
    end
    x = y;
elseif iscell(x)
    x = cellfun(@sanitize, x, 'UniformOutput', false);
elseif isa(x, 'function_handle')
    x = func2str(x);
elseif isnumeric(x) && ~isreal(x)
    x = sanitize(struct('re', real(x), 'im', imag(x)));
elseif isnumeric(x) && any(isinf(x(:)))
    c = num2cell(x);
    c(x == Inf) = {'Inf'};
    c(x == -Inf) = {'-Inf'};
    x = c;
end
end

function s = lvl(g)
if isnan(g.worstLevel), s = '-'; elseif isempty(g.levelText), s = sprintf('Level %d', g.worstLevel); else, s = g.levelText; end
end

function s = num(v)
if isempty(v) || isnan(v), s = '-'; elseif isinf(v), s = sprintf('%g', v); else, s = sprintf('%.4g', v); end
end

function s = condStr(c, ax)
if isempty(fieldnames(c)), s = '-'; return; end
p = {};
for k = 1:numel(ax)
    if isfield(c, ax{k}), p{end+1} = sprintf('%s=%g', ax{k}, c.(ax{k})); end %#ok<AGROW>
end
s = strjoin(p, ' ');
end

function s = exStr(e)
if isempty(e), s = '0'; return; end
s = strjoin(arrayfun(@(x) sprintf('%s x%d', x.reason, x.count), e, 'UniformOutput', false), '; ');
end
