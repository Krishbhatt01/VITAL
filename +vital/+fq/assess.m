function res = assess(rules, acFactory, conditions, opts)
%ASSESS  MIL-F-8785C flying-qualities assessment over a registered condition space.
%   res = vital.fq.assess(rules, acFactory, conditions)
%   res = vital.fq.assess(..., 'Refine', true, 'ReportDir', d, 'ReportName', n, ...
%                         'Coverage', cov, 'PointFcn', f, 'Label', txt)
%
%   rules       vital.fq.loadRules result (one Level boundary per record)
%   acFactory   ac = acFactory(c) for a condition point c (vital.fq.f16Factory)
%   conditions  vital.fq.loadConditions result: axes, fixed, categoryPolicy
%               (A/B/C {assess, reason}; a missing category is assessed) and
%               optionally validity {description, judgment, bounds(quantity,
%               min, max)}: the region where the aircraft model is valid
%   'PointFcn'  P = f(ac, c) with fields status, stage, reason, metrics, info
%               (default vital.fq.evaluatePoint: trim, linearize, modes, metrics)
%   'Refine'    one local refinement around every critical grid point of a USED
%               point: the midpoints to the neighbouring grid values on both
%               sides of each axis (never beyond the axis range); a refined point
%               is used only if OK. It never centres on excluded points, so it
%               cannot shrink an unrated region (review R2 MINOR 8).
%   'ReportDir' write <ReportName>.json and .md there (vital.fq.writeReport)
%   'Coverage'  vital.fq.loadCoverage table, carried into the result/report
%
%   Record at a point (y = metric value, lo/hi its bounds, scale > 0):
%     used if the point status is OK and the metric status is OK with y not NaN
%     (and the same for an increment metric), margin
%       m = min((y - lo_eff)/scale, (hi - y)/scale), finite bounds only,
%       lo_eff = lo + slope*max(0, x - threshold) with an increment (Table VI);
%     pass m >= 0, or m > 0 if strict. One scale per record normalizes both
%     sides (RULE_SCHEMA; review R2 MINOR 4: the upper side is thus divided by
%     the lower bound's magnitude when both exist).
%     Metric status DIVERGENT: USED, m = -Inf, fails every Level (review R2 B1).
%     Metric status NOT_APPLICABLE: NOT_APPLICABLE (counts as a pass for the
%     group Level). Any other point or metric status: EXCLUDED and counted by
%     reason '<stage>:<status>' (trim:INFEASIBLE, metric:NOT_OSCILLATORY,
%     metric:MODE_MISSING, metric:NAN, ...).
%   Record summary: critical point = smallest margin over USED points only
%     (FC-702); status ASSESSED (no excluded point), PARTIAL (some excluded),
%     NOT_ASSESSABLE (no used point and nothing not-applicable: FC-701; or a
%     Category the policy does not assess), NOT_APPLICABLE (only not-applicable
%     points); verdict PASS / FAIL / 'PASS (partial)' (passes at the used points,
%     others unrated).
%   Group (paragraph + Category [+ phase subset]): at a point, Level = the best
%     Level L whose records all pass or are not applicable (MIL-F-8785C 6.7.1);
%     4 = worse than Level 3. A point where any record of the group is excluded
%     has no Level. worstLevel = worst over the USED points; critical = worst
%     Level, then smallest margin to that Level's boundary (Level 4: to the
%     Level 3 boundary). complete = no excluded point; levelHeadline = worstLevel
%     when complete, 4 when a used point is already worse than Level 3, NaN
%     otherwise (review R2 B2: an excluded point never hides a worse Level);
%     levelText says how many points are unrated.
%   Validity envelope (review R2 M8): every point is tagged envelope 'IN' or
%     'EXTRAPOLATED' (vital.fq.envelopeTag; 'IN' everywhere when no validity is
%     registered). Every record and group also carries .inEnvelope and
%     .extrapolated: the same summary over the IN and over the EXTRAPOLATED
%     points only (critical indices refer to res.points). The headline Level is
%     the in-envelope one.
%
%   res fields: label, conditions (id, grid, axes, fixed, categoryPolicy, ofe,
%   validity), points (cond, status, stage, reason, refine, envelope,
%   envelopeValues, metrics, info), rules, groups, coverage, timing (total_s,
%   nEvaluated, perPoint_s), files (json, md).
%   Errors: vital:fq:noRules, vital:fq:badConditions.
arguments
    rules struct
    acFactory function_handle
    conditions (1,1) struct
    opts.PointFcn function_handle = @vital.fq.evaluatePoint
    opts.Refine (1,1) logical = false
    opts.ReportDir (1,:) char = ''
    opts.ReportName (1,:) char = 'fq_report'
    opts.Coverage struct = struct([])
    opts.Label (1,:) char = ''
end
t0 = tic;
if isempty(rules)
    error('vital:fq:noRules', 'no rules to assess.');
end
grid = vital.fq.gridPoints(conditions);
policy = struct();
if isfield(conditions, 'categoryPolicy') && isstruct(conditions.categoryPolicy), policy = conditions.categoryPolicy; end
validity = [];
if isfield(conditions, 'validity') && ~isempty(conditions.validity), validity = conditions.validity; end
axNames = {conditions.axes.name};

% ---- evaluate the grid ---------------------------------------------------------------
P = struct('cond', {}, 'status', {}, 'stage', {}, 'reason', {}, 'refine', {}, 'envelope', {}, ...
    'envelopeValues', {}, 'metrics', {}, 'info', {});
tEval = 0;
[P, tEval] = evaluate(P, grid, false, acFactory, opts.PointFcn, tEval, validity);
[R, G] = summarizeAll(rules, P, policy);

% ---- optional local refinement --------------------------------------------------------
if opts.Refine
    centres = unique([R.criticalIndex, G.criticalIndex]);
    keys = arrayfun(@(p) key(p.cond, axNames), P, 'UniformOutput', false);
    newPts = struct([]);
    for ci = centres
        c0 = P(ci).cond;
        opt = cell(1, numel(axNames));
        for k = 1:numel(axNames)
            v = conditions.axes(k).values(:).';
            j = find(v == c0.(axNames{k}), 1);
            o = v(j);
            if j > 1, o = [(v(j-1) + v(j)) / 2, o]; end %#ok<AGROW>
            if j < numel(v), o = [o, (v(j) + v(j+1)) / 2]; end %#ok<AGROW>
            opt{k} = o;
        end
        combos = cell(1, numel(opt));
        [combos{:}] = ndgrid(opt{:});
        for i = 1:numel(combos{1})
            c = c0;
            for k = 1:numel(axNames), c.(axNames{k}) = combos{k}(i); end
            kk = key(c, axNames);
            if any(strcmp(keys, kk)), continue; end
            keys{end+1} = kk; %#ok<AGROW>
            if isempty(newPts), newPts = c; else, newPts(end+1) = c; end %#ok<AGROW>
        end
    end
    if ~isempty(newPts)
        [P, tEval] = evaluate(P, newPts, true, acFactory, opts.PointFcn, tEval, validity);
        [R, G] = summarizeAll(rules, P, policy);
    end
end

% ---- result ---------------------------------------------------------------------------
res.label = opts.Label;
res.conditions = struct('id', field(conditions, 'id', ''), 'grid', field(conditions, 'grid', ''), ...
    'axes', conditions.axes, 'fixed', field(conditions, 'fixed', struct()), 'categoryPolicy', policy, ...
    'ofe', field(conditions, 'ofe', ''), 'validity', validity);
res.points = P;
res.rules = R;
res.groups = G;
res.coverage = opts.Coverage;
res.timing = struct('total_s', toc(t0), 'nEvaluated', numel(P), 'perPoint_s', tEval / max(1, numel(P)));
res.files = struct('json', '', 'md', '');
if ~isempty(opts.ReportDir)
    res.files = vital.fq.writeReport(res, opts.ReportDir, opts.ReportName);
end
end

% =======================================================================================
function [P, tEval] = evaluate(P, pts, isRefine, acFactory, pointFcn, tEval, validity)
for i = 1:numel(pts)
    c = pts(i);
    ac = acFactory(c);
    env = 'IN'; ev = struct();
    if ~isempty(validity)
        [env, ev] = vital.fq.envelopeTag(c, ac, validity);
    end
    t1 = tic;
    q = pointFcn(ac, c);
    tEval = tEval + toc(t1);
    e = struct('cond', c, 'status', q.status, 'stage', q.stage, 'reason', q.reason, 'refine', isRefine, ...
        'envelope', env, 'envelopeValues', ev, 'metrics', q.metrics, 'info', struct());
    if isfield(q, 'info'), e.info = q.info; end
    if isempty(P), P = e; else, P(end+1) = e; end %#ok<AGROW>
end
end

function k = key(c, names)
k = strjoin(cellfun(@(n) sprintf('%.15g', c.(n)), names, 'UniformOutput', false), '|');
end

function v = field(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end

function [ok, why] = categoryAssessed(policy, cat)
ok = true; why = '';
if isfield(policy, cat) && isfield(policy.(cat), 'assess') && ~policy.(cat).assess
    ok = false; why = 'category policy: not assessed';
    if isfield(policy.(cat), 'reason'), why = policy.(cat).reason; end
end
end

% =======================================================================================
function [R, G] = summarizeAll(rules, P, policy)
D = classify(rules, P, policy);
N = numel(P);
[R, G] = summarize(rules, P, D, 1:N);
inIdx = find(strcmp({P.envelope}, 'IN'));
exIdx = find(~strcmp({P.envelope}, 'IN'));
[Ri, Gi] = summarize(rules, P, D, inIdx);
[Rx, Gx] = summarize(rules, P, D, exIdx);
rf = {'status', 'reason', 'nPoints', 'nOK', 'nExcluded', 'nNotApplicable', 'excludedBy', 'minMargin', ...
    'criticalIndex', 'critical', 'criticalValue', 'verdict'};
gf = {'status', 'reason', 'nPoints', 'nOK', 'nExcluded', 'nNotApplicable', 'excludedBy', 'worstLevel', ...
    'levelHeadline', 'complete', 'levelText', 'criticalIndex', 'critical', 'criticalMargin'};
for k = 1:numel(R)
    R(k).inEnvelope = sub(Ri(k), rf);
    R(k).extrapolated = sub(Rx(k), rf);
end
for k = 1:numel(G)
    G(k).inEnvelope = sub(Gi(k), gf);
    G(k).extrapolated = sub(Gx(k), gf);
end
end

function s = sub(x, f)
s = struct();
for k = 1:numel(f), s.(f{k}) = x.(f{k}); end
end

function D = classify(rules, P, policy)
% per (record, point): class, exclusion reason, value, margin, pass
N = numel(P); nR = numel(rules);
D.cls = cell(nR, N); D.why = repmat({''}, nR, N);
D.val = NaN(nR, N); D.marg = NaN(nR, N); D.pass = false(nR, N);
D.catOK = true(1, nR); D.catWhy = repmat({''}, 1, nR);
for r = 1:nR
    ru = rules(r);
    [D.catOK(r), D.catWhy{r}] = categoryAssessed(policy, ru.category);
    for i = 1:N
        if ~D.catOK(r)
            D.cls{r, i} = 'NOT_ASSESSED'; continue
        end
        p = P(i);
        if ~strcmp(p.status, 'OK')
            D.cls{r, i} = 'EXCLUDED'; D.why{r, i} = [p.stage ':' p.status]; continue
        end
        [y, st] = metricOf(p.metrics, ru.metric);
        lo = ru.lo;
        if ru.incr.has && strcmp(st, 'OK')
            [x, stx] = metricOf(p.metrics, ru.incr.metric);
            if strcmp(stx, 'OK'), lo = lo + ru.incr.slope * max(0, x - ru.incr.threshold); else, st = stx; end
        end
        if ~isnan(y), D.val(r, i) = y; end
        if strcmp(st, 'NOT_APPLICABLE')
            D.cls{r, i} = 'NOT_APPLICABLE'; continue
        elseif strcmp(st, 'DIVERGENT')
            D.cls{r, i} = 'OK'; D.marg(r, i) = -Inf; D.pass(r, i) = false; continue
        elseif ~strcmp(st, 'OK')
            D.cls{r, i} = 'EXCLUDED'; D.why{r, i} = ['metric:' st]; continue
        end
        mLo = Inf; mHi = Inf;
        if isfinite(lo), mLo = (y - lo) / ru.scale; end
        if isfinite(ru.hi), mHi = (ru.hi - y) / ru.scale; end
        D.marg(r, i) = min(mLo, mHi);
        if ru.strict, D.pass(r, i) = D.marg(r, i) > 0; else, D.pass(r, i) = D.marg(r, i) >= 0; end
        D.cls{r, i} = 'OK';
    end
end
end

function [R, G] = summarize(rules, P, D, idx)
% record and group summaries over the points idx (critical indices are global)
nR = numel(rules); n = numel(idx);
R = struct([]);
for r = 1:nR
    ru = rules(r);
    cls = D.cls(r, idx); why = D.why(r, idx); marg = D.marg(r, idx); pass = D.pass(r, idx); val = D.val(r, idx);
    used = strcmp(cls, 'OK');
    na = strcmp(cls, 'NOT_APPLICABLE');
    ex = strcmp(cls, 'EXCLUDED');
    s = struct('id', ru.id, 'group', ru.group, 'paragraph', ru.paragraph, 'category', ru.category, ...
        'subset', ru.subset, 'level', ru.level, 'metric', ru.metric, 'lo', ru.lo, 'hi', ru.hi, ...
        'strict', ru.strict, 'scale', ru.scale, 'approximate', ru.approximate, 'status', '', 'reason', '', ...
        'nPoints', n, 'nOK', sum(used), 'nExcluded', sum(ex), 'nNotApplicable', sum(na), ...
        'excludedBy', {countReasons(why(ex))}, 'value', val.', 'margin', [], ...
        'pointClass', {cls.'}, 'minMargin', NaN, 'criticalIndex', [], 'critical', struct(), ...
        'criticalValue', NaN, 'verdict', '', 'refined', false);
    % FC-702: the critical point is searched over USED points only
    cand = find(used);
    if ~isempty(cand)
        [s.minMargin, k] = min(marg(cand));
        iC = idx(cand(k));
        s.criticalIndex = iC;
        s.critical = P(iC).cond;
        s.criticalValue = D.val(r, iC);
        s.refined = P(iC).refine;
        if ~all(pass(used))
            s.verdict = 'FAIL';
        elseif s.nExcluded == 0
            s.verdict = 'PASS';
        else
            s.verdict = 'PASS (partial)';
        end
    end
    m = marg; m(~used) = NaN;
    s.margin = m.';
    [s.status, s.reason] = statusOf(D.catOK(r), D.catWhy{r}, n, s.nOK, s.nExcluded, s.nNotApplicable);
    if isempty(R), R = s; else, R(r) = s; end
end

% ---- groups ------------------------------------------------------------------------------
[gNames, ~, gIdx] = unique({rules.group}, 'stable');
G = struct([]);
for g = 1:numel(gNames)
    ks = find(gIdx == g).';
    ru = rules(ks(1));
    lv = [rules(ks).level];
    levels = unique(lv);
    catOK = D.catOK(ks(1));
    lvlAt = NaN(n, 1); mAt = NaN(n, 1); gc = repmat({''}, n, 1); gw = repmat({''}, n, 1);
    for ii = 1:n
        i = idx(ii);
        c = D.cls(ks, i);
        if ~catOK, gc{ii} = 'NOT_ASSESSED'; continue; end
        exk = find(strcmp(c, 'EXCLUDED'), 1);
        if ~isempty(exk), gc{ii} = 'EXCLUDED'; gw{ii} = D.why{ks(exk), i}; continue; end
        if all(strcmp(c, 'NOT_APPLICABLE')), gc{ii} = 'NOT_APPLICABLE'; continue; end
        gc{ii} = 'OK';
        ok = D.pass(ks, i) | strcmp(c, 'NOT_APPLICABLE');
        lvlAt(ii) = 4;
        for L = levels
            if all(ok(lv == L)), lvlAt(ii) = L; break; end
        end
        Lm = min(lvlAt(ii), max(levels));
        mm = D.marg(ks(lv == Lm), i);
        mm = mm(~isnan(mm));
        if isempty(mm), mAt(ii) = Inf; else, mAt(ii) = min(mm); end
    end
    used = strcmp(gc, 'OK');
    s = struct('group', gNames{g}, 'paragraph', ru.paragraph, 'category', ru.category, 'subset', ru.subset, ...
        'metrics', {unique({rules(ks).metric}, 'stable')}, 'recordIds', {{rules(ks).id}}, ...
        'levelsDefined', levels, 'levelAtPoint', lvlAt, 'marginAtPoint', mAt, 'pointClass', {gc}, ...
        'worstLevel', NaN, 'levelHeadline', NaN, 'complete', false, 'criticalIndex', [], 'critical', struct(), ...
        'criticalMargin', NaN, 'status', '', 'reason', '', 'levelText', '', 'nPoints', n, 'nOK', sum(used), ...
        'nExcluded', sum(strcmp(gc, 'EXCLUDED')), 'nNotApplicable', sum(strcmp(gc, 'NOT_APPLICABLE')), ...
        'excludedBy', {countReasons(gw(strcmp(gc, 'EXCLUDED')).')}, 'refined', false);
    s.complete = catOK && n > 0 && s.nExcluded == 0;
    cand = find(used).';
    if ~isempty(cand)
        s.worstLevel = max(lvlAt(cand));
        w = cand(lvlAt(cand) == s.worstLevel);
        [s.criticalMargin, k] = min(mAt(w));
        iC = idx(w(k));
        s.criticalIndex = iC;
        s.critical = P(iC).cond;
        s.refined = P(iC).refine;
        if s.complete || s.worstLevel == 4
            s.levelHeadline = s.worstLevel;
        end
    end
    s.levelText = levelText(s, levels, n);
    [s.status, s.reason] = statusOf(catOK, D.catWhy{ks(1)}, n, s.nOK, s.nExcluded, s.nNotApplicable);
    if isempty(G), G = s; else, G(g) = s; end
end
end

function [st, why] = statusOf(catOK, catWhy, n, nOK, nEx, nNA)
if ~catOK
    st = 'NOT_ASSESSABLE'; why = catWhy;
elseif n == 0
    st = 'NO_POINTS'; why = 'no point in this subset';
elseif nOK == 0 && nEx == 0
    st = 'NOT_APPLICABLE'; why = sprintf('not applicable at all %d points', nNA);
elseif nOK == 0 && nNA == 0
    st = 'NOT_ASSESSABLE'; why = sprintf('no point could be assessed (FC-701): %d unrated', nEx);
elseif nEx == 0
    st = 'ASSESSED'; why = '';
else
    st = 'PARTIAL';
    why = sprintf('%d rated, not applicable at %d points, %d unrated: the Level holds over the rated points only', ...
        nOK, nNA, nEx);
end
end

function t = levelText(s, levels, n)
t = '';
if isnan(s.worstLevel), return; end
L = s.worstLevel;
if L == 4, base = 'worse than Level 3'; else, base = sprintf('Level %d', L); end
if min(levels) > 1 && L == min(levels)
    base = sprintf('Level %d boundary met (Levels 1-%d not assessed)', L, min(levels) - 1);
end
if s.complete || s.nExcluded == 0
    t = base;
elseif L == 4
    t = sprintf('worse than Level 3 (%d of %d points unrated)', s.nExcluded, n);
else
    t = sprintf('%s or worse (%d of %d points unrated)', base, s.nExcluded, n);
end
end

function [y, st] = metricOf(M, name)
if ~isstruct(M) || ~isfield(M, name)
    y = NaN; st = 'MISSING'; return
end
y = double(M.(name).value); st = M.(name).status;
if strcmp(st, 'OK') && isnan(y), st = 'NAN'; end
end

function e = countReasons(w)
e = struct('reason', {}, 'count', {});
if isempty(w), return; end
[u, ~, j] = unique(w);
cnt = accumarray(j(:), 1);
for k = 1:numel(u), e(k) = struct('reason', u{k}, 'count', cnt(k)); end
end
