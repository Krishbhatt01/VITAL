function r = analyze(opts)
%ANALYZE  M8 uncertainty analysis of the augmented NESC F-16: per group, the
%   bound-worst margin over the joint-coverage box, a Monte Carlo at the group's
%   nominal critical condition, the Clopper-Pearson lower bound and the
%   robustness verdict, at every width scale.
%   r = vital.uq.analyze()                                   plan defaults
%   r = vital.uq.analyze('Groups', {...}, 'WidthScales', [0.5 1 1.5], ...
%         'Spec', spec, 'Conditions', C, 'Rules', R, 'Controller', b, ...
%         'NumLHS', 32, 'NumStarts', 2, 'MaxEvals', 60, 'NumCandidates', 4, ...
%         'N', 200, 'Seed', 2026, 'Reserve', 0, 'Required', 0.95, 'Quiet', true, ...
%         'LonOnly', true, 'Surrogate', true, 'MaxRounds', 3)
%
%   Defaults (docs/PLAN_M5_M8.md, M8 and its amendment after review R3): spec
%   vital.uq.loadSpec() (JUDGMENT widths), conditions
%   vital.ctrl.inEnvelopeConditions() (only in-envelope points count), the
%   augmented aircraft vital.uq.augmentedBuilder(), every group with a finite
%   in-envelope headline Level of the NOMINAL augmented aircraft (the others
%   are listed in r.omitted with the reason; review R3 m6), widths x0.5, x1
%   (headline), x1.5.
%   Per group g (nominal in-envelope headline Level L0, margin m0 to the L0
%   boundary, vital.uq.F16Evaluator.levelMargin):
%     plan        vital.uq.searchPlan: 'longitudinal' (3.2.x groups: only Cm_q,
%                 Cm_table searched, lateral multipliers held at 1; a runtime
%                 spot check at the critical condition with the lateral
%                 multipliers at the widest box's lower corner must reproduce
%                 the margin within 1e-9 relative, otherwise the full box is
%                 used and the plan says so), 'surrogate' (+Inf spiral groups:
%                 Re(spiral root) maximized, vital.uq.surrogateWorst) or 'full'
%     candidates  the nominal critical in-envelope condition plus the next
%                 NumCandidates-1 in-envelope conditions by margin to L0, or by
%                 the surrogate for a 'surrogate' plan (never grid order)
%     per width w: box = vital.uq.box(spec, 'WidthScale', w);
%       bw = vital.uq.boundWorst / surrogateWorst over the plan's parameters
%            (margin to L0 at the candidates; confirmation = a fresh
%            in-envelope vital.fq.assess at the arg-min; a moving limit is
%            re-searched with the moved condition added, at most MaxRounds
%            rounds); bw.theta and bw.points.theta are returned over ALL
%            parameters (the held ones at 1); bw.searchNames lists the
%            searched ones
%       mahalanobis = distance of bw.theta from the nominal in the x1
%            (judgment) sigmas, with the chi-square tail for Dof = the number
%            of searched parameters (vital.uq.mahalanobis)
%       mc = vital.uq.monteCarlo (N samples N(1, w sigma) of ALL parameters at
%            the nominal critical condition; success = the group's Level there
%            <= L0)
%       verdict = vital.uq.verdict(bw, mc)
%     plan.sampledOnly: binary metric (searchPlan) or every evaluated margin
%       equal (flat): the bound-worst rests on the sampled points (R3 M2).
%   A requested group with no finite in-envelope headline Level (or Level 4)
%   is reported NOT_ASSESSABLE; no search is run for it.
%   Single-point evaluations are cached by (theta, condition) in one
%   vital.uq.F16Evaluator, so groups and phases that ask for the same point
%   share it (the centre, corners and LHS points are the same for every group).
%   r fields: label ('JUDGMENT'), spec, gains (controller), conditions,
%     nominal (group table of the vital.fq.assess at theta = 1), coverage
%     (vital.uq.boxCoverage of the x1 box), groups (group, level0, margin0,
%     critical (record, cond, condLabel), candidates (labels, margins, records,
%     conds, surrogate), status, reason, plan, widths (widthScale, box, bw,
%     mahalanobis, mc, verdict, runtime_s)), omitted (group, status, levelText,
%     reason), widthScales, options, counts (pointEvals, cacheHits, assess),
%     runtime_s.
%   Errors: vital:badInput (unknown group).
arguments
    opts.Groups cell = {}
    opts.WidthScales (1,:) double = [0.5 1 1.5]
    opts.Spec struct = struct([])
    opts.Conditions struct = struct([])
    opts.Rules struct = struct([])
    opts.Controller = 'augmented'
    opts.NumLHS (1,1) double = 32
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 60
    opts.NumCandidates (1,1) double = 4
    opts.N (1,1) double = 200
    opts.Seed (1,1) double = 2026
    opts.Reserve (1,1) double = 0
    opts.Required (1,1) double = 0.95
    opts.Quiet (1,1) logical = true
    opts.LonOnly (1,1) logical = true
    opts.Surrogate (1,1) logical = true
    opts.MaxRounds (1,1) double = 3
end
t0 = tic;
spec = opts.Spec; if isempty(spec), spec = vital.uq.loadSpec(); end
R = opts.Rules; if isempty(R), R = vital.fq.loadRules(); end
C = opts.Conditions; if isempty(C), C = vital.ctrl.inEnvelopeConditions(); end
if isempty(opts.WidthScales) || ~(isfinite(opts.NumCandidates) && opts.NumCandidates >= 1)
    error('vital:badInput', 'WidthScales must not be empty and NumCandidates must be >= 1.');
end
B1 = vital.uq.box(spec);
d = numel(B1.names);
E = vital.uq.F16Evaluator(B1.aeroScale, 'Rules', R, 'Conditions', C, 'Controller', opts.Controller);
if ischar(opts.Controller) && strcmp(opts.Controller, 'augmented')
    [~, k] = vital.uq.augmentedBuilder();
    gains = k;
elseif isempty(opts.Controller)
    gains = struct('law', 'none (bare airframe)');
else
    gains = struct('law', func2str(opts.Controller));
end
say(opts, 'M8: nominal augmented assessment over %d conditions ...\n', numel(vital.fq.gridPoints(C)));
res0 = E.assessAt(ones(1, d));
allNames = {res0.groups.group};
names = opts.Groups;
r.omitted = struct('group', {}, 'status', {}, 'levelText', {}, 'reason', {});
if isempty(names)
    L = arrayfun(@(g) g.inEnvelope.levelHeadline, res0.groups);
    names = allNames(isfinite(L));
    G = res0.groups(~isfinite(L));
    for g = G(:).'
        ie = g.inEnvelope;
        parts = cellfun(@char, {ie.levelText, ie.reason}, 'UniformOutput', false);
        why = strjoin(parts(~cellfun(@(t) isempty(strtrim(t)), parts)), '; ');
        r.omitted(end+1) = struct('group', g.group, 'status', ie.status, 'levelText', ie.levelText, ...
            'reason', sprintf('no finite in-envelope headline Level for the nominal aircraft (status %s%s)', ...
            ie.status, prefixed(why)));
    end
end
bad = names(~ismember(names, allNames));
if ~isempty(bad)
    error('vital:badInput', 'unknown group(s): %s.', strjoin(bad, ', '));
end

r.label = spec.label;
r.spec = spec;
r.gains = gains;
r.conditions = struct('id', C.id, 'grid', C.grid, 'axes', C.axes, 'validity', field(C, 'validity'));
r.nominal = nominalTable(res0);
r.coverage = vital.uq.boxCoverage(B1);
r.widthScales = opts.WidthScales;
r.options = rmfield(opts, {'Spec', 'Conditions', 'Rules', 'Controller'});
r.groups = struct('group', {}, 'level0', {}, 'margin0', {}, 'critical', {}, 'candidates', {}, 'status', {}, ...
    'reason', {}, 'plan', {}, 'widths', {});
for gi = 1:numel(names)
    name = names{gi};
    g0 = res0.groups(strcmp(allNames, name));
    L0 = g0.inEnvelope.levelHeadline;
    e = struct('group', name, 'level0', L0, 'margin0', NaN, 'critical', struct('record', '', 'cond', struct(), ...
        'condLabel', ''), 'candidates', struct(), 'status', 'DONE', 'reason', '', 'plan', struct(), 'widths', struct([]));
    if isnan(L0) || L0 >= 4
        e.status = 'NOT_ASSESSABLE';
        if isnan(L0)
            e.reason = sprintf('no in-envelope headline Level for the nominal aircraft (%s)', g0.inEnvelope.levelText);
        else
            e.reason = 'the nominal in-envelope headline is worse than Level 3: there is no Level to hold';
        end
        r.groups(end+1) = e; %#ok<AGROW>
        continue
    end
    [m0, ~] = vital.uq.F16Evaluator.levelMargin(res0, name, L0);
    plan = vital.uq.searchPlan(name, g0.metrics, m0, B1.aeroScale, 'LonOnly', opts.LonOnly, ...
        'Surrogate', opts.Surrogate);
    T = vital.uq.F16Evaluator.candidates(res0, name, L0, plan.mode);
    e.margin0 = m0;
    if isnan(m0) || isempty(T)
        e.status = 'NOT_ASSESSABLE';
        e.reason = 'no rated in-envelope margin to the nominal Level';
        e.plan = plan;
        r.groups(end+1) = e; %#ok<AGROW>
        continue
    end
    nc = min(opts.NumCandidates, numel(T));
    T = T(1:nc);
    e.critical = struct('record', T(1).record, 'cond', T(1).cond, 'condLabel', T(1).label);
    sur = NaN(1, nc); if isfield(T, 'surrogate'), sur = [T.surrogate]; end
    e.candidates = struct('labels', {{T.label}}, 'margins', [T.margin], 'records', {{T.record}}, 'conds', {{T.cond}}, ...
        'surrogate', sur);
    pf = @(th, c) E.groupMargin(th, c, name, L0);
    plan.spotCheck = struct('performed', false, 'passed', false, 'cond', '', 'theta', [], 'margin', NaN, ...
        'marginLateral', NaN, 'reason', '');
    if strcmp(plan.mode, 'longitudinal')
        plan.spotCheck = spotCheck(pf, T(1), spec, max(opts.WidthScales), plan.idx, d);
        if ~plan.spotCheck.passed
            plan.mode = 'full'; plan.idx = 1:d; plan.fields = B1.aeroScale;
            plan.reason = ['the lon/lat spot check FAILED, so the full box is searched: ' plan.spotCheck.reason];
        end
    end
    flat = false;
    for wi = 1:numel(opts.WidthScales)
        w = opts.WidthScales(wi);
        t1 = tic;
        B = vital.uq.box(spec, 'WidthScale', w);
        ix = plan.idx;
        ex = @(t) expandTheta(t, ix, B.nominal);
        prob = struct('names', {B.names(ix)}, 'lo', B.lo(ix), 'hi', B.hi(ix), 'nominal', B.nominal(ix), ...
            'conditions', {{T.cond}}, 'condLabels', {{T.label}});
        so = {'NumLHS', opts.NumLHS, 'Seed', opts.Seed, 'NumStarts', opts.NumStarts, 'MaxEvals', opts.MaxEvals, ...
            'MaxRounds', opts.MaxRounds, 'Reserve', opts.Reserve};
        if strcmp(plan.mode, 'surrogate')
            prob.pointFcn = @(th, c) E.spiralPoint(ex(th), c);
            prob.confirmFcn = @(th) confirmSurrogate(E, ex(th), name, L0);
            bw = vital.uq.surrogateWorst(prob, @(th, c) pf(ex(th), c), so{:});
        else
            prob.pointFcn = @(th, c) pf(ex(th), c);
            prob.confirmFcn = @(th) confirm(E, ex(th), name, L0);
            bw = vital.uq.boundWorst(prob, so{:});
        end
        bw = expandResult(bw, ix, B);
        fm = bw.points.margin(isfinite(bw.points.margin));
        flat = flat || (numel(fm) > 1 && all(fm == fm(1)) && ~strcmp(plan.mode, 'surrogate'));
        [D, p] = vital.uq.mahalanobis(bw.theta, B1.nominal, B1.sigma, 'Dof', numel(ix));
        mah = struct('D', D, 'dof', numel(ix), 'tail', p, ...
            'sigma', 'x1 (judgment) sigmas; tail = P(chi2_dof >= D^2) for dof = the searched parameters');
        mp = struct('names', {B.names}, 'nominal', B.nominal, 'sigma', B.sigmaEff, 'lo', B.lo, 'hi', B.hi, ...
            'cond', T(1).cond, 'condLabel', T(1).label, 'level0', L0, 'pointFcn', pf);
        mc = vital.uq.monteCarlo(mp, 'N', opts.N, 'Seed', opts.Seed);
        v = vital.uq.verdict(bw, mc, 'Reserve', opts.Reserve, 'Required', opts.Required);
        W = struct('widthScale', w, 'box', B, 'bw', bw, 'mahalanobis', mah, 'mc', rmfield(mc, 'cond'), ...
            'verdict', v, 'runtime_s', toc(t1));
        if isempty(e.widths), e.widths = W; else, e.widths(end+1) = W; end
        say(opts, '  %-22s x%-4g bound-worst %-9.4g %-15s MC %3d/%d CP %.4f  %-14s (%.0f s; %d points, %d cache hits)\n', ...
            name, w, bw.value, bw.status, mc.x, mc.N, mc.cpLower, v.verdict, toc(t1), E.nPointEvals, E.nCacheHits);
    end
    if flat && ~plan.sampledOnly
        plan.sampledOnly = true;
        plan.sampledReason = ['flat objective: every evaluated point has the same margin, so the optimizer''s ' ...
            'convergence means nothing; the bound-worst rests on the sampled points only'];
    end
    e.plan = plan;
    r.groups(end+1) = e; %#ok<AGROW>
end
r.counts = struct('pointEvals', E.nPointEvals, 'cacheHits', E.nCacheHits, 'assess', E.nAssess);
r.runtime_s = toc(t0);
end

function th = expandTheta(t, ix, nominal)
% the searched parameters t (n x numel(ix)) into the full parameter vector
th = repmat(nominal, size(t, 1), 1);
th(:, ix) = t;
end

function bw = expandResult(bw, ix, B)
% report a search over the parameters ix over ALL parameters (the others at 1)
bw.searchNames = B.names(ix);
bw.searchIndex = ix;
if numel(ix) == numel(B.names), return; end
full = @(t) expandTheta(t, ix, B.nominal);
if any(isnan(bw.theta)), bw.theta = NaN(1, numel(B.names)); else, bw.theta = full(bw.theta); end
bw.points.theta = full(bw.points.theta);
for k = 1:numel(bw.rounds)
    if any(isnan(bw.rounds(k).theta))
        bw.rounds(k).theta = NaN(1, numel(B.names));
    else
        bw.rounds(k).theta = full(bw.rounds(k).theta);
    end
end
bw.names = B.names; bw.lo = B.lo; bw.hi = B.hi;
end

function sc = spotCheck(pf, t1, spec, wmax, ix, d)
% runtime lon/lat spot check at the critical condition: the margin with the
% lateral multipliers at the widest box's lower corner equals the nominal one
Bm = vital.uq.box(spec, 'WidthScale', wmax);
lat = setdiff(1:d, ix);
th = ones(1, d); th(lat) = Bm.lo(lat);
q0 = pf(ones(1, d), t1.cond);
q1 = pf(th, t1.cond);
sc = struct('performed', true, 'passed', false, 'cond', t1.label, 'theta', th, 'margin', q0.margin, ...
    'marginLateral', q1.margin, 'reason', '');
if ~strcmp(q0.status, 'OK') || ~strcmp(q1.status, 'OK')
    sc.reason = sprintf('a spot-check point is not OK (%s / %s)', q0.status, q1.status);
elseif isequal(q0.margin, q1.margin) || abs(q1.margin - q0.margin) <= 1e-9 * abs(q0.margin)
    sc.passed = true;
    sc.reason = sprintf(['margin %.10g with the lateral multipliers at 1 and %.10g at the x%g lower corner (%s): ' ...
        'equal within 1e-9 relative'], q0.margin, q1.margin, wmax, t1.label);
else
    sc.reason = sprintf('margin %.10g vs %.10g with the lateral multipliers at the x%g lower corner (%s)', ...
        q0.margin, q1.margin, wmax, t1.label);
end
end

function c = confirm(E, th, group, L0)
res = E.assessAt(th);
[m, cr] = vital.uq.F16Evaluator.levelMargin(res, group, L0);
c = struct('status', 'OK', 'margin', m, 'condLabel', cr.condLabel, 'record', cr.record, 'reason', '', 'cond', cr.cond);
if isnan(m)
    g = res.groups(strcmp({res.groups.group}, group));
    c.status = 'NOT_OK';
    c.reason = sprintf('in-envelope margin unrated at the arg-min parameters (%s, %s)', g.inEnvelope.status, ...
        g.inEnvelope.reason);
end
end

function c = confirmSurrogate(E, th, group, L0)
% fresh in-envelope assessment: the largest spiral surrogate over the IN points
res = E.assessAt(th);
T = vital.uq.F16Evaluator.inEnvelopeSurrogate(res, group, L0);
m = vital.uq.F16Evaluator.levelMargin(res, group, L0);
c = struct('status', 'OK', 'value', NaN, 'condLabel', '', 'cond', struct(), 'record', 'spiral root', 'reason', '');
if isempty(T) || any(isnan([T.surrogate]))
    c.status = 'NOT_OK';
    c.reason = 'the spiral root is not available at every in-envelope point at the arg-max parameters';
elseif isnan(m)
    g = res.groups(strcmp({res.groups.group}, group));
    c.status = 'NOT_OK';
    c.reason = sprintf('in-envelope margin unrated at the arg-max parameters (%s, %s)', g.inEnvelope.status, ...
        g.inEnvelope.reason);
else
    c.value = T(1).surrogate; c.condLabel = T(1).label; c.cond = T(1).cond;
    c.reason = sprintf('in-envelope margin %.6g', m);
end
end

function T = nominalTable(res)
T = struct('group', {}, 'levelHeadline', {}, 'levelText', {}, 'criticalMargin', {}, 'critical', {}, 'status', {});
for g = res.groups(:).'
    ie = g.inEnvelope;
    T(end+1) = struct('group', g.group, 'levelHeadline', ie.levelHeadline, 'levelText', ie.levelText, ...
        'criticalMargin', ie.criticalMargin, 'critical', vital.uq.F16Evaluator.condLabel(ie.critical), ...
        'status', ie.status); %#ok<AGROW>
end
end

function t = prefixed(s)
if isempty(strtrim(s)), t = ''; else, t = ['; ' s]; end
end

function v = field(s, f)
if isfield(s, f), v = s.(f); else, v = []; end
end

function say(opts, varargin)
if ~opts.Quiet, fprintf(varargin{:}); end
end
