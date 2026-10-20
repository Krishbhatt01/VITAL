function res = lattice(problem, opts)
%LATTICE  Shared adaptive lattice of the longitudinal groups (M8 amendment R4b,
%   R4-3 corrected; docs/PLAN_M5_M8.md "Amendment R4b"; generic, no aircraft).
%   res = vital.uq.lattice(problem)
%   res = vital.uq.lattice(problem, 'GridPoints', 11, 'MaxLevel', 10,
%         'MaxPoints', 20000, 'LipschitzFactor', 2, 'AlphaMax', 3,
%         'Resolution', 0.01, 'Reserve', 0, 'MaxRounds', 3, 'DecideAt', 1,
%         'Boxes', struct('name', 'x1', 'alpha', 1))
%
%   ONE lattice over the AlphaMax box of the judged shape, nominal +/- AlphaMax
%   m, evaluated ONCE per candidate condition and reused by every group, both
%   reference shapes and every CSR alpha. No box search is run: alpha* is read
%   from the lattice, and the CPV is confirmed by the group's fresh assessment.
%
%   problem fields
%     names, nominal (1 x d, d <= 3), m (1 x d > 0: the judged half-widths;
%                 the lattice box is nominal +/- AlphaMax m, which must be >= 0)
%     conditions, condLabels   1 x nC cell / cellstr (opaque conditions)
%     pointFcn    q = f(theta, cond): ONE call gives every group: q.status
%                 (1 x nG cellstr, 'OK' or not), q.margin (1 x nG), q.record
%                 (1 x nG cellstr), q.reason (1 x nG cellstr). An exception is a
%                 point with status 'ERROR' for every group.
%     groups      struct array: name, conds (indices into conditions: the
%                 group's candidate conditions), confirmFcn ([] or c = f(theta):
%                 a FRESH assessment over all conditions: c.status, c.margin,
%                 c.condLabel, c.cond, c.record, c.reason)
%     shapes      struct array: name, m (1 x d > 0); every shape's cap box
%                 nominal +/- AlphaMax m must lie inside the lattice box
%   'Boxes'       extra boxes reported per group in the bound-worst form
%                 (res.groups(g).boxes(b)): name, alpha (in the units of
%                 problem.m, e.g. the x1 box: alpha 1)
%
%   LATTICE. Integer coordinates k (0..K per axis, K = (GridPoints - 1)
%   2^MaxLevel), theta = lo + (hi - lo) .* (k ./ K), with theta = hi exactly
%   at k = K and theta = nominal exactly at k = K/2 (GridPoints odd). It
%   starts with GridPoints points per axis (the base cells of size 2^MaxLevel).
%   A point is evaluated at a condition only when a group that has the
%   condition needs it, and never twice. A group's margin at a point is the
%   minimum over its conditions that are OK; the point is OK for the group
%   only if every one of them is; it FAILS when an OK condition has margin <
%   Reserve (a counterexample, even if another condition is not OK).
%   CERTIFICATE of a cell (per group): bound = min(vertex margins) -
%   sum_i L_i h_i (the contract's "cell minimum - L h"), h_i the cell's edge
%   along axis i (theta units), L_i = LipschitzFactor x the largest measured
%   slope |dm|/dtheta_i over the cell's own edges along i and over the base
%   edges along i of the base cells within one base cell of it (its 3^d base
%   neighbourhood: the measured LOCAL slopes; a kink inside a base cell is seen
%   through its neighbours). Certified: every vertex OK and bound >= Reserve.
%   The Lipschitz constant is an ESTIMATE from measured secants:
%   'grid-certified (Lipschitz estimate)', not a proof.
%   REFINEMENT (only near the zero level set): a cell is subdivided while it
%   is not certified, every vertex is OK, it is not at MaxLevel, and it can
%   still move alpha* of some shape: its entry alpha (the smallest alpha whose
%   box R(alpha) = nominal +/- alpha m meets the cell) is below
%   min(alphaHi - Resolution, the entry alpha of the first cell with a non-OK
%   vertex), or, with no failure known, at most AlphaMax, or (first shape only,
%   'DecideAt' a) at most a while a lies strictly inside the bracket. This
%   covers the contract's "certified bound < 0 and sampled minimum > 0" cells
%   and, so that alpha* can be resolved to the Resolution, the cells that
%   straddle the zero level set (some vertex failing). Subdivision is
%   ANISOTROPIC: the axes whose term L_i h_i is at least half the largest are
%   halved; a cell whose dominant axis is already at the finest spacing is
%   exhausted. Cells with a non-OK vertex are never subdivided. CAPS: MaxLevel
%   halvings per axis and MaxPoints lattice points PER GROUP (the points of
%   the group's own cells, the base lattice included). The cap is per group,
%   so sharing the lattice with other groups never changes a group's answer
%   (res.lattice.capped, cappedGroups).
%   PER BOX R(alpha) (res.box, and the 'Boxes'): 'VIOLATED' when a lattice
%   point inside fails; else 'NOT_ASSESSABLE' when a lattice point inside is
%   not OK, or when a cell meeting the box is not certified (reason starting
%   'GRID'); else 'OK'. A cell MEETS a box when their interiors intersect (on
%   an axis where the box has no width: when the closed cell contains it): a
%   box point on the boundary of a cell that only touches the box also lies in
%   a cell whose interior meets the box, and the certificate holds on closed
%   cells. So R(alphaLo) itself is certified.
%   CSR per group and shape (vital.uq.csr's fields): alphaLo = min(AlphaMax,
%   the smallest entry alpha of a non-certified cell); alphaHi = the smallest
%   scaled infinity norm max_i |theta_i - nominal_i| / m_i of a failing lattice
%   point within the cap (Inf if none); the CPV is that point (ties: the
%   smaller margin).
%     'OK'             alphaHi - alphaLo <= Resolution and the CPV confirmed
%                      (fresh assessment OK with margin < Reserve, not moving);
%                      alphaStar = alphaLo
%     'ROBUST_TO_CAP'  no failing point within the cap box and every cell
%                      meeting it certified; the arg-min of the cap box
%                      confirmed without a moving limit
%     'NOT_ASSESSABLE' otherwise (a non-OK lattice point, the caps ('GRID'),
%                      a confirmation that is not OK, or MOVING_LIMIT)
%   MOVING LIMIT (R3-M4): after the refinement, every group's CPVs, cap-box
%   arg-mins and 'Boxes' arg-mins are confirmed by its confirmFcn. A smaller
%   confirmed margin at a condition that is not one of the group's adds that
%   condition (the lattice is then evaluated there, once) and the refinement
%   is repeated: at most MaxRounds rounds; a confirmation still moving after
%   the last round makes its item NOT_ASSESSABLE ('MOVING_LIMIT').
%
%   AMENDMENT R5 (docs/PLAN_M5_M8.md "Amendment R5", coordinator 2026-10-14;
%   it supersedes the text above where they differ):
%   R5-1 'Certificate' 'half' (default): bound = min(vertex margins) - sum_i
%     L_i h_i / 2 (every point of a cell lies within h_i/2 of a vertex along
%     each axis); 'full' keeps the R4b form.
%   R5-2 refinement priority per group: (1) the cells deciding R(DecideAt) of the
%     first (judged) shape, (2) the judged shape to the Resolution, (3) the other
%     shapes at what the caps leave (reported as brackets). Every csr result has
%     lowerCertified / lowerReason: R(alphaLo) is certified over the final
%     candidates (its cells certified by construction; no confirmation item of
%     the final round moved; no corner, box or cap check inside R(alphaLo) whose
%     point evaluation or fresh confirmation fails or is not OK). A status 'OK'
%     or 'ROBUST_TO_CAP' whose lower end is not certified becomes NOT_ASSESSABLE.
%   R5-3 problem.switches (optional; struct array name, breakpoints) and
%     q.switchVals (1 x numel(switches)): the side of a point at a condition =
%     the number of breakpoints below each switching value. Slopes are never
%     measured over an edge whose ends lie on different sides (own edges and the
%     3^d base neighbourhood). A cell whose vertices lie on different sides at a
%     condition (it STRADDLES) is certified piecewise: per condition and side,
%     min(margins of the vertices of that side) - sum_i L_i h_i with the FULL
%     edge h (a planar cut leaves each side a vertex within one edge), L = factor
%     x the slopes at that condition (own edges and neighbourhood that do not
%     cross); its bound is the minimum over the conditions and sides.
%     res.groups(g).discontinuity: present, nCells, nCertified, variables,
%     breakpoints, maxJump, crossings (variable, breakpoint, maxJump, nEdges),
%     text.
%   R5-5 M2 'CornerChecks' (default true): each round also confirms the group at
%     the 2^d corners of R(DecideAt) and R(alphaLo) of the judged shape (extra
%     check points, evaluated by pointFcn at the group's conditions but never
%     vertices of a cell; res.lattice.nExtra), with the moving-limit rule of the
%     other items (item.kind 'corner'). res.groups(g).scope states what the
%     certificate covers.
%   m2: any exception inside pointFcn is an ERROR point; a malformed result is
%     vital:uq:badPointResult. m3: a cell whose vertices are all +Inf is not
%     certified and not refined. m5: 'MaxTotalPoints' (default Inf) caps the
%     lattice points of all groups together (res.lattice.budgetExhausted; the
%     capped groups' reasons say 'global').
%
%   res fields: groups (name, conds, condLabels, conditions, csr (1 x nS, the
%     fields of vital.uq.csr plus method 'lattice', label, lattice), boxes
%     (bound-worst compatible: status, reason, value, theta, cond, condition,
%     record, nominal, points, nEvaluated, optimizer, converged, confirmation,
%     rounds, nRounds, conditions, condLabels, nonOK, reserve, options, names,
%     lo, hi, method 'lattice', label, stages, certificate), certificate
%     (certified, lowerBound, L, maxSlope, factor, nCells, nPoints,
%     finestStep, reason: over the group's cells), rounds (round, candidates,
%     moved, confirmations)), box (handle st = res.box(g, lo, hi): status,
%     reason, value, theta, cond, lowerBound, nCells, nPoints; it reads the
%     final lattice and never evaluates), lattice (lo, hi, K, nPoints, nBase,
%     nEvaluations (per condition), nCells (per group), capped, cappedGroups,
%     finestStep),
%     conditions, condLabels, counts (pointEvals, confirmations), options.
%   Errors: vital:badInput (problem fields, d > 3, GridPoints not odd >= 3,
%   MaxLevel / MaxPoints / MaxRounds not positive integers, LipschitzFactor <
%   1, AlphaMax or Resolution not > 0, a group condition index out of range, a
%   shape cap box outside the lattice box, switches without strictly increasing
%   breakpoints); vital:uq:badPointResult (a malformed pointFcn result, R5 m2);
%   vital:uq:negativeMultiplier (nominal - AlphaMax m < 0).
arguments
    problem (1,1) struct
    opts.GridPoints (1,1) double = 11
    opts.MaxLevel (1,1) double = 10
    opts.MaxPoints (1,1) double = 20000
    opts.LipschitzFactor (1,1) double = 2
    opts.AlphaMax (1,1) double = 3
    opts.Resolution (1,1) double = 0.01
    opts.Reserve (1,1) double = 0
    opts.MaxRounds (1,1) double = 3
    opts.DecideAt (1,:) double = 1
    opts.Boxes struct = struct('name', {}, 'alpha', {})
    opts.Certificate (1,:) char {mustBeMember(opts.Certificate, {'half', 'full'})} = 'half'
    opts.CornerChecks (1,1) logical = true
    opts.MaxTotalPoints (1,1) double = Inf
end
P = validate(problem, opts);
d = numel(P.nominal); nG = numel(P.groups); nS = numel(P.shapes);
nom = P.nominal; Amax = opts.AlphaMax; Res = opts.Resolution; Rsv = opts.Reserve; fac = opts.LipschitzFactor;
if strcmp(opts.Certificate, 'full'), hf = 1; else, hf = 0.5; end   % R5-1: h/2 (the geometric bound)
SW = P.switches; nSw = numel(SW);                 % R5-3: switching variables (aero-table breakpoints)
budgetHit = false;
LO = nom - Amax * P.m; HI = nom + Amax * P.m;
ng = opts.GridPoints; s0 = 2^opts.MaxLevel; K = (ng - 1) * s0; nb = ng - 1;
tolA = 1e-12;
conds = P.conditions(:).'; labels = P.condLabels(:).';
nv = 2^d;
% (parent-level names below are unique (suffix _p): nested functions share any name they assign)
VO = zeros(nv, d);
for j_p = 0:nv - 1, VO(j_p + 1, :) = bitget(j_p, 1:d); end
EP = cell(1, d);                                  % vertex pairs of the edges along each axis
for i_p = 1:d
    a_p = find(VO(:, i_p) == 0);
    b_p = zeros(size(a_p));
    for j_p = 1:numel(a_p)
        w_p = VO(a_p(j_p), :); w_p(i_p) = 1;
        b_p(j_p) = find(all(VO == w_p, 2));
    end
    EP{i_p} = [a_p b_p];
end
W = (K + 1) .^ (0:d - 1);                         % integer key weights (exact below 2^53 for d <= 3)

% ---- stores ------------------------------------------------------------------------------
capN = 4096; nP = 0;
PK = zeros(capN, d); PT = zeros(capN, d);
pmap = containers.Map('KeyType', 'double', 'ValueType', 'double');
strT = {'', 'OK'}; smap = containers.Map(strT, {1, 2});
evDone = {}; evM = {}; evOK = {}; evRec = {}; evSt = {}; evWhy = {}; evSw = {}; evCode = {};
for c_p = 1:numel(conds), newCondStore(); end
nCalls = 0; nConf = 0;
isX = false(capN, 1); nX = 0;                     % extra (non-lattice) check points: corners of R(alpha)
xmap = containers.Map('KeyType', 'char', 'ValueType', 'double');
GR = struct('conds', {}, 'C', {}, 'H', {}, 'V', {}, 'X', {}, 'rounds', {}, 'mem', {}, 'nPts', {}, 'capped', {}, ...
    'cappedGlobal', {});
confCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

% ---- base lattice ---------------------------------------------------------------------------
g1_p = cell(1, d);
[g1_p{:}] = ndgrid(0:ng - 1);
BK_p = cell2mat(cellfun(@(z) z(:), g1_p, 'UniformOutput', false)) * s0;
for r_p = 1:size(BK_p, 1), ensurePoint(BK_p(r_p, :)); end
nBase = nP;
gb_p = cell(1, d);
[gb_p{:}] = ndgrid(0:nb - 1);
BC = cell2mat(cellfun(@(z) z(:), gb_p, 'UniformOutput', false)) * s0;     % base cell corners, linear order
nBC = size(BC, 1);
BV = zeros(nBC, nv);
for r_p = 1:nBC
    for j_p = 1:nv, BV(r_p, j_p) = ensurePoint(BC(r_p, :) + s0 * VO(j_p, :)); end
end
hT0 = (HI - LO) / nb;
for g_p = 1:nG
    GR(g_p).conds = P.groups(g_p).conds(:).';
    GR(g_p).C = BC; GR(g_p).H = s0 * ones(nBC, d); GR(g_p).V = BV; GR(g_p).X = false(nBC, 1);
    GR(g_p).rounds = struct('round', {}, 'candidates', {}, 'moved', {}, 'confirmations', {});
    GR(g_p).mem = false(capN, 1); GR(g_p).mem(unique(BV(:))) = true;
    GR(g_p).nPts = numel(unique(BV(:))); GR(g_p).capped = false; GR(g_p).cappedGlobal = false;
end
nomIdx = ensurePoint((K / 2) * ones(1, d));

% ---- rounds: refine, confirm, re-evaluate at a moved condition ------------------------------
CF = cell(nG, 1);                                 % the last confirmations per group
for ir_p = 1:opts.MaxRounds
    refineAll();
    moved_p = false;
    for g_p = 1:nG
        [CF{g_p}, mv_p, nc_p] = confirmGroup(g_p);
        GR(g_p).rounds(end+1) = struct('round', ir_p, 'candidates', {labels(GR(g_p).conds)}, 'moved', mv_p, ...
            'confirmations', CF{g_p});
        if mv_p && ir_p < opts.MaxRounds
            GR(g_p).conds = [GR(g_p).conds nc_p];
            moved_p = true;
        end
    end
    if ~moved_p, break; end
end

% ---- results -----------------------------------------------------------------------------------
FS = cell(nG, 1);
for g_p = 1:nG, FS{g_p} = cellStats(g_p); end
res.lattice = struct('lo', LO, 'hi', HI, 'K', K, 'nPoints', nP - nX, 'nBase', nBase, ...
    'nEvaluations', cellfun(@(z) sum(z(1:nP)), evDone), 'nCells', arrayfun(@(z) size(z.C, 1), GR), ...
    'capped', any([GR.capped]), 'cappedGroups', {{P.groups([GR.capped]).name}}, 'finestStep', finest(), ...
    'nExtra', nX, 'budgetExhausted', budgetHit, 'maxTotalPoints', opts.MaxTotalPoints);
G_p = struct('name', {}, 'conds', {}, 'condLabels', {}, 'conditions', {}, 'csr', {}, 'boxes', {}, ...
    'certificate', {}, 'rounds', {}, 'discontinuity', {}, 'scope', {});
for g_p = 1:nG
    e_p = struct();
    e_p.name = P.groups(g_p).name;
    e_p.conds = GR(g_p).conds;
    e_p.condLabels = labels(GR(g_p).conds);
    e_p.conditions = conds(GR(g_p).conds);
    cs_p = [];
    for s_p = 1:nS
        x_p = csrOf(g_p, s_p);
        if isempty(cs_p), cs_p = x_p; else, cs_p(s_p) = x_p; end %#ok<AGROW>
    end
    e_p.csr = cs_p;
    bx_p = [];
    for b_p = 1:numel(opts.Boxes)
        x_p = boxOf(g_p, opts.Boxes(b_p));
        if isempty(bx_p), bx_p = x_p; else, bx_p(b_p) = x_p; end %#ok<AGROW>
    end
    if isempty(bx_p), bx_p = struct([]); end
    e_p.boxes = bx_p;
    e_p.certificate = certOf(g_p);
    e_p.rounds = GR(g_p).rounds;
    e_p.discontinuity = discOf(g_p);
    e_p.scope = sprintf(['certified over the candidate condition(s) %s only; the other conditions are checked by ' ...
        'fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins%s'], ...
        strjoin(labels(GR(g_p).conds), '; '), ifs(opts.CornerChecks, ' and the 2^d corners of R(1) and R(alphaLo)', ''));
    if isempty(G_p), G_p = e_p; else, G_p(g_p) = e_p; end %#ok<AGROW>
end
res.groups = G_p;
res.box = @(gq, blo, bhi) boxQuery(gq, blo, bhi);
res.conditions = conds;
res.condLabels = labels;
res.counts = struct('pointEvals', nCalls, 'confirmations', nConf);
res.options = opts;

% =========================================================================================
    function newCondStore()
        evDone{end+1} = false(capN, 1);
        evM{end+1} = NaN(capN, nG);
        evOK{end+1} = false(capN, nG);
        evRec{end+1} = ones(capN, nG);
        evSt{end+1} = ones(capN, nG);
        evWhy{end+1} = ones(capN, nG);
        evSw{end+1} = NaN(capN, max(nSw, 1));
        evCode{end+1} = NaN(capN, 1);
    end

    function k = sidx(s)
        if isKey(smap, s), k = smap(s); else, strT{end+1} = s; k = numel(strT); smap(s) = k; end
    end

    function grow()
        n2 = 2 * capN;
        PK(n2, d) = 0; PT(n2, d) = 0;
        for cc = 1:numel(evDone)
            evDone{cc}(n2, 1) = false;
            evM{cc}(capN + 1:n2, :) = NaN;
            evOK{cc}(n2, nG) = false;
            evRec{cc}(capN + 1:n2, :) = 1;
            evSt{cc}(capN + 1:n2, :) = 1;
            evWhy{cc}(capN + 1:n2, :) = 1;
            evSw{cc}(capN + 1:n2, :) = NaN;
            evCode{cc}(capN + 1:n2, 1) = NaN;
        end
        isX(n2, 1) = false;
        for gg = 1:numel(GR), GR(gg).mem(n2, 1) = false; end
        capN = n2;
    end

    function idx = ensurePoint(kk)
        key = kk * W.';
        if isKey(pmap, key), idx = pmap(key); return; end
        if nP == capN, grow(); end
        nP = nP + 1; idx = nP;
        t = kk ./ K;
        th = LO + (HI - LO) .* t;
        th(kk == K) = HI(kk == K);
        th(kk == K / 2) = nom(kk == K / 2);
        PK(idx, :) = kk; PT(idx, :) = th;
        pmap(key) = idx;
    end

    function idx = ensureCheck(th)
        % R5-5 M2: a check point (a corner of R(alpha)): the lattice point when theta lies on
        % the lattice, else an EXTRA point (evaluated at the group's conditions like a lattice
        % point, never a vertex of a cell, not counted in nPoints)
        kk = (th - LO) ./ (HI - LO) * K;
        kr = round(kk);
        if all(abs(kk - kr) <= 1e-7) && all(kr >= 0 & kr <= K) && (isKey(pmap, kr * W.') || nP - nX < opts.MaxTotalPoints)
            idx = ensurePoint(kr);                   % a lattice point (within the global budget)
            return
        end
        key = sprintf('%.17g,', th);
        if isKey(xmap, key), idx = xmap(key); return; end
        if nP == capN, grow(); end
        nP = nP + 1; idx = nP; nX = nX + 1;
        PK(idx, :) = NaN; PT(idx, :) = th; isX(idx) = true;
        xmap(key) = idx;
    end

    function n = missingGlobal(kk)
        % lattice points of kk not yet in the lattice (the global budget, R5 m5)
        n = 0;
        for r2 = 1:size(kk, 1)
            if ~isKey(pmap, kk(r2, :) * W.'), n = n + 1; end
        end
    end

    function n = missingPoints(g, kk)
        % lattice points of kk that are not yet points of group g (the per-group budget)
        n = 0;
        for r2 = 1:size(kk, 1)
            key = kk(r2, :) * W.';
            if ~isKey(pmap, key) || ~GR(g).mem(pmap(key)), n = n + 1; end
        end
    end

    function evaluate(idx, c)
        idx = idx(~evDone{c}(idx));
        idx = unique(idx(:)).';
        for ii = idx
            th = PT(ii, :);
            try
                q = P.pointFcn(th, conds{c});
                failed = false;
            catch err
                % R5 m2: ANY exception inside the point evaluation (vital:badInput deep in the
                % chain included) is an ERROR point, never an abort of a multi-hour run
                q = struct('status', {repmat({'ERROR'}, 1, nG)}, 'margin', NaN(1, nG), ...
                    'record', {repmat({''}, 1, nG)}, 'reason', {repmat({sprintf('%s: %s', err.identifier, err.message)}, 1, nG)});
                failed = true;
            end
            if ~failed, q = checkQ(q); end           % a malformed result is a programming error: vital:uq:badPointResult
            nCalls = nCalls + 1;
            evDone{c}(ii) = true;
            ok = strcmp(q.status, 'OK');
            evOK{c}(ii, :) = ok;
            mm = q.margin(:).'; mm(~ok) = NaN;
            evM{c}(ii, :) = mm;
            for gg = 1:nG
                evRec{c}(ii, gg) = sidx(q.record{gg});
                evSt{c}(ii, gg) = sidx(q.status{gg});
                evWhy{c}(ii, gg) = sidx(q.reason{gg});
            end
            if nSw > 0 && isfield(q, 'switchVals')
                sv = double(q.switchVals(:).');
                evSw{c}(ii, 1:nSw) = sv;
                evCode{c}(ii) = sideCode(sv);
            end
        end
    end

    function k = sideCode(sv)
        % R5-3: the side of a point = the number of breakpoints below each switching
        % variable, combined into one integer (NaN when a variable is unknown)
        k = 0; base = 1;
        for jw = 1:nSw
            if ~isfinite(sv(jw)), k = NaN; return; end
            bpw = SW(jw).breakpoints;
            k = k + base * sum(sv(jw) > bpw);
            base = base * (numel(bpw) + 1);
        end
    end

    function q = checkQ(q)
        if ~isstruct(q) || ~all(isfield(q, {'status', 'margin'})) || ~iscell(q.status) || numel(q.status) ~= nG ...
                || ~isnumeric(q.margin) || numel(q.margin) ~= nG
            error('vital:uq:badPointResult', 'pointFcn must return q.status (1 x %d cellstr) and q.margin (1 x %d).', nG, nG);
        end
        if nSw > 0 && isfield(q, 'switchVals') && (~isnumeric(q.switchVals) || numel(q.switchVals) ~= nSw)
            error('vital:uq:badPointResult', 'q.switchVals must have %d numeric entries (one per switch).', nSw);
        end
        if ~isfield(q, 'record'), q.record = repmat({''}, 1, nG); end
        if ~isfield(q, 'reason'), q.reason = repmat({''}, 1, nG); end
    end

    function V = groupVals(g, idx)
        % per point (column vectors): margin, ok, fail, arg-min condition (global index), record,
        % status text and reason of the first non-OK condition
        cs = GR(g).conds;
        for cc = cs, evaluate(idx, cc); end
        idx = idx(:);
        n = numel(idx); nc = numel(cs);
        M = NaN(n, nc); OK = false(n, nc);
        for jc = 1:nc
            M(:, jc) = evM{cs(jc)}(idx, g);
            OK(:, jc) = evOK{cs(jc)}(idx, g);
        end
        [V.m, jm] = min(M, [], 2);
        V.ok = all(OK, 2);
        V.fail = any(OK & M < Rsv, 2);
        V.cond = cs(jm).';
        V.M = M;
        V.code = NaN(n, nc);
        for jc = 1:nc
            V.code(:, jc) = evCode{cs(jc)}(idx);
        end
        V.idx = idx;
        V.rec = zeros(n, 1);
        for jc = 1:nc
            sel = jm == jc;
            V.rec(sel) = evRec{cs(jc)}(idx(sel), g);
        end
        V.st = 2 * ones(n, 1); V.why = ones(n, 1); V.whyCond = zeros(n, 1);
        bad = find(~V.ok);
        for jj = bad(:).'
            jc = find(~OK(jj, :), 1);
            V.st(jj) = evSt{cs(jc)}(idx(jj), g);
            V.why(jj) = evWhy{cs(jc)}(idx(jj), g);
            V.whyCond(jj) = cs(jc);
        end
    end

    function S = cellStats(g)
        C = GR(g).C; H = GR(g).H; Vx = GR(g).V;
        n = size(C, 1);
        pts = unique(Vx(:));
        Vp = groupVals(g, pts);
        loc = zeros(nP, 1); loc(pts) = 1:numel(pts);
        Vm = reshape(Vp.m(loc(Vx)), n, nv);
        Vok = reshape(Vp.ok(loc(Vx)), n, nv);
        Vf = reshape(Vp.fail(loc(Vx)), n, nv);
        hT = (H / K) .* (HI - LO);
        nc = numel(GR(g).conds);
        Bv = groupVals(g, BV(:));
        CodeC = {}; BCode = {};                   % R5-3: per-condition sides of the vertices
        if nSw > 0
            CodeC = cell(1, nc); BCode = cell(1, nc);
            for jc = 1:nc
                CodeC{jc} = reshape(Vp.code(loc(Vx), jc), n, nv);
                BCode{jc} = reshape(Bv.code(:, jc), nBC, nv);
            end
        end
        Ms = Vm; Ms(~Vok) = NaN;
        own = slopes(Ms, hT, CodeC);
        % base neighbourhood slopes (edges across a breakpoint excluded, R5-3)
        Bm = reshape(Bv.m, nBC, nv); Bm(~reshape(Bv.ok, nBC, nv)) = NaN;
        BS = slopes(Bm, repmat(hT0, nBC, 1), BCode);
        NB = zeros(nBC, d);
        for ia = 1:d, NB(:, ia) = maxFilter(BS(:, ia)); end
        bsub = floor(C / s0);
        bsub = min(bsub, nb - 1);
        bl = 1 + bsub * (nb .^ (0:d - 1)).';
        sl = max(own, NB(bl, :));
        sl(isnan(sl)) = 0;
        L = fac * sl;
        allOK = all(Vok, 2);
        mn = min(Vm, [], 2);
        bound = mn - sum(L .* (hT * hf), 2);      % R5-1: cell minimum - sum L_i h_i / 2
        % R5-3: a cell whose vertices trim on both sides of a breakpoint at some condition
        % is certified PIECEWISE: per condition and side, the minimum over the vertices of
        % that side minus sum L_i h_i with the FULL edge (a planar cut leaves each side a
        % vertex within one edge), L from the edges that do not cross the breakpoint
        strad = false(n, 1);
        for jc = 1:numel(CodeC), strad = strad | rowStrad(CodeC{jc}); end
        js = find(strad & allOK);
        if ~isempty(js)
            NBc = cell(1, nc);
            for jc = 1:nc
                Bc = reshape(Bv.M(:, jc), nBC, nv);
                BSc = slopes(Bc, repmat(hT0, nBC, 1), BCode(jc));
                NBc{jc} = zeros(nBC, d);
                for ia = 1:d, NBc{jc}(:, ia) = maxFilter(BSc(:, ia)); end
            end
            for j = js(:).'
                vj = loc(Vx(j, :));
                bj = Inf; Lj = zeros(1, d);
                for jc = 1:nc
                    mc = Vp.M(vj, jc).';
                    cd = CodeC{jc}(j, :);
                    slp = max(slopes(mc, hT(j, :), {cd}), NBc{jc}(bl(j), :));
                    slp(isnan(slp)) = 0;
                    Lp = fac * slp;
                    u = unique(cd(~isnan(cd)));
                    if numel(u) <= 1
                        b = min(mc) - sum(Lp .* (hT(j, :) * hf));
                    else
                        b = Inf;
                        for uu = u
                            on = cd == uu | isnan(cd);
                            b = min(b, min(mc(on)) - sum(Lp .* hT(j, :)));
                        end
                    end
                    bj = min(bj, b); Lj = max(Lj, Lp);
                end
                bound(j) = bj; L(j, :) = Lj; sl(j, :) = Lj / fac;
            end
        end
        bound(~allOK) = NaN;
        bound(allOK & any(Vm == -Inf, 2)) = -Inf;
        infCell = allOK & all(Vm == Inf, 2);      % R5 m3: +Inf at every vertex bounds nothing between them
        bound(infCell) = NaN;
        S.n = n; S.C = C; S.H = H; S.V = Vx; S.hT = hT; S.L = L; S.slope = sl;
        S.allOK = allOK; S.anyFail = any(Vf, 2); S.bound = bound;
        S.strad = strad; S.infCell = infCell;
        S.certified = allOK & bound >= Rsv;
        S.cl = LO + (HI - LO) .* (C / K);
        S.ch = LO + (HI - LO) .* ((C + H) / K);
        S.pts = pts; S.P = Vp;
    end

    function s = slopes(Mv, hT, Codes)
        n = size(Mv, 1);
        s = zeros(n, d);
        for ia = 1:d
            D = abs(Mv(:, EP{ia}(:, 2)) - Mv(:, EP{ia}(:, 1)));
            D(~isfinite(D)) = NaN;
            for jw = 1:numel(Codes)              % R5-3: no slope is measured across a breakpoint
                Ca = Codes{jw}(:, EP{ia}(:, 1)); Cb = Codes{jw}(:, EP{ia}(:, 2));
                D(Ca ~= Cb & ~isnan(Ca) & ~isnan(Cb)) = NaN;
            end
            s(:, ia) = max(D, [], 2) ./ hT(:, ia);
        end
    end

    function t = rowStrad(Cd)
        t = max(Cd, [], 2) > min(Cd, [], 2);
    end

    function out = maxFilter(v)
        sz = [nb * ones(1, d), 1];
        A = reshape(v, sz);
        out = A;
        for ax = 1:d
            idx1 = repmat({':'}, 1, ndims(A)); idx2 = idx1;
            F = -Inf(size(A)); B = -Inf(size(A));
            idx1{ax} = 2:nb; idx2{ax} = 1:nb - 1;
            F(idx1{:}) = out(idx2{:});
            B(idx2{:}) = out(idx1{:});
            out = max(out, max(F, B));
        end
        out = out(:);
        out(isinf(out)) = NaN;
    end

    function e = entryAlpha(S, m)
        dist = max(0, max(S.cl - nom, nom - S.ch)) ./ m;
        e = max(dist, [], 2);
    end

    function r = pnorm(idx, m)
        r = max(abs(PT(idx, :) - nom) ./ m, [], 2);
    end

    function A = shapeState(S, s)
        % alpha* bracket of one shape from the cell statistics S
        m = P.shapes(s).m;
        A.e = entryAlpha(S, m);
        unc = ~S.certified;
        A.block = min([Inf; A.e(unc & ~S.allOK)]);
        inCap = A.e <= Amax + tolA;
        A.lo = min([Amax; A.e(unc & inCap)]);
        fp = S.pts(S.P.fail);
        A.hi = Inf; A.cpv = 0;
        if ~isempty(fp)
            nr = pnorm(fp, m);
            mm = S.P.m(S.P.fail);
            keep = nr <= Amax + tolA;
            if any(keep)
                fp = fp(keep); nr = nr(keep); mm = mm(keep);
                T = sortrows([nr, mm, (1:numel(nr)).']);
                A.hi = T(1, 1); A.cpv = fp(T(1, 3));
            end
        end
        A.unc = unc;
    end

    function sel = selectRefine(S, s, X, what)
        % what 'decide': the DecideAt cells of the first (judged) shape only (R5-2: the
        % verdict needs R(1) decided); 'resolve': the cells that can still move alpha*
        % of shape s to the Resolution
        A = shapeState(S, s);
        refinable = S.allOK & any(S.H > 1, 2) & ~X;
        refinable = refinable & ~S.infCell;        % R5 m3: refining an all-+Inf cell cannot certify it
        sel = false(S.n, 1);
        if strcmp(what, 'resolve')
            if isfinite(A.hi)
                if A.hi - A.lo > Res + tolA
                    sel = A.unc & refinable & A.e < min(A.hi - Res, A.block) - tolA;
                end
            else
                sel = A.unc & refinable & A.e <= Amax + tolA & A.e < A.block;
            end
        elseif s == 1
            for a = opts.DecideAt
                if A.lo < a - tolA && A.hi > a + tolA
                    sel = sel | (A.unc & refinable & A.e <= a + tolA & A.e < A.block);
                end
            end
        end
    end

    function sel = selectPhase(S, X)
        % R5-2 priority: (1) decide R(DecideAt) of the judged shape, (2) resolve the judged
        % shape to the Resolution, (3) the other shapes at whatever resolution the budget
        % leaves (they are reported as brackets)
        sel = selectRefine(S, 1, X, 'decide');
        if any(sel), return; end
        sel = selectRefine(S, 1, X, 'resolve');
        if any(sel), return; end
        for s = 2:nS
            sel = sel | selectRefine(S, s, X, 'resolve');
        end
    end

    function refineAll()
        while true
            any1 = false;
            for g = 1:nG
                if GR(g).capped, continue; end
                S = cellStats(g);
                sel = selectPhase(S, GR(g).X);
                if any(sel)
                    any1 = split(g, S, find(sel)) || any1;
                end
            end
            if ~any1, break; end
        end
    end

    function did = split(g, S, list)
        did = false;
        % the cells that move alpha* the most first: smallest entry alpha over the shapes
        e = inf(numel(list), 1);
        for s = 1:nS
            ee = entryAlpha(S, P.shapes(s).m);
            e = min(e, ee(list));
        end
        [~, o] = sort(e);
        list = list(o);
        keep = true(S.n, 1);
        newC = zeros(0, d); newH = zeros(0, d); newV = zeros(0, nv);
        for jc = list(:).'
            c = S.L(jc, :) .* S.hT(jc, :);
            Hc = S.H(jc, :);
            if all(c == 0 | isnan(c))
                ax = Hc > 1;
            else
                [mx, im] = max(c);
                if Hc(im) <= 1
                    GR(g).X(jc) = true;            % exhausted: the dominant axis is at the finest spacing
                    continue
                end
                ax = c >= 0.5 * mx & Hc > 1;
            end
            if ~any(ax), GR(g).X(jc) = true; continue; end
            h2 = Hc; h2(ax) = Hc(ax) / 2;
            na = sum(ax);
            offs = zeros(2^na, d);
            for jo = 0:2^na - 1
                offs(jo + 1, ax) = bitget(jo, 1:na);
            end
            kids = S.C(jc, :) + offs .* h2;
            allV = zeros(size(kids, 1) * nv, d);
            for jk = 1:size(kids, 1)
                allV((jk - 1) * nv + (1:nv), :) = kids(jk, :) + VO .* h2;
            end
            if GR(g).nPts + missingPoints(g, unique(allV, 'rows')) > opts.MaxPoints
                GR(g).capped = true;
                break
            end
            if nP - nX + missingGlobal(unique(allV, 'rows')) > opts.MaxTotalPoints   % R5 m5: the global budget
                GR(g).capped = true; GR(g).cappedGlobal = true; budgetHit = true;
                break
            end
            Vk = zeros(size(kids, 1), nv);
            for jk = 1:size(kids, 1)
                for jv = 1:nv
                    Vk(jk, jv) = ensurePoint(kids(jk, :) + VO(jv, :) .* h2);
                    if ~GR(g).mem(Vk(jk, jv))
                        GR(g).mem(Vk(jk, jv)) = true;
                        GR(g).nPts = GR(g).nPts + 1;
                    end
                end
            end
            keep(jc) = false;
            newC = [newC; kids]; %#ok<AGROW>
            newH = [newH; repmat(h2, size(kids, 1), 1)]; %#ok<AGROW>
            newV = [newV; Vk]; %#ok<AGROW>
            did = true;
        end
        if did
            GR(g).C = [GR(g).C(keep, :); newC];
            GR(g).H = [GR(g).H(keep, :); newH];
            GR(g).V = [GR(g).V(keep, :); newV];
            GR(g).X = [GR(g).X(keep); false(size(newC, 1), 1)];
        end
    end

    function [items, moved, newC] = confirmGroup(g)
        % confirm the CPV / cap arg-min of every shape and the arg-min of every box
        S = cellStats(g);
        items = struct('what', {}, 'point', {}, 'theta', {}, 'latticeMargin', {}, 'evaluated', {}, 'status', {}, ...
            'margin', {}, 'cond', {}, 'condition', {}, 'record', {}, 'moved', {}, 'reason', {}, 'kind', {}, ...
            'alpha', {}, 'pointStatus', {});
        moved = false; newC = [];
        for s = 1:nS
            A = shapeState(S, s);
            if isfinite(A.hi)
                items(end+1) = confirmPoint(g, S, A.cpv, sprintf('CPV %s', P.shapes(s).name)); %#ok<AGROW>
            else
                k = argminIn(S, LOs(s), HIs(s));
                if k > 0
                    items(end+1) = confirmPoint(g, S, k, sprintf('cap arg-min %s', P.shapes(s).name)); %#ok<AGROW>
                end
            end
        end
        for b = 1:numel(opts.Boxes)
            k = argminIn(S, nom - opts.Boxes(b).alpha * P.m, nom + opts.Boxes(b).alpha * P.m);
            if k > 0
                items(end+1) = confirmPoint(g, S, k, sprintf('box %s arg-min', opts.Boxes(b).name)); %#ok<AGROW>
                items(end).kind = 'box'; items(end).alpha = opts.Boxes(b).alpha;
            end
        end
        if opts.CornerChecks
            % R5-5 M2: fresh assessments at the 2^d corners of R(DecideAt) and R(alphaLo) of the
            % judged (first) shape; a smaller margin at a non-candidate condition is a moving
            % limit (the same rule as the CPV and arg-min items)
            A1 = shapeState(S, 1);
            m1 = P.shapes(1).m;
            als = unique([opts.DecideAt(opts.DecideAt > tolA & opts.DecideAt <= Amax + tolA), min(A1.lo, Amax)]);
            als = als(als > tolA);
            for a = als
                for jv = 1:nv
                    th = nom + (2 * VO(jv, :) - 1) .* (a * m1);
                    k = ensureCheck(th);
                    Sx = struct('pts', k, 'P', groupVals(g, k));
                    items(end+1) = confirmPoint(g, Sx, k, sprintf('corner R(%.4g) %d', a, jv)); %#ok<AGROW>
                    items(end).kind = 'corner'; items(end).alpha = a;
                end
            end
        end
        for it = 1:numel(items)
            x = items(it);
            if x.moved
                moved = true;
                ci = find(strcmp(labels, x.cond), 1);
                if isempty(ci)
                    conds{end+1} = x.condition; %#ok<AGROW>
                    labels{end+1} = x.cond; %#ok<AGROW>
                    newCondStore();
                    ci = numel(conds);
                end
                if ~ismember(ci, [GR(g).conds newC]), newC(end+1) = ci; end %#ok<AGROW>
            end
        end
    end

    function x = confirmPoint(g, S, k, what)
        jp = find(S.pts == k, 1);
        x = struct('what', what, 'point', k, 'theta', PT(k, :), 'latticeMargin', S.P.m(jp), 'evaluated', false, ...
            'status', 'OK', 'margin', S.P.m(jp), 'cond', labels{S.P.cond(jp)}, 'condition', [], 'record', strT{S.P.rec(jp)}, ...
            'moved', false, 'reason', 'no confirmation function: confirmed by the point function only', ...
            'kind', 'shape', 'alpha', NaN, 'pointStatus', 'OK');
        if S.P.fail(jp), x.pointStatus = 'FAIL'; elseif ~S.P.ok(jp), x.pointStatus = 'NOT_OK'; end
        if startsWith(what, 'CPV'), x.kind = 'cpv'; elseif startsWith(what, 'cap'), x.kind = 'cap'; end
        cf = P.groups(g).confirmFcn;
        if isempty(cf), return; end
        key = sprintf('%d|%d', g, k);
        if isKey(confCache, key)
            c = confCache(key);
        else
            try
                c = cf(PT(k, :));
            catch err
                c = struct('status', 'ERROR', 'margin', NaN, 'condLabel', '', 'record', '', ...
                    'reason', sprintf('%s: %s', err.identifier, err.message));
            end
            nConf = nConf + 1;
            confCache(key) = c;
        end
        x.evaluated = true;
        x.status = c.status; x.margin = c.margin; x.record = c.record; x.reason = c.reason;
        if isfield(c, 'condLabel'), x.cond = c.condLabel; else, x.cond = ''; end
        if isfield(c, 'cond'), x.condition = c.cond; end
        if strcmp(c.status, 'OK') && c.margin < S.P.m(jp) && isfield(c, 'cond') ...
                && ~any(strcmp(labels(GR(g).conds), x.cond))
            x.moved = true;
            x.reason = sprintf(['moving limit: the confirmation found margin %.6g at %s, not a candidate of the ' ...
                'group (the lattice gave %.6g at %s)'], c.margin, x.cond, S.P.m(jp), labels{S.P.cond(jp)});
        end
    end

    function v = LOs(s), v = nom - Amax * P.shapes(s).m; end
    function v = HIs(s), v = nom + Amax * P.shapes(s).m; end

    function k = argminIn(S, blo, bhi)
        inb = all(PT(S.pts, :) >= blo - tolA & PT(S.pts, :) <= bhi + tolA, 2);
        mm = S.P.m; mm(~inb) = NaN;
        mm(~(S.P.ok | S.P.fail)) = NaN;
        if all(isnan(mm)), k = 0; return; end
        [~, j] = min(mm);
        k = S.pts(j);
    end

    function q = boxQuery(g, blo, bhi)
        q = boxCore(FS{g}, blo(:).', bhi(:).');
    end

    function q = boxCore(S, blo, bhi)
        inb = all(PT(S.pts, :) >= blo - tolA & PT(S.pts, :) <= bhi + tolA, 2);
        meet = meets(S, blo, bhi);
        q = struct('status', 'OK', 'reason', '', 'value', NaN, 'theta', NaN(1, d), 'cond', '', 'record', '', ...
            'lowerBound', NaN, 'nCells', sum(meet), 'nPoints', sum(inb), 'point', 0, 'inside', find(inb));
        mm = S.P.m; mm(~inb | ~(S.P.ok | S.P.fail)) = NaN;
        if any(~isnan(mm))
            [q.value, j] = min(mm);
            q.theta = PT(S.pts(j), :); q.cond = labels{S.P.cond(j)}; q.record = strT{S.P.rec(j)}; q.point = S.pts(j);
        end
        q.lowerBound = min(S.bound(meet));
        fl = inb & S.P.fail;
        nok = inb & ~S.P.ok & ~S.P.fail;
        unc = meet & ~S.certified;
        if any(fl)
            q.status = 'VIOLATED';
            q.reason = sprintf('lattice counterexample: margin %.6g < reserve %g at %s, theta %s; %d of %d lattice points inside fail', ...
                q.value, Rsv, q.cond, mat2str(q.theta, 6), sum(fl), sum(inb));
        elseif any(nok)
            q.status = 'NOT_ASSESSABLE';
            j = find(nok, 1);
            q.reason = sprintf('%d of %d lattice points inside the box are not OK, e.g. %s (%s: %s) at theta %s', sum(nok), ...
                sum(inb), strT{S.P.st(j)}, labelOf(S.P.whyCond(j)), strT{S.P.why(j)}, mat2str(PT(S.pts(j), :), 6));
        elseif any(unc)
            q.status = 'NOT_ASSESSABLE';
            q.reason = sprintf(['GRID: not certified (grid-certified (Lipschitz estimate)): %d of %d lattice cells meeting ' ...
                'the box have a certified bound below the reserve %g (lowest %.6g); no lattice point inside fails'], ...
                sum(unc), sum(meet), Rsv, min(S.bound(unc)));
        else
            q.reason = sprintf(['grid-certified (Lipschitz estimate): every one of the %d lattice cells meeting the box is ' ...
                'certified, lower bound %.6g >= reserve %g'], sum(meet), q.lowerBound, Rsv);
        end
    end

    function t = labelOf(ci)
        if ci > 0, t = labels{ci}; else, t = ''; end
    end

    function c = csrOf(g, s)
        S = FS{g};
        A = shapeState(S, s);
        m = P.shapes(s).m;
        c = struct('status', '', 'reason', '', 'shape', P.shapes(s).name, 'alphaStar', NaN, 'alphaLo', A.lo, ...
            'alphaHi', A.hi, 'alphaMax', Amax, 'resolution', Res, 'm', m, 'nominal', nom, 'names', {P.names}, ...
            'psm', NaN(1, d), 'psmHi', NaN(1, d), 'cpv', NaN(1, d), 'cpvMargin', NaN, 'cpvCond', '', 'cpvRecord', '', ...
            'cpvConfirmed', false, 'confirmation', struct('evaluated', false, 'status', '', 'margin', NaN, 'cond', '', ...
            'record', '', 'moved', false, 'reason', 'no confirmation'), 'nominalMargin', NaN, ...
            'searches', struct('alpha', {}, 'origin', {}, 'lo', {}, 'hi', {}, 'status', {}, 'value', {}, 'theta', {}, ...
            'cond', {}, 'nEvaluated', {}, 'label', {}, 'reason', {}), 'nSearches', 0, ...
            'rays', struct('from', {}, 'theta', {}, 'tPass', {}, 'tFail', {}, 'alpha', {}, 'margin', {}, 'cond', {}, 'nEval', {}), ...
            'conditions', {conds(GR(g).conds)}, 'condLabels', {labels(GR(g).conds)}, ...
            'options', struct('AlphaMax', Amax, 'Resolution', Res, 'Reserve', Rsv, 'Prior', [], 'Search', 'lattice'), ...
            'method', 'lattice', 'label', 'grid-certified (Lipschitz estimate)', ...
            'lattice', struct('nCells', S.n, 'nPoints', GR(g).nPts, 'capped', GR(g).capped, 'finestStep', finest()));
        jn = find(S.pts == nomIdx, 1);
        c.nominalMargin = S.P.m(jn);
        conf = findConf(g, s);
        if ~isempty(conf)
            c.confirmation = rmfield(conf, {'what', 'point', 'theta', 'latticeMargin', 'condition', 'kind', 'alpha', ...
                'pointStatus'});
        end
        c.lowerCertified = false;
        c.lowerReason = '';
        if ~S.P.ok(jn) && ~S.P.fail(jn)
            c.status = 'NOT_ASSESSABLE';
            c.reason = sprintf('the nominal point is not OK (%s: %s)', strT{S.P.st(jn)}, strT{S.P.why(jn)});
            c.lowerReason = c.reason;
            c = orderfields(c);
            return
        end
        if isfinite(A.hi)
            jp = find(S.pts == A.cpv, 1);
            c.cpv = PT(A.cpv, :); c.cpvMargin = S.P.m(jp); c.cpvCond = labels{S.P.cond(jp)}; c.cpvRecord = strT{S.P.rec(jp)};
            c.psmHi = A.hi * m;
            cf = c.confirmation;
            c.cpvConfirmed = c.cpvMargin < Rsv && (~cf.evaluated || (strcmp(cf.status, 'OK') && cf.margin < Rsv));
        end
        lim = limitText(g, S, A);
        if isfinite(A.hi) && A.hi - A.lo <= Res + tolA
            cf = c.confirmation;
            if cf.moved
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf('MOVING_LIMIT: the CPV confirmation still moves after %d round(s): %s', ...
                    numel(GR(g).rounds), cf.reason);
            elseif cf.evaluated && ~strcmp(cf.status, 'OK')
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf('the CPV confirmation is not OK: %s (%s)', cf.status, cf.reason);
            elseif ~c.cpvConfirmed
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf(['the CPV is not confirmed: the fresh assessment gives margin %.6g >= reserve %g ' ...
                    '(the lattice gave %.6g at %s)'], cf.margin, Rsv, c.cpvMargin, c.cpvCond);
            else
                c.status = 'OK';
                c.alphaStar = A.lo;
                c.reason = sprintf(['alpha* in [%.4g, %.4g] (resolution %g), read from the lattice: every cell meeting ' ...
                    'R(%.4g) is certified (grid-certified (Lipschitz estimate)) and the CPV at scaled norm %.4g fails ' ...
                    '(margin %.6g at %s, %s), confirmed by a fresh assessment'], A.lo, A.hi, Res, A.lo, A.hi, ...
                    c.cpvMargin, c.cpvCond, c.cpvRecord);
            end
        elseif ~isfinite(A.hi) && A.lo >= Amax - tolA
            cf = c.confirmation;
            if cf.moved
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf('MOVING_LIMIT: the cap-box confirmation still moves after %d round(s): %s', ...
                    numel(GR(g).rounds), cf.reason);
            elseif cf.evaluated && ~strcmp(cf.status, 'OK')
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf('the confirmation at the cap-box arg-min is not OK: %s (%s)', cf.status, cf.reason);
            elseif cf.evaluated && cf.margin < Rsv
                c.status = 'NOT_ASSESSABLE';
                c.reason = sprintf(['the confirmation at the cap-box arg-min fails (margin %.6g at %s) although the ' ...
                    'lattice does not: the point evaluation and the confirmation disagree'], cf.margin, cf.cond);
            else
                c.status = 'ROBUST_TO_CAP';
                c.alphaLo = Amax; c.alphaStar = Amax; c.alphaHi = Inf;
                c.cpvConfirmed = false;
                c.reason = sprintf(['no failure up to AlphaMax: every lattice cell meeting the cap box R(%g) is certified ' ...
                    '(grid-certified (Lipschitz estimate)) and no lattice point in it fails'], Amax);
            end
        else
            c.status = 'NOT_ASSESSABLE';
            c.reason = sprintf('%s; alpha* in [%.4g, %s] is not resolved to %g', lim, A.lo, numTxt(A.hi), Res);
        end
        c.alphaLo = min(c.alphaLo, Amax);
        if strcmp(c.status, 'ROBUST_TO_CAP'), c.alphaLo = Amax; end
        % R5-2: is R(alphaLo) certified? (every cell meeting it certified by construction of
        % alphaLo; the final round's fresh confirmations must agree)
        [c.lowerCertified, c.lowerReason] = lowerOf(g, s, S, c.alphaLo);
        if ~c.lowerCertified && any(strcmp(c.status, {'OK', 'ROBUST_TO_CAP'})) && c.alphaLo > 0
            c.status = 'NOT_ASSESSABLE';
            c.reason = sprintf('%s; but R(alphaLo) is not confirmed: %s', c.reason, c.lowerReason);
            c.alphaStar = NaN;
            if isinf(c.alphaHi), c.alphaLo = A.lo; end
        end
        c.psm = c.alphaStar * m;
        c = orderfields(c);
    end

    function [ok, why] = lowerOf(g, s, S, lo)
        % R(lo) of shape s: certified clean over the final candidates (R5-2)
        jn = find(S.pts == nomIdx, 1);
        if ~(S.P.ok(jn) && ~S.P.fail(jn))
            ok = false; why = 'the nominal point fails or is not OK';
            return
        end
        items = CF{g};
        ok = true; why = sprintf('every lattice cell meeting R(%.4g) is certified (%s)', lo, ...
            'grid-certified (Lipschitz estimate)');
        if isempty(items), return; end
        mv = items([items.moved]);
        if ~isempty(mv)
            ok = false;
            why = sprintf(['MOVING_LIMIT: the final round''s confirmation "%s" still moves (%s): the candidate ' ...
                'conditions are incomplete'], mv(1).what, mv(1).reason);
            return
        end
        % fresh confirmations inside R(lo): the corners (judged shape) and the box arg-mins
        % with alpha <= lo, and the cap arg-min of this shape when lo is the cap
        isIn = false(size(items));
        for it = 1:numel(items)
            x = items(it);
            switch x.kind
                case 'corner', isIn(it) = s == 1 && x.alpha <= lo + tolA;
                case 'box', isIn(it) = s == 1 && x.alpha <= lo + tolA;
                case 'cap', isIn(it) = strcmp(x.what, ['cap arg-min ' P.shapes(s).name]) && lo >= Amax - tolA;
            end
        end
        for x = items(isIn)
            if ~strcmp(x.pointStatus, 'OK')
                ok = false;
                why = sprintf(['the point evaluation at the check point "%s" inside R(%.4g) is %s although every ' ...
                    'cell is certified: the certificate is contradicted'], x.what, lo, x.pointStatus);
                return
            end
            if x.evaluated && ~strcmp(x.status, 'OK')
                ok = false;
                why = sprintf('the fresh confirmation "%s" inside R(%.4g) is not OK: %s (%s)', x.what, lo, x.status, ...
                    x.reason);
                return
            end
            if x.evaluated && x.margin < Rsv
                ok = false;
                why = sprintf(['the fresh confirmation "%s" inside R(%.4g) fails (margin %.6g at %s) although the ' ...
                    'lattice does not: the point evaluation and the confirmation disagree'], x.what, lo, x.margin, x.cond);
                return
            end
        end
        nc = sum(isIn & strcmp({items.kind}, 'corner'));
        if nc > 0
            why = sprintf('%s; the fresh assessments at %d corner(s) inside it agree', why, nc);
        end
    end

    function t = limitText(g, S, A)
        % why the lower end stops where it does
        unc = A.unc & A.e <= A.lo + tolA;
        j = find(unc & ~S.allOK, 1);
        if ~isempty(j)
            vx = S.V(j, :);
            [~, jj] = ismember(vx, S.pts);
            bad = jj(~S.P.ok(jj) & ~S.P.fail(jj));
            if ~isempty(bad)
                b = bad(1);
                t = sprintf('a lattice point is not OK at scaled distance %.4g: %s (%s: %s) at theta %s', A.lo, ...
                    strT{S.P.st(b)}, labelOf(S.P.whyCond(b)), strT{S.P.why(b)}, mat2str(PT(S.pts(b), :), 6));
                return
            end
        end
        j = find(unc & S.infCell, 1);
        if ~isempty(j)
            t = sprintf(['GRID: a lattice cell at scaled distance %.4g has the margin +Inf at every vertex (no record ' ...
                'applies there): the Lipschitz estimate bounds nothing between its vertices, so it is not certified ' ...
                '(review R5 m3)'], A.lo);
            return
        end
            t = sprintf(['GRID: the lattice caps are reached (MaxLevel %d, MaxPoints %d per group, %d points of the group, capped %d) with %d ' ...
            'uncertified cell(s) at entry alpha %.4g (grid-certified (Lipschitz estimate))'], opts.MaxLevel, ...
            opts.MaxPoints, GR(g).nPts, GR(g).capped, sum(unc), A.lo);
        if GR(g).cappedGlobal
            t = sprintf('%s; the global lattice budget (MaxTotalPoints %d over all groups) is exhausted', t, ...
                opts.MaxTotalPoints);
        end
        if ~startsWith(t, 'GRID'), t = ['GRID: ' t]; end
    end

    function x = findConf(g, s)
        x = [];
        if isempty(CF{g}), return; end
        nm = P.shapes(s).name;
        k = find(strcmp({CF{g}.what}, ['CPV ' nm]) | strcmp({CF{g}.what}, ['cap arg-min ' nm]), 1);
        if ~isempty(k), x = CF{g}(k); end
    end

    function bw = boxOf(g, B)
        S = FS{g};
        blo = nom - B.alpha * P.m; bhi = nom + B.alpha * P.m;
        q = boxCore(S, blo, bhi);
        cs = GR(g).conds;
        ins = S.pts(q.inside);
        jj = q.inside;
        np = numel(ins);
        stt = repmat({'OK'}, np, 1); why = repmat({''}, np, 1);
        for t = 1:np
            if ~S.P.ok(jj(t))
                stt{t} = strT{S.P.st(jj(t))};
                why{t} = sprintf('%s: %s', labelOf(S.P.whyCond(jj(t))), strT{S.P.why(jj(t))});
            end
        end
        [~, ci] = ismember(S.P.cond(jj), cs);
        pts = struct('theta', PT(ins, :), 'phase', {repmat({'lattice'}, np, 1)}, 'margin', S.P.m(jj), ...
            'cond', {labels(S.P.cond(jj)).'}, 'condIndex', ci, 'record', {strT(S.P.rec(jj)).'}, 'status', {stt}, ...
            'reason', {why}, 'condMargin', S.P.M(jj, :));
        if np == 0, pts.cond = cell(0, 1); pts.record = cell(0, 1); end
        k = find(strcmp({CF{g}.what}, sprintf('box %s arg-min', B.name)), 1);
        conf = struct('evaluated', false, 'status', '', 'margin', NaN, 'cond', '', 'condition', [], 'record', '', ...
            'moved', false, 'reason', 'no confirmation function');
        if ~isempty(k)
            x = CF{g}(k);
            conf = struct('evaluated', x.evaluated, 'status', x.status, 'margin', x.margin, 'cond', x.cond, ...
                'condition', x.condition, 'record', x.record, 'moved', x.moved, 'reason', x.reason);
        end
        bw = struct();
        bw.value = q.value; bw.searchValue = q.value; bw.theta = q.theta; bw.cond = q.cond; bw.record = q.record;
        bw.condition = [];
        if q.point > 0, bw.condition = conds{S.P.cond(S.pts == q.point)}; end
        jn = find(S.pts == nomIdx, 1);
        bw.nominal = struct('margin', S.P.m(jn), 'cond', labels{S.P.cond(jn)}, 'record', strT{S.P.rec(jn)}, ...
            'status', ifs(S.P.ok(jn), 'OK', strT{S.P.st(jn)}));
        bw.points = pts;
        bw.nEvaluated = np;
        bw.optimizer = struct('start', {}, 'x', {}, 'fval', {}, 'exitflag', {}, 'funcCount', {}, 'converged', {}, 'message', {});
        bw.confirmation = conf;
        bw.rounds = arrayfun(@(r) struct('round', r.round, 'candidates', {r.candidates}, 'nEvaluated', np, ...
            'searchValue', q.value, 'theta', q.theta, 'cond', q.cond, 'record', q.record, 'converged', ...
            strcmp(q.status, 'OK'), 'nNonOK', sum(~strcmp(stt, 'OK')), 'nViolating', sum(S.P.fail(jj)), ...
            'confirmation', rmfield(conf, 'condition')), GR(g).rounds);
        bw.nRounds = numel(GR(g).rounds);
        bw.conditions = conds(cs); bw.condLabels = labels(cs);
        bw.nonOK = find(~strcmp(stt, 'OK')).';
        bw.reserve = Rsv;
        bw.options = opts;
        bw.names = P.names; bw.lo = blo; bw.hi = bhi;
        bw.method = 'lattice';
        bw.label = 'grid-certified (Lipschitz estimate)';
        bw.stages = struct('name', 'lattice', 'nEval', np, 'converged', strcmp(q.status, 'OK'), 'message', q.reason, ...
            'generations', NaN);
        meet = meets(S, blo, bhi);
        bw.certificate = struct('certified', strcmp(q.status, 'OK'), 'lowerBound', q.lowerBound, ...
            'L', max(S.L(meet, :), [], 1), 'maxSlope', max(S.slope(meet, :), [], 1), 'factor', fac, ...
            'nCells', sum(meet), 'nPoints', np, 'finestStep', finest(), 'reason', q.reason);
        bw.converged = strcmp(q.status, 'OK') || strcmp(q.status, 'VIOLATED');
        confViol = conf.evaluated && strcmp(conf.status, 'OK') && conf.margin < Rsv;
        if strcmp(q.status, 'VIOLATED') || confViol
            bw.status = 'VIOLATED';
            if strcmp(q.status, 'VIOLATED')
                bw.reason = q.reason;
            else
                bw.reason = sprintf('counterexample (confirmation): margin %.6g < reserve %g at %s (%s)', conf.margin, ...
                    Rsv, conf.cond, conf.record);
                bw.value = conf.margin; bw.cond = conf.cond; bw.record = conf.record; bw.condition = conf.condition;
            end
        elseif conf.moved
            bw.status = 'NOT_ASSESSABLE';
            bw.reason = sprintf('MOVING_LIMIT: %s; still moving after %d round(s)', conf.reason, bw.nRounds);
            bw.value = conf.margin; bw.cond = conf.cond; bw.record = conf.record; bw.condition = conf.condition;
        elseif conf.evaluated && ~strcmp(conf.status, 'OK')
            bw.status = 'NOT_ASSESSABLE';
            bw.reason = sprintf('the confirmation is not OK: %s (%s); %s', conf.status, conf.reason, q.reason);
        else
            bw.status = q.status;
            bw.reason = q.reason;
        end
        bw = orderfields(bw);
    end

    function ce = certOf(g)
        S = FS{g};
        t = sprintf('%d of %d cells certified (bound: minimum vertex margin - sum L_i h_i%s, L = %g x the measured slopes)', ...
            sum(S.certified), S.n, ifs(hf == 0.5, '/2', ''), fac);
        if any(S.strad)
            t = sprintf('%s; %d cell(s) straddle a breakpoint and are certified piecewise (%d certified)', t, ...
                sum(S.strad), sum(S.strad & S.certified));
        end
        if any(S.infCell), t = sprintf('%s; %d all-+Inf cell(s) not certified', t, sum(S.infCell)); end
        ce = struct('certified', all(S.certified), 'lowerBound', min(S.bound), 'L', max(S.L, [], 1), ...
            'maxSlope', max(S.slope, [], 1), 'factor', fac, 'nCells', S.n, 'nPoints', numel(S.pts), ...
            'finestStep', finest(), 'reason', t, 'certificate', opts.Certificate);
    end

    function D = discOf(g)
        % R5-3: the margin discontinuities met by the group's cells (breakpoint crossings)
        S = FS{g}; cs = GR(g).conds;
        D = struct('present', false, 'nCells', 0, 'nCertified', 0, 'variables', {{}}, 'breakpoints', zeros(1, 0), ...
            'maxJump', 0, 'crossings', struct('variable', {}, 'breakpoint', {}, 'maxJump', {}, 'nEdges', {}), 'text', '');
        if nSw == 0
            D.text = 'no switching variables given: discontinuities are not detected';
            return
        end
        js = find(S.strad);
        D.nCells = numel(js); D.nCertified = sum(S.certified(js)); D.present = ~isempty(js);
        X = zeros(0, 3);                              % rows: switch, breakpoint, |jump|
        for j = js(:).'
            vi = S.V(j, :);
            for c = cs
                mm = evM{c}(vi, g).'; sv = evSw{c}(vi, 1:nSw); cd = evCode{c}(vi).';
                for ia = 1:d
                    for e = 1:size(EP{ia}, 1)
                        a = EP{ia}(e, 1); b = EP{ia}(e, 2);
                        if isnan(cd(a)) || isnan(cd(b)) || cd(a) == cd(b), continue; end
                        jv = abs(mm(b) - mm(a));
                        if ~isfinite(jv), jv = NaN; end
                        for w = 1:nSw
                            l2 = min(sv(a, w), sv(b, w)); h2 = max(sv(a, w), sv(b, w));
                            bw = SW(w).breakpoints;
                            for bv = bw(bw >= l2 & bw < h2)
                                X(end+1, :) = [w, bv, jv]; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end
        if isempty(X)
            D.text = 'the margin is continuous over the group''s cells as far as the vertices show (no cell straddles a breakpoint)';
            return
        end
        U = unique(X(:, 1:2), 'rows', 'stable');
        for k = 1:size(U, 1)
            sel = X(:, 1) == U(k, 1) & X(:, 2) == U(k, 2);
            D.crossings(end+1) = struct('variable', SW(U(k, 1)).name, 'breakpoint', U(k, 2), ...
                'maxJump', max([X(sel, 3); 0], [], 'omitnan'), 'nEdges', sum(sel)); %#ok<AGROW>
        end
        D.variables = unique({D.crossings.variable}, 'stable');
        D.breakpoints = unique([D.crossings.breakpoint]);
        D.maxJump = max([D.crossings.maxJump]);
        D.text = sprintf(['the margin is DISCONTINUOUS at %s: %d cell(s) straddle a breakpoint (%d certified ' ...
            'piecewise, each side from its own vertices); largest jump over a straddling edge %.4g'], ...
            strjoin(arrayfun(@(x) sprintf('%s = %g (jump up to %.4g, %d edges)', x.variable, x.breakpoint, ...
            x.maxJump, x.nEdges), D.crossings, 'UniformOutput', false), '; '), D.nCells, D.nCertified, D.maxJump);
    end

    function f = finest()
        Hm = s0 * ones(1, d);
        for gg = 1:numel(GR), Hm = min([Hm; GR(gg).H], [], 1); end
        f = (Hm / K) .* (HI - LO);
    end
end

% =========================================================================================
function t = numTxt(v)
if isinf(v), t = 'Inf'; else, t = sprintf('%.4g', v); end
end

function v = ifs(c, a, b)
if c, v = a; else, v = b; end
end

function P = validate(P, opts)
need = {'names', 'nominal', 'm', 'conditions', 'condLabels', 'pointFcn', 'groups', 'shapes'};
for k = 1:numel(need)
    if ~isfield(P, need{k})
        error('vital:badInput', 'lattice problem lacks field "%s".', need{k});
    end
end
d = numel(P.nominal);
P.nominal = double(P.nominal(:).'); P.m = double(P.m(:).');
if d == 0 || d > 3 || numel(P.m) ~= d || numel(P.names) ~= d
    error('vital:badInput', 'names, nominal and m must have the same length d, 1 <= d <= 3.');
end
if ~all(isfinite(P.m)) || any(P.m <= 0) || ~all(isfinite(P.nominal))
    error('vital:badInput', 'm must be finite and > 0, nominal finite.');
end
isInt = @(v, lo) isfinite(v) && v >= lo && v == round(v);
if ~isInt(opts.GridPoints, 3) || mod(opts.GridPoints, 2) ~= 1
    error('vital:badInput', 'GridPoints must be an odd integer >= 3 (the nominal is a lattice point).');
end
if ~isInt(opts.MaxLevel, 0) || ~isInt(opts.MaxPoints, 1) || ~isInt(opts.MaxRounds, 1)
    error('vital:badInput', 'MaxLevel must be an integer >= 0; MaxPoints and MaxRounds positive integers.');
end
if (opts.GridPoints - 1) * 2^opts.MaxLevel > 2^17
    error('vital:badInput', 'the lattice is too fine: (GridPoints - 1) 2^MaxLevel must be <= 2^17.');
end
if ~(isfinite(opts.LipschitzFactor) && opts.LipschitzFactor >= 1)
    error('vital:badInput', 'LipschitzFactor must be >= 1 (a safety factor on the measured slopes).');
end
if ~(isfinite(opts.AlphaMax) && opts.AlphaMax > 0) || ~(isfinite(opts.Resolution) && opts.Resolution > 0)
    error('vital:badInput', 'AlphaMax and Resolution must be finite and > 0.');
end
lo = P.nominal - opts.AlphaMax * P.m;
if any(lo < 0)
    k = find(lo < 0, 1);
    error('vital:uq:negativeMultiplier', ['the lattice box has lower bound %g < 0 for %s (a multiplier must be ' ...
        '>= 0): reduce AlphaMax or m.'], lo(k), P.names{k});
end
if ~iscell(P.conditions) || isempty(P.conditions) || numel(P.condLabels) ~= numel(P.conditions)
    error('vital:badInput', 'conditions must be a non-empty cell with one label per condition.');
end
if ~isa(P.pointFcn, 'function_handle')
    error('vital:badInput', 'pointFcn must be a function handle q = f(theta, cond).');
end
if ~isstruct(P.groups) || isempty(P.groups) || ~all(isfield(P.groups, {'name', 'conds'}))
    error('vital:badInput', 'groups must be a non-empty struct array with fields name, conds (and confirmFcn).');
end
if ~isfield(P.groups, 'confirmFcn'), [P.groups.confirmFcn] = deal([]); end
for g = 1:numel(P.groups)
    c = P.groups(g).conds;
    if isempty(c) || any(~isfinite(c) | c < 1 | c > numel(P.conditions) | c ~= round(c))
        error('vital:badInput', 'group %s: conds must be indices into the %d conditions.', P.groups(g).name, ...
            numel(P.conditions));
    end
    if ~isempty(P.groups(g).confirmFcn) && ~isa(P.groups(g).confirmFcn, 'function_handle')
        error('vital:badInput', 'group %s: confirmFcn must be a function handle or [].', P.groups(g).name);
    end
end
if ~isfield(P, 'switches') || isempty(P.switches)
    P.switches = struct('name', {}, 'breakpoints', {});
elseif ~isstruct(P.switches) || ~all(isfield(P.switches, {'name', 'breakpoints'}))
    error('vital:badInput', 'switches must be a struct array with fields name, breakpoints.');
else
    for k = 1:numel(P.switches)
        b = double(P.switches(k).breakpoints(:).');
        if isempty(b) || any(~isfinite(b)) || any(diff(b) <= 0)
            error('vital:badInput', 'switch %s: breakpoints must be finite and strictly increasing.', P.switches(k).name);
        end
        P.switches(k).breakpoints = b;
    end
    P.switches = struct('name', {P.switches.name}, 'breakpoints', {P.switches.breakpoints});
end
if ~isstruct(P.shapes) || isempty(P.shapes) || ~all(isfield(P.shapes, {'name', 'm'}))
    error('vital:badInput', 'shapes must be a non-empty struct array with fields name, m.');
end
for s = 1:numel(P.shapes)
    ms = double(P.shapes(s).m(:).');
    if numel(ms) ~= d || ~all(isfinite(ms)) || any(ms <= 0)
        error('vital:badInput', 'shape %s: m must have %d finite entries > 0.', P.shapes(s).name, d);
    end
    if any(opts.AlphaMax * ms > opts.AlphaMax * P.m * (1 + 1e-12))
        error('vital:badInput', 'shape %s: its cap box (alpha %g) leaves the lattice box.', P.shapes(s).name, ...
            opts.AlphaMax);
    end
    P.shapes(s).m = ms;
end
end

function k = meets(S, blo, bhi)
% cells whose interior meets the box [blo, bhi] (on an axis where the box has no
% width: the closed cell contains it). A point of the box on the boundary of a cell
% that only touches the box also lies in a cell whose interior meets the box, and
% the certificate holds on closed cells, so touching cells need not be certified.
flat = (bhi - blo) <= 1e-12 * max(1, abs(bhi));
k = all((S.cl < bhi - 1e-12 & S.ch > blo + 1e-12) | (flat & S.cl <= bhi + 1e-12 & S.ch >= blo - 1e-12), 2);
end
