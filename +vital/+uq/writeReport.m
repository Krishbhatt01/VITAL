function files = writeReport(r, folder, name)
%WRITEREPORT  Write a vital.uq.analyze result as JSON and Markdown.
%   files = vital.uq.writeReport(r, folder, name)
%   JSON: the result (Inf/-Inf as the strings "Inf"/"-Inf", NaN null; function
%   handles as text). Markdown: the JUDGMENT label of the widths, the spec
%   table with the box half-widths, the HEADLINE table per group (nominal Level,
%   bound-worst margin and status, Monte Carlo successes/N and Clopper-Pearson
%   lower bound, verdict at every width), then per group and width the active
%   set, the confirmation (and any moving limit), the optimizer exit flags and
%   the Monte Carlo failures.
%   After review R3 (amendment 2026-10-09) the Markdown also states: the joint
%   probability content of the box (m2), the MRC meaning of every multiplier
%   and the Cm_table coupling (M5), that the bound-worst is a search estimate
%   (upper bound), not a proof, with 'sampled only' groups (M2), the box
%   nesting (m9), the omitted groups (m6), and per group the search plan
%   (longitudinal-only / surrogate / full), every moving-limit round (M4) and
%   the Mahalanobis distance of each arg-min (M5).
%   After amendment R4 (2026-10-13) the Markdown leads with the R4 headline
%   (vital.uq.headline: the Critical Similitude Ratio of the judged and the
%   equal-percentage shapes, the parametric safety margins, the CPV and the R4
%   verdict), states the search method and budgets of every group (grid-
%   certified (Lipschitz estimate) / hybrid search estimate / sqp), the split
%   of the pitching-moment table (Cm_basic, Cm_de), and per group and shape
%   every CSR box search, ray refinement and the CPV confirmation.
%   files: struct(json, md) with the full paths.
arguments
    r (1,1) struct
    folder (1,:) char
    name (1,:) char
end
if ~isfolder(folder), mkdir(folder); end
files.json = fullfile(folder, [name '.json']);
files.md = fullfile(folder, [name '.md']);
out = r;
out.files = files;
fid = fopen(files.json, 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(sanitize(out), 'PrettyPrint', true));
fclose(fid);
L = mdLines(r);
fid = fopen(files.md, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', L{:});
fclose(fid);
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

function t = candText(c, k, hasSur)
if hasSur
    t = sprintf('%s (margin %.4g, spiral Re %.4g 1/s)', c.labels{k}, c.margins(k), c.surrogate(k));
else
    t = sprintf('%s (%.4g)', c.labels{k}, c.margins(k));
end
end

function t = passTxt(ok)
if ok, t = 'passed'; else, t = 'FAILED'; end
end

function t = movedTxt(cf)
if ~cf.evaluated, t = 'no confirmation';
elseif cf.moved, t = 'MOVED: re-searched with this condition, or MOVING_LIMIT in the last round';
else, t = 'did not move'; end
end

function n = maxRounds(r)
n = 3;
if isfield(r, 'options') && isfield(r.options, 'MaxRounds'), n = r.options.MaxRounds; end
end

function L = mdLines(r)
L = {'# M8 uncertainty: does the augmented F-16''s in-envelope MIL-F-8785C Level hold?', ''};
L{end+1} = sprintf(['**The 1-sigma widths are %s (engineering judgment, docs/PLAN_M5_M8.md M8), not published ' ...
    'values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.'], r.label);
L{end+1} = '';
g = r.gains;
if isfield(g, 'Kq')
    L{end+1} = sprintf('Aircraft: bare NESC F-16 + pitch SAS Kq = %g s, Ka = %g + yaw damper Kr = %g s (%s).', ...
        g.Kq, g.Ka, g.Kr, g.source);
else
    L{end+1} = sprintf('Aircraft: %s.', g.law);
end
L{end+1} = sprintf('Conditions `%s` grid `%s`: %s.', r.conditions.id, r.conditions.grid, ...
    strjoin(arrayfun(@(a) sprintf('%s %s', a.name, mat2str(a.values(:).', 6)), r.conditions.axes, 'UniformOutput', false), ', '));
o = r.options;
L{end+1} = sprintf(['Search budget (stated): centre + 2^d corners + %d LHS points (seed %d); method %s per group ' ...
    '(grid for <= %s searched parameters: %s points per dimension, %s local refinement levels, at most %s ' ...
    'Lipschitz refinement levels and %s lattice points, safety factor 2; hybrid above: differential evolution %s ' ...
    'members x %s generations, then Nelder-Mead from %d best points x %d evaluations, TolX %s, TolFun %s; sqp: ' ...
    'fmincon from %d best points x %d evaluations); %d candidate conditions; at most %d moving-limit rounds; ' ...
    'Monte Carlo N = %d (seed %d); reserve %g; required CP lower bound %.2f. Runtime %.0f s; %d single-point ' ...
    'assessments, %d cache hits, %d full assessments.'], o.NumLHS, o.Seed, opt(o, 'Method', 'sqp'), ...
    optn(o, 'GridMaxDim'), optn(o, 'GridPoints'), optn(o, 'GridLocalLevels'), optn(o, 'GridMaxRefine'), ...
    optn(o, 'GridBudget'), optn(o, 'DEPopulation'), optn(o, 'DEGenerations'), o.NumStarts, o.MaxEvals, ...
    optn(o, 'TolX'), optn(o, 'TolFun'), o.NumStarts, o.MaxEvals, o.NumCandidates, maxRounds(r), o.N, o.Seed, ...
    o.Reserve, o.Required, r.runtime_s, r.counts.pointEvals, r.counts.cacheHits, r.counts.assess);
if opt(o, 'CSR', false)
    L{end+1} = sprintf(['CSR (amendment R4-1): AlphaMax %g, resolution %g, reference shapes judged (k_g sigma) and ' ...
        'equal percentage (%g %%), at most %d box searches per shape; every box search uses the group''s method ' ...
        'and budget above.'], o.AlphaMax, o.Resolution, 100 * o.EqualPct, o.MaxSearches);
end
L{end+1} = '';
L{end+1} = sprintf('## Uncertain parameters (%s; spec `%s`)', r.spec.label, r.spec.id);
L{end+1} = '';
W = r.widthScales;
h = '| parameter | AeroScale field | NASA term | group | sigma | d | k_g |';
s = '|---|---|---|---|---|---|---|';
for w = W, h = [h sprintf(' half-width x%g |', w)]; s = [s '---|']; end %#ok<AGROW>
L(end+1:end+2) = {h, s};
P = r.spec.parameters;
for i = 1:numel(P)
    row = sprintf('| %s | %s | %s | %s | %g | %d | %.4f |', P(i).name, P(i).aeroScale, P(i).term, P(i).group, ...
        P(i).sigma, r.spec.groups(strcmp({r.spec.groups.name}, P(i).group)).d, P(i).kg);
    for w = W, row = [row sprintf(' %.4f |', w * P(i).kg * P(i).sigma)]; end %#ok<AGROW>
    L{end+1} = row; %#ok<AGROW>
end
L{end+1} = '';
if isfield(r, 'coverage')
    cg = strjoin(arrayfun(@(g) sprintf('%s %.4f (d = %d)', g.name, g.coverage, g.d), r.coverage.groups, ...
        'UniformOutput', false), ', ');
    L{end+1} = sprintf(['**Joint coverage of the box: %.4f** under the analysis'' own model (independent normal ' ...
        'multipliers): the product of the group boxes (%s). It is the same at every width, because the box and the ' ...
        'Monte Carlo sigma scale together; per-group 99 %% ellipsoids do not make a 99 %% joint box.'], ...
        r.coverage.joint, cg);
    L{end+1} = '';
end
L{end+1} = ['**What a multiplier means.** Every multiplier scales ONE term of NASA''s aerodynamic tables about the ' ...
    'moment reference centre, i.e. about the MRC (35 % MAC), not a stability derivative about the CG (ADR R2-5). ' ...
    'Cm_table scales the whole pitching-moment table cmt(el, alpha): Cm0, M_alpha (about the MRC) and the elevator ' ...
    'power M_de together, so it also moves the trim and scales the authority of the pitch SAS (its Ka and Kq act ' ...
    'through M_de). Because the MRC and CG parts of M_alpha can have opposite signs, the effect about the CG is not ' ...
    'a plain scaling (effective CG-derivative ratios: tests/M8/tUqR3F16.m#effectiveDerivativeRatios). ' ...
    'Amendment R4-5 splits it (aero-database build-up): Cm_basic scales cmt(el = 0, alpha), the static part ' ...
    '(Cm0 and the static slope about the MRC), and Cm_de scales cmt(el, alpha) - cmt(el = 0, alpha), the ' ...
    'elevator increment (elevator power and the SAS''s authority); both are in the R4 specification instead of ' ...
    'Cm_table (effective CG-derivative ratios: tests/M8/tUqR4F16.m#effectiveDerivativeRatiosR4). Cn_r (named ' ...
    'Cnr_table until R4-6) scales the yaw-damping table cnr(alpha).'];
L{end+1} = '';
L{end+1} = ['**Search.** Longitudinal groups (3.2.x) are searched over the longitudinal parameters only (Cm_q and ' ...
    'Cm_table, or Cm_basic and Cm_de in the R4 specification), the lateral multipliers held at 1: at a ' ...
    'wings-level, beta = 0 trim they change no longitudinal ' ...
    'metric (tests/M8/tUqR3F16.m#lonLatInvariance, 1e-9 relative). Lateral groups (3.3.x) search every ' ...
    'multiplier except Cm_q (R4-9: Cm_q acts only through the pitch rate, zero at the wings-level trim; gated per ' ...
    'group), the pitching-moment multipliers included, because they move the trim. A group whose nominal margin ' ...
    'is +Inf (3.3.1.3 spiral) is searched on the surrogate ' ...
    'Re(spiral root), maximized, with its candidate conditions ranked by it; if the largest value found is <= 0 the ' ...
    'spiral is stable over the box (bound-worst +Inf). When the confirmation (a fresh in-envelope assessment at the ' ...
    'arg-min) finds a smaller margin at a non-candidate condition (a moving limit), that condition is added and the ' ...
    'search re-run, at most ' sprintf('%d', maxRounds(r)) ' rounds; the status can be OK only if the final ' ...
    'confirmation did not move (otherwise NOT_ASSESSABLE, MOVING_LIMIT). The Mahalanobis distance D of each arg-min ' ...
    'is in the x1 (judgment) sigmas, with the chi-square tail for the number of searched parameters. Amendments ' ...
    'R4/R4b/R5: the longitudinal groups (at most 3 searched parameters) are decided on ONE shared adaptive ' ...
    'lattice ("grid-certified (Lipschitz estimate)", h/2 certificate, piecewise at the aero-table breakpoints); ' ...
    'any other box of at most 2 searched parameters on a grid (dense grid, local refinement, Lipschitz bound ' ...
    'from the measured slopes x 2); a box of more parameters by a hybrid search (seeded differential evolution, ' ...
    'then Nelder-Mead with a bound transform: a "search estimate"), with the convergence of every stage reported.'];
L{end+1} = '';
L{end+1} = '**Judgments and preconditions (amendment R5, review R5 m10).**';
J = vital.uq.statements('judgments');
if isfield(r.spec, 'judgments'), J = r.spec.judgments; end
for s = J(:).'
    L{end+1} = ['- ' s{1}]; %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '## Headline';
L{end+1} = '';
L = [L, vital.uq.headline(r)];
L{end+1} = '';
L{end+1} = ['Box verdict (per width, the original M8 definition): ROBUST = bound-worst status OK with margin >= reserve AND Clopper-Pearson one-sided 95 % lower ' ...
    'bound >= required; NOT_ROBUST = a counterexample in the box OR the lower bound below required; ' ...
    'NOT_ASSESSABLE = anything else (e.g. the optimizer did not converge, FC-901, or a point in the box is not OK).'];
L{end+1} = '';
L{end+1} = '## Details per group';
for g = r.groups(:).'
    L{end+1} = ''; %#ok<AGROW>
    L{end+1} = sprintf('### %s', g.group); %#ok<AGROW>
    if ~strcmp(g.status, 'DONE')
        L{end+1} = sprintf('%s: %s', g.status, g.reason); %#ok<AGROW>
        continue
    end
    L{end+1} = sprintf('Nominal Level %d, margin %.6g, critical %s at %s.', g.level0, g.margin0, g.critical.record, ...
        g.critical.condLabel); %#ok<AGROW>
    hasSur = isfield(g.candidates, 'surrogate') && any(isfinite(g.candidates.surrogate));
    L{end+1} = sprintf('Candidates: %s.', strjoin(arrayfun(@(k) candText(g.candidates, k, hasSur), ...
        1:numel(g.candidates.labels), 'UniformOutput', false), '; ')); %#ok<AGROW>
    if isfield(g, 'plan') && isfield(g.plan, 'mode')
        p = g.plan;
        L{end+1} = sprintf('Search (%s; %s): %s.', p.mode, p.objective, p.reason); %#ok<AGROW>
        if isfield(p, 'spotCheck') && p.spotCheck.performed
            L{end+1} = sprintf('Lon/lat spot check: %s (%s).', passTxt(p.spotCheck.passed), p.spotCheck.reason); %#ok<AGROW>
        end
        if p.sampledOnly
            L{end+1} = sprintf('**Sampled only:** %s.', p.sampledReason); %#ok<AGROW>
        end
        if isfield(p, 'method')
            L{end+1} = sprintf('Search method: %s.', p.method); %#ok<AGROW>
        end
        if isfield(p, 'latCheck') && isfield(p.latCheck, 'cond')
            L{end+1} = sprintf('R4-9 gate (Cm_q held at 1) at %s: %s (%s).', p.latCheck.cond, ...
                passTxt(p.latCheck.passed), p.latCheck.reason); %#ok<AGROW>
        end
        if isfield(p, 'lattice')
            la = p.lattice;
            L{end+1} = sprintf(['Shared lattice (R4b): %d lattice points and %d cells of this group (capped %d), ' ...
                '%d round(s), conditions %s; certificate over all cells: %s.'], la.nPoints, la.nCells, la.capped, ...
                la.rounds, strjoin(la.conditions, '; '), la.certificate.reason); %#ok<AGROW>
            if isfield(la, 'discontinuity')
                L{end+1} = sprintf('Discontinuity (R5-3): %s.', la.discontinuity.text); %#ok<AGROW>
                L{end+1} = sprintf('Scope (R5-5 M2): %s.', la.scope); %#ok<AGROW>
                for x = la.confirmations(:).'
                    L{end+1} = sprintf('  - confirmation %s: %s %.6g at %s (lattice %.6g; %s)', x.what, x.status, ...
                        x.margin, x.cond, x.latticeMargin, ifMoved(x.moved)); %#ok<AGROW>
                end
            end
        end
    end
    if isfield(g, 'stage') && isstruct(g.stage) && isfield(g.stage, 'decidedBy')
        L{end+1} = sprintf('Decided by stage %d (R4-8): %s.', g.stage.decidedBy, g.stage.reason); %#ok<AGROW>
        s1 = g.stage.stage1;
        if isstruct(s1) && ~isempty(s1)
            t = sprintf('stage-1 result (re-run at the full budget): verdict %s; %d candidate condition(s)', s1.verdict, ...
                numel(s1.candidates.labels));
            if ~isempty(s1.csrJudged)
                t = sprintf('%s; CSR judged %s in [%.4g, %s]', t, s1.csrJudged.status, s1.csrJudged.alphaLo, ...
                    num2str(s1.csrJudged.alphaHi, 4));
            end
            if ~isempty(s1.x1)
                t = sprintf('%s; x1 bound-worst %.6g (%s)', t, s1.x1.value, s1.x1.status);
            end
            L{end+1} = [t '.']; %#ok<AGROW>
        end
    end
    L{end+1} = ''; %#ok<AGROW>
    L{end+1} = '| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |'; %#ok<AGROW>
    L{end+1} = '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|'; %#ok<AGROW>
    for x = g.widths(:).'
        b = x.bw;
        cf = b.confirmation;
        if cf.moved, ct = sprintf('MOVING LIMIT: %.4g at %s (search %.4g)', cf.margin, cf.cond, b.searchValue);
        elseif cf.evaluated, ct = sprintf('%s %.4g', cf.status, cf.margin);
        else, ct = 'none'; end
        ex = strjoin(arrayfun(@(o) sprintf('%g', o.exitflag), b.optimizer, 'UniformOutput', false), ', ');
        nr = 1; if isfield(b, 'nRounds'), nr = b.nRounds; end
        mt = '-';
        if isfield(x, 'mahalanobis'), mt = sprintf('%.3g (%.2g, dof %d)', x.mahalanobis.D, x.mahalanobis.tail, x.mahalanobis.dof); end
        lab = 'search estimate (sqp)'; if isfield(b, 'label'), lab = b.label; end
        L{end+1} = sprintf('| x%g | %.6g | %s | %s | %s | %s | %s | %s | %d | %s | %s | %d | %d/%d | %d | %d | %.4f | %s |', ...
            x.widthScale, b.value, b.status, lab, mat2str(b.theta, 4), b.cond, b.record, ct, nr, mt, ex, b.nEvaluated, ...
            x.mc.x, x.mc.N, x.mc.nNotOK, x.mc.nWorseLevel, x.mc.cpLower, x.verdict.verdict); %#ok<AGROW>
    end
    L{end+1} = ''; %#ok<AGROW>
    for x = g.widths(:).'
        L{end+1} = sprintf('- x%g: %s. Verdict reason: %s.', x.widthScale, x.bw.reason, x.verdict.reason); %#ok<AGROW>
        if isfield(x.bw, 'surrogate')
            su = x.bw.surrogate;
            L{end+1} = sprintf('  - surrogate: largest %s found %.6g (surrogate search %s).', su.quantity, su.value, ...
                su.status); %#ok<AGROW>
        end
        if isfield(x.bw, 'rounds')
            sv = 'search value';
            if isfield(x.bw, 'surrogate'), sv = sprintf('surrogate search value (-%s)', x.bw.surrogate.quantity); end
            for q = x.bw.rounds(:).'
                L{end+1} = sprintf(['  - round %d: %d candidate condition(s) (%s); ' sv ' %.6g at %s, theta %s; ' ...
                    'confirmation %s %.6g at %s (%s)'], q.round, numel(q.candidates), strjoin(q.candidates, '; '), ...
                    q.searchValue, q.cond, mat2str(q.theta, 4), q.confirmation.status, q.confirmation.margin, ...
                    q.confirmation.cond, movedTxt(q.confirmation)); %#ok<AGROW>
            end
        end
        if isfield(x.bw, 'stages')
            st = x.bw.stages;
            L{end+1} = sprintf('  - stages: %s', strjoin(arrayfun(@(q) sprintf('%s %d points (converged %s)', q.name, ...
                q.nEval, convTxt(q.converged)), st, 'UniformOutput', false), '; ')); %#ok<AGROW>
        end
        if isfield(x.bw, 'certificate') && isfield(x.bw, 'method') && any(strcmp(x.bw.method, {'grid', 'lattice'}))
            ce = x.bw.certificate;
            L{end+1} = sprintf(['  - grid certificate (Lipschitz estimate): certified %d, lower bound %.6g, L %s ' ...
                '(= 2 x measured slopes %s), %s'], ce.certified, ce.lowerBound, mat2str(ce.L, 4), ...
                mat2str(ce.maxSlope, 4), ce.reason); %#ok<AGROW>
        end
        F = x.mc.failures;
        for k = 1:min(5, numel(F))
            L{end+1} = sprintf('  - MC sample %d not OK: %s (%s)', F(k).index, F(k).status, F(k).reason); %#ok<AGROW>
        end
        if numel(F) > 5, L{end+1} = sprintf('  - ... %d more not-OK samples (JSON)', numel(F) - 5); end %#ok<AGROW>
    end
    if isfield(g, 'csr') && ~isempty(g.csr)
        L{end+1} = ''; %#ok<AGROW>
        L{end+1} = sprintf('Critical Similitude Ratio over %s; R4 verdict **%s**: %s.', strjoin(g.csr.searchNames, ', '), ...
            g.verdict.verdict, g.verdict.reason); %#ok<AGROW>
        for sh = {'judged', 'equal'}
            c = g.csr.(sh{1});
            L{end+1} = sprintf(['- %s shape (m = %s): status %s, alpha* %.4g, bracket [%.4g, %.4g]; parametric safety ' ...
                'margin %s; CPV %s at %s (margin %.6g, %s), confirmation %s %.6g at %s; %s'], sh{1}, ...
                mat2str(c.m(c.searchIndex), 4), c.status, c.alphaStar, c.alphaLo, c.alphaHi, mat2str(c.psm, 4), ...
                mat2str(c.cpv, 5), c.cpvCond, c.cpvMargin, c.cpvRecord, c.confirmation.status, c.confirmation.margin, ...
                c.confirmation.cond, c.reason); %#ok<AGROW>
            [lo, ok, why] = vital.uq.lowerEnd(c);
            L{end+1} = sprintf('  - lower end (R5-2): R(%.4g) certified %d: %s', lo, ok, why); %#ok<AGROW>
            for q = c.searches(:).'
                L{end+1} = sprintf('  - box search alpha %.4g (%s): %s, value %.6g at %s, %d points (%s)', q.alpha, ...
                    q.origin, q.status, q.value, q.cond, q.nEvaluated, q.label); %#ok<AGROW>
            end
            for q = c.rays(:).'
                L{end+1} = sprintf('  - ray (%s): failing at scaled norm %.4g (t in [%.4f, %.4f]), margin %.6g at %s', ...
                    q.from, q.alpha, q.tPass, q.tFail, q.margin, q.cond); %#ok<AGROW>
            end
        end
    end
end
if isfield(r, 'bracketed') && ~isempty(r.bracketed)
    L{end+1} = '';
    L{end+1} = '## BRACKETED points (R4-7: linearization at a table breakpoint; margin = the worse of the two sides)';
    L{end+1} = '';
    gn = {r.groups(strcmp({r.groups.status}, 'DONE')).group};
    L{end+1} = '| condition | theta | breakpoint | d | side alphas (deg) | margins of the analysed groups at their nominal Level (side 1 / side 2) |';
    L{end+1} = '|---|---|---|---|---|---|';
    for b = r.bracketed(:).'
        mt = {};
        for k = 1:numel(gn)
            g = r.groups(strcmp({r.groups.group}, gn{k}));
            L0 = g.level0;
            m = arrayfun(@(sd) sideMargin(sd, gn{k}, L0), b.sides);
            mt{end+1} = sprintf('%s %.6g / %.6g', gn{k}, m(1), m(2)); %#ok<AGROW>
        end
        L{end+1} = sprintf('| %s | %s | %s = %g | %g | %.6f / %.6f | %s |', b.cond, mat2str(b.theta, 6), b.variable, ...
            b.breakpoint, b.d, b.sides(1).alpha_deg, b.sides(2).alpha_deg, strjoin(mt, '; ')); %#ok<AGROW>
    end
end
L{end+1} = '';
L{end+1} = '## Nominal augmented aircraft (in-envelope headline, vital.fq.assess at theta = 1)';
L{end+1} = '';
L{end+1} = '| group | Level | critical margin | critical condition | status |';
L{end+1} = '|---|---|---|---|---|';
for n = r.nominal(:).'
    L{end+1} = sprintf('| %s | %s | %.4g | %s | %s |', n.group, n.levelText, n.criticalMargin, n.critical, n.status); %#ok<AGROW>
end
end

function m = sideMargin(sd, group, L0)
m = NaN;
g = sd.groups(strcmp({sd.groups.group}, group));
if ~isempty(g) && strcmp(g.pointClass, 'OK') && isfinite(L0) && L0 >= 1 && L0 <= 3, m = g.marginTo(L0); end
end

function t = ifMoved(m)
if m, t = 'MOVED: a moving limit'; else, t = 'did not move'; end
end

function t = convTxt(c)
if isempty(c) || (isnumeric(c) && isnan(c)), t = '-'; elseif c, t = 'yes'; else, t = 'no'; end
end

function v = opt(o, f, d)
if isfield(o, f), v = o.(f); else, v = d; end
end

function t = optn(o, f)
if isfield(o, f), t = sprintf('%g', o.(f)); else, t = '-'; end
end
