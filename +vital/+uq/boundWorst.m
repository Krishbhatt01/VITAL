function bw = boundWorst(problem, opts)
%BOUNDWORST  Bound-worst margin over a parameter box (M8; generic, no aircraft).
%   bw = vital.uq.boundWorst(problem)
%   bw = vital.uq.boundWorst(problem, 'NumLHS', 32, 'Seed', 2026, 'NumStarts', 2,
%                            'MaxEvals', 60, 'FDStep', 1e-3, 'Reserve', 0,
%                            'MaxRounds', 3, 'Method', 'sqp')
%   Method 'grid' (M8 amendment R4-3): 'GridPoints' 11, 'GridLocalLevels' 3,
%       'GridMaxRefine' 8, 'GridBudget' 5000, 'LipschitzFactor' 2
%   Method 'hybrid' (M8 amendment R4-4): 'DEPopulation' 20, 'DEGenerations' 20,
%       'DEF' 0.7, 'DECR' 0.9, 'NumStarts', 'MaxEvals' (per Nelder-Mead start),
%       'TolX' 1e-3, 'TolFun' 1e-4
%
%   problem fields
%     names       1 x d parameter names
%     lo, hi      1 x d box bounds (lo <= hi)
%     nominal     1 x d nominal parameters (inside the box; the centre point)
%     conditions  1 x nC cell of candidate conditions (opaque; passed to pointFcn)
%     condLabels  1 x nC cellstr
%     pointFcn    q = f(theta, cond): q.status ('OK' or anything else: not OK),
%                 q.margin (normalized margin; -Inf for a divergent point),
%                 q.record (the active record), q.reason
%     confirmFcn  (optional, [] = none) c = f(theta): a FRESH assessment over
%                 ALL conditions at theta; c.status, c.margin, c.condLabel,
%                 c.record, c.reason, and c.cond (the condition itself, needed
%                 to re-search a moving limit)
%
%   SEARCH of one round (every evaluated point is kept). At a point theta the
%   margin is the minimum over the candidate conditions that are OK (NaN if
%   none is) and the point is OK only if every condition is OK; an exception
%   in pointFcn is a point with status ERROR and the exception's identifier in
%   its reason.
%     1. the nominal point (phase 'centre')
%     1b. from round 2 on: the arg-min of every earlier round ('previous'), so
%        the moved condition is evaluated where it was found
%     2. the 2^d corners of the box ('corner')
%     3. a seeded Latin-hypercube sample of NumLHS points ('lhs'): in every
%        dimension each of the NumLHS equal strata holds exactly one point
%        (RandStream mt19937ar with Seed)
%     4. fmincon (sqp; bounds = the box, which sqp honours also in its finite
%        differences; forward differences of step FDStep relative to theta) from
%        the NumStarts best distinct points of 1-3 (sorted by margin, stable),
%        each with a budget of MaxEvals objective evaluations ('fmincon<k>'); a
%        point that is not OK is NaN to the optimizer. A start whose objective
%        is not finite cannot be optimized and counts as not converged. A start
%        converges when fmincon's exit flag is > 0.
%   The round's bound-worst = the minimum margin over EVERY point evaluated in
%   it; the arg-min (theta, condition, record) is the active set.
%   CONFIRMATION AND MOVING LIMIT (docs/PLAN_M5_M8.md, M8 amendment R3-M4):
%   when confirmFcn is given it is called at the round's arg-min. If it finds
%   a smaller margin at another condition (a moving limit), that condition is
%   added to the candidates and the search is run again (a new round), until
%   the confirmation no longer moves, at most MaxRounds rounds. If the final
%   confirmation still moves, its margin and condition REPLACE the search
%   value and the status cannot be OK. bw.rounds lists every round.
%   STATUS
%     'VIOLATED'        some evaluated point (or a confirmation) of any round
%                       has margin < Reserve: a counterexample, definitive even
%                       if the optimizer did not converge
%     'NOT_ASSESSABLE'  no counterexample, and: the final confirmation still
%                       moves (reason starts 'MOVING_LIMIT'), or a point inside
%                       the box is not OK (trim infeasible, metric NaN, ...),
%                       or the confirmation is not OK, or an optimizer start of
%                       the final round did not converge (FC-901; the reason
%                       then starts with 'FC-901' unless one of the others
%                       applies)
%     'OK'              every evaluated point OK, every start of the final
%                       round converged, and the final confirmation did not move
%   THE BOUND-WORST IS A SEARCH ESTIMATE: the smallest margin found, an upper
%   bound on the true minimum over the box, not a proof (review R3 M2).
%
%   METHODS (docs/PLAN_M5_M8.md, M8 amendment R4; steps 3-4 above are the
%   'sqp' method, the default, unchanged):
%   'hybrid' (R4-4; groups with more than 2 searched parameters): steps 1-3,
%     then a GLOBAL stage, vital.uq.diffEvolution (DE/rand/1/bin, seeded with
%     Seed + 1, DEPopulation members, the LHS points as its initial population
%     (topped up with seeded uniform points), DEGenerations generations; phase
%     'de'; DEPopulation 0 skips it), then a LOCAL stage: fminsearch
%     (Nelder-Mead) from the NumStarts best distinct points of all earlier
%     stages, on z with theta = lo + (hi - lo)(1 + sin(z - 3))/2 (a bound
%     transform: every point lies in the box; the offset 3 keeps every z
%     component away from 0, where fminsearch's first simplex would be only
%     0.00025 wide and could stop at once), budget MaxEvals per start,
%     TolX (in z) and TolFun (margin); a point that is not OK is +Inf to
%     Nelder-Mead (phase 'local<k>'). The local stage converges when every
%     start ends with exit flag 1; otherwise FC-901 as for sqp. Nelder-Mead is
%     derivative-free, so the kinks of the margin functions do not stall it.
%     bw.stages reports every stage (centre, corner, lhs, de, local): nEval,
%     converged (DE: the population's spread, reported only), message.
%   'grid' (R4-3; groups with at most 2 searched parameters): step 1, then a
%     dense grid of GridPoints points per dimension over the box on an integer
%     lattice (box coordinate t = (theta - lo)/(hi - lo), base spacing
%     1/(GridPoints - 1), finest spacing that / 2^GridMaxRefine; it contains
%     the 2^d corners), phase 'grid'; LOCAL REFINEMENT around the minimum
%     (GridLocalLevels times the cells touching the best lattice point are
%     halved); then LIPSCHITZ CERTIFICATION: per axis i, L_i = LipschitzFactor
%     x the largest measured slope |dm|/dt_i over every evaluated grid edge
%     along i, and every cell has the bound min(vertex margins) - sum_i L_i
%     dt_i/2 (every point of the cell is within dt_i/2 of a vertex along each
%     axis); cells whose bound is below the reserve are halved and the slopes
%     re-measured, until every bound is >= reserve (CERTIFIED), a cell reaches
%     the finest spacing, or GridBudget lattice points are used. 'OK' needs
%     the certificate (bw.converged = certified); without it and without a
%     counterexample the status is 'NOT_ASSESSABLE' with a reason starting
%     'GRID' (this replaces FC-901 for these groups). The Lipschitz constant is
%     an ESTIMATE from measured slopes (safety factor 2), so the certificate is
%     labelled 'grid-certified (Lipschitz estimate)'. bw.certificate: certified,
%     lowerBound, L, maxSlope, factor, nCells, nPoints, finestStep, reason.
%   bw.method, bw.label ('search estimate (sqp)', 'search estimate (hybrid:
%   differential evolution + Nelder-Mead)', 'grid-certified (Lipschitz
%   estimate)'), bw.stages.
%   bw fields: status, reason, value, searchValue, theta, cond (label),
%     condition (the condition itself), record, nominal (margin, cond, record,
%     status at the centre, round 1), points (of the final round: theta
%     (nE x d), phase, margin, cond, condIndex, record, status, reason,
%     condMargin (nE x nC)), nEvaluated, optimizer (struct array: start, x,
%     fval, exitflag, funcCount, converged, message), converged, confirmation
%     (evaluated, status, margin, cond, condition, record, moved, reason),
%     rounds (round, candidates, nEvaluated, searchValue, theta, cond, record,
%     converged, nNonOK, nViolating, confirmation), nRounds, conditions,
%     condLabels (the final candidates), nonOK (indices into points), reserve,
%     options, names, lo, hi.
%   Errors: vital:badInput (inconsistent problem: sizes, lo > hi, nominal
%   outside the box, no condition, pointFcn not a function handle; MaxRounds
%   not a positive integer; Method not sqp/hybrid/grid; GridPoints < 2,
%   GridMaxRefine, GridLocalLevels < 0, GridBudget < 1, LipschitzFactor < 1;
%   DEPopulation not 0 or an integer >= 4, DEGenerations < 0, DEF outside
%   (0, 2], DECR outside [0, 1], TolX / TolFun not > 0).
arguments
    problem (1,1) struct
    opts.NumLHS (1,1) double = 32
    opts.Seed (1,1) double = 2026
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 60
    opts.FDStep (1,1) double = 1e-3
    opts.Reserve (1,1) double = 0
    opts.MaxRounds (1,1) double = 3
    opts.Method (1,:) char = 'sqp'
    opts.GridPoints (1,1) double = 11
    opts.GridMaxRefine (1,1) double = 8
    opts.GridLocalLevels (1,1) double = 3
    opts.GridBudget (1,1) double = 5000
    opts.LipschitzFactor (1,1) double = 2
    opts.DEPopulation (1,1) double = 20
    opts.DEGenerations (1,1) double = 20
    opts.DEF (1,1) double = 0.7
    opts.DECR (1,1) double = 0.9
    opts.TolX (1,1) double = 1e-3
    opts.TolFun (1,1) double = 1e-4
end
validateOptions(opts);
isGrid = strcmp(opts.Method, 'grid');
isHybrid = strcmp(opts.Method, 'hybrid');
P = validateProblem(problem);
if ~(isfinite(opts.MaxRounds) && opts.MaxRounds >= 1 && opts.MaxRounds == round(opts.MaxRounds))
    error('vital:badInput', 'MaxRounds must be a positive integer.');
end
d = numel(P.lo);
lo = P.lo; hi = P.hi;
conds = P.conditions(:).';
labels = P.condLabels(:).';
prev = zeros(0, d);
R = struct('round', {}, 'candidates', {}, 'nEvaluated', {}, 'searchValue', {}, 'theta', {}, 'cond', {}, ...
    'record', {}, 'converged', {}, 'nNonOK', {}, 'nViolating', {}, 'confirmation', {});
anyViol = false;
nonOKEarlier = 0;
stopWhy = '';
nC = 0; S = []; O = []; ST = []; CERT = [];

for ir = 1:opts.MaxRounds
    nC = numel(conds);
    S = struct('theta', zeros(0, d), 'phase', {cell(0, 1)}, 'margin', zeros(0, 1), 'cond', {cell(0, 1)}, ...
        'condIndex', zeros(0, 1), 'record', {cell(0, 1)}, 'status', {cell(0, 1)}, 'reason', {cell(0, 1)}, ...
        'condMargin', zeros(0, nC));

    % ---- 1. centre (and the arg-min of earlier rounds) ------------------------------------
    evalPoint(P.nominal, 'centre');
    if ir == 1
        bw.nominal = struct('margin', S.margin(1), 'cond', S.cond{1}, 'record', S.record{1}, 'status', S.status{1});
    end
    for j = 1:size(prev, 1)
        evalPoint(prev(j, :), 'previous');
    end

    ST = stage('centre', numel(S.margin), NaN, 'the nominal point (and earlier arg-mins)');
    O = struct('start', {}, 'x', {}, 'fval', {}, 'exitflag', {}, 'funcCount', {}, 'converged', {}, 'message', {});
    CERT = struct('certified', false, 'lowerBound', NaN, 'L', NaN(1, d), 'maxSlope', NaN(1, d), ...
        'factor', opts.LipschitzFactor, 'nCells', 0, 'nPoints', 0, 'finestStep', NaN, 'reason', 'not a grid search');

    % ---- 2. corners (the grid contains them) --------------------------------------------------
    n0 = numel(S.margin);
    for k = 0:2^d - 1
        if isGrid, break; end
        bits = bitget(k, 1:d);
        th = lo;
        th(bits == 1) = hi(bits == 1);
        evalPoint(th, 'corner');
    end
    if ~isGrid, ST(end+1) = stage('corner', numel(S.margin) - n0, NaN, 'the 2^d vertices'); end %#ok<AGROW>

    % ---- 3. seeded Latin hypercube -----------------------------------------------------------
    n = opts.NumLHS;
    if isGrid, n = 0; end
    n0 = numel(S.margin);
    if n > 0
        rs = RandStream('mt19937ar', 'Seed', opts.Seed);
        U = zeros(n, d);
        for j = 1:d
            U(:, j) = (randperm(rs, n).' - rand(rs, n, 1)) / n;
        end
        for i = 1:n
            evalPoint(min(max(lo + (hi - lo) .* U(i, :), lo), hi), 'lhs');
        end
    end
    if ~isGrid, ST(end+1) = stage('lhs', numel(S.margin) - n0, NaN, sprintf('%d seeded Latin-hypercube points', n)); end %#ok<AGROW>

    % ---- 4. the method's own stages -------------------------------------------------------------
    if isGrid
        n0 = numel(S.margin);
        CERT = gridStage();
        ST(end+1) = stage('grid', numel(S.margin) - n0, double(CERT.certified), CERT.reason); %#ok<AGROW>
        nS = 0;
        bw.converged = CERT.certified;
    else
        if isHybrid
            n0 = numel(S.margin);
            [okDE, msgDE, genDE] = deStage();
            ST(end+1) = stage('de', numel(S.margin) - n0, okDE, msgDE); %#ok<AGROW>
            ST(end).generations = genDE;
        end
        [~, ord] = sort(S.margin);
        T = S.theta(ord, :);
        [~, iu] = unique(T, 'rows', 'stable');
        nS = min(opts.NumStarts, numel(iu));
        starts = T(iu(1:nS), :);
        n0 = numel(S.margin);
        for s = 1:nS
            if isHybrid
                O(s) = runLocal(starts(s, :), s); %#ok<AGROW>
            else
                O(s) = runStart(starts(s, :), s); %#ok<AGROW>
            end
        end
        nm = 'fmincon'; if isHybrid, nm = 'local'; end
        ST(end+1) = stage(nm, numel(S.margin) - n0, nS > 0 && all([O.converged]), ...
            strjoin(arrayfun(@(i) sprintf('start %d: exit flag %g, %d evaluations', i, O(i).exitflag, ...
            O(i).funcCount), 1:numel(O), 'UniformOutput', false), '; ')); %#ok<AGROW>
        bw.converged = nS > 0 && all([O.converged]);
    end

    % ---- bound-worst and active set of this round ---------------------------------------------
    use = find(~isnan(S.margin));
    if isempty(use)
        bw.value = NaN; bw.theta = NaN(1, d); bw.cond = ''; bw.record = ''; bw.condition = [];
    else
        [bw.value, k] = min(S.margin(use));
        k = use(k);
        bw.theta = S.theta(k, :); bw.cond = S.cond{k}; bw.record = S.record{k};
        bw.condition = [];
        if S.condIndex(k) > 0, bw.condition = conds{S.condIndex(k)}; end
    end
    bw.searchValue = bw.value;

    % ---- confirmation ----------------------------------------------------------------------------
    bw.confirmation = struct('evaluated', false, 'status', '', 'margin', NaN, 'cond', '', 'condition', [], ...
        'record', '', 'moved', false, 'reason', 'no confirmation function');
    c = [];
    if ~isempty(P.confirmFcn) && all(isfinite(bw.theta))
        try
            c = P.confirmFcn(bw.theta);
        catch err
            c = struct('status', 'ERROR', 'margin', NaN, 'condLabel', '', 'record', '', ...
                'reason', sprintf('%s: %s', err.identifier, err.message));
        end
        cc = []; if isfield(c, 'cond'), cc = c.cond; end
        bw.confirmation = struct('evaluated', true, 'status', c.status, 'margin', c.margin, 'cond', c.condLabel, ...
            'condition', cc, 'record', c.record, 'moved', false, 'reason', c.reason);
        if strcmp(c.status, 'OK') && c.margin < bw.value
            bw.confirmation.moved = true;
            bw.confirmation.reason = sprintf(['moving limit: the confirmation found margin %.6g at %s (%s), smaller ' ...
                'than the search value %.6g at %s (%s)'], c.margin, c.condLabel, c.record, bw.value, bw.cond, bw.record);
        elseif strcmp(c.status, 'OK') && c.margin > bw.value
            bw.confirmation.reason = sprintf(['the confirmation margin %.6g is above the search value %.6g (the ' ...
                'confirmation does not cover the candidate %s?); the search value is kept'], c.margin, bw.value, bw.cond);
        elseif strcmp(c.status, 'OK')
            bw.confirmation.reason = 'the confirmation reproduces the search value';
        end
    end

    % ---- record the round --------------------------------------------------------------------------
    nViol = sum(S.margin < opts.Reserve);
    cf = bw.confirmation;
    if nViol > 0 || (cf.evaluated && strcmp(cf.status, 'OK') && cf.margin < opts.Reserve)
        anyViol = true;
    end
    nNon = sum(~strcmp(S.status, 'OK'));
    R(ir) = struct('round', ir, 'candidates', {labels}, 'nEvaluated', numel(S.margin), 'searchValue', bw.value, ...
        'theta', bw.theta, 'cond', bw.cond, 'record', bw.record, 'converged', bw.converged, 'nNonOK', nNon, ...
        'nViolating', nViol, 'confirmation', rmfield(cf, 'condition'));

    % ---- re-search at a moved condition (R3-M4) ----------------------------------------------------
    if ~cf.moved || anyViol
        break                                   % settled, or a counterexample decides
    end
    if ir == opts.MaxRounds
        stopWhy = sprintf('still moving after %d round(s) (MaxRounds %d)', ir, opts.MaxRounds);
        break
    end
    if ~isfield(c, 'cond')
        stopWhy = 'the confirmation returned no condition, so the moved condition cannot be added to the candidates';
        break
    end
    if any(strcmp(labels, c.condLabel))
        stopWhy = sprintf(['the moved condition %s is already a candidate (the confirmation and the point ' ...
            'evaluation disagree)'], c.condLabel);
        break
    end
    nonOKEarlier = nonOKEarlier + nNon;
    conds{end+1} = c.cond; %#ok<AGROW>
    labels{end+1} = c.condLabel; %#ok<AGROW>
    prev(end+1, :) = bw.theta; %#ok<AGROW>
end

% ---- final result -----------------------------------------------------------------------------
bw.points = S;
bw.nEvaluated = numel(S.margin);
bw.optimizer = O;
bw.method = opts.Method;
bw.stages = ST;
bw.certificate = CERT;
switch opts.Method
    case 'grid', bw.label = 'grid-certified (Lipschitz estimate)';
    case 'hybrid', bw.label = 'search estimate (hybrid: differential evolution + Nelder-Mead)';
    otherwise, bw.label = 'search estimate (sqp)';
end
bw.rounds = R;
bw.nRounds = numel(R);
bw.conditions = conds;
bw.condLabels = labels;
bw.reserve = opts.Reserve;
bw.options = opts;
bw.names = P.names; bw.lo = lo; bw.hi = hi;
movedFinal = bw.confirmation.moved;
if movedFinal                                   % the final confirmation replaces the search value
    bw.value = bw.confirmation.margin; bw.cond = bw.confirmation.cond; bw.record = bw.confirmation.record;
    bw.condition = bw.confirmation.condition;
    if isempty(stopWhy), stopWhy = 'a counterexample decided first'; end
end

% ---- status ------------------------------------------------------------------------------------
bw.nonOK = find(~strcmp(S.status, 'OK')).';
confOK = ~bw.confirmation.evaluated || strcmp(bw.confirmation.status, 'OK');
viol = find(S.margin < opts.Reserve);
confViol = bw.confirmation.evaluated && confOK && bw.confirmation.margin < opts.Reserve;
if ~isempty(viol) || confViol || anyViol
    bw.status = 'VIOLATED';
    if confViol && movedFinal
        bw.reason = sprintf('counterexample (confirmation, moving limit): margin %.6g < reserve %g at %s (%s), theta %s', ...
            bw.value, opts.Reserve, bw.cond, bw.record, mat2str(bw.theta, 6));
    elseif ~isempty(viol)
        bw.reason = sprintf('counterexample: margin %.6g < reserve %g at %s (%s), theta %s; %d of %d evaluated points violate', ...
            bw.value, opts.Reserve, bw.cond, bw.record, mat2str(bw.theta, 6), numel(viol), bw.nEvaluated);
    else
        bw.reason = sprintf('counterexample in an earlier round (%s); final value %.6g at %s (%s)', ...
            strjoin(arrayfun(@(r) sprintf('round %d: %d violating points', r.round, r.nViolating), R, ...
            'UniformOutput', false), ', '), bw.value, bw.cond, bw.record);
    end
    if ~bw.converged
        bw.reason = [bw.reason '; definitive although the optimizer did not converge'];
    end
elseif movedFinal || ~isempty(bw.nonOK) || nonOKEarlier > 0 || ~confOK || ~bw.converged
    bw.status = 'NOT_ASSESSABLE';
    why = {};
    if movedFinal
        why{end+1} = sprintf(['MOVING_LIMIT: the confirmation at the arg-min of round %d found margin %.6g at %s ' ...
            '(%s), below the search value %.6g; %s'], bw.nRounds, bw.value, bw.cond, bw.record, bw.searchValue, stopWhy);
    end
    if ~isempty(bw.nonOK)
        i = bw.nonOK(1);
        why{end+1} = sprintf('%d of %d evaluated points are not OK inside the box, e.g. %s (%s) at theta %s', ...
            numel(bw.nonOK), bw.nEvaluated, S.status{i}, S.reason{i}, mat2str(S.theta(i, :), 6));
    end
    if nonOKEarlier > 0
        why{end+1} = sprintf('%d points of earlier rounds are not OK inside the box', nonOKEarlier);
    end
    if ~confOK
        why{end+1} = sprintf('the confirmation is not OK: %s (%s)', bw.confirmation.status, bw.confirmation.reason);
    end
    if ~bw.converged && isGrid
        why{end+1} = sprintf(['GRID: not certified (grid-certified (Lipschitz estimate)): %s; no grid point ' ...
            'violates, so the box is not decided'], CERT.reason);
    elseif ~bw.converged
        bad = find(~[O.converged]);
        if isempty(bad), txt = 'no optimizer start'; else
            txt = strjoin(arrayfun(@(i) sprintf('start %d exit flag %g (%s)', i, O(i).exitflag, O(i).message), bad, ...
                'UniformOutput', false), '; ');
        end
        what = 'the optimizer';
        if isHybrid, what = 'the local stage (Nelder-Mead)'; end
        why{end+1} = sprintf('FC-901: %s did not converge (%s) and no counterexample was found', what, txt);
    end
    bw.reason = strjoin(why, '; ');
else
    bw.status = 'OK';
    if isGrid
        how = sprintf('grid-certified (Lipschitz estimate): certified lower bound %.6g >= reserve %g', ...
            CERT.lowerBound, opts.Reserve);
    elseif isHybrid
        how = 'every Nelder-Mead start of the local stage converged';
    else
        how = 'every optimizer start converged';
    end
    bw.reason = sprintf(['every evaluated point OK (%d), %s; bound-worst %.6g >= ' ...
        'reserve %g; %d round(s), the final confirmation did not move'], bw.nEvaluated, how, bw.value, opts.Reserve, bw.nRounds);
end
bw = orderfields(bw);

% =========================================================================================
    function [f, ok] = evalPoint(th, phase)
        m = NaN(1, nC); st = 'OK'; why = ''; recs = repmat({''}, 1, nC);
        for kc = 1:nC
            try
                q = P.pointFcn(th, conds{kc});
            catch err
                q = struct('status', 'ERROR', 'margin', NaN, 'record', '', ...
                    'reason', sprintf('%s: %s', err.identifier, err.message));
            end
            if strcmp(q.status, 'OK')
                m(kc) = q.margin; recs{kc} = q.record;
            elseif strcmp(st, 'OK')
                st = q.status;
                why = sprintf('%s: %s', labels{kc}, q.reason);
            end
        end
        okc = find(~isnan(m));
        if isempty(okc)
            f = NaN; cl = ''; rc = ''; ci = 0;
        else
            [f, jm] = min(m(okc));
            ci = okc(jm);
            cl = labels{ci}; rc = recs{ci};
        end
        S.theta(end+1, :) = th;
        S.phase{end+1, 1} = phase;
        S.margin(end+1, 1) = f;
        S.cond{end+1, 1} = cl;
        S.condIndex(end+1, 1) = ci;
        S.record{end+1, 1} = rc;
        S.status{end+1, 1} = st;
        S.reason{end+1, 1} = why;
        S.condMargin(end+1, :) = m;
        ok = strcmp(st, 'OK');
    end

    function st = stage(name, nEval, converged, message)
        st = struct('name', name, 'nEval', nEval, 'converged', converged, 'message', message, 'generations', NaN);
        if ~isnan(converged), st.converged = logical(converged); end
    end

    function [ok, msg, gen] = deStage()
        % global stage (R4-4): seeded differential evolution, the LHS points
        % of this round as its initial population
        NP = opts.DEPopulation;
        if NP == 0
            ok = NaN; msg = 'skipped (DEPopulation 0)'; gen = 0;
            return
        end
        il = find(strcmp(S.phase, 'lhs'));
        il = il(1:min(NP, numel(il)));
        [~, ~, info] = vital.uq.diffEvolution(@deObjective, lo, hi, 'Population', NP, ...
            'Generations', opts.DEGenerations, 'F', opts.DEF, 'CR', opts.DECR, 'Seed', opts.Seed + 1, ...
            'Init', S.theta(il, :), 'InitF', S.margin(il), 'TolFun', opts.TolFun, 'TolX', opts.TolX);
        ok = info.converged;
        gen = info.generations;
        msg = sprintf(['differential evolution DE/rand/1/bin: population %d (%d from the LHS), %d generations, ' ...
            '%d evaluations; population spread %.3g in margin; converged (reported only) %d'], NP, numel(il), ...
            info.generations, info.nEval, info.spreadF, info.converged);

        function f = deObjective(x)
            f = evalPoint(x, 'de');
        end
    end

    function o = runLocal(x0, s)
        % local stage (R4-4): Nelder-Mead (fminsearch) with the bound transform
        % theta = lo + (hi - lo)(1 + sin z)/2
        o = struct('start', x0, 'x', x0, 'fval', NaN, 'exitflag', NaN, 'funcCount', 0, 'converged', false, 'message', '');
        i0 = find(all(S.theta == x0, 2), 1);
        f0 = S.margin(i0);
        if ~isfinite(f0) || ~strcmp(S.status{i0}, 'OK')
            o.message = sprintf('objective not finite or not OK at the start (margin %g, %s): Nelder-Mead cannot run', ...
                f0, S.status{i0});
            return
        end
        act = hi > lo;
        zc = 3;                                          % offset in z (period 2 pi): fminsearch's first simplex
        z0 = asin(min(max(2 * (x0(act) - lo(act)) ./ (hi(act) - lo(act)) - 1, -1), 1)) + zc;   % has steps 0.07-0.23
        cnt = 0;
        ph = sprintf('local%d', s);
        oo = optimset('Display', 'off', 'MaxFunEvals', opts.MaxEvals, 'MaxIter', 10 * opts.MaxEvals, ...
            'TolX', opts.TolX, 'TolFun', opts.TolFun);
        try
            [z, fz, ef, out] = fminsearch(@nmObjective, z0, oo);
            o.x = toTheta(z); o.fval = fz; o.exitflag = ef; o.funcCount = cnt;
            o.converged = (ef == 1);
            o.message = strtrim(regexprep(out.message, '\s+', ' '));
            if numel(o.message) > 300, o.message = [o.message(1:300) '...']; end
        catch err
            o.funcCount = cnt;
            switch err.identifier
                case 'vital:uq:budget'
                    o.exitflag = 0;
                    o.message = sprintf('budget of %d evaluations exhausted', opts.MaxEvals);
                case 'vital:uq:divergent'
                    o.exitflag = -100;
                    o.message = 'stopped at a divergent point (margin -Inf): a counterexample';
                otherwise
                    o.exitflag = NaN;
                    o.message = sprintf('fminsearch failed: %s: %s', err.identifier, err.message);
            end
            [fb, kb] = min(S.margin(strcmp(S.phase, ph)));
            if ~isempty(fb)
                T2 = S.theta(strcmp(S.phase, ph), :);
                o.x = T2(kb, :); o.fval = fb;
            end
        end

        function th = toTheta(z)
            th = x0;
            th(act) = lo(act) + (hi(act) - lo(act)) .* (1 + sin(z(:).' - zc)) / 2;
            th = min(max(th, lo), hi);
        end

        function f = nmObjective(z)
            if cnt >= opts.MaxEvals
                error('vital:uq:budget', 'evaluation budget exhausted');
            end
            cnt = cnt + 1;
            [f, okp] = evalPoint(toTheta(z), ph);
            if f == -Inf
                error('vital:uq:divergent', 'divergent point');
            end
            if ~okp || isnan(f), f = Inf; end
        end
    end

    function ce = gridStage()
        % R4-3: dense grid + local refinement around the minimum + Lipschitz
        % certification with measured slopes (factor LipschitzFactor)
        ng = opts.GridPoints;
        act = find(hi > lo);
        da = numel(act);
        K = (ng - 1) * 2^opts.GridMaxRefine;            % lattice: t = k / K
        s0 = 2^opts.GridMaxRefine;
        vals = containers.Map('KeyType', 'char', 'ValueType', 'double');
        okv = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        nPts = 0;
        ce = struct('certified', false, 'lowerBound', NaN, 'L', zeros(1, d), 'maxSlope', zeros(1, d), ...
            'factor', opts.LipschitzFactor, 'nCells', 0, 'nPoints', 0, 'finestStep', NaN, 'reason', '');
        if da == 0
            f = S.margin(1);
            ce.certified = strcmp(S.status{1}, 'OK') && f >= opts.Reserve;
            ce.lowerBound = f; ce.nPoints = 0; ce.finestStep = 0;
            ce.reason = 'degenerate box (a single point)';
            return
        end
        base = 0:s0:K;
        G = cell(1, da);
        [G{:}] = ndgrid(base(1:end - 1));
        C = [cell2mat(cellfun(@(g) g(:), G, 'UniformOutput', false)), s0 * ones(numel(G{1}), 1)];
        V = dec2bin(0:2^da - 1, da) - '0';               % vertex offsets of a cell
        V = fliplr(V);
        for ic = 1:size(C, 1), cellVals(C(ic, :)); end
        % local refinement around the minimum
        for lev = 1:opts.GridLocalLevels
            kb = bestVertex();
            near = all(C(:, 1:da) <= kb & C(:, 1:da) + C(:, end) >= kb, 2) & C(:, end) > 1;
            if ~any(near), break; end
            C = refine(C, near);
        end
        % Lipschitz certification
        maxS = zeros(1, da);
        why = '';
        while true
            [~, sl, ~, viol, nonok] = bounds(C);
            maxS = max(maxS, sl);
            Lc = opts.LipschitzFactor * maxS;           % the Lipschitz estimate: safety factor x measured slopes
            [LB, ~, bad] = bounds(C, Lc);
            if viol
                why = 'a grid point violates the reserve (a counterexample)'; break
            end
            if nonok
                why = 'a grid point is not OK'; break
            end
            if ~any(bad)
                ce.certified = true;
                why = sprintf('every cell certified: lower bound %.6g >= reserve %g', min(LB), opts.Reserve);
                break
            end
            canRef = bad & C(:, end) > 1;
            if ~any(canRef)
                why = sprintf(['the finest spacing (1/%d of the box) is reached with %d uncertified cell(s); ' ...
                    'lower bound %.6g < reserve %g'], K, sum(bad), min(LB), opts.Reserve);
                break
            end
            need = sum(canRef) * (3^da - 2^da);
            if nPts + need > opts.GridBudget
                why = sprintf(['the grid budget (%d points) would be exceeded; %d uncertified cell(s), lower ' ...
                    'bound %.6g < reserve %g'], opts.GridBudget, sum(bad), min(LB), opts.Reserve);
                break
            end
            C = refine(C, canRef);
        end
        [LB, ~, ~] = bounds(C, Lc);
        ce.lowerBound = min(LB);
        ce.maxSlope(act) = maxS;
        ce.L(act) = Lc;
        ce.nCells = size(C, 1);
        ce.nPoints = nPts;
        ce.finestStep = min(C(:, end)) / K;
        ce.reason = sprintf('%s (%d cells, %d lattice points, finest step %.4g of the box)', why, ce.nCells, ...
            nPts, ce.finestStep);

        function C2 = refine(C1, sel)
            kids = zeros(0, da + 1);
            for jc = find(sel(:)).'
                h2 = C1(jc, end) / 2;
                for jv = 1:size(V, 1)
                    kids(end+1, :) = [C1(jc, 1:da) + h2 * V(jv, :), h2]; %#ok<AGROW>
                end
            end
            C2 = [C1(~sel, :); kids];
            for jc = 1:size(kids, 1), cellVals(kids(jc, :)); end
        end

        function m = cellVals(cl)
            m = zeros(size(V, 1), 1);
            for jv = 1:size(V, 1)
                m(jv) = latticeValue(cl(1:da) + cl(end) * V(jv, :));
            end
        end

        function [f, ok] = latticeValue(kk)
            key = sprintf('%d,', kk);
            if isKey(vals, key)
                f = vals(key); ok = okv(key); return
            end
            th = lo;
            t = kk / K;
            th(act) = lo(act) + (hi(act) - lo(act)) .* t;
            th(act(kk == K)) = hi(act(kk == K));
            th = min(max(th, lo), hi);
            [f, ok] = evalPoint(th, 'grid');
            nPts = nPts + 1;
            vals(key) = f; okv(key) = ok;
        end

        function kb = bestVertex()
            ks = keys(vals);
            fv = cellfun(@(k) vals(k), ks);
            fv(isnan(fv)) = Inf;
            [~, jb] = min(fv);
            kb = sscanf(ks{jb}, '%d,').';
        end

        function [LB, sl, bad, viol, nonok] = bounds(C1, Ls)
            nc = size(C1, 1);
            LB = NaN(nc, 1); sl = zeros(1, da); viol = false; nonok = false;
            for jc = 1:nc
                m = cellVals(C1(jc, :));
                ok = arrayfun(@(jv) okv(sprintf('%d,', C1(jc, 1:da) + C1(jc, end) * V(jv, :))), 1:size(V, 1));
                if any(m < opts.Reserve), viol = true; end
                if ~all(ok), nonok = true; continue; end
                dt = C1(jc, end) / K;
                for ia = 1:da                            % edges along axis ia
                    lowv = find(V(:, ia) == 0);
                    for jv = lowv(:).'
                        jw = find(all(V == [V(jv, 1:ia - 1), 1, V(jv, ia + 1:end)], 2));
                        if isfinite(m(jv)) && isfinite(m(jw))
                            sl(ia) = max(sl(ia), abs(m(jw) - m(jv)) / dt);
                        end
                    end
                end
                if nargin > 1 && all(isfinite(m))
                    LB(jc) = min(m) - sum(Ls * dt / 2);
                elseif any(m == -Inf)
                    LB(jc) = -Inf;
                end
            end
            bad = isnan(LB) | LB < opts.Reserve;
        end
    end

    function o = runStart(x0, s)
        o = struct('start', x0, 'x', x0, 'fval', NaN, 'exitflag', NaN, 'funcCount', 0, 'converged', false, 'message', '');
        i0 = find(all(S.theta == x0, 2), 1);
        f0 = S.margin(i0);
        if ~isfinite(f0) || ~strcmp(S.status{i0}, 'OK')
            o.message = sprintf('objective not finite or not OK at the start (margin %g, %s): fmincon cannot run', ...
                f0, S.status{i0});
            return
        end
        count = 0;
        phase = sprintf('fmincon%d', s);
        oo = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', 'MaxFunctionEvaluations', opts.MaxEvals, ...
            'MaxIterations', 10 * opts.MaxEvals, 'FiniteDifferenceType', 'forward', ...
            'FiniteDifferenceStepSize', opts.FDStep);
        try
            [x, fval, flag, out] = fmincon(@objective, x0, [], [], [], [], lo, hi, [], oo);
            o.x = x; o.fval = fval; o.exitflag = flag; o.funcCount = count;
            o.converged = flag > 0;
            o.message = out.message;
            o.message = strtrim(regexprep(o.message, '\s+', ' '));
            if numel(o.message) > 300, o.message = [o.message(1:300) '...']; end
        catch err
            o.funcCount = count;
            switch err.identifier
                case 'vital:uq:budget'
                    o.exitflag = 0;
                    o.message = sprintf('budget of %d evaluations exhausted', opts.MaxEvals);
                case 'vital:uq:divergent'
                    o.exitflag = -100;
                    o.message = 'stopped at a divergent point (margin -Inf): a counterexample';
                otherwise
                    o.exitflag = NaN;
                    o.message = sprintf('fmincon failed: %s: %s', err.identifier, err.message);
            end
            [fb, kb] = min(S.margin(strcmp(S.phase, phase)));
            if ~isempty(fb)
                T2 = S.theta(strcmp(S.phase, phase), :);
                o.x = T2(kb, :); o.fval = fb;
            end
        end

        function f = objective(x)
            if count >= opts.MaxEvals
                error('vital:uq:budget', 'evaluation budget exhausted');
            end
            count = count + 1;
            [f, okp] = evalPoint(x(:).', phase);   % sqp honours the bounds (never clipped here)
            if f == -Inf
                error('vital:uq:divergent', 'divergent point');
            end
            if ~okp, f = NaN; end
        end
    end
end

% =========================================================================================
function validateOptions(o)
if ~any(strcmp(o.Method, {'sqp', 'hybrid', 'grid'}))
    error('vital:badInput', 'Method must be ''sqp'', ''hybrid'' or ''grid'' (got ''%s'').', o.Method);
end
isInt = @(v, m) isfinite(v) && v >= m && v == round(v);
if ~isInt(o.GridPoints, 2) || ~isInt(o.GridMaxRefine, 0) || ~isInt(o.GridLocalLevels, 0) || ~isInt(o.GridBudget, 1)
    error('vital:badInput', 'GridPoints must be an integer >= 2; GridMaxRefine, GridLocalLevels >= 0; GridBudget >= 1.');
end
if ~(isfinite(o.LipschitzFactor) && o.LipschitzFactor >= 1)
    error('vital:badInput', 'LipschitzFactor must be >= 1 (a safety factor on the measured slopes).');
end
if ~(o.DEPopulation == 0 || isInt(o.DEPopulation, 4)) || ~isInt(o.DEGenerations, 0)
    error('vital:badInput', 'DEPopulation must be 0 (no global stage) or an integer >= 4; DEGenerations >= 0.');
end
if ~(o.DEF > 0 && o.DEF <= 2) || ~(o.DECR >= 0 && o.DECR <= 1)
    error('vital:badInput', 'DEF must lie in (0, 2] and DECR in [0, 1].');
end
if ~(o.TolX > 0 && o.TolFun > 0)
    error('vital:badInput', 'TolX and TolFun must be > 0.');
end
end

function P = validateProblem(P)
need = {'names', 'lo', 'hi', 'nominal', 'conditions', 'condLabels', 'pointFcn'};
for k = 1:numel(need)
    if ~isfield(P, need{k})
        error('vital:badInput', 'boundWorst problem lacks field "%s".', need{k});
    end
end
if ~isfield(P, 'confirmFcn'), P.confirmFcn = []; end
d = numel(P.lo);
if d == 0 || numel(P.hi) ~= d || numel(P.nominal) ~= d || numel(P.names) ~= d
    error('vital:badInput', 'names, lo, hi and nominal must have the same non-zero length.');
end
P.lo = double(P.lo(:).'); P.hi = double(P.hi(:).'); P.nominal = double(P.nominal(:).');
if ~all(isfinite([P.lo P.hi P.nominal])) || any(P.lo > P.hi)
    error('vital:badInput', 'the box must be finite with lo <= hi.');
end
if any(P.nominal < P.lo | P.nominal > P.hi)
    error('vital:badInput', 'the nominal point must lie inside the box.');
end
if ~iscell(P.conditions) || isempty(P.conditions) || numel(P.condLabels) ~= numel(P.conditions)
    error('vital:badInput', 'conditions must be a non-empty cell with one label per condition.');
end
if ~isa(P.pointFcn, 'function_handle')
    error('vital:badInput', 'pointFcn must be a function handle q = f(theta, cond).');
end
if ~isempty(P.confirmFcn) && ~isa(P.confirmFcn, 'function_handle')
    error('vital:badInput', 'confirmFcn must be a function handle or [].');
end
end
