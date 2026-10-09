function r = analyze(opts)
%ANALYZE  M8 uncertainty analysis of the augmented NESC F-16: per group, the
%   bound-worst margin over the joint-coverage box, a Monte Carlo at the group's
%   nominal critical condition, the Clopper-Pearson lower bound and the
%   robustness verdict, at every width scale.
%   r = vital.uq.analyze()                                   plan defaults
%   r = vital.uq.analyze('Groups', {...}, 'WidthScales', [0.5 1 1.5], ...
%         'Spec', spec, 'Conditions', C, 'Rules', R, 'Controller', b, ...
%         'NumLHS', 32, 'NumStarts', 2, 'MaxEvals', 60, 'NumCandidates', 4, ...
%         'N', 200, 'Seed', 2026, 'Reserve', 0, 'Required', 0.95, 'Quiet', true)
%
%   Defaults (docs/PLAN_M5_M8.md, M8): spec vital.uq.loadSpec() (JUDGMENT
%   widths), conditions vital.ctrl.inEnvelopeConditions() (only in-envelope
%   points count), the augmented aircraft vital.uq.augmentedBuilder(), every
%   group with a finite in-envelope headline Level of the NOMINAL augmented
%   aircraft, widths x0.5, x1 (headline), x1.5.
%   Per group g (nominal in-envelope headline Level L0, margin m0 to the L0
%   boundary, vital.uq.F16Evaluator.levelMargin):
%     candidates  the nominal critical in-envelope condition plus the next
%                 NumCandidates-1 in-envelope conditions by margin to L0
%     per width w: box = vital.uq.box(spec, 'WidthScale', w);
%       bw = vital.uq.boundWorst (margin to L0 at the candidates; confirmation
%            = a fresh in-envelope vital.fq.assess at the arg-min)
%       mc = vital.uq.monteCarlo (N samples N(1, w sigma) at the nominal
%            critical condition; success = the group's Level there <= L0)
%       verdict = vital.uq.verdict(bw, mc)
%   A requested group with no finite in-envelope headline Level (or Level 4)
%   is reported NOT_ASSESSABLE; no search is run for it.
%   Single-point evaluations are cached by (theta, condition) in one
%   vital.uq.F16Evaluator, so groups and phases that ask for the same point
%   share it (the centre, corners and LHS points are the same for every group).
%   r fields: label ('JUDGMENT'), spec, gains (controller), conditions,
%     nominal (group table of the vital.fq.assess at theta = 1), groups (group,
%     level0, margin0, critical (record, cond, condLabel), candidates (labels,
%     margins, records, conds), status, reason, widths (widthScale, box, bw, mc,
%     verdict)), widthScales, options, counts (pointEvals, cacheHits, assess),
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
if isempty(names)
    L = arrayfun(@(g) g.inEnvelope.levelHeadline, res0.groups);
    names = allNames(isfinite(L));
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
r.widthScales = opts.WidthScales;
r.options = rmfield(opts, {'Spec', 'Conditions', 'Rules', 'Controller'});
r.groups = struct('group', {}, 'level0', {}, 'margin0', {}, 'critical', {}, 'candidates', {}, 'status', {}, ...
    'reason', {}, 'widths', {});
for gi = 1:numel(names)
    name = names{gi};
    g0 = res0.groups(strcmp(allNames, name));
    L0 = g0.inEnvelope.levelHeadline;
    e = struct('group', name, 'level0', L0, 'margin0', NaN, 'critical', struct('record', '', 'cond', struct(), ...
        'condLabel', ''), 'candidates', struct(), 'status', 'DONE', 'reason', '', 'widths', struct([]));
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
    T = vital.uq.F16Evaluator.inEnvelopeMargins(res0, name, L0);
    e.margin0 = m0;
    if isnan(m0) || isempty(T)
        e.status = 'NOT_ASSESSABLE';
        e.reason = 'no rated in-envelope margin to the nominal Level';
        r.groups(end+1) = e; %#ok<AGROW>
        continue
    end
    nc = min(opts.NumCandidates, numel(T));
    T = T(1:nc);
    e.critical = struct('record', T(1).record, 'cond', T(1).cond, 'condLabel', T(1).label);
    e.candidates = struct('labels', {{T.label}}, 'margins', [T.margin], 'records', {{T.record}}, 'conds', {{T.cond}});
    pf = @(th, c) E.groupMargin(th, c, name, L0);
    for wi = 1:numel(opts.WidthScales)
        w = opts.WidthScales(wi);
        t1 = tic;
        B = vital.uq.box(spec, 'WidthScale', w);
        prob = struct('names', {B.names}, 'lo', B.lo, 'hi', B.hi, 'nominal', B.nominal, ...
            'conditions', {{T.cond}}, 'condLabels', {{T.label}}, 'pointFcn', pf, ...
            'confirmFcn', @(th) confirm(E, th, name, L0));
        bw = vital.uq.boundWorst(prob, 'NumLHS', opts.NumLHS, 'Seed', opts.Seed, 'NumStarts', opts.NumStarts, ...
            'MaxEvals', opts.MaxEvals, 'Reserve', opts.Reserve);
        mp = struct('names', {B.names}, 'nominal', B.nominal, 'sigma', B.sigmaEff, 'lo', B.lo, 'hi', B.hi, ...
            'cond', T(1).cond, 'condLabel', T(1).label, 'level0', L0, 'pointFcn', pf);
        mc = vital.uq.monteCarlo(mp, 'N', opts.N, 'Seed', opts.Seed);
        v = vital.uq.verdict(bw, mc, 'Reserve', opts.Reserve, 'Required', opts.Required);
        W = struct('widthScale', w, 'box', B, 'bw', bw, 'mc', rmfield(mc, 'cond'), 'verdict', v, 'runtime_s', toc(t1));
        if isempty(e.widths), e.widths = W; else, e.widths(end+1) = W; end
        say(opts, '  %-22s x%-4g bound-worst %-9.4g %-15s MC %3d/%d CP %.4f  %-14s (%.0f s; %d points, %d cache hits)\n', ...
            name, w, bw.value, bw.status, mc.x, mc.N, mc.cpLower, v.verdict, toc(t1), E.nPointEvals, E.nCacheHits);
    end
    r.groups(end+1) = e; %#ok<AGROW>
end
r.counts = struct('pointEvals', E.nPointEvals, 'cacheHits', E.nCacheHits, 'assess', E.nAssess);
r.runtime_s = toc(t0);
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

function T = nominalTable(res)
T = struct('group', {}, 'levelHeadline', {}, 'levelText', {}, 'criticalMargin', {}, 'critical', {}, 'status', {});
for g = res.groups(:).'
    ie = g.inEnvelope;
    T(end+1) = struct('group', g.group, 'levelHeadline', ie.levelHeadline, 'levelText', ie.levelText, ...
        'criticalMargin', ie.criticalMargin, 'critical', vital.uq.F16Evaluator.condLabel(ie.critical), ...
        'status', ie.status); %#ok<AGROW>
end
end

function v = field(s, f)
if isfield(s, f), v = s.(f); else, v = []; end
end

function say(opts, varargin)
if ~opts.Quiet, fprintf(varargin{:}); end
end
