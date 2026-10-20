function L = headline(r)
%HEADLINE  The M8 headline tables of a vital.uq.analyze result (Markdown lines).
%   L = vital.uq.headline(r)     cellstr
%   R4 TABLE (amendment R4, when the analysis computed the CSR): one row per
%   group: nominal in-envelope Level and margin; the Critical Similitude Ratio
%   alpha* of the judged shape (k_g sigma, x1) with its status, the parametric
%   safety margin alpha* m of every searched multiplier and the CPV's
%   condition; alpha* x 10 % of the equal-percentage shape (the tolerated
%   uniform tolerance); the x1 bound-worst (status and search label); the
%   Monte Carlo successes/N with the one-sided 95 % Clopper-Pearson lower
%   bound; and the R4 verdict.
%   BOX TABLE: per width (x1 by default; x0.5, x1.5 on request; JUDGMENT
%   multiples) the bound-worst margin and status (tagged 'sampled only' for a
%   binary or flat metric, 'surrogate' for a +Inf group searched on
%   Re(spiral root), 'grid-certified' for a grid search), the Monte Carlo and
%   the box verdict (the original M8 definition).
%   Below the tables: what alpha* and the bound-worst are (search estimates;
%   grid-certified for grid searches), the box nesting, and the groups
%   omitted for a NaN headline (review R3 M2, m6, m9). Used by
%   vital.uq.writeReport and run_f16_uq.
arguments
    r (1,1) struct
end
W = r.widthScales;
hasCsr = isfield(r.groups, 'csr') && any(arrayfun(@(g) ~isempty(g.csr), r.groups));
L = {sprintf('Widths are %s multiples of the 1-sigma judgment widths (x1 = the judged box).', r.label), ''};
if hasCsr
    L(end+1:end+2) = {['| group | nominal Level | nominal margin | CSR alpha* judged (k_g sigma) | parametric safety ' ...
        'margin (judged, multiplier) | CPV condition | alpha* x 10 % (equal percentage) | x1 bound-worst (status) | ' ...
        'x1 MC (CP lower) | verdict (R5: from R(1)) | decided by |'], '|---|---|---|---|---|---|---|---|---|---|---|'};
    for g = r.groups(:).'
        row = sprintf('| %s | %s | %s |', g.group, lvl(g.level0), num(g.margin0));
        if ~strcmp(g.status, 'DONE') || isempty(g.csr)
            why = g.reason; if isempty(why), why = 'CSR not computed'; end
            L{end+1} = [row sprintf(' %s: %s | | | | | | **%s** | %s |', g.status, why, g.verdict.verdict, ...
                stageText(g))]; %#ok<AGROW>
            continue
        end
        cj = g.csr.judged; ce = g.csr.equal;
        x = g.widths([g.widths.widthScale] == 1);
        if isempty(x)
            bwt = '-'; mct = sprintf('CP %.4f', g.verdict.cpLower);
        else
            bwt = sprintf('%s (%s%s)', num(x.bw.value), x.bw.status, tags(g));
            mct = sprintf('%d/%d (%.4f)', x.mc.x, x.mc.N, x.mc.cpLower);
        end
        L{end+1} = [row sprintf(' %s | %s | %s | %s | %s | %s | **%s** | %s |', alphaText(cj), psmText(cj), ...
            cpvText(cj), eqText(ce, g.csr.equalPct), bwt, mct, g.verdict.verdict, stageText(g))]; %#ok<AGROW>
    end
    L{end+1} = '';
    L{end+1} = ['**Critical Similitude Ratio (CSR; Crespo, Kenny and Giesy, NASA LaRC).** alpha* is the largest ' ...
        'scaling of the reference box [1 - alpha m, 1 + alpha m] about the nominal, alpha in [0, 3], whose ' ...
        'margin to the nominal Level stays >= 0 at the group''s candidate conditions; it is reported as a bracket ' ...
        '[alphaLo, alphaHi]: R(alphaLo) is certified (lattice groups: every lattice cell meeting it certified; ' ...
        'other groups: the box searched clean) and the CPV (critical parameter value: a failing point, confirmed by ' ...
        'a fresh in-envelope assessment) lies at scaled distance alphaHi. The judged shape is resolved to 0.01 ' ...
        'when the budget allows; the equal shape is reported at the resolution its budget allows. The parametric ' ...
        'safety margin is alpha* m in multiplier units. Two reference shapes: judged (m = k_g sigma, the x1 ' ...
        'half-widths: alpha* >= 1 means the judged box holds) and equal percentage (m = 10 % for every searched ' ...
        'multiplier: alpha* x 10 % is the uniform tolerance the Level tolerates, independent of the judged ratios ' ...
        'between the parameters). ROBUST_TO_CAP: no failure up to alpha = 3.'];
    L{end+1} = '';
    S = vital.uq.statements('limits');
    L{end+1} = S{end};                       % the R5 verdict
    L{end+1} = '';
end
L = [L, r4bLines(r)];
h = '| group | nominal Level | nominal margin |';
s = '|---|---|---|';
for w = W
    h = [h sprintf(' x%g bound-worst (status) | x%g MC (CP lower) | x%g box verdict |', w, w, w)]; %#ok<AGROW>
    s = [s '---|---|---|']; %#ok<AGROW>
end
L(end+1:end+2) = {h, s};
for g = r.groups(:).'
    row = sprintf('| %s | %s | %s |', g.group, lvl(g.level0), num(g.margin0));
    if ~strcmp(g.status, 'DONE')
        row = [row sprintf(' %s: %s |', g.status, g.reason)]; %#ok<AGROW>
        L{end+1} = row; %#ok<AGROW>
        continue
    end
    for w = W
        x = g.widths([g.widths.widthScale] == w);
        row = [row sprintf(' %s (%s%s) | %d/%d (%.4f) | **%s** |', num(x.bw.value), x.bw.status, tags(g), x.mc.x, ...
            x.mc.N, x.mc.cpLower, x.verdict.verdict)]; %#ok<AGROW>
    end
    L{end+1} = row; %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = ['**The bound-worst margin is a search estimate (upper bound), not a proof:** it is the smallest margin ' ...
    'the search found (centre, 2^d corners, Latin hypercube, then fmincon (sqp), or differential evolution + ' ...
    'Nelder-Mead (hybrid), from the best points, re-searched at a moving limit); the true minimum over the box can ' ...
    'only be lower. A grid search (at most 2 searched parameters) is grid-certified (Lipschitz estimate): its ' ...
    'status OK rests on a lower bound between the grid points from the measured slopes x 2, an estimate, not a ' ...
    'proof. "sampled only" marks a binary or flat metric (e.g. 3.3.1.4), where the optimizer''s convergence ' ...
    'means nothing and the value rests on the sampled points. alpha* inherits the nature of its box searches.'];
L{end+1} = '';
L{end+1} = ['The boxes are nested (x0.5 inside x1 inside x1.5, and R(a) inside R(b) for a < b): robustness of a box ' ...
    'implies robustness of every box it contains. NOT_ASSESSABLE means "not established" (the search could not ' ...
    'support a verdict), not "fails".'];
L{end+1} = '';
L{end+1} = '**Judgments, preconditions and limits (amendment R5).**';
for s = [vital.uq.statements('judgments'), vital.uq.statements('limits')]
    L{end+1} = ['- ' s{1}]; %#ok<AGROW>
end
if isfield(r, 'omitted')
    L{end+1} = '';
    if isempty(r.omitted)
        L{end+1} = 'Groups omitted (no finite in-envelope headline Level of the nominal aircraft): none.';
    else
        L{end+1} = 'Groups omitted (no finite in-envelope headline Level of the nominal aircraft; nothing to hold):';
        for o = r.omitted(:).'
            L{end+1} = sprintf('- %s: %s', o.group, o.reason); %#ok<AGROW>
        end
    end
end
end

function t = tags(g)
t = '';
if isfield(g, 'plan') && isfield(g.plan, 'mode')
    if strcmp(g.plan.mode, 'surrogate'), t = [t ', surrogate']; end
    if isfield(g.plan, 'method') && strcmp(g.plan.method, 'grid'), t = [t ', grid-certified']; end
    if isfield(g.plan, 'method') && strcmp(g.plan.method, 'lattice'), t = [t ', grid-certified, shared lattice']; end
    if g.plan.sampledOnly, t = [t ', sampled only']; end
end
end

function t = stageText(g)
% the stage that decided the group (amendment R4b, R4-8)
t = 'stage 1';
if isfield(g, 'stage') && isstruct(g.stage) && isfield(g.stage, 'decidedBy') && g.stage.decidedBy == 2
    t = 'stage 2';
elseif isfield(g, 'plan') && isfield(g.plan, 'method') && strcmp(g.plan.method, 'lattice')
    t = 'stage 1 (lattice)';
end
end

function L = r4bLines(r)
% amendment R4b: what the lattice, the bracketing, the staging and R4-9 mean
L = {};
if isfield(r, 'lattice') && isstruct(r.lattice) && isfield(r.lattice, 'used') && r.lattice.used
    la = r.lattice;
    L{end+1} = sprintf(['**Shared lattice (amendment R4b, R4-3 corrected).** The longitudinal groups (%s) are ' ...
        'decided on ONE adaptive lattice over the AlphaMax box of the judged shape, evaluated once per candidate ' ...
        'condition (%s) and reused by every group, both shapes and every alpha: %d lattice points, %d single-point ' ...
        'evaluations, %d confirmations; refined only near the zero level set (caps: %d levels per axis, %d points ' ...
        'per group, %s points over all groups; capped: %s). A cell is certified when its minimum vertex margin minus ' ...
        'sum L_i h_i/2 (L = 2 x the measured local slopes; amendment R5-1) is >= 0: grid-certified (Lipschitz ' ...
        'estimate), not a proof. The lattice decides R(1) of the judged shape first, then reads alpha*(judged) to ' ...
        '0.01 and the equal shape at what the budget leaves; the CPV is confirmed by a fresh in-envelope ' ...
        'assessment; an undecided box is NOT_ASSESSABLE (GRID).'], strjoin(la.groups, ', '), ...
        strjoin(la.conditions, '; '), la.nPoints, la.pointEvals, la.confirmations, la.options.MaxLevel, ...
        la.options.MaxPoints, numOrInf(optField(la.options, 'MaxTotalPoints', Inf)), capText(la.cappedGroups));
    L{end+1} = '';
    for g = r.groups(:).'
        if isfield(g, 'plan') && isfield(g.plan, 'lattice') && isfield(g.plan.lattice, 'discontinuity')
            L{end+1} = sprintf('- %s: %s. Scope: %s.', g.group, g.plan.lattice.discontinuity.text, ...
                g.plan.lattice.scope); %#ok<AGROW>
        end
    end
    L{end+1} = '';
end
on = @(f) isfield(r, 'options') && isfield(r.options, f) && r.options.(f);
nb = 0; if isfield(r, 'bracketed'), nb = numel(r.bracketed); end
if on('Bracket')
L{end+1} = sprintf(['**Breakpoint bracketing (R4-7).** A point whose closed-loop linearization is NOT_CONVERGED ' ...
    'with its trim alpha or elevator within 0.01 deg of a NESC aero-table breakpoint (read from the generated ' ...
    'model) is evaluated at theta x (1 -/+ d), d = 1e-3 up to 1e-2; when the two sides trim on opposite sides of ' ...
    'the breakpoint and both are OK, the point is OK with the WORSE of the two margins and is labelled ' ...
    'BRACKETED (both values are listed below). Physical failures (trim INFEASIBLE or NOT_CONVERGED, DIVERGENT, ' ...
    'non-classical modes) are never bracketed. BRACKETED points in this run: %d.'], nb);
L{end+1} = '';
end
if isfield(r, 'stages') && isstruct(r.stages) && isfield(r.stages, 'staged') && r.stages.staged
    s1 = r.stages.stage1;
    s2 = r.stages.stage2Groups;
    if isempty(s2), t2 = 'none'; else, t2 = strjoin(s2, ', '); end
    L{end+1} = sprintf(['**Staged run (R4-8).** Stage 1: every group at NumCandidates %d, differential evolution %d x ' ...
        '%d, Monte Carlo N = %d. Stage 2 (the full budget: NumCandidates %d, differential evolution %d x %d) only ' ...
        'for the groups whose judged CSR bracket overlaps [%g, %g] or that are NOT_ASSESSABLE for budget reasons ' ...
        '(FC-901); the lattice groups need no stage 2. Re-run in stage 2: %s. The column "decided by" gives the ' ...
        'stage of each group.'], s1.NumCandidates, s1.DEPopulation, s1.DEGenerations, s1.N, r.stages.full.NumCandidates, ...
        r.stages.full.DEPopulation, r.stages.full.DEGenerations, r.stages.band(1), r.stages.band(2), t2);
    L{end+1} = '';
end
if on('LatDropCmq')
    L{end+1} = ['**Lateral groups without Cm_q (R4-9).** Cm_q acts only through the pitch rate, zero at the ' ...
        'wings-level trim, so a lateral group (3.3.x) is searched without it; this is gated per group at its ' ...
        'critical condition (margin unchanged within 1e-9 relative with Cm_q at the extreme values of every box ' ...
        'searched) and falls back to the full set of parameters if the gate fails ' ...
        '(tests/M8/tUqR4bF16.m#lateralInvarianceCmq).'];
    L{end+1} = '';
end
end

function v = optField(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end

function t = numOrInf(v)
if isinf(v), t = 'no limit on the'; else, t = sprintf('%d', v); end
end

function t = capText(c)
if isempty(c), t = 'none'; else, t = strjoin(c, ', '); end
end

function t = alphaText(c)
switch c.status
    case 'OK', t = sprintf('%.2f (OK; CPV at %.2f)', c.alphaStar, c.alphaHi);
    case 'ROBUST_TO_CAP', t = sprintf('>= %g (ROBUST_TO_CAP)', c.alphaStar);
    otherwise, t = sprintf('NOT_ASSESSABLE (in [%.2f, %s])', c.alphaLo, num(c.alphaHi));
end
[lo, ok] = vital.uq.lowerEnd(c);                 % R5-2: is R(1) certified?
if ok && lo >= 1
    t = [t '; R(1) certified'];
elseif ok
    t = sprintf('%s; R(%.2f) certified', t, lo);
else
    t = [t '; lower end not certified'];
end
end

function t = psmText(c)
if isnan(c.alphaStar), t = '-'; return; end
t = strjoin(arrayfun(@(k) sprintf('%s +/-%.3f', c.names{k}, c.psm(k)), c.searchIndex, 'UniformOutput', false), ', ');
end

function t = cpvText(c)
if ~all(isfinite(c.cpv)), t = '-'; return; end
t = sprintf('%s (margin %.3g%s)', c.cpvCond, c.cpvMargin, ifs(c.cpvConfirmed, ', confirmed', ', NOT confirmed'));
end

function t = eqText(c, pct)
switch c.status
    case 'OK', t = sprintf('%.1f %% (alpha* %.2f)', 100 * pct * c.alphaStar, c.alphaStar);
    case 'ROBUST_TO_CAP', t = sprintf('>= %.0f %% (ROBUST_TO_CAP)', 100 * pct * c.alphaStar);
    otherwise, t = sprintf('NOT_ASSESSABLE (in [%.1f %%, %s %%])', 100 * pct * c.alphaLo, num(100 * pct * c.alphaHi));
end
end

function t = ifs(c, a, b)
if c, t = a; else, t = b; end
end

function t = lvl(L)
if isnan(L), t = '-'; elseif L == 4, t = 'worse than 3'; else, t = sprintf('%d', L); end
end

function t = num(v)
if isnan(v), t = 'NaN'; else, t = sprintf('%.4g', v); end
end
