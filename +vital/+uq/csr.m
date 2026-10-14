function c = csr(problem, opts)
%CSR  Critical Similitude Ratio of a hyper-rectangular reference set (M8
%   amendment R4-1, docs/PLAN_M5_M8.md "Amendment R4"; generic, no aircraft).
%   c = vital.uq.csr(problem)
%   c = vital.uq.csr(problem, 'AlphaMax', 3, 'Resolution', 0.01, 'Reserve', 0,
%        'Search', f, 'DecideAt', [], 'Prior', S, 'MaxSearches', 15,
%        'MaxRounds', 3, 'Shape', '')
%
%   Definitions (Crespo, Kenny and Giesy, NASA LaRC, "A Verification-driven
%   Approach to Control Analysis and Tuning"): the reference set is the box
%   R(pbar, m) = [pbar - m, pbar + m]; its homothetic deformation by the
%   similitude ratio alpha is R(alpha) = [pbar - alpha m, pbar + alpha m]. The
%   Critical Similitude Ratio alpha* is the largest alpha in [0, AlphaMax] for
%   which the margin stays >= Reserve over R(alpha) (failure: margin <
%   Reserve); the Critical Parameter Value (CPV) is a point where the
%   deformed box first touches failure; R(alpha*) is the Maximal Set; the
%   parametric safety margin is alpha* m (multiplier units). In scaled
%   coordinates s = (p - pbar)./m, R(alpha) is ||s||_inf <= alpha, so a
%   failing point p gives the upper bound alpha* <= ||p - pbar||_inf,m.
%
%   problem fields
%     names, nominal (1 x d, pbar), m (1 x d > 0, the reference half-widths)
%     conditions, condLabels   candidate conditions (as vital.uq.boundWorst)
%     pointFcn    q = f(theta, cond): q.status, q.margin, q.record, q.reason
%     confirmFcn  (optional) c = f(theta): a FRESH assessment over all
%                 conditions: c.status, c.margin, c.condLabel, c.cond, c.record,
%                 c.reason
%   'Search'  bw = f(P): a box search of the vital.uq.boundWorst problem P
%             (names, lo, hi, nominal, conditions, condLabels, pointFcn,
%             confirmFcn) returning bw.status ('OK' = searched clean, 'VIOLATED'
%             = a counterexample at bw.theta with margin bw.value,
%             'NOT_ASSESSABLE'), bw.theta, bw.value, bw.cond, bw.condition,
%             bw.conditions, bw.condLabels, bw.nEvaluated, bw.reason, bw.label.
%             Default: vital.uq.boundWorst with the method of
%             vital.uq.searchMethod(d) ('grid' for d <= 2, 'hybrid' above).
%
%   ALGORITHM (bisection on alpha with the box searches; nested boxes make the
%   answer monotone in alpha: a box inside a clean box is clean, a box that
%   contains a failing point fails):
%   0. The nominal point (all candidates). Not OK: NOT_ASSESSABLE. Failing:
%      alpha* = 0, CPV = the nominal (confirmed as in 4).
%   1. Priors ('Prior', a struct array with fields lo, hi, status, theta,
%      value; e.g. the searches of an earlier CSR of the same problem in another
%      shape, or the x1 bound-worst): a prior box searched clean ('OK') that
%      contains R(a) gives alphaLo >= a; a prior counterexample theta gives
%      alphaHi <= ||theta - pbar||_inf,m (after its ray refinement) if that is
%      <= AlphaMax; a failing point beyond the cap bounds nothing and no box
%      beyond R(AlphaMax) is ever searched. Priors are not counted in
%      nSearches.
%   2. With no failing point yet: search the cap box R(AlphaMax). Clean:
%      ROBUST_TO_CAP. Not decided: the DecideAt boxes below it are searched (to
%      report a lower bound), and the status is NOT_ASSESSABLE.
%   3. Every failing point p_f is refined along the ray from pbar (the RAY):
%      bisection on t in p(t) = pbar + t (p_f - pbar) between a passing and a
%      failing point until the bracket is below Resolution/2 in alpha; the
%      failing end is the CPV candidate and alphaHi = its scaled norm.
%      Then, until alphaHi - alphaLo <= Resolution: the box at
%      alphaHi - Resolution is searched (an optimistic step; clean -> done;
%      the ray of a failing box search usually lands close to the CPV), after
%      two consecutive failed optimistic steps the bisection midpoint; a clean box
%      raises alphaLo, a failing one lowers alphaHi (via its ray), an
%      undecided one stops with NOT_ASSESSABLE. At most MaxSearches searches.
%      Each search's candidate conditions are carried over (a moving limit
%      found by a search stays a candidate). A DecideAt value a strictly
%      inside (alphaLo, alphaHi) is then searched, so that alpha* >= a or
%      alpha* < a is decided (vital.uq.analyze uses a = 1 for the judged
%      shape).
%   4. CONFIRMATION of the CPV (with the moving-limit rule of R3-M4): a fresh
%      assessment (confirmFcn) at the CPV must be OK with margin < Reserve. If
%      its critical condition is not a candidate and its margin is smaller,
%      the condition is added and the box at alphaLo is searched again, at
%      most MaxRounds rounds (then NOT_ASSESSABLE, 'MOVING_LIMIT'). Without a
%      confirmFcn the CPV is confirmed by the point function only
%      (confirmation.evaluated false).
%   STATUS
%     'OK'             alpha* bracketed to Resolution with a confirmed CPV:
%                      alphaStar = alphaLo (the largest box searched clean),
%                      alphaHi = ||CPV - pbar||_inf,m, alphaHi - alphaLo <=
%                      Resolution
%     'ROBUST_TO_CAP'  no failure up to AlphaMax: alphaStar = alphaLo =
%                      AlphaMax, alphaHi = Inf, no CPV
%     'NOT_ASSESSABLE' the searches could not decide (reason given); alphaStar
%                      NaN; alphaLo/alphaHi still bound alpha* (a confirmed CPV
%                      with alphaHi <= 1 still proves alpha* < 1)
%   Like the bound-worst, a clean box is a search estimate (grid-certified for
%   'grid' searches).
%   c fields: status, reason, shape, alphaStar, alphaLo, alphaHi, alphaMax,
%     resolution, m, nominal, names, psm (alphaStar m), psmHi (alphaHi m), cpv,
%     cpvMargin, cpvCond, cpvRecord, cpvConfirmed, confirmation (evaluated,
%     status, margin, cond, record, moved, reason), nominalMargin, searches
%     (alpha, origin ('cap', 'optimistic', 'bisection', 'decide', 'recheck'),
%     lo, hi, status, value, theta, cond, nEvaluated, label, reason), nSearches,
%     rays (from, theta, tPass, tFail, alpha, margin, cond, nEval), conditions,
%     condLabels (the final candidates), options.
%   Errors: vital:badInput (sizes, m not finite > 0, AlphaMax or Resolution
%   not finite > 0, Search not a function handle, MaxSearches/MaxRounds not
%   positive integers); vital:uq:negativeMultiplier (the cap box has a
%   negative lower bound: pbar - AlphaMax m < 0).
arguments
    problem (1,1) struct
    opts.AlphaMax (1,1) double = 3
    opts.Resolution (1,1) double = 0.01
    opts.Reserve (1,1) double = 0
    opts.Search = []
    opts.DecideAt (1,:) double = []
    opts.Prior struct = struct([])
    opts.MaxSearches (1,1) double = 15
    opts.MaxRounds (1,1) double = 3
    opts.Shape (1,:) char = ''
end
P = validate(problem, opts);
d = numel(P.nominal);
nom = P.nominal; m = P.m;
Search = opts.Search;
if isempty(Search)
    Search = @(Q) vital.uq.boundWorst(Q, 'Method', vital.uq.searchMethod(numel(Q.lo)));
end
conds = P.conditions(:).';
labels = P.condLabels(:).';
Res = opts.Resolution; Amax = opts.AlphaMax; Rsv = opts.Reserve;
nrm = @(th) max(abs(th - nom) ./ m);

c = struct('status', '', 'reason', '', 'shape', opts.Shape, 'alphaStar', NaN, 'alphaLo', 0, 'alphaHi', Inf, ...
    'alphaMax', Amax, 'resolution', Res, 'm', m, 'nominal', nom, 'names', {P.names}, 'psm', NaN(1, d), ...
    'psmHi', NaN(1, d), 'cpv', NaN(1, d), 'cpvMargin', NaN, 'cpvCond', '', 'cpvRecord', '', 'cpvConfirmed', false, ...
    'confirmation', struct('evaluated', false, 'status', '', 'margin', NaN, 'cond', '', 'record', '', 'moved', false, ...
    'reason', 'no confirmation'), 'nominalMargin', NaN, ...
    'searches', struct('alpha', {}, 'origin', {}, 'lo', {}, 'hi', {}, 'status', {}, 'value', {}, 'theta', {}, ...
    'cond', {}, 'nEvaluated', {}, 'label', {}, 'reason', {}), 'nSearches', 0, ...
    'rays', struct('from', {}, 'theta', {}, 'tPass', {}, 'tFail', {}, 'alpha', {}, 'margin', {}, 'cond', {}, 'nEval', {}), ...
    'conditions', {conds}, 'condLabels', {labels}, 'options', opts);
c.options.Search = func2str(Search);
lo = 0; hi = Inf;
clean = 0;                                       % alphas of boxes found clean (0: the nominal)
cpv = NaN(1, d); cpvM = NaN; cpvC = ''; cpvR = '';
why = '';

% ---- 0. nominal ------------------------------------------------------------------------------
q0 = pointAll(nom);
c.nominalMargin = q0.margin;
if ~strcmp(q0.status, 'OK')
    finish('NOT_ASSESSABLE', sprintf('the nominal point is not OK (%s: %s)', q0.status, q0.reason));
    return
end
if q0.margin < Rsv
    lo = 0; hi = 0; cpv = nom; cpvM = q0.margin; cpvC = q0.cond; cpvR = q0.record;
    [ok, msg] = confirmCpv(false);
    if ok
        finish('OK', sprintf('the nominal point fails (margin %.6g < reserve %g at %s): alpha* = 0', q0.margin, Rsv, q0.cond));
    else
        finish('NOT_ASSESSABLE', msg);
    end
    return
end

% ---- 1. priors ------------------------------------------------------------------------------
fails = zeros(0, d); failM = zeros(0, 1);
for k = 1:numel(opts.Prior)
    pr = opts.Prior(k);
    if ~all(isfield(pr, {'status', 'theta', 'value'})), continue; end
    if strcmp(pr.status, 'OK') && all(isfield(pr, {'lo', 'hi'})) && numel(pr.lo) == d && all(isfinite([pr.lo pr.hi]))
        a = min(min((nom - pr.lo) ./ m), min((pr.hi - nom) ./ m));
        if a > lo, lo = min(a, Amax); clean(end+1) = lo; end %#ok<AGROW>
    elseif strcmp(pr.status, 'VIOLATED') && numel(pr.theta) == d && all(isfinite(pr.theta)) && pr.value < Rsv
        fails(end+1, :) = pr.theta; failM(end+1, 1) = pr.value; %#ok<AGROW>
    end
end
if ~isempty(fails)
    [~, k] = min(arrayfun(@(i) nrm(fails(i, :)), 1:size(fails, 1)));
    ray(fails(k, :), failM(k), 'prior');
end

% ---- 2-4. searches, ray refinement, confirmation ------------------------------------------
rounds = 0;
while true
    if isinf(hi)
        if lo >= Amax
            finish('ROBUST_TO_CAP', sprintf('a box searched clean contains the cap box R(%g): no failure up to AlphaMax', Amax));
            return
        end
        bw = boxSearch(Amax, 'cap');
        switch bw.status
            case 'OK'
                lo = Amax; clean(end+1) = Amax; %#ok<AGROW>
                finish('ROBUST_TO_CAP', sprintf(['no failure up to AlphaMax: the cap box R(%g) was searched clean ' ...
                    '(%s; %s)'], Amax, bw.label, bw.reason));
                return
            case 'VIOLATED'
                ray(bw.theta(:).', bw.value, 'cap');
            otherwise
                why = sprintf('the cap box R(%g) is not decided: %s', Amax, bw.reason);
                for a = sort(opts.DecideAt(opts.DecideAt > lo & opts.DecideAt < Amax), 'descend')
                    b2 = boxSearch(a, 'decide');
                    if strcmp(b2.status, 'OK')
                        lo = max(lo, a); clean(end+1) = a; %#ok<AGROW>
                        break
                    elseif strcmp(b2.status, 'VIOLATED')
                        ray(b2.theta(:).', b2.value, 'decide');
                        break
                    end
                end
                if isinf(hi)
                    finish('NOT_ASSESSABLE', why);
                    return
                end
                why = '';
        end
    end
    % bracket to the resolution
    nOptFail = 0;                                % consecutive failed optimistic steps
    while hi - lo > Res + 1e-12
        if c.nSearches >= opts.MaxSearches
            finish('NOT_ASSESSABLE', sprintf('the search budget (%d box searches) is used up with alpha* in [%.4g, %.4g]', ...
                opts.MaxSearches, lo, hi));
            return
        end
        if nOptFail < 2 && hi - Res > lo
            a = hi - Res; org = 'optimistic';
        else
            a = (lo + hi) / 2; org = 'bisection';
        end
        bw = boxSearch(a, org);
        switch bw.status
            case 'OK'
                lo = max(lo, a); clean(end+1) = a; nOptFail = 0; %#ok<AGROW>   a clean box raises the lower end
            case 'VIOLATED'
                ray(bw.theta(:).', bw.value, org);
                nOptFail = strcmp(org, 'optimistic') * (nOptFail + 1);
            otherwise
                finish('NOT_ASSESSABLE', sprintf('the box R(%.4g) is not decided (alpha* in [%.4g, %.4g]): %s', a, lo, hi, ...
                    bw.reason));
                return
        end
    end
    % decide at the requested alphas
    for a = opts.DecideAt
        if a > lo && a < hi
            bw = boxSearch(a, 'decide');
            if strcmp(bw.status, 'OK')
                lo = a; clean(end+1) = a; %#ok<AGROW>
            elseif strcmp(bw.status, 'VIOLATED')
                ray(bw.theta(:).', bw.value, 'decide');
            else
                finish('NOT_ASSESSABLE', sprintf('the box R(%g) (DecideAt) is not decided: %s', a, bw.reason));
                return
            end
        end
    end
    if hi - lo > Res + 1e-12
        continue                                 % a decide search reopened the bracket
    end
    % confirmation of the CPV (moving-limit rule)
    [ok, msg, moved] = confirmCpv(true);
    if ~ok
        finish('NOT_ASSESSABLE', msg);
        return
    end
    if ~moved
        break
    end
    rounds = rounds + 1;
    if rounds >= opts.MaxRounds
        finish('NOT_ASSESSABLE', sprintf('MOVING_LIMIT: the CPV confirmation still moves after %d round(s): %s', rounds, msg));
        return
    end
    if lo > 0                                    % re-search the largest clean box with the new candidate
        bw = boxSearch(lo, 'recheck');
        if strcmp(bw.status, 'VIOLATED')
            ray(bw.theta(:).', bw.value, 'recheck');
        elseif ~strcmp(bw.status, 'OK')
            finish('NOT_ASSESSABLE', sprintf('the re-search of R(%.4g) after a moving limit is not decided: %s', lo, bw.reason));
            return
        end
    end
end
finish('OK', sprintf(['alpha* in [%.4g, %.4g] (resolution %g): the box R(%.4g) was searched clean and the CPV at ' ...
    'scaled norm %.4g fails (margin %.6g at %s, %s), confirmed by a fresh assessment'], lo, hi, Res, lo, hi, cpvM, ...
    cpvC, cpvR));

% =========================================================================================
    function q = pointAll(th)
        % the margin at th: the minimum over the current candidates (OK only if every one is)
        q = struct('status', 'OK', 'margin', NaN, 'cond', '', 'record', '', 'reason', '');
        mm = NaN(1, numel(conds));
        recs = repmat({''}, 1, numel(conds));
        for kc = 1:numel(conds)
            try
                r = P.pointFcn(th, conds{kc});
            catch err
                r = struct('status', 'ERROR', 'margin', NaN, 'record', '', 'reason', sprintf('%s: %s', err.identifier, err.message));
            end
            if strcmp(r.status, 'OK')
                mm(kc) = r.margin; recs{kc} = r.record;
            elseif strcmp(q.status, 'OK')
                q.status = r.status;
                q.reason = sprintf('%s: %s', labels{kc}, r.reason);
            end
        end
        okc = find(~isnan(mm));
        if ~isempty(okc)
            [q.margin, j] = min(mm(okc));
            q.cond = labels{okc(j)}; q.record = recs{okc(j)};
            if q.margin < Rsv && ~strcmp(q.status, 'OK')
                q.status = 'OK';                 % a failing candidate decides even if another is not OK
            end
        end
    end

    function bw = boxSearch(a, origin)
        Q = struct('names', {P.names}, 'lo', nom - a * m, 'hi', nom + a * m, 'nominal', nom, ...
            'conditions', {conds}, 'condLabels', {labels}, 'pointFcn', P.pointFcn, 'confirmFcn', P.confirmFcn);
        bw = Search(Q);
        c.nSearches = c.nSearches + 1;
        lab = ''; if isfield(bw, 'label'), lab = bw.label; end
        th = NaN(1, d); if isfield(bw, 'theta') && numel(bw.theta) == d, th = bw.theta(:).'; end
        c.searches(end+1) = struct('alpha', a, 'origin', origin, 'lo', Q.lo, 'hi', Q.hi, 'status', bw.status, ...
            'value', bw.value, 'theta', th, 'cond', bw.cond, 'nEvaluated', bw.nEvaluated, 'label', lab, 'reason', bw.reason);
        % candidates found by the search (moving limits) stay candidates
        if isfield(bw, 'conditions') && isfield(bw, 'condLabels')
            for kc = 1:numel(bw.condLabels)
                addCond(bw.conditions{kc}, bw.condLabels{kc});
            end
        end
        if isfield(bw, 'condition') && ~isempty(bw.condition) && ~isempty(bw.cond)
            addCond(bw.condition, bw.cond);
        end
    end

    function addCond(cd, lb)
        if ~any(strcmp(labels, lb))
            conds{end+1} = cd;
            labels{end+1} = lb;
        end
    end

    function ray(pf, mf, origin)
        % refine a failing point along the ray from the nominal
        af = nrm(pf);
        dir = pf - nom;
        q = pointAll(pf);
        n0 = 1;
        tP = 0; tF = 1; qF = q;
        if ~(strcmp(q.status, 'OK') && q.margin < Rsv)
            % not reproduced by the point function at the candidates: keep the
            % search's own counterexample (margin mf), unrefined
            qF = struct('status', 'OK', 'margin', mf, 'cond', '', 'record', '', 'reason', 'not reproduced');
            if isempty(qF.cond) && isfield(c, 'searches') && ~isempty(c.searches), qF.cond = c.searches(end).cond; end
        else
            while (tF - tP) * af > Res / 2
                t = (tP + tF) / 2;
                qt = pointAll(nom + t * dir);
                n0 = n0 + 1;
                if ~strcmp(qt.status, 'OK'), break; end
                if qt.margin < Rsv
                    tF = t; qF = qt;
                else
                    tP = t;
                end
            end
        end
        th = nom + tF * dir;
        aF = nrm(th);
        c.rays(end+1) = struct('from', origin, 'theta', th, 'tPass', tP, 'tFail', tF, 'alpha', aF, 'margin', qF.margin, ...
            'cond', qF.cond, 'nEval', n0);
        if aF < hi && aF <= Amax + 1e-12         % a failing point beyond the cap bounds nothing in [0, AlphaMax]
            hi = aF; cpv = th; cpvM = qF.margin; cpvC = qF.cond; cpvR = qF.record;
            if hi <= lo                          % a failing point inside a box called clean: the search missed it
                lo = max([0, clean(clean < hi)]);
            end
        end
    end

    function [ok, msg, moved] = confirmCpv(allowMove)
        ok = false; msg = ''; moved = false;
        if isempty(P.confirmFcn)
            c.confirmation = struct('evaluated', false, 'status', 'OK', 'margin', cpvM, 'cond', cpvC, 'record', cpvR, ...
                'moved', false, 'reason', 'no confirmation function: the CPV is confirmed by the point function only');
            ok = cpvM < Rsv;
            if ~ok, msg = 'the CPV does not fail'; end
            return
        end
        try
            cf = P.confirmFcn(cpv);
        catch err
            cf = struct('status', 'ERROR', 'margin', NaN, 'condLabel', '', 'record', '', ...
                'reason', sprintf('%s: %s', err.identifier, err.message));
        end
        cl = ''; if isfield(cf, 'condLabel'), cl = cf.condLabel; end
        c.confirmation = struct('evaluated', true, 'status', cf.status, 'margin', cf.margin, 'cond', cl, ...
            'record', cf.record, 'moved', false, 'reason', cf.reason);
        if ~strcmp(cf.status, 'OK')
            msg = sprintf('the CPV confirmation is not OK: %s (%s)', cf.status, cf.reason);
            return
        end
        if ~(cf.margin < Rsv)
            msg = sprintf(['the CPV is not confirmed: the fresh assessment gives margin %.6g >= reserve %g at the CPV ' ...
                '(the point evaluation gave %.6g at %s)'], cf.margin, Rsv, cpvM, cpvC);
            return
        end
        ok = true;
        if allowMove && cf.margin < cpvM && ~any(strcmp(labels, cl)) && isfield(cf, 'cond')
            moved = true;
            c.confirmation.moved = true;
            c.confirmation.reason = sprintf(['moving limit: the confirmation found margin %.6g at %s, not a candidate ' ...
                '(the point evaluation gave %.6g at %s); the condition is added'], cf.margin, cl, cpvM, cpvC);
            msg = c.confirmation.reason;
            addCond(cf.cond, cl);
        end
    end

    function finish(st, reason)
        c.status = st;
        c.reason = reason;
        c.alphaLo = lo;
        c.alphaHi = hi;
        c.conditions = conds;
        c.condLabels = labels;
        c.cpv = cpv; c.cpvMargin = cpvM; c.cpvCond = cpvC; c.cpvRecord = cpvR;
        c.cpvConfirmed = all(isfinite(cpv)) && cpvM < Rsv && (~c.confirmation.evaluated || ...
            (strcmp(c.confirmation.status, 'OK') && c.confirmation.margin < Rsv));
        if strcmp(st, 'ROBUST_TO_CAP')
            c.alphaLo = Amax; c.alphaStar = Amax; c.alphaHi = Inf;
            c.cpvConfirmed = false;
        elseif strcmp(st, 'OK')
            c.alphaStar = lo;
        else
            c.alphaStar = NaN;
        end
        c.psm = c.alphaStar * m;
        c.psmHi = c.alphaHi * m;
        c = orderfields(c);
    end
end

% =========================================================================================
function P = validate(P, opts)
need = {'names', 'nominal', 'm', 'conditions', 'condLabels', 'pointFcn'};
for k = 1:numel(need)
    if ~isfield(P, need{k})
        error('vital:badInput', 'csr problem lacks field "%s".', need{k});
    end
end
if ~isfield(P, 'confirmFcn'), P.confirmFcn = []; end
d = numel(P.nominal);
P.nominal = double(P.nominal(:).'); P.m = double(P.m(:).');
if d == 0 || numel(P.m) ~= d || numel(P.names) ~= d
    error('vital:badInput', 'names, nominal and m must have the same non-zero length.');
end
if ~all(isfinite(P.m)) || any(P.m <= 0) || ~all(isfinite(P.nominal))
    error('vital:badInput', 'm must be finite and > 0, nominal finite.');
end
if ~(isfinite(opts.AlphaMax) && opts.AlphaMax > 0) || ~(isfinite(opts.Resolution) && opts.Resolution > 0)
    error('vital:badInput', 'AlphaMax and Resolution must be finite and > 0.');
end
isInt = @(v) isfinite(v) && v >= 1 && v == round(v);
if ~isInt(opts.MaxSearches) || ~isInt(opts.MaxRounds)
    error('vital:badInput', 'MaxSearches and MaxRounds must be positive integers.');
end
if ~isempty(opts.Search) && ~isa(opts.Search, 'function_handle')
    error('vital:badInput', 'Search must be a function handle bw = f(problem).');
end
if ~iscell(P.conditions) || isempty(P.conditions) || numel(P.condLabels) ~= numel(P.conditions)
    error('vital:badInput', 'conditions must be a non-empty cell with one label per condition.');
end
if ~isa(P.pointFcn, 'function_handle') || (~isempty(P.confirmFcn) && ~isa(P.confirmFcn, 'function_handle'))
    error('vital:badInput', 'pointFcn (and confirmFcn) must be function handles.');
end
lo = P.nominal - opts.AlphaMax * P.m;
if any(lo < 0)
    k = find(lo < 0, 1);
    error('vital:uq:negativeMultiplier', ['the cap box R(%g) has lower bound %g < 0 for %s (a multiplier must be ' ...
        '>= 0): reduce AlphaMax or m.'], opts.AlphaMax, lo(k), P.names{k});
end
end
