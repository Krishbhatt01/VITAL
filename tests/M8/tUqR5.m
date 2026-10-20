classdef (TestTags = {'M8'}) tUqR5 < vital.test.VitalTestCase
%TUQR5  M8 amendment R5 (docs/PLAN_M5_M8.md, "Amendment R5", coordinator
%   2026-10-14, after review R5, reports/review/R5_REVIEW.md) on closed-form
%   margins and fakes (no aircraft): R5-1 (h/2 certificate), R5-2 (verdict from
%   R(1)), R5-3 (piecewise certificate at table breakpoints), R5-4 (stage-1
%   band rule), R5-5 (M2 corner assessments, M4 tests for the R5 sabotages
%   S8Q-1, 2, 3, 5, 7, 9, minors m1/m2/m3/m5/m10). The F-16 items are in
%   tests/M8/tUqR5F16.m. Expected runtime: about 1 min.
%
%   Toys as tests/M8/tUqLattice.m (copied helpers, so the class stands alone):
%   s = (p - 1)./m_j, m_j = [0.1 0.2 0.15] (3-D), shapes judged m_j and equal
%   0.10; every group's confirmFcn is the minimum over ALL the toy's conditions
%   unless stated. Lattice defaults (vital.uq.lattice) unless stated.
%
%   NEW LATTICE INTERFACE (stated here, before any implementation):
%   - 'Certificate' 'half' (default, R5-1) | 'full' (the superseded R4b form).
%   - 'CornerChecks' true (default, R5-5 M2): after each refinement, every
%     group's confirmFcn is also called at the 2^d corners of R(1) (the
%     DecideAt values) and of R(alphaLo) of the judged (first) shape; these items
%     go through the same moving-limit rule as the CPV and arg-min items
%     (item.what starting 'corner R(').
%   - 'MaxTotalPoints' (default Inf, R5 m5): a GLOBAL cap on the lattice points
%     of all groups; reaching it caps every group that still refines
%     (res.lattice.budgetExhausted true; the capped groups' reasons contain
%     'global').
%   - problem.switches (R5-3): struct array (name, breakpoints); pointFcn's q may
%     carry q.switchVals (1 x numel(switches), the switching variables at the
%     point, per condition). The side of a vertex = the number of breakpoints
%     below its value. A cell whose vertices lie on different sides at a
%     condition STRADDLES; it is certified PIECEWISE: per condition and side,
%     min(vertex margins on that side) - sum_i L_i h_i (full edge h), L = 2 x
%     the measured slopes of the edges that do not straddle (own and 3^d base
%     neighbourhood). res.groups(g).discontinuity: present, nCells, variables,
%     breakpoints (crossed), maxJump (largest |margin difference| over a
%     straddling edge of the group's cells).
%   - csr results (lattice and vital.uq.csr) gain lowerCertified (R(alphaLo)
%     certified clean on the final candidates, no moving item in the final
%     round, no failing or non-OK fresh confirmation inside R(alphaLo)) and
%     lowerReason. vital.uq.lowerEnd(csr) -> [alphaLo, certified, why] (a legacy
%     R4 struct without these fields: certified = status OK or ROBUST_TO_CAP,
%     alphaLo = alphaStar).
%   - A vital:badInput raised by pointFcn is an ERROR point (R5 m2); a
%     malformed q raises vital:uq:badPointResult.
%   - A cell whose vertices are all +Inf is never certified nor refined (R5 m3).
%   - vital.uq.stageBand(errors, 'Floor', [0.8 1.2]) (R5-4): e = max(errors),
%     band = [min(F1, 1 - 2e), max(F2, 1 + 2e)]; errors empty, NaN or < 0 ->
%     vital:badInput.
%   - vital.uq.statements(kind): 'judgments' | 'limits' (cellstr, the report's
%     explicit statements, R5 m1/m10/M2); other kind -> vital:badInput;
%     vital.uq.loadSpec().judgments = statements('judgments').
%
%   PRE-REGISTERED (agent uq5, 2026-10-14, with the stubs, before any
%   implementation; ANALYTIC unless stated):
%   1. h/2 CERTIFICATE (R5-1) on LIP (tUqLattice header 4: m = 0.5 + 0.02 s1 -
%      0.05 s2 + 0.03 s3): default certificate: options.Certificate 'half',
%      certificate.L [0.4 0.5 0.4] (1e-12), lowerBound = 0.2 - (0.4 x 0.06 +
%      0.5 x 0.12 + 0.4 x 0.09)/2 = 0.14 (1e-12). 'Certificate' 'full': 0.08
%      (the R4b value, kept). SUPERSEDES tests/M8/tUqLattice.m header 4 (0.08).
%   2. R5-2 VERDICT TRUTH TABLE (Required 0.95), csr (status, alphaStar,
%      alphaLo, alphaHi, cpvConfirmed, lowerCertified) + cpLower:
%        NOT_ASSESSABLE NaN 1.05 1.20 true  true , 0.99 -> ROBUST (R(1) certified)
%        NOT_ASSESSABLE NaN 1.00 Inf  false true , 0.95 -> ROBUST (both inclusive)
%        NOT_ASSESSABLE NaN 0.99 Inf  false true , 0.99 -> NOT_ASSESSABLE
%        NOT_ASSESSABLE NaN 1.20 Inf  false false, 0.99 -> NOT_ASSESSABLE (not certified)
%        OK             1.2 1.20 1.21 true  true , 0.99 -> ROBUST
%        OK             0.8 0.80 0.81 true  true , 0.99 -> NOT_ROBUST
%        NOT_ASSESSABLE NaN 0.40 0.90 true  true , 0.99 -> NOT_ROBUST (CPV in R(1))
%        NOT_ASSESSABLE NaN 0.40 0.90 false true , 0.99 -> NOT_ASSESSABLE
%        ROBUST_TO_CAP  3   3    Inf  false true , 0.99 -> ROBUST
%        ROBUST_TO_CAP  3   3    Inf  false true , 0.94 -> NOT_ROBUST
%        ROBUST_TO_CAP  3   3    Inf  false true , NaN  -> NOT_ROBUST (S8Q-7)
%        NOT_ASSESSABLE NaN 1.50 Inf  false true , NaN  -> NOT_ROBUST (S8Q-7)
%      every reason non-empty; v.alphaLo and v.lowerCertified reported; a struct
%      with lowerCertified but no alphaLo -> vital:badInput. lowerEnd of a legacy
%      R4 struct (OK 1.2) -> [1.2, true]; (NOT_ASSESSABLE NaN) -> [NaN, false].
%   3. S8Q-7 ON THE LEGACY FORM: R4 rows (no lowerCertified) with cpLower NaN:
%      OK 1.2 1.21 true -> NOT_ROBUST; ROBUST_TO_CAP 3 Inf false -> NOT_ROBUST
%      (never ROBUST without a Monte Carlo bound).
%   4. R(1) DECIDES (R5-2, lattice): SHIFT m = 0.63 - 0.1 (s1 + s2 + s3) with
%      'MaxPoints' 1331 (the base lattice only; true alpha*(judged) 2.1).
%      Every base cell meeting R(1.2) is certified at h/2 (worst: min vertex
%      0.27 - 3 x 0.06 = 0.09) and the cell [1.2, 1.8]^3 is not (0.09 - 0.18),
%      so judged alphaLo = 1.2 (1e-12), lowerCertified true, status
%      NOT_ASSESSABLE with a reason starting 'GRID' (capped), alphaHi = 2.4
%      (1e-12: base point (2.4, 2.4, 1.8)), cpvConfirmed true; verdict with
%      cpLower 0.99: ROBUST (R5) whereas the legacy R4 form of the same result
%      (lowerCertified and lowerReason removed) gives NOT_ASSESSABLE.
%   5. JUDGED SHAPE FIRST (R5-2: 0.01 required for the judged shape only): LIN
%      (alpha* 2 judged, 36/13 equal) with 'MaxPoints' 6000: judged status OK
%      with alphaStar in [1.99, 2], alphaHi in [2, 2.01] (REG budget: review
%      R5 measured 4,431 points for the judged shape alone at h/2); equal:
%      alphaLo <= 36/13 <= alphaHi (any status). Also lowerCertified true for
%      both shapes.
%   6. PIECEWISE: KNOWN JUMP (R5-3): switch z = s1 + 0.5 s2, breakpoint 0.37;
%      m = 0.05 + 0.01 s1 + 0.1 [z > 0.37] (> 0 everywhere, min 0.02). Both
%      shapes ROBUST_TO_CAP, res.lattice.nPoints 1331 exactly (no refinement:
%      every piece bound >= 0.02 - 2 x 0.1 x 0.06 > 0), discontinuity.present
%      true, nCells > 0, variables {'z'}, breakpoints 0.37, maxJump in
%      [0.1, 0.106] (+/-1e-12: 0.1 + 0.01 x 0.6 along s1, 0.1 along s2); the R(1)
%      box status 'OK'. GUARD: the same toy without problem.switches and
%      'MaxPoints' 3000: judged NOT_ASSESSABLE with a reason starting 'GRID'
%      (a straddling cell's bound is about min - jump at every level).
%   7. PIECEWISE: A JUMP HIDES A REAL FAILURE (R5-3): z = s1, breakpoint 1.37;
%      m = 0.2 for s1 <= 1.37, -0.02 + 2 (s1 - 1.5)^2 above (fails for
%      1.4 < s1 < 1.6; guard: every base point has m > 0, the base cell
%      [1.2, 1.8] straddles). alpha* = 1.4 for both shapes (m_1 = 0.1 in both):
%      status OK, alphaStar in [1.39, 1.4], alphaHi in [1.4, 1.41]; the judged
%      box R(1.45) 'VIOLATED'.
%   8. CORNERS CATCH A CANDIDATE GAP (R5-5 M2; review R5 toy T3): conditions
%      c1 (the group's only candidate), c2; m(c1) = 0.132 - 0.1 s1, m(c2) =
%      0.15 + 0.2 s2 (true alpha*(judged) 0.75 at c2): with 'CornerChecks'
%      true: 'c2' in the group's condLabels, judged status OK, alphaStar in
%      [0.74, 0.75], alphaHi in [0.75, 0.76], cpvCond 'c2'; some round has a
%      moved item whose what starts 'corner R('; verdict (cpLower 0.99)
%      NOT_ROBUST. The default of 'CornerChecks' is true (res.options).
%   9. CORNERS CATCH A CAP GAP (R5-5 M2; review R5 toy T4): m(c1) = 0.3 +
%      0.05 s1 - 0.01 s2 (never fails), m(c2) = 0.35 + 0.2 s2 (true alpha* 1.75):
%      with corners: status OK, alphaStar in [1.74, 1.75], alphaHi in
%      [1.75, 1.76], 'c2' added. GUARD: 'CornerChecks' false: ROBUST_TO_CAP (the
%      cap arg-min (s1, s2) = (-3, 3) sees c2 = 0.95: the as-built gap).
%   10. MOVING LIMIT WITH A POSITIVE CONFIRMATION (S8Q-9): m(c1) = 0.41 -
%      0.1 s1 + 0.01 s2 + 0.01 s3 (cap minimum 0.05 at (3, -3, -3)), m(c2) =
%      0.03 + 0.1 (|s1| - 1)(|s1| - 3) (0.03 > 0 at |s1| = 1 and 3, fails for
%      |s1| in (2 - sqrt(0.7), 2 + sqrt(0.7))): judged alpha* a = 2 - sqrt(0.7):
%      'c2' in condLabels, status not ROBUST_TO_CAP, alphaLo in [a - 0.02, a],
%      alphaHi in [a, a + 0.01]. (Written before the implementation, after a
%      check of the as-built code with the stubs, 2026-10-14: the as-built
%      lattice gives [1.161, 1.172], 0.011 wide, so status 'OK' to 0.01 is not
%      required here; the item guards the moving limit, S8Q-9.)
%   11. A FAILING CANDIDATE DECIDES (S8Q-1): conditions c1, c2 both candidates;
%      m(c1) = LIN, c2 'NOT_CONVERGED' where s1 + s2 + s3 > 5 (margin 1
%      elsewhere); confirmFcn = minimum over the OK conditions. The cap box
%      R(3) (res.box) 'VIOLATED'; judged alphaHi <= 3 (finite) and
%      cpvConfirmed true.
%   12. POINT EVALUATION AND CONFIRMATION DISAGREE (S8Q-2): pointFcn CAP (never
%      fails), confirmFcn always OK with margin -0.1 at c1: judged status
%      NOT_ASSESSABLE, reason containing 'disagree'; lowerCertified false;
%      verdict (cpLower 0.99) not ROBUST.
%      ADDED 2026-10-14 (uq5, after the first R5 sabotage run, before GREEN):
%      S8Q-2 was NOT DETECTED because the new R5-2 lower-end check also turns
%      the case into NOT_ASSESSABLE (defence in depth). To see the cap-branch
%      guard itself, its reason is pinned: it starts with 'the confirmation at
%      the cap-box arg-min fails'.
%   13. MAX, NOT MEAN, SLOPE (S8Q-3): m = 1.5 - 0.05 s1 s2 (non-separable,
%      parallel edges differ): certificate.maxSlope = [1.5 0.75 0] (1e-12;
%      |dm/dtheta_1| = 0.05 |s2| / 0.1 at |s2| = 3), status ROBUST_TO_CAP.
%   14. worseOf, SIDE B NaN (S8Q-5; the mirror of tUqBracket header 10 g3):
%      A [0.5 0.2 1], B [0.4 NaN 1] -> marginTo [0.4 NaN 1] (isequaln).
%   15. vital:badInput INSIDE pointFcn IS AN ERROR POINT (m2): margin 0.5,
%      pointFcn raises vital:badInput where s1 > 2: no exception; judged
%      NOT_ASSESSABLE with 'ERROR' in its reason, alphaLo = 1.8 (1e-12). A
%      pointFcn returning a struct without margin -> vital:uq:badPointResult.
%   16. ALL-+Inf CELLS (m3; review R5 toy T5c): m = +Inf for s1 > 0.5, -0.1 for
%      0.65 < s1 < 0.7 (a pocket between +Inf vertices), 0.5 elsewhere: judged
%      NOT_ASSESSABLE, alphaLo = 0.6 (1e-12; the cells [0.6, 1.2] are all
%      +Inf), reason containing 'Inf'; res.lattice.nPoints 1331 (all-+Inf
%      cells are not refined).
%   17. GLOBAL LATTICE BUDGET (m5): groups LIN, KINK, CAP (one condition) with
%      'MaxTotalPoints' 3000: res.lattice.nPoints <= 3000, budgetExhausted
%      true; LIN and KINK judged NOT_ASSESSABLE with 'global' in the reason;
%      CAP judged ROBUST_TO_CAP. Without the option: options.MaxTotalPoints Inf.
%   18. stageBand (R5-4): [0.05 0.12] -> [0.76 1.24]; [0 0.01] -> [0.8 1.2];
%      0.3 -> [0.4 1.6] (1e-12); [], NaN, -0.1 -> vital:badInput.
%   19. STATEMENTS (m1, m10, M2): statements('judgments') contains 'Cm_basic and
%      Cm_de are treated as independent' and 'wings-level'; statements('limits')
%      contains 'narrower than a lattice cell', 'discontinuous', 'h/2',
%      'engineering rule', 'per-condition success probability', 'candidate
%      conditions only' and 'R(1)'; loadSpec().judgments isequal
%      statements('judgments'); statements('x') -> vital:badInput.
%   20. lowerCertified OF vital.uq.csr (R5-2 on box searches; tUqCsr toys K9,
%      K4, K3 with the grid search): K9 (margin 1, INFEASIBLE for s > 2,
%      'DecideAt' 1): status NOT_ASSESSABLE, alphaLo 1, lowerCertified true,
%      verdict (cpLower 0.99) ROBUST -- SUPERSEDES tests/M8/tUqCsr.m header 9's
%      verdict NOT_ASSESSABLE (R(1) was searched clean); K4 (nominal fails):
%      lowerCertified false; K3 (ROBUST_TO_CAP): lowerCertified true, alphaLo 3.

    properties (Constant)
        MJ = [0.1 0.2 0.15]
    end

    methods (Static)
        function P = problem(mj, F, nC, groupConds, sw)
            % F: 1 x nG cell of f(s, k) -> margin, or a struct (status, reason[, sw])
            d = numel(mj);
            if nargin < 5, sw = struct([]); end
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.m = mj;
            P.conditions = num2cell(1:nC);
            P.condLabels = arrayfun(@(k) sprintf('c%d', k), 1:nC, 'UniformOutput', false);
            P.pointFcn = @(th, k) tUqR5.point(F, th, mj, k, sw);
            G = struct('name', {}, 'conds', {}, 'confirmFcn', {});
            for g = 1:numel(F)
                G(g).name = sprintf('g%d', g);
                G(g).conds = groupConds{g};
                f = F{g};
                G(g).confirmFcn = @(th) tUqR5.confirmAll(f, (th - 1) ./ mj, nC);
            end
            P.groups = G;
            P.shapes = struct('name', {'judged', 'equal'}, 'm', {mj, 0.1 * ones(1, d)});
            if ~isempty(sw)
                P.switches = struct('name', {sw.name}, 'breakpoints', {sw.breakpoints});
            end
        end

        function q = point(F, th, mj, k, sw)
            s = (th - 1) ./ mj;
            nG = numel(F);
            q.status = repmat({'OK'}, 1, nG);
            q.margin = NaN(1, nG);
            q.record = repmat({'R1'}, 1, nG);
            q.reason = repmat({''}, 1, nG);
            for g = 1:nG
                v = F{g}(s, k);
                if isstruct(v)
                    q.status{g} = v.status; q.reason{g} = v.reason; q.record{g} = '';
                else
                    q.margin(g) = v;
                end
            end
            if ~isempty(sw)
                q.switchVals = arrayfun(@(w) w.fcn(s), sw);
            end
        end

        function c = confirmAll(f, s, nC)
            m = NaN(1, nC);
            for k = 1:nC
                v = f(s, k);
                if isstruct(v)
                    c = struct('status', 'NOT_OK', 'margin', NaN, 'condLabel', sprintf('c%d', k), 'cond', k, ...
                        'record', '', 'reason', v.reason);
                    return
                end
                m(k) = v;
            end
            [mm, k] = min(m);
            c = struct('status', 'OK', 'margin', mm, 'condLabel', sprintf('c%d', k), 'cond', k, 'record', 'R1', ...
                'reason', '');
        end

        function c = confirmOkOnly(f, s, nC)
            % the minimum over the conditions that are OK (S8Q-1: a failing condition decides)
            m = NaN(1, nC);
            for k = 1:nC
                v = f(s, k);
                if ~isstruct(v), m(k) = v; end
            end
            [mm, k] = min(m);
            c = struct('status', 'OK', 'margin', mm, 'condLabel', sprintf('c%d', k), 'cond', k, 'record', 'R1', ...
                'reason', '');
        end

        function v = lin(s), v = 0.6 - 0.1 * (s(1) + s(2) + s(3)); end
        function v = kink(s), v = abs(s(1) - 1.5) - 0.05 + 0.05 * abs(s(2)) + 0.02 * s(3)^2; end
        function v = cap(s), v = 0.5 + 0.05 * s(1) - 0.03 * s(2) + 0.02 * s(3)^2; end
        function v = lip(s), v = 0.5 + 0.02 * s(1) - 0.05 * s(2) + 0.03 * s(3); end
        function v = pick(x, k), v = x(k); end

        function v = jump(s)
            v = 0.05 + 0.01 * s(1) + 0.1 * (s(1) + 0.5 * s(2) > 0.37);
        end

        function v = hidden(s)
            if s(1) <= 1.37, v = 0.2; else, v = -0.02 + 2 * (s(1) - 1.5)^2; end
        end

        function v = s8q1(s, k)
            if k == 1, v = tUqR5.lin(s); return; end
            if s(1) + s(2) + s(3) > 5
                v = struct('status', 'NOT_CONVERGED', 'reason', 'linearize: NOT_CONVERGED (toy)');
            else
                v = 1;
            end
        end

        function v = badAbove2(s)
            if s(1) > 2, error('vital:badInput', 'toy: a malformed input deep in the chain'); end
            v = 0.5;
        end

        function v = infPocket(s)
            if s(1) > 0.65 && s(1) < 0.7, v = -0.1;
            elseif s(1) > 0.5, v = Inf;
            else, v = 0.5;
            end
        end

        function c = csrToy(mref, fcn)
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:numel(mref), 'UniformOutput', false);
            P.nominal = ones(1, numel(mref));
            P.m = mref;
            P.conditions = {1};
            P.condLabels = {'c1'};
            P.pointFcn = @(th, k) tUqR5.wrap(fcn(th));
            P.confirmFcn = @(th) tUqR5.wrapConfirm(fcn(th));
            grid = @(Q) vital.uq.boundWorst(Q, 'Method', 'grid');
            c = vital.uq.csr(P, 'Search', grid, 'DecideAt', 1);
        end

        function q = wrap(v)
            if isstruct(v)
                q = struct('status', v.status, 'margin', NaN, 'record', '', 'reason', v.reason);
            else
                q = struct('status', 'OK', 'margin', v, 'record', 'R1', 'reason', '');
            end
        end

        function c = wrapConfirm(v)
            if isstruct(v)
                c = struct('status', 'NOT_OK', 'margin', NaN, 'condLabel', 'c1', 'cond', 1, 'record', '', 'reason', v.reason);
            else
                c = struct('status', 'OK', 'margin', v, 'condLabel', 'c1', 'cond', 1, 'record', 'R1', 'reason', '');
            end
        end

        function v = k9(th)
            if (th - 1) / 0.1 > 2
                v = struct('status', 'INFEASIBLE', 'reason', 'trim: INFEASIBLE (toy)');
            else
                v = 1;
            end
        end

        function g = grp(name, pc, lev, m, r)
            g = struct('group', name, 'pointClass', pc, 'why', '', 'level', lev, 'marginTo', m, 'recordTo', {r});
        end
    end

    methods (Access = private)
        function checkBracket(tc, c, a, what)
            tc.verifyEqual(c.status, 'OK', [what ': ' c.reason]);
            tc.verifyWithin(c.alphaStar, a - 0.01, a, 'ANALYTIC', [what ': alpha* - 0.01 <= alphaStar <= alpha*'], ...
                'Quantity', [what ' alphaStar']);
            tc.verifyWithin(c.alphaHi, a, a + 0.01 + 1e-12, 'ANALYTIC', [what ': alpha* <= alphaHi <= alpha* + 0.01'], ...
                'Quantity', [what ' alphaHi']);
        end

        function res = run1(tc, F, varargin) %#ok<INUSL>
            P = tUqR5.problem(tUqR5.MJ, {F}, 1, {1});
            res = vital.uq.lattice(P, varargin{:});
        end
    end

    methods (Test)
        function halfEdgeCertificate(tc)
            res = tc.run1(@(s, k) tUqR5.lip(s), 'Certificate', 'half');
            ce = res.groups(1).certificate;
            tc.verifyTol(ce.L, [0.4 0.5 0.4], 1e-12, 'abs', 'ANALYTIC', 'header 1: L = 2 x measured slope', ...
                'Quantity', 'lattice Lipschitz estimate');
            tc.verifyTol(ce.lowerBound, 0.14, 1e-12, 'abs', 'ANALYTIC', 'header 1: min vertex - sum L_i h_i / 2', ...
                'Quantity', 'lattice certified lower bound (h/2)');
            r0 = tc.run1(@(s, k) tUqR5.lip(s));
            tc.verifyEqual(r0.options.Certificate, 'half', 'header 1: h/2 is the default');
            tc.verifyTol(r0.groups(1).certificate.lowerBound, 0.14, 1e-12, 'abs', 'ANALYTIC', 'header 1: default', ...
                'Quantity', 'lattice certified lower bound (default)');
            rf = tc.run1(@(s, k) tUqR5.lip(s), 'Certificate', 'full');
            tc.verifyTol(rf.groups(1).certificate.lowerBound, 0.08, 1e-12, 'abs', 'ANALYTIC', ...
                'header 1: the superseded full-edge form', 'Quantity', 'lattice certified lower bound (full h)');
        end

        function verdictTruthTableR5(tc)
            c = @(s, a, lo, h, k, ce) struct('status', s, 'alphaStar', a, 'alphaLo', lo, 'alphaHi', h, ...
                'cpvConfirmed', k, 'lowerCertified', ce, 'lowerReason', '');
            m = @(p) struct('cpLower', p);
            [lo, ok] = vital.uq.lowerEnd(c('NOT_ASSESSABLE', NaN, 1.05, 1.2, true, true));
            tc.verifyEqual([lo ok], [1.05 1], 'lowerEnd of an R5 struct');
            rows = {c('NOT_ASSESSABLE', NaN, 1.05, 1.20, true, true), 0.99, 'ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 1.00, Inf, false, true), 0.95, 'ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 0.99, Inf, false, true), 0.99, 'NOT_ASSESSABLE'; ...
                    c('NOT_ASSESSABLE', NaN, 1.20, Inf, false, false), 0.99, 'NOT_ASSESSABLE'; ...
                    c('OK', 1.2, 1.20, 1.21, true, true), 0.99, 'ROBUST'; ...
                    c('OK', 0.8, 0.80, 0.81, true, true), 0.99, 'NOT_ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 0.40, 0.90, true, true), 0.99, 'NOT_ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 0.40, 0.90, false, true), 0.99, 'NOT_ASSESSABLE'; ...
                    c('ROBUST_TO_CAP', 3, 3, Inf, false, true), 0.99, 'ROBUST'; ...
                    c('ROBUST_TO_CAP', 3, 3, Inf, false, true), 0.94, 'NOT_ROBUST'; ...
                    c('ROBUST_TO_CAP', 3, 3, Inf, false, true), NaN, 'NOT_ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 1.50, Inf, false, true), NaN, 'NOT_ROBUST'};
            for i = 1:size(rows, 1)
                v = vital.uq.verdict(rows{i, 1}, m(rows{i, 2}));
                tc.verifyEqual(v.verdict, rows{i, 3}, sprintf('header 2 row %d: %s', i, v.reason));
                tc.verifyNotEmpty(v.reason, sprintf('header 2 row %d reason', i));
                tc.verifyEqual([v.alphaLo double(v.lowerCertified)], [rows{i, 1}.alphaLo double(rows{i, 1}.lowerCertified)], ...
                    sprintf('header 2 row %d: reported lower end', i));
            end
            bad = rmfield(c('OK', 1.2, 1.2, 1.21, true, true), 'alphaLo');
            tc.verifyError(@() vital.uq.verdict(bad, m(0.99)), 'vital:badInput');
            leg = @(s, a, h, k) struct('status', s, 'alphaStar', a, 'alphaHi', h, 'cpvConfirmed', k);
            [lo, ok] = vital.uq.lowerEnd(leg('OK', 1.2, 1.21, true));
            tc.verifyEqual([lo ok], [1.2 1], 'header 2: lowerEnd of a legacy R4 struct');
            [lo, ok] = vital.uq.lowerEnd(leg('NOT_ASSESSABLE', NaN, Inf, false));
            tc.verifyTrue(isnan(lo) && ~ok, 'header 2: lowerEnd of a legacy NOT_ASSESSABLE struct');
        end

        function verdictNaNMonteCarloLegacy(tc)
            % GUARD on existing behaviour (S8Q-7): a NaN Clopper-Pearson bound is never adequate
            leg = @(s, a, h, k) struct('status', s, 'alphaStar', a, 'alphaHi', h, 'cpvConfirmed', k);
            v = vital.uq.verdict(leg('OK', 1.2, 1.21, true), struct('cpLower', NaN));
            tc.verifyEqual(v.verdict, 'NOT_ROBUST', ['header 3: ' v.reason]);
            v = vital.uq.verdict(leg('ROBUST_TO_CAP', 3, Inf, false), struct('cpLower', NaN));
            tc.verifyEqual(v.verdict, 'NOT_ROBUST', ['header 3: ' v.reason]);
        end

        function r1DecidesTheVerdict(tc)
            res = tc.run1(@(s, k) 0.63 - 0.1 * (s(1) + s(2) + s(3)), 'MaxPoints', 1331);
            cj = res.groups(1).csr(1);
            [lo, ok] = vital.uq.lowerEnd(cj);
            tc.verifyTol(lo, 1.2, 1e-12, 'abs', 'ANALYTIC', 'header 4: entry alpha of [1.2, 1.8]^3', ...
                'Quantity', 'SHIFT judged alphaLo');
            tc.verifyTrue(ok, ['header 4: R(alphaLo) certified: ' cj.lowerReason]);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', cj.reason);
            tc.verifyTrue(startsWith(cj.reason, 'GRID'), cj.reason);
            tc.verifyTol(cj.alphaHi, 2.4, 1e-12, 'abs', 'ANALYTIC', 'header 4: base point (2.4, 2.4, 1.8)', ...
                'Quantity', 'SHIFT judged alphaHi');
            tc.verifyTrue(cj.cpvConfirmed, 'header 4: confirmed CPV');
            v = vital.uq.verdict(cj, struct('cpLower', 0.99));
            tc.verifyEqual(v.verdict, 'ROBUST', ['header 4 (R5-2): ' v.reason]);
            v4 = vital.uq.verdict(rmfield(cj, {'lowerCertified', 'lowerReason'}), struct('cpLower', 0.99));
            tc.verifyEqual(v4.verdict, 'NOT_ASSESSABLE', ['header 4: the legacy R4 reading: ' v4.reason]);
        end

        function judgedShapeFirst(tc)
            res = tc.run1(@(s, k) tUqR5.lin(s), 'MaxPoints', 6000, 'Certificate', 'half');
            cj = res.groups(1).csr(1); ce = res.groups(1).csr(2);
            tc.checkBracket(cj, 2, 'header 5 LIN judged');
            tc.verifyLessThanOrEqual(ce.alphaLo, 36 / 13, ['header 5 equal: ' ce.reason]);
            tc.verifyGreaterThanOrEqual(ce.alphaHi, 36 / 13, ['header 5 equal: ' ce.reason]);
            tc.verifyTrue(cj.lowerCertified && ce.lowerCertified, 'header 5: lowerCertified');
        end

        function jumpCertifiedPiecewise(tc)
            sw = struct('name', 'z', 'breakpoints', 0.37, 'fcn', @(s) s(1) + 0.5 * s(2));
            P = tUqR5.problem(tUqR5.MJ, {@(s, k) tUqR5.jump(s)}, 1, {1}, sw);
            res = vital.uq.lattice(P);
            for c = res.groups(1).csr
                tc.verifyEqual(c.status, 'ROBUST_TO_CAP', ['header 6 ' c.shape ': ' c.reason]);
            end
            tc.verifyEqual(res.lattice.nPoints, 1331, 'header 6: no refinement');
            D = res.groups(1).discontinuity;
            tc.verifyTrue(D.present, 'header 6: discontinuity reported');
            tc.verifyGreaterThan(D.nCells, 0, 'header 6');
            tc.verifyEqual(D.variables, {'z'}, 'header 6');
            tc.verifyEqual(D.breakpoints, 0.37, 'header 6');
            tc.verifyWithin(D.maxJump, 0.1 - 1e-12, 0.106 + 1e-12, 'ANALYTIC', 'header 6: jump over a straddling edge', ...
                'Quantity', 'JUMP largest jump');
            mj = tUqR5.MJ;
            st = res.box(1, 1 - mj, 1 + mj);
            tc.verifyEqual(st.status, 'OK', ['header 6: R(1): ' st.reason]);
            % guard: without the switch the jump defeats the certificate
            P0 = rmfield(P, 'switches');
            r0 = vital.uq.lattice(P0, 'MaxPoints', 3000);
            c0 = r0.groups(1).csr(1);
            tc.verifyEqual(c0.status, 'NOT_ASSESSABLE', ['header 6 guard: ' c0.reason]);
            tc.verifyTrue(startsWith(c0.reason, 'GRID'), ['header 6 guard: ' c0.reason]);
        end

        function jumpHidesFailure(tc)
            u = -3:0.6:3;
            tc.assertGreaterThan(min(arrayfun(@(x) tUqR5.hidden([x 0 0]), u)), 0, 'guard: every base point passes');
            sw = struct('name', 'z', 'breakpoints', 1.37, 'fcn', @(s) s(1));
            P = tUqR5.problem(tUqR5.MJ, {@(s, k) tUqR5.hidden(s)}, 1, {1}, sw);
            res = vital.uq.lattice(P);
            tc.checkBracket(res.groups(1).csr(1), 1.4, 'header 7 judged');
            tc.checkBracket(res.groups(1).csr(2), 1.4, 'header 7 equal');
            mj = tUqR5.MJ;
            st = res.box(1, 1 - 1.45 * mj, 1 + 1.45 * mj);
            tc.verifyEqual(st.status, 'VIOLATED', ['header 7: R(1.45): ' st.reason]);
        end

        function cornerCatchesCandidateGap(tc)
            F = @(s, k) tUqR5.pick([0.132 - 0.1 * s(1), 0.15 + 0.2 * s(2)], k);
            P = tUqR5.problem(tUqR5.MJ, {F}, 2, {1});
            res = vital.uq.lattice(P, 'CornerChecks', true);
            g = res.groups(1);
            cj = g.csr(1);
            tc.verifyTrue(any(strcmp(g.condLabels, 'c2')), 'header 8: c2 added');
            tc.checkBracket(cj, 0.75, 'header 8 judged');
            tc.verifyEqual(cj.cpvCond, 'c2', 'header 8');
            items = [g.rounds.confirmations];
            mv = items([items.moved]);
            tc.verifyTrue(any(startsWith({mv.what}, 'corner R(')), 'header 8: a corner moved the limit');
            v = vital.uq.verdict(cj, struct('cpLower', 0.99));
            tc.verifyEqual(v.verdict, 'NOT_ROBUST', ['header 8: ' v.reason]);
            r0 = vital.uq.lattice(P, 'MaxPoints', 1331);
            tc.verifyTrue(r0.options.CornerChecks, 'header 8: corners on by default');
        end

        function cornerCatchesCapGap(tc)
            F = @(s, k) tUqR5.pick([0.3 + 0.05 * s(1) - 0.01 * s(2), 0.35 + 0.2 * s(2)], k);
            P = tUqR5.problem(tUqR5.MJ, {F}, 2, {1});
            res = vital.uq.lattice(P, 'CornerChecks', true);
            g = res.groups(1);
            tc.checkBracket(g.csr(1), 1.75, 'header 9 judged');
            tc.verifyTrue(any(strcmp(g.condLabels, 'c2')), 'header 9: c2 added');
            r0 = vital.uq.lattice(P, 'CornerChecks', false);
            tc.verifyEqual(r0.groups(1).csr(1).status, 'ROBUST_TO_CAP', ['header 9 guard (as built): ' ...
                r0.groups(1).csr(1).reason]);
        end

        function movingLimitPositive(tc)
            F = @(s, k) tUqR5.pick([0.41 - 0.1 * s(1) + 0.01 * s(2) + 0.01 * s(3), ...
                0.03 + 0.1 * (abs(s(1)) - 1) * (abs(s(1)) - 3)], k);
            P = tUqR5.problem(tUqR5.MJ, {F}, 2, {1});
            res = vital.uq.lattice(P);
            g = res.groups(1);
            a = 2 - sqrt(0.7);
            c = g.csr(1);
            tc.verifyTrue(any(strcmp(g.condLabels, 'c2')), 'header 10: c2 added');
            tc.verifyNotEqual(c.status, 'ROBUST_TO_CAP', ['header 10: ' c.reason]);
            tc.verifyWithin(c.alphaLo, a - 0.02, a, 'ANALYTIC', 'header 10: alphaLo', 'Quantity', 'POSML alphaLo');
            tc.verifyWithin(c.alphaHi, a, a + 0.01 + 1e-12, 'ANALYTIC', 'header 10: alphaHi', 'Quantity', 'POSML alphaHi');
        end

        function failingCandidateDecides(tc)
            F = @(s, k) tUqR5.s8q1(s, k);
            P = tUqR5.problem(tUqR5.MJ, {F}, 2, {[1 2]});
            P.groups(1).confirmFcn = @(th) tUqR5.confirmOkOnly(F, (th - 1) ./ tUqR5.MJ, 2);
            res = vital.uq.lattice(P);
            mj = tUqR5.MJ;
            st = res.box(1, 1 - 3 * mj, 1 + 3 * mj);
            tc.verifyEqual(st.status, 'VIOLATED', ['header 11: ' st.reason]);
            cj = res.groups(1).csr(1);
            tc.verifyLessThanOrEqual(cj.alphaHi, 3, 'header 11: a failing lattice point bounds alpha*');
            tc.verifyTrue(cj.cpvConfirmed, 'header 11: confirmed CPV');
        end

        function confirmationDisagrees(tc)
            P = tUqR5.problem(tUqR5.MJ, {@(s, k) tUqR5.cap(s)}, 1, {1});
            P.groups(1).confirmFcn = @(th) struct('status', 'OK', 'margin', -0.1, 'condLabel', 'c1', 'cond', 1, ...
                'record', 'R1', 'reason', 'toy: the fresh assessment fails');
            res = vital.uq.lattice(P);
            cj = res.groups(1).csr(1);
            [~, ok, why] = vital.uq.lowerEnd(cj);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', ['header 12: ' cj.reason]);
            tc.verifySubstring(cj.reason, 'disagree', 'header 12');
            tc.verifyTrue(startsWith(cj.reason, 'the confirmation at the cap-box arg-min fails'), ...
                ['header 12 (cap-branch guard): ' cj.reason]);
            tc.verifyFalse(ok, ['header 12: ' why]);
            v = vital.uq.verdict(cj, struct('cpLower', 0.99));
            tc.verifyNotEqual(v.verdict, 'ROBUST', ['header 12: ' v.reason]);
        end

        function maxNotMeanSlope(tc)
            res = tc.run1(@(s, k) 1.5 - 0.05 * s(1) * s(2));
            ce = res.groups(1).certificate;
            tc.verifyTol(ce.maxSlope, [1.5 0.75 0], 1e-12, 'abs', 'ANALYTIC', 'header 13: max over parallel edges', ...
                'Quantity', 'lattice max slope (non-separable)');
            tc.verifyEqual(res.groups(1).csr(1).status, 'ROBUST_TO_CAP', res.groups(1).csr(1).reason);
        end

        function worseOfSideBNaN(tc)
            A.status = 'OK'; B.status = 'OK';
            A.groups = tUqR5.grp('g3', 'OK', 1, [0.5 0.2 1], {'c', 'c', 'c'});
            B.groups = tUqR5.grp('g3', 'OK', 1, [0.4 NaN 1], {'d', '', 'd'});
            A.spiralRe = -0.01; B.spiralRe = -0.02;
            S = vital.uq.F16Evaluator.worseOf(A, B);
            tc.verifyTrue(isequaln(S.groups(1).marginTo, [0.4 NaN 1]), ...
                sprintf('header 14: NaN on side B wins (%s)', mat2str(S.groups(1).marginTo)));
        end

        function badInputIsErrorPoint(tc)
            res = tc.run1(@(s, k) tUqR5.badAbove2(s));
            cj = res.groups(1).csr(1);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', ['header 15: ' cj.reason]);
            tc.verifySubstring(cj.reason, 'ERROR', 'header 15');
            tc.verifyTol(cj.alphaLo, 1.8, 1e-12, 'abs', 'ANALYTIC', 'header 15: entry alpha of [1.8, 2.4]', ...
                'Quantity', 'ERROR alphaLo');
            P = tUqR5.problem(tUqR5.MJ, {@(s, k) 1}, 1, {1});
            P.pointFcn = @(th, k) struct('status', {{'OK'}});
            tc.verifyError(@() vital.uq.lattice(P), 'vital:uq:badPointResult');
        end

        function allInfCellNotCertified(tc)
            res = tc.run1(@(s, k) tUqR5.infPocket(s));
            cj = res.groups(1).csr(1);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', ['header 16: ' cj.reason]);
            tc.verifySubstring(cj.reason, 'Inf', 'header 16');
            tc.verifyTol(cj.alphaLo, 0.6, 1e-12, 'abs', 'ANALYTIC', 'header 16: entry alpha of the +Inf cells', ...
                'Quantity', 'INF alphaLo');
            tc.verifyEqual(res.lattice.nPoints, 1331, 'header 16: +Inf cells are not refined');
        end

        function globalLatticeBudget(tc)
            toys = {@(s, k) tUqR5.lin(s), @(s, k) tUqR5.kink(s), @(s, k) tUqR5.cap(s)};
            P = tUqR5.problem(tUqR5.MJ, toys, 1, {1, 1, 1});
            res = vital.uq.lattice(P, 'MaxTotalPoints', 3000);
            tc.verifyLessThanOrEqual(res.lattice.nPoints, 3000, 'header 17');
            tc.verifyTrue(res.lattice.budgetExhausted, 'header 17');
            for g = 1:2
                c = res.groups(g).csr(1);
                tc.verifyEqual(c.status, 'NOT_ASSESSABLE', sprintf('header 17 group %d: %s', g, c.reason));
                tc.verifySubstring(c.reason, 'global', sprintf('header 17 group %d', g));
            end
            tc.verifyEqual(res.groups(3).csr(1).status, 'ROBUST_TO_CAP', ['header 17: ' res.groups(3).csr(1).reason]);
            r0 = tc.run1(@(s, k) tUqR5.cap(s));
            tc.verifyEqual(r0.options.MaxTotalPoints, Inf, 'header 17: default');
        end

        function stageBandRule(tc)
            tc.verifyTol(vital.uq.stageBand([0.05 0.12]), [0.76 1.24], 1e-12, 'abs', 'ANALYTIC', 'header 18', ...
                'Quantity', 'stage band');
            tc.verifyTol(vital.uq.stageBand([0 0.01]), [0.8 1.2], 1e-12, 'abs', 'ANALYTIC', 'header 18: floor', ...
                'Quantity', 'stage band (floor)');
            tc.verifyTol(vital.uq.stageBand(0.3), [0.4 1.6], 1e-12, 'abs', 'ANALYTIC', 'header 18', ...
                'Quantity', 'stage band (wide)');
            tc.verifyError(@() vital.uq.stageBand([]), 'vital:badInput');
            tc.verifyError(@() vital.uq.stageBand(NaN), 'vital:badInput');
            tc.verifyError(@() vital.uq.stageBand(-0.1), 'vital:badInput');
        end

        function statementsAndJudgments(tc)
            J = vital.uq.statements('judgments');
            Lm = vital.uq.statements('limits');
            jt = strjoin(J, ' '); lt = strjoin(Lm, ' ');
            for s = {'Cm_basic and Cm_de are treated as independent', 'wings-level'}
                tc.verifySubstring(jt, s{1}, 'header 19 judgments');
            end
            for s = {'narrower than a lattice cell', 'discontinuous', 'h/2', 'engineering rule', ...
                    'per-condition success probability', 'candidate conditions only', 'R(1)'}
                tc.verifySubstring(lt, s{1}, 'header 19 limits');
            end
            spec = vital.uq.loadSpec();
            tc.verifyEqual(spec.judgments, J, 'header 19: the spec carries the judgments');
            tc.verifyError(@() vital.uq.statements('x'), 'vital:badInput');
        end

        function csrLowerCertified(tc)
            c = tUqR5.csrToy(0.1, @(th) tUqR5.k9(th));
            [lo, ok] = vital.uq.lowerEnd(c);
            tc.verifyEqual(c.status, 'NOT_ASSESSABLE', c.reason);
            tc.verifyEqual(lo, 1, 'header 20 K9: alphaLo');
            tc.verifyTrue(ok, ['header 20 K9: ' c.lowerReason]);
            v = vital.uq.verdict(c, struct('cpLower', 0.99));
            tc.verifyEqual(v.verdict, 'ROBUST', ['header 20 K9 (supersedes tUqCsr header 9): ' v.reason]);
            c = tUqR5.csrToy(0.1, @(th) -0.05 + 0.1 * (th - 1) / 0.1);
            tc.verifyFalse(c.lowerCertified, 'header 20 K4: the nominal fails');
            c = tUqR5.csrToy([0.1 0.1], @(th) 0.5 + 0.1 * ((th(1) - 1) / 0.1)^2 - 0.05 * (th(2) - 1) / 0.1);
            tc.verifyEqual(c.status, 'ROBUST_TO_CAP', c.reason);
            tc.verifyTrue(c.lowerCertified, 'header 20 K3');
            tc.verifyEqual(c.alphaLo, 3, 'header 20 K3');
        end
    end
end
