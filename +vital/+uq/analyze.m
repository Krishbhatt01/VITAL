function r = analyze(opts)
%ANALYZE  M8 uncertainty analysis of the augmented NESC F-16, per group: the
%   bound-worst margin over the joint-coverage box, the Critical Similitude
%   Ratio (CSR) of two reference shapes (the headline, amendment R4), a Monte
%   Carlo at the group's nominal critical condition, the Clopper-Pearson lower
%   bound and the robustness verdict.
%   r = vital.uq.analyze()                                   plan defaults
%   r = vital.uq.analyze('Groups', {...}, 'WidthScales', 1, 'Spec', spec,
%         'Conditions', C, 'Rules', R, 'Controller', b, 'NumLHS', 32,
%         'NumStarts', 2, 'MaxEvals', 150, 'NumCandidates', 4, 'N', 200,
%         'Seed', 2026, 'Reserve', 0, 'Required', 0.95, 'Quiet', true,
%         'LonOnly', true, 'Surrogate', true, 'MaxRounds', 3,
%         'Method', 'auto', 'GridMaxDim', 2, 'GridPoints', 11,
%         'GridLocalLevels', 3, 'GridMaxRefine', 8, 'GridBudget', 2000,
%         'DEPopulation', 16, 'DEGenerations', 8, 'TolX', 1e-2, 'TolFun', 1e-4,
%         'CSR', true, 'AlphaMax', 3, 'Resolution', 0.01, 'EqualPct', 0.10,
%         'MaxSearches', 15, 'Lattice', true, 'LatticeMaxLevel', 10,
%         'LatticeMaxPoints', 6000, 'LatDropCmq', true, 'Bracket', true,
%         'Staged', false, 'Stage1', struct(...), 'Stage2Band', [0.8 1.2])
%
%   Defaults (docs/PLAN_M5_M8.md, M8, its amendment after review R3 and
%   amendment R4): spec vital.uq.loadSpec() (JUDGMENT widths), conditions
%   vital.ctrl.inEnvelopeConditions() (only in-envelope points count), the
%   augmented aircraft vital.uq.augmentedBuilder(), every group with a finite
%   in-envelope headline Level of the NOMINAL augmented aircraft (the others
%   are listed in r.omitted with the reason; review R3 m6), width x1 only
%   (R4-2: the x0.5 / x1.5 widths are available with 'WidthScales').
%   STATED SEARCH BUDGETS (defaults): centre + 2^d corners + 32 seeded LHS
%   points; method 'auto' (vital.uq.searchMethod): 'grid' for <= GridMaxDim (2)
%   searched parameters (11 points per dimension, 3 local refinement levels, at
%   most 8 Lipschitz refinement levels and 2000 lattice points; R4-3), else
%   'hybrid' (differential evolution 16 members x 8 generations seeded with the
%   LHS points, then Nelder-Mead from the 2 best points, 150 evaluations each,
%   TolX 1e-2 in the transformed coordinate, TolFun 1e-4; R4-4); 4 candidate
%   conditions; at most 3 moving-limit rounds per search; Monte Carlo N = 200.
%   'Method' 'sqp' (or 'grid' / 'hybrid') forces one method for every group.
%
%   AMENDMENT R4b (docs/PLAN_M5_M8.md "Amendment R4b", coordinator 2026-10-14):
%   R4-3 corrected ('Lattice' true, with 'Method' 'auto'): every longitudinal
%     group (plan mode 'longitudinal', whatever its dimension <= 3) is decided on
%     ONE shared adaptive lattice (vital.uq.lattice) over the AlphaMax box of
%     the judged shape, evaluated once per candidate condition (the union of
%     the longitudinal groups' candidates) and reused by every longitudinal
%     group, both reference shapes, every CSR alpha and every width box:
%     GridPoints (11) per axis, at most LatticeMaxLevel (10) halvings per axis
%     and LatticeMaxPoints (6000) lattice points per group (STATED CAPS), the
%     Lipschitz factor 2. alpha* is read from the lattice to the resolution
%     (0.01); the CPV (and the cap-box and width-box arg-mins) are confirmed by
%     a fresh in-envelope assessment with the moving-limit rule (MaxRounds).
%     plan.method 'lattice'; csr.judged/equal.method 'lattice' (nSearches 0);
%     the width boxes are reported in the bound-worst form (method 'lattice',
%     label 'grid-certified (Lipschitz estimate)'). A longitudinal group whose
%     equal-percentage cap box would leave the lattice box (a half-width below
%     EqualPct) uses vital.uq.searchMethod instead, and its plan says so.
%   R4-7 ('Bracket' true): the evaluator brackets linearization failures at NESC
%     aero-table breakpoints (vital.uq.F16Evaluator, vital.uq.bracket); every
%     bracketed point is listed in r.bracketed with both sides' margins.
%   R4-8 ('Staged' true; run_f16_uq's default): STAGE 1 runs every group at the
%     reduced budget vital.uq.stageBudget (NumCandidates 2, differential
%     evolution 8 x 4, the stated Monte Carlo N; 'Stage1' overrides those three
%     values); STAGE 2 re-runs at the full budget only the groups that
%     vital.uq.stagePlan selects (judged CSR bracket overlapping Stage2Band
%     [0.8 1.2], or NOT_ASSESSABLE for budget reasons, FC-901); the lattice
%     groups never need stage 2. Stage 2 is skipped when its budget equals
%     stage 1's. Every group reports g.stage (decidedBy 1 or 2, reason, stage1:
%     the stage-1 summary of a re-run group), and r.stages the budgets.
%   R4-9 ('LatDropCmq' true): a lateral group (3.3.x) does not search Cm_q
%     (plan mode 'lateral', or 'surrogate' without Cm_q, plan.dropped). Runtime
%     gate at the group's critical condition: the margin (the spiral surrogate
%     for a 'surrogate' plan) with Cm_q at the extreme values of every box
%     searched must equal the nominal one within 1e-9 relative
%     (vital.uq.invarianceCheck); if it does not, vital.uq.gatePlan falls back
%     to the full set of parameters (plan.latCheck).
%
%   Per group g (nominal in-envelope headline Level L0, margin m0 to the L0
%   boundary, vital.uq.F16Evaluator.levelMargin):
%     plan        vital.uq.searchPlan: 'longitudinal' (3.2.x groups: only the
%                 longitudinal multipliers Cm_q, Cm_table, Cm_basic, Cm_de of
%                 the spec searched, the lateral ones held at 1; a runtime
%                 spot check at the critical condition with the lateral
%                 multipliers at their most extreme lower value of any box
%                 searched (the widest width, and with 'CSR' the cap boxes of
%                 both shapes) must reproduce the margin within 1e-9 relative,
%                 otherwise the full box is used and the plan says so),
%                 'lateral' (R4-9), 'surrogate' (+Inf spiral groups: Re(spiral
%                 root) maximized, vital.uq.surrogateWorst) or 'full';
%                 plan.method 'lattice' / 'grid' / 'hybrid' / 'sqp'
%     candidates  the nominal critical in-envelope condition plus the next
%                 NumCandidates-1 in-envelope conditions by margin to L0, or by
%                 the surrogate for a 'surrogate' plan (never grid order)
%     per width w: box = vital.uq.box(spec, 'WidthScale', w);
%       bw = the lattice box R(w) (lattice groups), or vital.uq.boundWorst /
%            surrogateWorst over the plan's parameters with plan.method (margin
%            to L0 at the candidates; confirmation = a fresh in-envelope
%            vital.fq.assess at the arg-min; a moving limit is re-searched, at
%            most MaxRounds rounds); bw.theta and bw.points.theta are over ALL
%            parameters (the held ones at 1)
%       mahalanobis = distance of bw.theta in the x1 (judgment) sigmas
%            (vital.uq.mahalanobis, Dof = the number of searched parameters)
%       mc = vital.uq.monteCarlo (N samples N(1, w sigma) of ALL parameters at
%            the nominal critical condition; success = Level there <= L0)
%       verdict = vital.uq.verdict(bw, mc): the BOX verdict at this width (the
%            original M8 definition; reported beside the headline)
%     csr (amendment R4-1; 'CSR' true): from the lattice for lattice groups,
%       else vital.uq.csr over the searched parameters with the same search
%       (method, budgets, candidates, confirmation, moving-limit rule),
%       AlphaMax 3, resolution 0.01, two reference shapes:
%         judged  m = the x1 half-widths k_g sigma (the headline; DecideAt 1,
%                 so alpha*(judged) >= 1 or < 1 is always decided; the x1
%                 bound-worst result is its prior)
%         equal   m = EqualPct (0.10) for every searched parameter (alpha* x
%                 10 % is the tolerated uniform tolerance); every search of the
%                 judged shape is its prior (a clean box contains smaller
%                 equal boxes; a failing point bounds alpha* in any shape)
%       the CPV and the parametric safety margins (alpha* m) are reported over
%       ALL parameters (the held ones at 1, margin 0)
%     verdict (R4-2) = vital.uq.verdict(csr.judged, mc at x1): the HEADLINE
%       (ROBUST / NOT_ROBUST / NOT_ASSESSABLE); 'CSR' false: NOT_ASSESSABLE
%       with the reason 'CSR not computed'
%     plan.sampledOnly: binary metric (searchPlan) or every evaluated margin
%       equal (flat): the bound-worst rests on the sampled points only.
%   A requested group with no finite in-envelope headline Level (or Level 4)
%   is reported NOT_ASSESSABLE; no search is run for it.
%   Single-point evaluations are cached by (theta, condition) in one
%   vital.uq.F16Evaluator, so groups, widths, shapes, phases and stages that ask
%   for the same point share it.
%   r fields: label ('JUDGMENT'), spec, gains (controller), conditions,
%     nominal (group table of the vital.fq.assess at theta = 1), coverage
%     (vital.uq.boxCoverage of the x1 box), groups (group, level0, margin0,
%     critical (record, cond, condLabel), candidates (labels, margins, records,
%     conds, surrogate), status, reason, plan, widths (widthScale, box, bw,
%     mahalanobis, mc, verdict, runtime_s), csr (judged, equal, names,
%     searchNames, runtime_s), verdict, stage), omitted (group, status,
%     levelText, reason), widthScales, options, stages, lattice (the shared
%     lattice: groups, conditions, nPoints, nEvaluations, capped), bracketed
%     (vital.uq.F16Evaluator.bracketed), counts (pointEvals, cacheHits,
%     assess, bracketed), runtime_s.
%   Errors: vital:badInput (unknown group, a Stage1 field other than
%   NumCandidates / DEPopulation / DEGenerations).
arguments
    opts.Groups cell = {}
    opts.WidthScales (1,:) double = 1
    opts.Spec struct = struct([])
    opts.Conditions struct = struct([])
    opts.Rules struct = struct([])
    opts.Controller = 'augmented'
    opts.NumLHS (1,1) double = 32
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 150
    opts.NumCandidates (1,1) double = 4
    opts.N (1,1) double = 200
    opts.Seed (1,1) double = 2026
    opts.Reserve (1,1) double = 0
    opts.Required (1,1) double = 0.95
    opts.Quiet (1,1) logical = true
    opts.LonOnly (1,1) logical = true
    opts.Surrogate (1,1) logical = true
    opts.MaxRounds (1,1) double = 3
    opts.Method (1,:) char = 'auto'
    opts.GridMaxDim (1,1) double = 2
    opts.GridPoints (1,1) double = 11
    opts.GridLocalLevels (1,1) double = 3
    opts.GridMaxRefine (1,1) double = 8
    opts.GridBudget (1,1) double = 2000
    opts.DEPopulation (1,1) double = 16
    opts.DEGenerations (1,1) double = 8
    opts.TolX (1,1) double = 1e-2
    opts.TolFun (1,1) double = 1e-4
    opts.CSR (1,1) logical = true
    opts.AlphaMax (1,1) double = 3
    opts.Resolution (1,1) double = 0.01
    opts.EqualPct (1,1) double = 0.10
    opts.MaxSearches (1,1) double = 15
    opts.Lattice (1,1) logical = true
    opts.LatticeMaxLevel (1,1) double = 10
    opts.LatticeMaxPoints (1,1) double = 6000
    opts.LatDropCmq (1,1) logical = true
    opts.Staged (1,1) logical = false
    opts.Stage1 struct = struct([])
    opts.Stage2Band (1,2) double = [0.8 1.2]
    opts.Bracket (1,1) logical = true
end
t0 = tic;
spec = opts.Spec; if isempty(spec), spec = vital.uq.loadSpec(); end
R = opts.Rules; if isempty(R), R = vital.fq.loadRules(); end
C = opts.Conditions; if isempty(C), C = vital.ctrl.inEnvelopeConditions(); end
if isempty(opts.WidthScales) || ~(isfinite(opts.NumCandidates) && opts.NumCandidates >= 1)
    error('vital:badInput', 'WidthScales must not be empty and NumCandidates must be >= 1.');
end
ov = {};
if ~isempty(opts.Stage1)
    f1 = fieldnames(opts.Stage1);
    bad = setdiff(f1, {'NumCandidates', 'DEPopulation', 'DEGenerations'});
    if ~isempty(bad)
        error('vital:badInput', 'Stage1 may set NumCandidates, DEPopulation and DEGenerations only (got %s).', ...
            strjoin(bad, ', '));
    end
    for k = 1:numel(f1), ov(end+1:end+2) = {f1{k}, opts.Stage1.(f1{k})}; end %#ok<AGROW>
end
B1 = vital.uq.box(spec);
d = numel(B1.names);
E = vital.uq.F16Evaluator(B1.aeroScale, 'Rules', R, 'Conditions', C, 'Controller', opts.Controller, ...
    'Bracket', opts.Bracket);
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
ctx = struct('E', E, 'res0', res0, 'spec', spec, 'B1', B1, 'd', d, 'allNames', {allNames});
full = budgetOf(opts);
if opts.Staged
    [s1, same] = vital.uq.stageBudget(full, ov{:});
    o1 = opts;
    for f = fieldnames(s1).', o1.(f{1}) = s1.(f{1}); end
    say(opts, 'M8 STAGE 1 (reduced budget: NumCandidates %d, differential evolution %d x %d, N %d) ...\n', ...
        s1.NumCandidates, s1.DEPopulation, s1.DEGenerations, s1.N);
    [Gr, lat] = runGroups(names, o1, ctx);
    need2 = {};
    for k = 1:numel(Gr)
        [need, why] = vital.uq.stagePlan(Gr(k), 'Band', opts.Stage2Band);
        Gr(k).stage = struct('decidedBy', 1, 'reason', why, 'stage1', []);
        if need && ~same
            need2{end+1} = Gr(k).group; %#ok<AGROW>
        elseif need
            Gr(k).stage.reason = [why '; stage 2 not run: its budget equals the stage-1 budget'];
        end
    end
    if ~isempty(need2)
        say(opts, 'M8 STAGE 2 (full budget) for %d group(s): %s ...\n', numel(need2), strjoin(need2, ', '));
        G2 = runGroups(need2, opts, ctx);
        for j = 1:numel(G2)
            k = find(strcmp({Gr.group}, G2(j).group), 1);
            G2(j).stage = struct('decidedBy', 2, 'reason', Gr(k).stage.reason, 'stage1', stage1Summary(Gr(k)));
            Gr(k) = G2(j);
        end
    end
    r.stages = struct('staged', true, 'stage1', s1, 'full', full, 'same', same, 'band', opts.Stage2Band, ...
        'stage2Groups', {need2});
else
    [Gr, lat] = runGroups(names, opts, ctx);
    for k = 1:numel(Gr)
        Gr(k).stage = struct('decidedBy', 1, 'reason', 'single-stage run (Staged false)', 'stage1', []);
    end
    r.stages = struct('staged', false, 'stage1', [], 'full', full, 'same', true, 'band', opts.Stage2Band, ...
        'stage2Groups', {{}});
end
r.groups = Gr;
r.lattice = lat;
r.bracketed = E.bracketed;
r.counts = struct('pointEvals', E.nPointEvals, 'cacheHits', E.nCacheHits, 'assess', E.nAssess, ...
    'bracketed', numel(E.bracketed));
r.runtime_s = toc(t0);
end

% =========================================================================================
function [Gr, lat] = runGroups(names, opts, ctx)
% the analysis of the groups names at the budget opts (one stage)
E = ctx.E; res0 = ctx.res0; spec = ctx.spec; B1 = ctx.B1; d = ctx.d; allNames = ctx.allNames;
Gr = struct('group', {}, 'level0', {}, 'margin0', {}, 'critical', {}, 'candidates', {}, 'status', {}, ...
    'reason', {}, 'plan', {}, 'widths', {}, 'csr', {}, 'verdict', {}, 'stage', {});
lat = struct('used', false, 'groups', {{}}, 'conditions', {{}}, 'nPoints', 0, 'nBase', 0, 'nEvaluations', [], ...
    'capped', false, 'cappedGroups', {{}}, 'pointEvals', 0, 'confirmations', 0, 'runtime_s', 0, 'options', struct());
noCsr = struct('verdict', 'NOT_ASSESSABLE', 'reason', 'CSR not computed (option CSR false)', 'csrStatus', '', ...
    'alphaStar', NaN, 'alphaHi', NaN, 'cpLower', NaN, 'reserve', opts.Reserve, 'required', opts.Required);
stage0 = struct('decidedBy', 1, 'reason', '', 'stage1', []);
% ---- 1. plans, candidates, spot checks ----------------------------------------------------
prep = struct('k', {}, 'T', {}, 'L0', {}, 'pf', {});
for gi = 1:numel(names)
    name = names{gi};
    g0 = res0.groups(strcmp(allNames, name));
    L0 = g0.inEnvelope.levelHeadline;
    e = struct('group', name, 'level0', L0, 'margin0', NaN, 'critical', struct('record', '', 'cond', struct(), ...
        'condLabel', ''), 'candidates', struct(), 'status', 'DONE', 'reason', '', 'plan', struct(), 'widths', struct([]), ...
        'csr', struct([]), 'verdict', noCsr, 'stage', stage0);
    if isnan(L0) || L0 >= 4
        e.status = 'NOT_ASSESSABLE';
        if isnan(L0)
            e.reason = sprintf('no in-envelope headline Level for the nominal aircraft (%s)', g0.inEnvelope.levelText);
        else
            e.reason = 'the nominal in-envelope headline is worse than Level 3: there is no Level to hold';
        end
        e.verdict.reason = e.reason;
        Gr(end+1) = e; %#ok<AGROW>
        continue
    end
    [m0, ~] = vital.uq.F16Evaluator.levelMargin(res0, name, L0);
    plan = vital.uq.searchPlan(name, g0.metrics, m0, B1.aeroScale, 'LonOnly', opts.LonOnly, ...
        'Surrogate', opts.Surrogate, 'Method', opts.Method, 'GridMaxDim', opts.GridMaxDim, ...
        'LatDropCmq', opts.LatDropCmq, 'Lattice', opts.Lattice);
    if strcmp(plan.method, 'lattice')
        hw = B1.halfWidth(plan.idx);
        if any(hw < opts.EqualPct) || any(1 - opts.AlphaMax * hw < 0) || any(opts.WidthScales > opts.AlphaMax)
            plan.method = vital.uq.searchMethod(numel(plan.idx), 'GridMaxDim', opts.GridMaxDim);
            plan.reason = sprintf(['%s; the shared lattice is not used (a judged half-width is below the equal ' ...
                'percentage %g, the cap box has a negative multiplier, or a width exceeds AlphaMax): %s search'], ...
                plan.reason, opts.EqualPct, plan.method);
        end
    end
    T = vital.uq.F16Evaluator.candidates(res0, name, L0, plan.mode);
    e.margin0 = m0;
    if isnan(m0) || isempty(T)
        e.status = 'NOT_ASSESSABLE';
        e.reason = 'no rated in-envelope margin to the nominal Level';
        e.verdict.reason = e.reason;
        e.plan = plan;
        Gr(end+1) = e; %#ok<AGROW>
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
        latLo = vital.uq.box(spec, 'WidthScale', max(opts.WidthScales)).lo;
        if opts.CSR || strcmp(plan.method, 'lattice')
            latLo = min([latLo; 1 - opts.AlphaMax * B1.halfWidth; (1 - opts.AlphaMax * opts.EqualPct) * ones(1, d)], [], 1);
        end
        plan.spotCheck = spotCheck(pf, T(1), latLo, plan.idx, d);
        if ~plan.spotCheck.passed
            plan.mode = 'full'; plan.idx = 1:d; plan.fields = B1.aeroScale;
            plan.reason = ['the lon/lat spot check FAILED, so the full box is searched: ' plan.spotCheck.reason];
            if strcmp(opts.Method, 'auto')
                plan.method = vital.uq.searchMethod(d, 'GridMaxDim', opts.GridMaxDim);
            end
        end
    end
    if isfield(plan, 'dropped') && ~isempty(plan.dropped)          % R4-9 runtime gate
        plan = vital.uq.gatePlan(plan, latGate(E, pf, T(1), plan, B1, opts), B1.aeroScale, 'Method', opts.Method, ...
            'GridMaxDim', opts.GridMaxDim);
    end
    e.plan = plan;
    Gr(end+1) = e; %#ok<AGROW>
    prep(end+1) = struct('k', numel(Gr), 'T', {T}, 'L0', L0, 'pf', pf); %#ok<AGROW>
end
% ---- 2. the shared lattice of the longitudinal groups (R4b R4-3 corrected) -----------------
iL = arrayfun(@(p) strcmp(Gr(p.k).plan.method, 'lattice'), prep);
LR = [];
if any(iL)
    t1 = tic;
    pl = prep(iL);
    ixL = Gr(pl(1).k).plan.idx;
    for p = pl(2:end)
        if ~isequal(Gr(p.k).plan.idx, ixL)
            error('vital:badInput', 'the longitudinal groups must search the same parameters to share a lattice.');
        end
    end
    exL = @(t) expandTheta(t, ixL, B1.nominal);
    lbl = {}; cnd = {};
    gconds = cell(1, numel(pl));
    for j = 1:numel(pl)
        for t = pl(j).T(:).'
            k = find(strcmp(lbl, t.label), 1);
            if isempty(k), lbl{end+1} = t.label; cnd{end+1} = t.cond; k = numel(lbl); end %#ok<AGROW>
            gconds{j}(end+1) = k;
        end
    end
    gnames = arrayfun(@(p) Gr(p.k).group, pl, 'UniformOutput', false);
    L0s = [pl.L0];
    LP = struct('names', {B1.names(ixL)}, 'nominal', B1.nominal(ixL), 'm', B1.halfWidth(ixL), ...
        'conditions', {cnd}, 'condLabels', {lbl}, ...
        'pointFcn', @(th, c) latticePoint(E, exL(th), c, gnames, L0s));
    LP.groups = struct('name', gnames, 'conds', gconds, ...
        'confirmFcn', arrayfun(@(j) @(th) confirm(E, exL(th), gnames{j}, L0s(j)), 1:numel(pl), 'UniformOutput', false));
    LP.shapes = struct('name', {'judged', 'equal'}, 'm', {B1.halfWidth(ixL), opts.EqualPct * ones(1, numel(ixL))});
    boxes = struct('name', arrayfun(@(w) sprintf('x%g', w), opts.WidthScales, 'UniformOutput', false), ...
        'alpha', num2cell(opts.WidthScales));
    n0 = E.nPointEvals;
    say(opts, '  shared lattice: %d longitudinal group(s) (%s) over %s at %d candidate condition(s) ...\n', ...
        numel(pl), strjoin(gnames, ', '), strjoin(B1.names(ixL), ', '), numel(lbl));
    LR = vital.uq.lattice(LP, 'GridPoints', opts.GridPoints, 'MaxLevel', opts.LatticeMaxLevel, ...
        'MaxPoints', opts.LatticeMaxPoints, 'AlphaMax', opts.AlphaMax, 'Resolution', opts.Resolution, ...
        'Reserve', opts.Reserve, 'MaxRounds', opts.MaxRounds, 'DecideAt', 1, 'Boxes', boxes);
    lat = struct('used', true, 'groups', {gnames}, 'conditions', {LR.condLabels}, 'nPoints', LR.lattice.nPoints, ...
        'nBase', LR.lattice.nBase, 'nEvaluations', LR.lattice.nEvaluations, 'capped', LR.lattice.capped, ...
        'cappedGroups', {LR.lattice.cappedGroups}, 'pointEvals', E.nPointEvals - n0, ...
        'confirmations', LR.counts.confirmations, 'runtime_s', toc(t1), 'options', rmfield(LR.options, 'Boxes'));
    say(opts, '  shared lattice: %d lattice points, %d point evaluations, %d confirmations (%.0f s)\n', ...
        LR.lattice.nPoints, E.nPointEvals - n0, LR.counts.confirmations, toc(t1));
end
latIdx = find(iL);
% ---- 3. per group: widths, Monte Carlo, CSR, verdict -----------------------------------------
for ip = 1:numel(prep)
    p = prep(ip);
    e = Gr(p.k);
    name = e.group; plan = e.plan; T = p.T; L0 = p.L0; pf = p.pf;
    ix = plan.idx;
    ex = @(t) expandTheta(t, ix, B1.nominal);
    isLat = strcmp(plan.method, 'lattice');
    if isLat
        jL = find(latIdx == ip, 1);
        lg = LR.groups(jL);
        plan.lattice = struct('conditions', {lg.condLabels}, 'certificate', lg.certificate, 'rounds', numel(lg.rounds), ...
            'nPoints', lg.csr(1).lattice.nPoints, 'nCells', lg.csr(1).lattice.nCells, 'capped', lg.csr(1).lattice.capped, ...
            'shared', {lat.groups});
    end
    so = {'NumLHS', opts.NumLHS, 'Seed', opts.Seed, 'NumStarts', opts.NumStarts, 'MaxEvals', opts.MaxEvals, ...
        'MaxRounds', opts.MaxRounds, 'Reserve', opts.Reserve};
    extra = {};
    if ~any(strcmp(plan.method, {'sqp', 'lattice'}))
        extra = {'GridPoints', opts.GridPoints, 'GridLocalLevels', opts.GridLocalLevels, 'GridMaxRefine', ...
            opts.GridMaxRefine, 'GridBudget', opts.GridBudget, 'DEPopulation', opts.DEPopulation, 'DEGenerations', ...
            opts.DEGenerations, 'TolX', opts.TolX, 'TolFun', opts.TolFun};
    end
    if strcmp(plan.mode, 'surrogate')
        search = @(P) vital.uq.surrogateWorst(surrogateProblem(P, E, ex, name, L0), @(th, c) pf(ex(th), c), so{:}, ...
            'Method', plan.method, 'Extra', extra);
    else
        search = @(P) vital.uq.boundWorst(P, so{:}, 'Method', plan.method, extra{:});
    end
    marginFcn = @(th, c) pf(ex(th), c);
    confirmFcn = @(th) confirm(E, ex(th), name, L0);
    flat = false;
    mc1 = [];
    for wi = 1:numel(opts.WidthScales)
        w = opts.WidthScales(wi);
        t1 = tic;
        B = vital.uq.box(spec, 'WidthScale', w);
        if isLat
            bw = lg.boxes(wi);
        else
            prob = struct('names', {B.names(ix)}, 'lo', B.lo(ix), 'hi', B.hi(ix), 'nominal', B.nominal(ix), ...
                'conditions', {{T.cond}}, 'condLabels', {{T.label}}, 'pointFcn', marginFcn, 'confirmFcn', confirmFcn);
            bw = search(prob);
        end
        bw = expandResult(bw, ix, B);
        fm = bw.points.margin(isfinite(bw.points.margin));
        flat = flat || (numel(fm) > 1 && all(fm == fm(1)) && ~strcmp(plan.mode, 'surrogate'));
        [D, pval] = vital.uq.mahalanobis(bw.theta, B1.nominal, B1.sigma, 'Dof', numel(ix));
        mah = struct('D', D, 'dof', numel(ix), 'tail', pval, ...
            'sigma', 'x1 (judgment) sigmas; tail = P(chi2_dof >= D^2) for dof = the searched parameters');
        mc = vital.uq.monteCarlo(mcProblem(B, T, L0, pf), 'N', opts.N, 'Seed', opts.Seed);
        if w == 1, mc1 = mc; end
        v = vital.uq.verdict(bw, mc, 'Reserve', opts.Reserve, 'Required', opts.Required);
        W = struct('widthScale', w, 'box', B, 'bw', bw, 'mahalanobis', mah, 'mc', rmfield(mc, 'cond'), ...
            'verdict', v, 'runtime_s', toc(t1));
        if isempty(e.widths), e.widths = W; else, e.widths(end+1) = W; end
        say(opts, '  %-22s x%-4g bound-worst %-9.4g %-15s MC %3d/%d CP %.4f  box verdict %-14s (%.0f s; %d points, %d cache hits)\n', ...
            name, w, bw.value, bw.status, mc.x, mc.N, mc.cpLower, v.verdict, toc(t1), E.nPointEvals, E.nCacheHits);
    end
    if opts.CSR
        t1 = tic;
        if isempty(mc1)                          % the headline verdict needs the x1 Monte Carlo
            mc1 = vital.uq.monteCarlo(mcProblem(vital.uq.box(spec), T, L0, pf), 'N', opts.N, 'Seed', opts.Seed);
        end
        if isLat
            cj = lg.csr(1); ce = lg.csr(2);
        else
            cp = struct('names', {B1.names(ix)}, 'nominal', B1.nominal(ix), 'm', B1.halfWidth(ix), ...
                'conditions', {{T.cond}}, 'condLabels', {{T.label}}, 'pointFcn', marginFcn, 'confirmFcn', confirmFcn);
            prior = struct('alpha', {}, 'origin', {}, 'lo', {}, 'hi', {}, 'status', {}, 'value', {}, 'theta', {});
            k1 = find([e.widths.widthScale] == 1, 1);
            if ~isempty(k1)
                b1 = e.widths(k1).bw;
                prior(1) = struct('alpha', 1, 'origin', 'prior (x1 bound-worst)', 'lo', B1.lo(ix), 'hi', B1.hi(ix), ...
                    'status', b1.status, 'value', b1.value, 'theta', b1.theta(ix));
            end
            co = {'Search', search, 'AlphaMax', opts.AlphaMax, 'Resolution', opts.Resolution, 'Reserve', opts.Reserve, ...
                'MaxSearches', opts.MaxSearches, 'MaxRounds', opts.MaxRounds};
            cj = vital.uq.csr(cp, co{:}, 'DecideAt', 1, 'Prior', prior, 'Shape', 'judged');
            pe = prior;
            for s = cj.searches(:).'
                pe(end+1) = struct('alpha', s.alpha, 'origin', 'prior (judged)', 'lo', s.lo, 'hi', s.hi, ...
                    'status', s.status, 'value', s.value, 'theta', s.theta); %#ok<AGROW>
            end
            if cj.cpvConfirmed || (isfinite(cj.cpvMargin) && cj.cpvMargin < opts.Reserve)
                pe(end+1) = struct('alpha', NaN, 'origin', 'prior (judged CPV)', 'lo', NaN(1, numel(ix)), ...
                    'hi', NaN(1, numel(ix)), 'status', 'VIOLATED', 'value', cj.cpvMargin, 'theta', cj.cpv); %#ok<AGROW>
            end
            cp.m = opts.EqualPct * ones(1, numel(ix));
            ce = vital.uq.csr(cp, co{:}, 'Prior', pe, 'Shape', 'equal');
            cj.method = plan.method; ce.method = plan.method;
        end
        e.csr = struct('judged', expandCsr(cj, ix, B1), 'equal', expandCsr(ce, ix, B1), 'names', {B1.names}, ...
            'searchNames', {B1.names(ix)}, 'equalPct', opts.EqualPct, 'runtime_s', toc(t1));
        e.verdict = vital.uq.verdict(cj, mc1, 'Reserve', opts.Reserve, 'Required', opts.Required);
        say(opts, '  %-22s CSR judged %-14s alpha* %-7.4g | equal %-14s alpha* %-7.4g | %s (%.0f s; %d points)\n', ...
            name, cj.status, cj.alphaStar, ce.status, ce.alphaStar, e.verdict.verdict, toc(t1), E.nPointEvals);
    end
    if flat && ~plan.sampledOnly
        plan.sampledOnly = true;
        plan.sampledReason = ['flat objective: every evaluated point has the same margin, so the optimizer''s ' ...
            'convergence means nothing; the bound-worst rests on the sampled points only'];
    end
    e.plan = plan;
    Gr(p.k) = e;
end
end

function q = latticePoint(E, th, c, gnames, L0s)
% one lattice point at one condition: every longitudinal group from ONE point summary
n = numel(gnames);
q = struct('status', {repmat({'OK'}, 1, n)}, 'margin', NaN(1, n), 'record', {repmat({''}, 1, n)}, ...
    'reason', {repmat({''}, 1, n)});
for j = 1:n
    g = E.groupMargin(th, c, gnames{j}, L0s(j));
    q.status{j} = g.status; q.margin(j) = g.margin; q.record{j} = g.record; q.reason{j} = g.reason;
end
end

function chk = latGate(E, pf, t1, plan, B1, opts)
% R4-9 runtime gate: the group's quantity at its critical condition is unchanged
% with the dropped parameters at the extreme values of every box searched
d = numel(B1.names);
iq = find(ismember(B1.aeroScale, plan.dropped));
hw = B1.halfWidth(iq);
lo = min([1 - max(opts.WidthScales) * hw; 1 - opts.AlphaMax * hw; (1 - opts.AlphaMax * opts.EqualPct) * ones(size(hw))], [], 1);
hi = max([1 + max(opts.WidthScales) * hw; 1 + opts.AlphaMax * hw; (1 + opts.AlphaMax * opts.EqualPct) * ones(size(hw))], [], 1);
ths = ones(2, d); ths(1, iq) = lo; ths(2, iq) = hi;
if strcmp(plan.mode, 'surrogate')
    qf = @(th) toValue(E.spiralPoint(th, t1.cond), 'value');
else
    qf = @(th) toValue(pf(th, t1.cond), 'margin');
end
chk = vital.uq.invarianceCheck(qf, ones(1, d), ths, 'RelTol', 1e-9);
chk.cond = t1.label;
chk.dropped = plan.dropped;
end

function v = toValue(q, f)
v = struct('status', q.status, 'value', q.(f));
end

function s = stage1Summary(e)
% the stage-1 result of a group that stage 2 re-ran (kept in the report)
s = struct('status', e.status, 'method', '', 'candidates', e.candidates, 'csrJudged', struct([]), ...
    'csrEqual', struct([]), 'x1', struct([]), 'verdict', e.verdict.verdict, 'verdictReason', e.verdict.reason);
if isfield(e.plan, 'method'), s.method = e.plan.method; end
lite = @(c) struct('status', c.status, 'alphaStar', c.alphaStar, 'alphaLo', c.alphaLo, 'alphaHi', c.alphaHi, ...
    'reason', c.reason);
if ~isempty(e.csr)
    s.csrJudged = lite(e.csr.judged);
    s.csrEqual = lite(e.csr.equal);
end
if ~isempty(e.widths)
    k = find([e.widths.widthScale] == 1, 1);
    if ~isempty(k)
        b = e.widths(k).bw;
        s.x1 = struct('status', b.status, 'value', b.value, 'reason', b.reason, 'nEvaluated', b.nEvaluated);
    end
end
end

function b = budgetOf(o)
b = struct('NumCandidates', o.NumCandidates, 'DEPopulation', o.DEPopulation, 'DEGenerations', o.DEGenerations, ...
    'N', o.N, 'NumLHS', o.NumLHS, 'NumStarts', o.NumStarts, 'MaxEvals', o.MaxEvals, 'MaxRounds', o.MaxRounds);
end

function mp = mcProblem(B, T, L0, pf)
% the Monte Carlo problem of a group at the box B: all parameters, sigma = w sigma,
% at the nominal critical condition T(1)
mp = struct('names', {B.names}, 'nominal', B.nominal, 'sigma', B.sigmaEff, 'lo', B.lo, 'hi', B.hi, ...
    'cond', T(1).cond, 'condLabel', T(1).label, 'level0', L0, 'pointFcn', pf);
end

function P = surrogateProblem(P, E, ex, group, L0)
% the surrogate search of a +Inf spiral group: point and confirmation functions
% of the spiral surrogate on the same box and candidates
P.pointFcn = @(th, c) E.spiralPoint(ex(th), c);
P.confirmFcn = @(th) confirmSurrogate(E, ex(th), group, L0);
end

function c = expandCsr(c, ix, B)
% a CSR over the searched parameters ix, reported over ALL parameters
d = numel(B.names);
full = @(t, fill) expandTheta(t, ix, fill * ones(1, d));
c.searchNames = B.names(ix);
c.searchIndex = ix;
c.names = B.names;
c.cpv = full(c.cpv, 1);
c.psm = full(c.psm, 0);
c.psmHi = full(c.psmHi, 0);
c.m = full(c.m, 0);
c.nominal = ones(1, d);
for k = 1:numel(c.searches)
    c.searches(k).lo = full(c.searches(k).lo, 1);
    c.searches(k).hi = full(c.searches(k).hi, 1);
    c.searches(k).theta = full(c.searches(k).theta, 1);
end
for k = 1:numel(c.rays)
    c.rays(k).theta = full(c.rays(k).theta, 1);
end
if isfield(c.options, 'Prior'), c.options = rmfield(c.options, 'Prior'); end
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
if numel(ix) == numel(B.names)
    bw.names = B.names;
    return
end
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

function sc = spotCheck(pf, t1, latLo, ix, d)
% runtime lon/lat spot check at the critical condition: the margin with the
% lateral multipliers at the most extreme lower value of any box searched
% equals the nominal one
lat = setdiff(1:d, ix);
th = ones(1, d); th(lat) = latLo(lat);
q0 = pf(ones(1, d), t1.cond);
q1 = pf(th, t1.cond);
sc = struct('performed', true, 'passed', false, 'cond', t1.label, 'theta', th, 'margin', q0.margin, ...
    'marginLateral', q1.margin, 'reason', '');
if ~strcmp(q0.status, 'OK') || ~strcmp(q1.status, 'OK')
    sc.reason = sprintf('a spot-check point is not OK (%s / %s)', q0.status, q1.status);
elseif isequal(q0.margin, q1.margin) || abs(q1.margin - q0.margin) <= 1e-9 * abs(q0.margin)
    sc.passed = true;
    sc.reason = sprintf(['margin %.10g with the lateral multipliers at 1 and %.10g at their most extreme lower ' ...
        'values %s (%s): equal within 1e-9 relative'], q0.margin, q1.margin, mat2str(th(lat), 4), t1.label);
else
    sc.reason = sprintf('margin %.10g vs %.10g with the lateral multipliers at %s (%s)', ...
        q0.margin, q1.margin, mat2str(th(lat), 4), t1.label);
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
