function bw = boundWorst(problem, opts)
%BOUNDWORST  Bound-worst margin over a parameter box (M8; generic, no aircraft).
%   bw = vital.uq.boundWorst(problem)
%   bw = vital.uq.boundWorst(problem, 'NumLHS', 32, 'Seed', 2026, 'NumStarts', 2,
%                            'MaxEvals', 60, 'FDStep', 1e-3, 'Reserve', 0)
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
%                 c.record, c.reason
%
%   SEARCH (every evaluated point is kept). At a point theta the margin is the
%   minimum over the candidate conditions that are OK (NaN if none is) and the
%   point is OK only if every condition is OK; an exception in pointFcn is a
%   point with status ERROR and the exception's identifier in its reason.
%     1. the nominal point (phase 'centre')
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
%   Bound-worst = the minimum margin over EVERY evaluated point; the arg-min
%   (theta, condition, record) is the active set.
%   CONFIRMATION: when confirmFcn is given it is called at the arg-min. If it
%   finds a smaller margin (a moving limit: the critical condition changed with
%   the parameters), that margin and condition REPLACE the search value and
%   bw.confirmation.moved is true.
%   STATUS
%     'VIOLATED'        some evaluated point (or the confirmation) has margin <
%                       Reserve: a counterexample, definitive even if the
%                       optimizer did not converge
%     'NOT_ASSESSABLE'  no counterexample, and a point inside the box is not OK
%                       (trim infeasible, metric NaN, ...) or the confirmation is
%                       not OK, or an optimizer start did not converge (FC-901;
%                       the reason then starts with 'FC-901')
%     'OK'              every evaluated point OK, every start converged
%   bw fields: status, reason, value, searchValue, theta, cond (label), record,
%     nominal (margin, cond, record, status at the centre), points (theta
%     (nE x d), phase, margin, cond, record, status, reason, condMargin
%     (nE x nC)), nEvaluated, optimizer (struct array: start, x, fval,
%     exitflag, funcCount, converged, message), converged, confirmation
%     (evaluated, status, margin, cond, record, moved, reason), nonOK (indices
%     into points), reserve, options, names, lo, hi.
%   Errors: vital:badInput (inconsistent problem: sizes, lo > hi, nominal
%   outside the box, no condition, pointFcn not a function handle).
arguments
    problem (1,1) struct
    opts.NumLHS (1,1) double = 32
    opts.Seed (1,1) double = 2026
    opts.NumStarts (1,1) double = 2
    opts.MaxEvals (1,1) double = 60
    opts.FDStep (1,1) double = 1e-3
    opts.Reserve (1,1) double = 0
end
P = validateProblem(problem);
d = numel(P.lo);
nC = numel(P.conditions);
lo = P.lo; hi = P.hi;

S = struct('theta', zeros(0, d), 'phase', {cell(0, 1)}, 'margin', zeros(0, 1), 'cond', {cell(0, 1)}, ...
    'record', {cell(0, 1)}, 'status', {cell(0, 1)}, 'reason', {cell(0, 1)}, 'condMargin', zeros(0, nC));

% ---- 1. centre --------------------------------------------------------------------------
evalPoint(P.nominal, 'centre');
bw.nominal = struct('margin', S.margin(1), 'cond', S.cond{1}, 'record', S.record{1}, 'status', S.status{1});

% ---- 2. corners -------------------------------------------------------------------------
for k = 0:2^d - 1
    bits = bitget(k, 1:d);
    th = lo;
    th(bits == 1) = hi(bits == 1);
    evalPoint(th, 'corner');
end

% ---- 3. seeded Latin hypercube -----------------------------------------------------------
n = opts.NumLHS;
if n > 0
    rs = RandStream('mt19937ar', 'Seed', opts.Seed);
    U = zeros(n, d);
    for j = 1:d
        U(:, j) = (randperm(rs, n).' - rand(rs, n, 1)) / n;
    end
    for i = 1:n
        evalPoint(lo + (hi - lo) .* U(i, :), 'lhs');
    end
end

% ---- 4. fmincon from the best distinct points --------------------------------------------
[~, ord] = sort(S.margin);
T = S.theta(ord, :);
[~, iu] = unique(T, 'rows', 'stable');
nS = min(opts.NumStarts, numel(iu));
starts = T(iu(1:nS), :);
O = struct('start', {}, 'x', {}, 'fval', {}, 'exitflag', {}, 'funcCount', {}, 'converged', {}, 'message', {});
for s = 1:nS
    O(s) = runStart(starts(s, :), s); %#ok<AGROW>
end

% ---- bound-worst and active set -----------------------------------------------------------
bw.points = S;
bw.nEvaluated = numel(S.margin);
bw.optimizer = O;
bw.converged = nS > 0 && all([O.converged]);
bw.reserve = opts.Reserve;
bw.options = opts;
bw.names = P.names; bw.lo = lo; bw.hi = hi;
use = find(~isnan(S.margin));
if isempty(use)
    bw.value = NaN; bw.theta = NaN(1, d); bw.cond = ''; bw.record = '';
else
    [bw.value, k] = min(S.margin(use));
    k = use(k);
    bw.theta = S.theta(k, :); bw.cond = S.cond{k}; bw.record = S.record{k};
end
bw.searchValue = bw.value;

% ---- confirmation ----------------------------------------------------------------------------
bw.confirmation = struct('evaluated', false, 'status', '', 'margin', NaN, 'cond', '', 'record', '', ...
    'moved', false, 'reason', 'no confirmation function');
if ~isempty(P.confirmFcn) && all(isfinite(bw.theta))
    try
        c = P.confirmFcn(bw.theta);
    catch err
        c = struct('status', 'ERROR', 'margin', NaN, 'condLabel', '', 'record', '', ...
            'reason', sprintf('%s: %s', err.identifier, err.message));
    end
    bw.confirmation = struct('evaluated', true, 'status', c.status, 'margin', c.margin, 'cond', c.condLabel, ...
        'record', c.record, 'moved', false, 'reason', c.reason);
    if strcmp(c.status, 'OK') && c.margin < bw.value
        bw.confirmation.moved = true;
        bw.confirmation.reason = sprintf(['moving limit: the confirmation found margin %.6g at %s (%s), smaller ' ...
            'than the search value %.6g at %s (%s); it replaces the search value'], c.margin, c.condLabel, ...
            c.record, bw.value, bw.cond, bw.record);
        bw.value = c.margin; bw.cond = c.condLabel; bw.record = c.record;
    elseif strcmp(c.status, 'OK') && c.margin > bw.value
        bw.confirmation.reason = sprintf(['the confirmation margin %.6g is above the search value %.6g (the ' ...
            'confirmation does not cover the candidate %s?); the search value is kept'], c.margin, bw.value, bw.cond);
    elseif strcmp(c.status, 'OK')
        bw.confirmation.reason = 'the confirmation reproduces the search value';
    end
end

% ---- status ------------------------------------------------------------------------------------
bw.nonOK = find(~strcmp(S.status, 'OK')).';
confOK = ~bw.confirmation.evaluated || strcmp(bw.confirmation.status, 'OK');
viol = find(S.margin < opts.Reserve);
confViol = bw.confirmation.evaluated && confOK && bw.confirmation.margin < opts.Reserve;
if ~isempty(viol) || confViol
    bw.status = 'VIOLATED';
    if confViol && bw.confirmation.moved
        bw.reason = sprintf('counterexample (confirmation, moving limit): margin %.6g < reserve %g at %s (%s), theta %s', ...
            bw.value, opts.Reserve, bw.cond, bw.record, mat2str(bw.theta, 6));
    else
        bw.reason = sprintf('counterexample: margin %.6g < reserve %g at %s (%s), theta %s; %d of %d evaluated points violate', ...
            bw.value, opts.Reserve, bw.cond, bw.record, mat2str(bw.theta, 6), numel(viol), bw.nEvaluated);
    end
    if ~bw.converged
        bw.reason = [bw.reason '; definitive although the optimizer did not converge'];
    end
elseif ~isempty(bw.nonOK) || ~confOK || ~bw.converged
    bw.status = 'NOT_ASSESSABLE';
    why = {};
    if ~bw.converged
        bad = find(~[O.converged]);
        if isempty(bad), txt = 'no optimizer start'; else
            txt = strjoin(arrayfun(@(i) sprintf('start %d exit flag %g (%s)', i, O(i).exitflag, O(i).message), bad, ...
                'UniformOutput', false), '; ');
        end
        why{end+1} = sprintf('FC-901: the optimizer did not converge (%s) and no counterexample was found', txt);
    end
    if ~isempty(bw.nonOK)
        i = bw.nonOK(1);
        why{end+1} = sprintf('%d of %d evaluated points are not OK inside the box, e.g. %s (%s) at theta %s', ...
            numel(bw.nonOK), bw.nEvaluated, S.status{i}, S.reason{i}, mat2str(S.theta(i, :), 6));
    end
    if ~confOK
        why{end+1} = sprintf('the confirmation is not OK: %s (%s)', bw.confirmation.status, bw.confirmation.reason);
    end
    if ~bw.converged && (~isempty(bw.nonOK) || ~confOK)
        why = [why(2:end), why(1)];   % the non-OK points are the primary reason
    end
    bw.reason = strjoin(why, '; ');
else
    bw.status = 'OK';
    bw.reason = sprintf('every evaluated point OK (%d), every optimizer start converged; bound-worst %.6g >= reserve %g', ...
        bw.nEvaluated, bw.value, opts.Reserve);
end
bw = orderfields(bw);

% =========================================================================================
    function [f, ok] = evalPoint(th, phase)
        m = NaN(1, nC); st = 'OK'; why = ''; recs = repmat({''}, 1, nC);
        for kc = 1:nC
            try
                q = P.pointFcn(th, P.conditions{kc});
            catch err
                q = struct('status', 'ERROR', 'margin', NaN, 'record', '', ...
                    'reason', sprintf('%s: %s', err.identifier, err.message));
            end
            if strcmp(q.status, 'OK')
                m(kc) = q.margin; recs{kc} = q.record;
            elseif strcmp(st, 'OK')
                st = q.status;
                why = sprintf('%s: %s', P.condLabels{kc}, q.reason);
            end
        end
        okc = find(~isnan(m));
        if isempty(okc)
            f = NaN; cl = ''; rc = '';
        else
            [f, j] = min(m(okc));
            cl = P.condLabels{okc(j)}; rc = recs{okc(j)};
        end
        S.theta(end+1, :) = th;
        S.phase{end+1, 1} = phase;
        S.margin(end+1, 1) = f;
        S.cond{end+1, 1} = cl;
        S.record{end+1, 1} = rc;
        S.status{end+1, 1} = st;
        S.reason{end+1, 1} = why;
        S.condMargin(end+1, :) = m;
        ok = strcmp(st, 'OK');
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
