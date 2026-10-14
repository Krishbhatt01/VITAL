classdef (TestTags = {'M8'}) tUqLattice < vital.test.VitalTestCase
%TUQLATTICE  M8 amendment R4b, item R4-3 corrected (docs/PLAN_M5_M8.md,
%   "Amendment R4b", coordinator 2026-10-14): ONE shared adaptive lattice for
%   the longitudinal groups, vital.uq.lattice, on closed-form margins (no
%   aircraft). Expected runtime: under 1 min.
%
%   Lattice (stated here, before any implementation; the defaults of
%   vital.uq.lattice): the box nominal +/- AlphaMax (3) x the judged half-widths
%   m_j (the cap box of the judged shape); 'GridPoints' 11 per axis (odd: the
%   nominal is a lattice point); integer lattice t = k/K, K = 10 x 2^MaxLevel,
%   theta = lo + (hi - lo) .* (k ./ K) per axis, with theta = hi exactly at
%   k = K and theta = nominal exactly at k = K/2;
%   'MaxLevel' 10 halvings per axis; 'MaxPoints' 20000 lattice points (toys).
%   Every lattice point is evaluated by ONE call pointFcn(theta, cond) that
%   returns the margins of EVERY group (q.status, q.margin, q.record, q.reason:
%   1 x nG); a (point, condition) pair is never evaluated twice.
%   Certificate of a cell for a group (R4b: "cell minimum - L h, with L = 2 x
%   the measured local slopes"): bound = min(vertex margins) - sum_i L_i h_i,
%   h_i the cell's edge along axis i (theta units), L_i = LipschitzFactor (2) x
%   the largest measured slope |dm|/dtheta_i over the cell's own edges along i
%   and over the base-lattice edges along i of the base cells within one base
%   cell of it (its 3^d base neighbourhood: "local"). A cell is certified when
%   bound >= reserve (0) and every vertex is OK.
%   Refinement (only near the zero level set): a cell with every vertex OK,
%   not certified, not every vertex failing, below MaxLevel, is subdivided
%   when it can still move alpha* of some shape (its entry alpha, the
%   smallest alpha whose box R(alpha) meets the cell, is below alphaHi - 0.01,
%   or below AlphaMax while no failure is known, or below the DecideAt value 1
%   of the judged shape while 1 lies inside the bracket). Subdivision is
%   anisotropic: the axes whose term L_i h_i is at least half the largest.
%   Per box R(alpha) of a shape: VIOLATED on a lattice point with margin < 0
%   inside the box; NOT_ASSESSABLE if a lattice point inside is not OK or a
%   cell meeting the box is not certified (reason starting 'GRID' for the
%   latter); OK otherwise. alpha*: alphaLo = alphaStar = min(AlphaMax, the
%   smallest entry alpha of a non-certified cell), alphaHi = the smallest scaled
%   infinity norm of a failing lattice point (the CPV, confirmed by the group's
%   fresh confirmFcn with the moving-limit rule of R3-M4, at most MaxRounds 3
%   rounds). Status OK: alphaHi - alphaLo <= 0.01 with a confirmed CPV;
%   ROBUST_TO_CAP: no failure and every cell meeting R(AlphaMax) certified;
%   otherwise NOT_ASSESSABLE. No box search is run (nSearches 0, method
%   'lattice'). Shapes: judged m_j and equal percentage 0.10.
%   Toys: s = (p - 1)./m_j (judged scaled coordinates), m_j = [0.1 0.2 0.15]
%   (3-D) so the equal-percentage cap box (+/-0.3) lies inside the lattice box
%   (+/- 3 m_j). Every group's confirmFcn is the minimum over ALL the toy's
%   conditions (the fresh assessment of the toys).
%
%   PRE-REGISTERED (agent uq4, 2026-10-14, with the stubs, before any
%   implementation; every expected alpha* is ANALYTIC from the closed forms):
%   1. CORNER FIRST, LINEAR (LIN): m = 0.6 - 0.1 (s1 + s2 + s3). Judged: the
%      box corner (a, a, a) touches first: alpha* = 2 exactly. Equal (|p_i - 1|
%      <= 0.1 b, i.e. s_i <= b (1, 0.5, 2/3)): min = 0.6 - 0.1 b (13/6), so
%      b* = 36/13 = 2.769231. Both: status 'OK', alphaStar in [a* - 0.01, a*],
%      alphaHi in [a*, a* + 0.01], alphaHi - alphaStar <= 0.01 (+1e-12),
%      alphaLo = alphaStar, cpvConfirmed true with confirmation.evaluated true
%      and confirmation margin < 0, the CPV within 0.01 m_i (shape units) of
%      the touching corner on every axis, method 'lattice', nSearches 0,
%      psm = alphaStar m.
%   2. KINKED SURFACE, HIDDEN FAILURE (KINK): m = |s1 - 1.5| - 0.05 +
%      0.05 |s2| + 0.02 s3^2 (V-shaped in s1 and s2). Failure only in the band
%      1.45 < s1 < 1.55 near s2 = s3 = 0, which the base lattice (s1 = 1.2,
%      1.8, ...) does not sample: guard, every base lattice point has m > 0
%      (checked in the test). The box R(a) first touches failure at
%      (1.45, 0, 0), the interior of a face: alpha* = 1.45 (judged); equal
%      (s1 <= b, since m_j1 = 0.1): b* = 1.45. Both 'OK' with the bracket
%      conditions of item 1; the judged CPV within 0.01 m_1 of p1 = 1.145.
%      The failure can only be found by refining cells whose sampled minimum
%      is > 0 (sabotage S8X-1).
%   3. ROBUST TO THE CAP (CAP): m = 0.5 + 0.05 s1 - 0.03 s2 + 0.02 s3^2 (min
%      over the cap box 0.26 > 0). Both shapes 'ROBUST_TO_CAP', alphaStar 3
%      (exact), alphaHi Inf, cpv NaN, cpvConfirmed false; no refinement is
%      needed (ANALYTIC: every base cell's bound >= 0.26 - 2 (0.03 + 0.018 +
%      0.0648) > 0): exactly 11^3 = 1331 lattice points; the cap box R(3)
%      status 'OK'.
%   4. LIPSCHITZ CERTIFICATE (LIP, ANALYTIC): m = 0.5 + 0.02 s1 - 0.05 s2 +
%      0.03 s3 (linear; every secant equals the gradient dm/dp = [0.2 -0.25
%      0.2]): certificate.maxSlope = [0.2 0.25 0.2], certificate.L = 2 x that
%      = [0.4 0.5 0.4] (1e-12 abs), certificate.factor 2, and the certified
%      lower bound = min vertex - sum L_i h_i over the worst base cell = 0.2 -
%      (0.4 x 0.06 + 0.5 x 0.12 + 0.4 x 0.09) = 0.08 (1e-12 abs; h = 0.6 m_j),
%      'ROBUST_TO_CAP' (sabotage S8X-2: factor dropped -> L = [0.2 0.25 0.2],
%      bound 0.14).
%   5. NOMINAL FAILS (NOM): m = -0.05 + 0.1 s1: both shapes 'OK', alphaStar =
%      alphaHi = 0 (exact), CPV = the nominal (exact), cpvConfirmed true.
%   6. MOVING LIMIT (ML; R3-M4 inside the lattice): conditions c1, c2; the
%      group's candidates are c1 only; m(c1) = 0.35 - 0.1 s1, m(c2) = 0.2 -
%      0.1 s1. Over c1 alone the cap box is clean (min 0.05); the confirmation
%      at the cap box's arg-min finds c2 (margin -0.1) -> c2 is added, the
%      lattice is evaluated at c2 -> judged alpha* = 2.0: status 'OK',
%      alphaStar in [1.99, 2], alphaHi in [2, 2.01], 'c2' in the group's
%      condLabels and the csr's condLabels, cpvCond 'c2'; rounds >= 2.
%   7. NON-OK LATTICE POINTS (NONOK): margin 0.5 everywhere, status
%      'INFEASIBLE' where s1 > 2. The base cell [1.8, 2.4] in s1 has a non-OK
%      vertex at s1 = 2.4, so (judged) alphaLo = 1.8 (1e-12 abs), alphaHi Inf,
%      status 'NOT_ASSESSABLE', reason mentioning 'INFEASIBLE', alphaStar NaN;
%      the box R(1) is 'OK' (res.box) and R(2.5) 'NOT_ASSESSABLE' with
%      'INFEASIBLE' in its reason.
%   8. CAPS: KINK with 'MaxLevel' 2: the hidden band cannot be resolved: judged
%      status 'NOT_ASSESSABLE' with a reason starting 'GRID', never 'OK';
%      alphaLo <= 1.45 <= alphaHi. 'MaxPoints' 1331 with LIN: 'NOT_ASSESSABLE',
%      reason starting 'GRID', lattice.capped true.
%   9. ONE EVALUATION PASS, SHARED (the R4b requirement): groups LIN (conditions
%      c1, c2), KINK (c1) and CAP (c1, c2) with m_g(s, k) = toy_g(s) + 0.01
%      (k - 1), both shapes, plus 'Boxes' alpha 1, then res.box queries for
%      every group, both shapes, alpha = 0.25:0.25:3:
%      a) no (theta, condition) pair is passed to pointFcn twice (counter);
%      b) every one of the 11^3 base points is evaluated exactly once at c1
%         and exactly once at c2 (c2 is used by LIN and CAP);
%      c) the res.box queries add no pointFcn call (counter unchanged);
%      d) each group's results (status, alphaStar, alphaHi, cpv of both
%         shapes) are identical (isequaln) to a lattice of that group alone:
%         sharing never changes an answer;
%      e) res.counts.pointEvals equals the counter's number of calls.
%   10. BOX STATUS (LIN, judged): res.box at R(alphaStar) 'OK' with
%      lowerBound >= 0; at R(alphaHi) 'VIOLATED' with value < 0; at R(1)
%      (the 'Boxes' entry, reported as res.groups.boxes(1), a bound-worst
%      compatible struct) 'OK' with label 'grid-certified (Lipschitz
%      estimate)', method 'lattice' and value >= 0.3 - 1e-12 (ANALYTIC: the
%      true minimum over R(1) is 0.6 - 0.3 = 0.3 at the R(1) corner; the
%      reported value is the minimum over the lattice points inside R(1),
%      which can never be below the true minimum).
%   11. FAILURE MODES: 'GridPoints' 10 (even) -> vital:badInput; an equal
%      shape whose cap box leaves the lattice box (m = 0.2 on an axis with
%      m_j = 0.1) -> vital:badInput; nominal - 3 m_j < 0 ->
%      vital:uq:negativeMultiplier; a group with an unknown condition index ->
%      vital:badInput.

    properties (Constant)
        MJ = [0.1 0.2 0.15]
    end

    methods (Static)
        function P = problem(mj, F, nC, groupConds, cnt)
            % F: 1 x nG cell of f(s, k) -> margin, or a struct (status, reason) for a non-OK point
            d = numel(mj);
            if nargin < 5, cnt = containers.Map('KeyType', 'char', 'ValueType', 'double'); end
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.m = mj;
            P.conditions = num2cell(1:nC);
            P.condLabels = arrayfun(@(k) sprintf('c%d', k), 1:nC, 'UniformOutput', false);
            P.pointFcn = @(th, k) tUqLattice.point(F, th, mj, k, cnt);
            G = struct('name', {}, 'conds', {}, 'confirmFcn', {});
            for g = 1:numel(F)
                G(g).name = sprintf('g%d', g);
                G(g).conds = groupConds{g};
                f = F{g};
                G(g).confirmFcn = @(th) tUqLattice.confirmAll(f, (th - 1) ./ mj, nC);
            end
            P.groups = G;
            P.shapes = struct('name', {'judged', 'equal'}, 'm', {mj, 0.1 * ones(1, d)});
        end

        function q = point(F, th, mj, k, cnt)
            key = [sprintf('%.17g,', th) sprintf('#%d', k)];
            if isKey(cnt, key), cnt(key) = cnt(key) + 1; else, cnt(key) = 1; end
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

        function v = lin(s), v = 0.6 - 0.1 * (s(1) + s(2) + s(3)); end
        function v = kink(s), v = abs(s(1) - 1.5) - 0.05 + 0.05 * abs(s(2)) + 0.02 * s(3)^2; end
        function v = cap(s), v = 0.5 + 0.05 * s(1) - 0.03 * s(2) + 0.02 * s(3)^2; end
        function v = lip(s), v = 0.5 + 0.02 * s(1) - 0.05 * s(2) + 0.03 * s(3); end

        function v = nonok(s)
            if s(1) > 2
                v = struct('status', 'INFEASIBLE', 'reason', 'trim: INFEASIBLE (toy)');
            else
                v = 0.5;
            end
        end

        function n = calls(cnt)
            v = cell2mat(values(cnt));
            if isempty(v), n = 0; else, n = sum(v); end
        end
    end

    methods (Access = private)
        function checkBracket(tc, c, a, what)
            tc.verifyEqual(c.status, 'OK', [what ': ' c.reason]);
            tc.verifyWithin(c.alphaStar, a - 0.01, a, 'ANALYTIC', [what ': alpha* - 0.01 <= alphaStar <= alpha*'], ...
                'Quantity', [what ' alphaStar']);
            tc.verifyWithin(c.alphaHi, a, a + 0.01 + 1e-12, 'ANALYTIC', [what ': alpha* <= alphaHi <= alpha* + 0.01'], ...
                'Quantity', [what ' alphaHi']);
            tc.verifyLessThanOrEqual(c.alphaHi - c.alphaStar, 0.01 + 1e-12, [what ': bracket <= resolution']);
            tc.verifyEqual(c.alphaLo, c.alphaStar, [what ': alphaStar = alphaLo']);
            tc.verifyTrue(c.cpvConfirmed, [what ': confirmed CPV']);
            tc.verifyTrue(c.confirmation.evaluated, [what ': confirmation evaluated']);
            tc.verifyLessThan(c.confirmation.margin, 0, [what ': the confirmation fails']);
            tc.verifyEqual(c.method, 'lattice', what);
            tc.verifyEqual(c.nSearches, 0, [what ': no box search']);
            tc.verifyEqual(c.psm, c.alphaStar * c.m, [what ': psm = alpha* m']);
        end

        function res = run1(tc, F, varargin) %#ok<INUSL>
            P = tUqLattice.problem(tUqLattice.MJ, {F}, 1, {1});
            res = vital.uq.lattice(P, varargin{:});
        end
    end

    methods (Test)
        function cornerFirstLinear(tc)
            res = tc.run1(@(s, k) tUqLattice.lin(s));
            cj = res.groups(1).csr(1); ce = res.groups(1).csr(2);
            tc.verifyEqual({cj.shape, ce.shape}, {'judged', 'equal'});
            tc.checkBracket(cj, 2, 'LIN judged');
            tc.checkBracket(ce, 36 / 13, 'LIN equal');
            mj = tUqLattice.MJ;
            tc.verifyTol((cj.cpv - 1) ./ mj, [2 2 2], 0.01, 'abs', 'ANALYTIC', 'header 1: judged CPV at the corner', ...
                'Quantity', 'LIN judged CPV (scaled)');
            tc.verifyTol((ce.cpv - 1) / 0.1, (36 / 13) * [1 1 1], 0.01, 'abs', 'ANALYTIC', ...
                'header 1: equal CPV at the corner', 'Quantity', 'LIN equal CPV (scaled)');
        end

        function kinkedHiddenBand(tc)
            mj = tUqLattice.MJ;
            u = -3:0.6:3;
            [a, b, c] = ndgrid(u, u, u);
            base = arrayfun(@(i) tUqLattice.kink([a(i) b(i) c(i)]), 1:numel(a));
            tc.assertGreaterThan(min(base), 0, 'guard: the base lattice does not sample the failure band');
            res = tc.run1(@(s, k) tUqLattice.kink(s));
            cj = res.groups(1).csr(1); ce = res.groups(1).csr(2);
            tc.checkBracket(cj, 1.45, 'KINK judged');
            tc.checkBracket(ce, 1.45, 'KINK equal');
            tc.verifyTol(cj.cpv(1), 1.145, 0.01 * mj(1), 'abs', 'ANALYTIC', 'header 2: CPV p1', 'Quantity', 'KINK CPV p1');
        end

        function robustToCap(tc)
            res = tc.run1(@(s, k) tUqLattice.cap(s));
            for c = res.groups(1).csr
                tc.verifyEqual(c.status, 'ROBUST_TO_CAP', [c.shape ': ' c.reason]);
                tc.verifyEqual(c.alphaStar, 3, c.shape);
                tc.verifyEqual(c.alphaHi, Inf, c.shape);
                tc.verifyTrue(all(isnan(c.cpv)), c.shape);
                tc.verifyFalse(c.cpvConfirmed, c.shape);
            end
            tc.verifyEqual(res.lattice.nPoints, 1331, 'header 3: no refinement');
            mj = tUqLattice.MJ;
            st = res.box(1, 1 - 3 * mj, 1 + 3 * mj);
            tc.verifyEqual(st.status, 'OK', st.reason);
        end

        function lipschitzCertificate(tc)
            res = tc.run1(@(s, k) tUqLattice.lip(s));
            ce = res.groups(1).certificate;
            tc.verifyTol(ce.maxSlope, [0.2 0.25 0.2], 1e-12, 'abs', 'ANALYTIC', 'header 4: secant = gradient', ...
                'Quantity', 'lattice max slope');
            tc.verifyTol(ce.L, [0.4 0.5 0.4], 1e-12, 'abs', 'ANALYTIC', 'header 4: L = 2 x measured slope', ...
                'Quantity', 'lattice Lipschitz estimate');
            tc.verifyEqual(ce.factor, 2);
            tc.verifyTol(ce.lowerBound, 0.08, 1e-12, 'abs', 'ANALYTIC', 'header 4: min vertex - sum L_i h_i', ...
                'Quantity', 'lattice certified lower bound');
            tc.verifyEqual(res.groups(1).csr(1).status, 'ROBUST_TO_CAP', res.groups(1).csr(1).reason);
        end

        function nominalFails(tc)
            res = tc.run1(@(s, k) -0.05 + 0.1 * s(1));
            for c = res.groups(1).csr
                tc.verifyEqual(c.status, 'OK', [c.shape ': ' c.reason]);
                tc.verifyEqual([c.alphaStar c.alphaHi], [0 0], c.shape);
                tc.verifyEqual(c.cpv, [1 1 1], c.shape);
                tc.verifyTrue(c.cpvConfirmed, c.shape);
            end
        end

        function movingLimit(tc)
            F = @(s, k) tUqLattice.pick([0.35 - 0.1 * s(1), 0.2 - 0.1 * s(1)], k);
            P = tUqLattice.problem(tUqLattice.MJ, {F}, 2, {1});
            res = vital.uq.lattice(P);
            g = res.groups(1);
            cj = g.csr(1);
            tc.verifyEqual(cj.status, 'OK', cj.reason);
            tc.verifyWithin(cj.alphaStar, 1.99, 2, 'ANALYTIC', 'header 6', 'Quantity', 'ML alphaStar');
            tc.verifyWithin(cj.alphaHi, 2, 2.01 + 1e-12, 'ANALYTIC', 'header 6', 'Quantity', 'ML alphaHi');
            tc.verifyTrue(any(strcmp(g.condLabels, 'c2')), 'header 6: c2 added to the group');
            tc.verifyTrue(any(strcmp(cj.condLabels, 'c2')), 'header 6: c2 among the csr conditions');
            tc.verifyEqual(cj.cpvCond, 'c2', 'header 6');
            tc.verifyGreaterThanOrEqual(numel(g.rounds), 2, 'header 6: a second round');
        end

        function nonOkLatticePoints(tc)
            res = tc.run1(@(s, k) tUqLattice.nonok(s));
            cj = res.groups(1).csr(1);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', cj.reason);
            tc.verifySubstring(cj.reason, 'INFEASIBLE');
            tc.verifyTol(cj.alphaLo, 1.8, 1e-12, 'abs', 'ANALYTIC', 'header 7: entry alpha of the cell [1.8, 2.4]', ...
                'Quantity', 'NONOK alphaLo');
            tc.verifyEqual(cj.alphaHi, Inf);
            tc.verifyTrue(isnan(cj.alphaStar));
            mj = tUqLattice.MJ;
            st = res.box(1, 1 - mj, 1 + mj);
            tc.verifyEqual(st.status, 'OK', ['header 7: R(1): ' st.reason]);
            st = res.box(1, 1 - 2.5 * mj, 1 + 2.5 * mj);
            tc.verifyEqual(st.status, 'NOT_ASSESSABLE', 'header 7: R(2.5)');
            tc.verifySubstring(st.reason, 'INFEASIBLE');
        end

        function capsGiveGrid(tc)
            res = tc.run1(@(s, k) tUqLattice.kink(s), 'MaxLevel', 2);
            cj = res.groups(1).csr(1);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', cj.reason);
            tc.verifyTrue(startsWith(cj.reason, 'GRID'), cj.reason);
            tc.verifyLessThanOrEqual(cj.alphaLo, 1.45, 'header 8');
            tc.verifyGreaterThanOrEqual(cj.alphaHi, 1.45, 'header 8');
            res = tc.run1(@(s, k) tUqLattice.lin(s), 'MaxPoints', 1331);
            cj = res.groups(1).csr(1);
            tc.verifyEqual(cj.status, 'NOT_ASSESSABLE', cj.reason);
            tc.verifyTrue(startsWith(cj.reason, 'GRID'), cj.reason);
            tc.verifyTrue(res.lattice.capped, 'header 8: lattice capped');
        end

        function sharedLatticeEvaluatedOnce(tc)
            toys = {@(s) tUqLattice.lin(s), @(s) tUqLattice.kink(s), @(s) tUqLattice.cap(s)};
            F = cellfun(@(f) @(s, k) f(s) + 0.01 * (k - 1), toys, 'UniformOutput', false);
            gc = {[1 2], 1, [1 2]};
            cnt = containers.Map('KeyType', 'char', 'ValueType', 'double');
            P = tUqLattice.problem(tUqLattice.MJ, F, 2, gc, cnt);
            res = vital.uq.lattice(P, 'Boxes', struct('name', 'x1', 'alpha', 1));
            v = cell2mat(values(cnt));
            tc.verifyEqual(max(v), 1, 'header 9a: no (theta, condition) evaluated twice');
            tc.verifyEqual(res.counts.pointEvals, sum(v), 'header 9e');
            % 9b: base points once at c1 and once at c2
            mj = tUqLattice.MJ;
            lo = 1 - 3 * mj; hi = 1 + 3 * mj;
            u = lo + (hi - lo) .* ((0:10).' * 1024 ./ 10240);
            u(end, :) = hi; u(6, :) = 1;
            [a, b, c] = ndgrid(u(:, 1), u(:, 2), u(:, 3));
            nb = [0 0];
            for i = 1:numel(a)
                th = [a(i) b(i) c(i)];
                for k = 1:2
                    key = [sprintf('%.17g,', th) sprintf('#%d', k)];
                    nb(k) = nb(k) + (isKey(cnt, key) && cnt(key) == 1);
                end
            end
            tc.verifyEqual(nb, [1331 1331], 'header 9b: every base point once per condition');
            % 9c: queries never evaluate
            n0 = tUqLattice.calls(cnt);
            for g = 1:3
                for sh = {mj, 0.1 * ones(1, 3)}
                    for al = 0.25:0.25:3
                        res.box(g, 1 - al * sh{1}, 1 + al * sh{1});
                    end
                end
            end
            tc.verifyEqual(tUqLattice.calls(cnt), n0, 'header 9c: box queries add no evaluation');
            % 9d: sharing never changes an answer
            for g = 1:3
                P1 = tUqLattice.problem(tUqLattice.MJ, F(g), 2, gc(g));
                r1 = vital.uq.lattice(P1, 'Boxes', struct('name', 'x1', 'alpha', 1));
                for s = 1:2
                    A = res.groups(g).csr(s); B = r1.groups(1).csr(s);
                    tc.verifyTrue(isequaln({A.status, A.alphaStar, A.alphaHi, A.cpv}, {B.status, B.alphaStar, B.alphaHi, B.cpv}), ...
                        sprintf('header 9d: group %d shape %d shared = alone', g, s));
                end
            end
        end

        function boxStatus(tc)
            res = tc.run1(@(s, k) tUqLattice.lin(s), 'Boxes', struct('name', 'x1', 'alpha', 1));
            cj = res.groups(1).csr(1);
            mj = tUqLattice.MJ;
            st = res.box(1, 1 - cj.alphaStar * mj, 1 + cj.alphaStar * mj);
            tc.verifyEqual(st.status, 'OK', st.reason);
            tc.verifyGreaterThanOrEqual(st.lowerBound, 0, 'header 10');
            st = res.box(1, 1 - cj.alphaHi * mj, 1 + cj.alphaHi * mj);
            tc.verifyEqual(st.status, 'VIOLATED', st.reason);
            tc.verifyLessThan(st.value, 0, 'header 10');
            bw = res.groups(1).boxes(1);
            tc.verifyEqual(bw.status, 'OK', bw.reason);
            tc.verifyEqual(bw.label, 'grid-certified (Lipschitz estimate)');
            tc.verifyEqual(bw.method, 'lattice');
            tc.verifyGreaterThanOrEqual(bw.value, 0.3 - 1e-12, 'header 10: lattice minimum over R(1) >= true minimum');
        end

        function badLatticeInput(tc)
            P = tUqLattice.problem(tUqLattice.MJ, {@(s, k) 1}, 1, {1});
            tc.verifyError(@() vital.uq.lattice(P, 'GridPoints', 10), 'vital:badInput');
            Q = P; Q.shapes(2).m = [0.2 0.1 0.1];
            tc.verifyError(@() vital.uq.lattice(Q), 'vital:badInput');
            Q = P; Q.m = [0.4 0.2 0.15];
            tc.verifyError(@() vital.uq.lattice(Q), 'vital:uq:negativeMultiplier');
            Q = P; Q.groups(1).conds = 3;
            tc.verifyError(@() vital.uq.lattice(Q), 'vital:badInput');
        end
    end

    methods (Static)
        function v = pick(x, k), v = x(k); end
    end
end
