classdef (TestTags = {'M8'}) tUqCsr < vital.test.VitalTestCase
%TUQCSR  M8 amendment R4-1/R4-2 (docs/PLAN_M5_M8.md, "Amendment R4: judgment-light
%   robustness", coordinator 2026-10-13): the Critical Similitude Ratio (CSR)
%   vital.uq.csr and the R4 verdict vital.uq.verdict(csr, mc), on closed-form
%   margins (no aircraft). Expected runtime: under 1 min.
%
%   Definitions (Crespo, Kenny, Giesy, NASA LaRC, "A Verification-driven
%   Approach to Control Analysis and Tuning": homothetic deformation of a
%   hyper-rectangular reference set R(pbar, m) by the similitude ratio alpha;
%   CPV, CSR, maximal set, parametric safety margin). Reference box
%   R(alpha) = [1 - alpha m, 1 + alpha m] about the nominal 1; scaled
%   coordinates s_i = (p_i - 1)/m_i, so R(alpha) is |s_i| <= alpha. alpha* is
%   the largest alpha in [0, AlphaMax = 3] whose box keeps margin >= 0
%   (failure = margin < 0). Resolution 0.01. The result brackets alpha*:
%   alphaLo (= alphaStar: the largest box searched clean) <= alpha* <= alphaHi
%   (= the scaled infinity norm of the CPV, a confirmed failing point), with
%   alphaHi - alphaLo <= 0.01.
%   Box searches (stated here): 'grid' (R4-3) for d <= 2 and 'hybrid' (R4-4)
%   with MaxEvals 200 for d = 3, via the CSR option 'Search'; every toy has a
%   confirmation function = the minimum over ALL its conditions (the fresh
%   assessment of the toys).
%
%   PRE-REGISTERED (agent uq3, 2026-10-13, written with the stubs, before any
%   implementation; every expected value is ANALYTIC from the closed forms):
%   1. LINEAR, ONE PARAMETER (K1): m = 0.15 - (p - 1), m_ref = 0.1, i.e.
%      m = 0.15 - 0.1 s; failure for s > 1.5 only, so alpha* = 1.5 exactly.
%      status 'OK'; alphaStar in [1.49, 1.5]; alphaHi in [1.5, 1.51];
%      alphaHi - alphaStar <= 0.01 (+1e-12); CPV p within 0.001 (0.01 m) of
%      1.15 and its margin < 0; cpvConfirmed true, confirmation margin < 0;
%      psm = alphaStar * 0.1 (exact); every searched box is [1 - a m, 1 + a m]
%      for its alpha a (1e-15) and inside the cap box.
%   2. TWO PARAMETERS, THE BOX CORNER TOUCHES FIRST (K2): m = 0.35 - 0.1 s1 -
%      0.1 s2, m_ref = [0.1 0.05]. min over R(alpha) = 0.35 - 0.2 alpha at the
%      corner s = (alpha, alpha): alpha* = 1.75, CPV p = (1.175, 1.0875).
%      A one-parameter-at-a-time box (each s_j up to the cap 3, the other 0)
%      keeps margin >= 0.05 > 0 (checked in the test): it would report
%      ROBUST_TO_CAP. Expected: status 'OK', alphaStar in [1.74, 1.75],
%      alphaHi in [1.75, 1.76], bracket <= 0.01, CPV within 0.01 m_i of the
%      corner on every axis. The same with the hybrid search (R4-4).
%   3. NEVER FAILS (K3): m = 0.5 + 0.1 s1^2 - 0.05 s2 (min over the cap box
%      0.35 > 0): status 'ROBUST_TO_CAP', alphaStar = alphaLo = 3 (exact),
%      alphaHi = Inf, cpv NaN, cpvConfirmed false, exactly one search (the
%      cap box). R4 verdict with cpLower 0.99: 'ROBUST'.
%   4. NOMINAL FAILS (K4): m = -0.05 + 0.1 s (1-D): status 'OK', alphaStar =
%      alphaHi = 0 (exact), CPV = the nominal (exact), cpvConfirmed true
%      (confirmation margin -0.05, 1e-15), no box search run (nSearches 0).
%      R4 verdict with cpLower 0.99: 'NOT_ROBUST'.
%   5. NON-MONOTONE AND KINKED (K5): m = |s - 1.2| - 0.1 (1-D): failure only in
%      the band 1.1 < s < 1.3 (a V-shaped kink at 1.2; the cap endpoints
%      s = -3 and +3 have margins 4.1 and 1.7, both > 0: checked in the test).
%      alpha* = 1.1: status 'OK', alphaStar in [1.09, 1.1], alphaHi in
%      [1.1, 1.11], CPV s in [1.1, 1.11].
%   6. THREE PARAMETERS, HYBRID SEARCH (K6): m = 0.6 - 0.1 (s1 + s2 + s3),
%      m_ref = [0.1 0.2 0.05]: alpha* = 2.0 (corner). status 'OK', alphaStar
%      in [1.99, 2.0], alphaHi in [2.0, 2.01].
%   7. EQUAL-PERCENTAGE SHAPE (K7, R4-1(b)): K2's margin in p is
%      m = 0.35 - (p1 - 1) - 2 (p2 - 1); with m_ref = [0.1 0.1] the minimum
%      over R(beta) is 0.35 - 0.3 beta, so beta* = 7/6 (a uniform tolerance of
%      11.67 %). status 'OK', alphaStar in [7/6 - 0.01, 7/6], alphaHi in
%      [7/6, 7/6 + 0.01]. With 'Prior' = the searches of the judged-shape CSR
%      of item 2 (clean boxes contain smaller equal boxes, failing points give
%      an upper bound in any shape): the same bracket conditions, and
%      nSearches(with prior) <= nSearches(without).
%   8. MOVING LIMIT (K8, R3-M4 inside the CSR): 1-D, conditions c1 (the only
%      candidate) m1 = 0.35 - 0.1 s and c2 m2 = 0.2 - 0.1 s. Over c1 alone the
%      cap box is clean (min 0.05); the confirmation (min over c1, c2) at the
%      arg-min finds c2 -> re-search -> failure at c2. alpha* = 2.0: status
%      'OK', alphaStar in [1.99, 2.0], alphaHi in [2.0, 2.01], 'c2' among
%      csr.condLabels, cpvCond 'c2'.
%   9. NOT ASSESSABLE (K9): 1-D, margin 1 everywhere but status 'INFEASIBLE'
%      for s > 2 (no failure anywhere): the cap search cannot decide.
%      'DecideAt' 1: the box R(1) is searched and clean. status
%      'NOT_ASSESSABLE', reason mentions 'INFEASIBLE', alphaStar NaN, alphaLo
%      = 1 (exact), alphaHi = Inf, cpvConfirmed false. R4 verdict with
%      cpLower 0.99: 'NOT_ASSESSABLE'.
%      SUPERSEDED BY R5 (amendment R5-2, agent uq5, 2026-10-14; text above kept):
%      the verdict comes from the judged box R(1), which was searched clean
%      (csr.lowerCertified true, alphaLo 1), so the verdict is 'ROBUST'
%      (pre-registered in tests/M8/tUqR5.m header 20).
%   10. R4 VERDICT TRUTH TABLE (R4-2; Required 0.95), csr (status, alphaStar,
%      alphaHi, cpvConfirmed) with mc.cpLower:
%        OK 1.20 1.21 true, 0.96              -> ROBUST
%        OK 1.00 1.01 true, 0.95              -> ROBUST (both bounds inclusive)
%        ROBUST_TO_CAP 3 Inf false, 0.99      -> ROBUST
%        OK 0.80 0.81 true, 0.99              -> NOT_ROBUST
%        OK 0.99 1.00 true, 0.99              -> NOT_ROBUST (CPV inside R(1))
%        ROBUST_TO_CAP 3 Inf false, 0.94      -> NOT_ROBUST (Clopper-Pearson)
%        OK 1.20 1.21 true, 0.90              -> NOT_ROBUST
%        NOT_ASSESSABLE NaN Inf false, 0.99   -> NOT_ASSESSABLE
%        NOT_ASSESSABLE NaN 0.70 true, 0.99   -> NOT_ROBUST (a confirmed CPV
%                                                inside the judged box:
%                                                alpha* <= 0.70 < 1)
%        NOT_ASSESSABLE NaN 0.70 false, 0.99  -> NOT_ASSESSABLE
%      Every verdict has a non-empty reason. A csr struct lacking alphaStar
%      and value -> vital:badInput. (The bound-worst form verdict(bw, mc) of
%      the original M8 contract is unchanged: tests/M8/tMonteCarloVerdict.m.)
%   11. FAILURE MODES: AlphaMax <= 0, Resolution <= 0, an m_ref entry <= 0, m
%      of the wrong size -> vital:badInput; a cap box with a negative lower
%      bound (AlphaMax m > 1) -> vital:uq:negativeMultiplier.
%   12. CAP RESPECTED WITH A FAR PRIOR (added 2026-10-13 after the reduced
%      smoke run of run_f16_uq showed equal-shape box searches at alpha 8.37
%      and 5.83 > AlphaMax 3, started from a judged-shape failing point whose
%      equal-shape norm exceeded the cap; ANALYTIC): m = 0.5 - 0.1 s (1-D,
%      m_ref 0.1; failure only for s > 5, beyond the cap 3), 'Prior' = one
%      failing point at s = 6 (theta 1.6, margin -0.1). Expected:
%      'ROBUST_TO_CAP', alphaStar 3, every searched alpha <= 3 (exact), at
%      least one search (the cap box).

    methods (Static)
        function P = problem(mref, fcn, labels, confirm)
            if nargin < 3, labels = {'c1'}; end
            d = numel(mref);
            P.names = arrayfun(@(i) sprintf('p%d', i), 1:d, 'UniformOutput', false);
            P.nominal = ones(1, d);
            P.m = mref;
            P.conditions = num2cell(1:numel(labels));
            P.condLabels = labels;
            P.pointFcn = @(th, k) tUqCsr.wrap(fcn(th, k));
            if nargin < 4
                n = numel(labels);
                P.confirmFcn = @(th) tUqCsr.confirmAll(th, fcn, n);
            else
                P.confirmFcn = confirm;
            end
        end

        function q = wrap(m)
            if isstruct(m), q = m; return; end
            q = struct('status', 'OK', 'margin', m, 'record', 'R1', 'reason', '');
        end

        function c = confirmAll(th, fcn, n)
            m = NaN(1, n);
            for k = 1:n
                q = tUqCsr.wrap(fcn(th, k));
                if ~strcmp(q.status, 'OK')
                    c = struct('status', 'NOT_OK', 'margin', NaN, 'condLabel', sprintf('c%d', k), 'cond', k, ...
                        'record', '', 'reason', q.reason);
                    return
                end
                m(k) = q.margin;
            end
            [mm, k] = min(m);
            c = struct('status', 'OK', 'margin', mm, 'condLabel', sprintf('c%d', k), 'cond', k, 'record', 'R1', 'reason', '');
        end

        function s = sc(th, mref)
            s = (th - 1) ./ mref;
        end

        function q = k9(th)
            s = (th - 1) / 0.1;
            if s > 2
                q = struct('status', 'INFEASIBLE', 'margin', NaN, 'record', '', 'reason', 'trim: INFEASIBLE (toy)');
            else
                q = struct('status', 'OK', 'margin', 1, 'record', 'R1', 'reason', '');
            end
        end

        function f = grid()
            f = @(P) vital.uq.boundWorst(P, 'Method', 'grid');
        end

        function f = hybrid()
            f = @(P) vital.uq.boundWorst(P, 'Method', 'hybrid', 'MaxEvals', 200);
        end
    end

    methods (Access = private)
        function checkBracket(tc, c, a, what)
            tc.verifyEqual(c.status, 'OK', [what ': ' c.reason]);
            tc.verifyWithin(c.alphaStar, a - 0.01, a, 'ANALYTIC', [what ': alpha* - 0.01 <= alphaStar <= alpha*'], ...
                'Quantity', [what ' alphaStar']);
            tc.verifyWithin(c.alphaHi, a, a + 0.01, 'ANALYTIC', [what ': alpha* <= alphaHi <= alpha* + 0.01'], ...
                'Quantity', [what ' alphaHi']);
            tc.verifyLessThanOrEqual(c.alphaHi - c.alphaStar, 0.01 + 1e-12, [what ': bracket <= resolution']);
            tc.verifyEqual(c.alphaLo, c.alphaStar, [what ': alphaStar is the largest clean box']);
            tc.verifyTrue(c.cpvConfirmed, [what ': confirmed CPV']);
            tc.verifyLessThan(c.cpvMargin, 0, [what ': the CPV fails']);
        end
    end

    methods (Test)
        function linearOneParameter(tc)
            P = tUqCsr.problem(0.1, @(th, k) 0.15 - (th - 1));
            c = vital.uq.csr(P, 'Search', tUqCsr.grid());
            tc.checkBracket(c, 1.5, 'K1');
            tc.verifyTol(c.cpv, 1.15, 0.001, 'abs', 'ANALYTIC', 'header 1: CPV p = 1.15', 'Quantity', 'K1 CPV');
            tc.verifyTrue(c.confirmation.evaluated);
            tc.verifyLessThan(c.confirmation.margin, 0);
            tc.verifyEqual(c.psm, c.alphaStar * 0.1, 'header 1: psm = alpha* m');
            tc.verifyEqual(c.m, 0.1);
            for k = 1:numel(c.searches)
                s = c.searches(k);
                tc.verifyTol([s.lo s.hi], [1 - s.alpha * 0.1, 1 + s.alpha * 0.1], 1e-15, 'abs', 'ANALYTIC', ...
                    'header 1: searched box = R(alpha)', 'Quantity', sprintf('K1 box %d', k));
                tc.verifyLessThanOrEqual(s.alpha, 3 + 1e-12, 'inside the cap');
            end
        end

        function cornerTouchesFirst(tc)
            mref = [0.1 0.05];
            f = @(th, k) 0.35 - 0.1 * sum(tUqCsr.sc(th, mref));
            oat = min([0.35 - 0.1 * 3, 0.35 - 0.1 * 3]);
            tc.verifyGreaterThan(oat, 0, 'header 2: one-at-a-time to the cap never fails');
            P = tUqCsr.problem(mref, f);
            for srch = {tUqCsr.grid(), tUqCsr.hybrid()}
                c = vital.uq.csr(P, 'Search', srch{1});
                tc.checkBracket(c, 1.75, 'K2');
                for ia = 1:2                    % per-axis tolerance 0.01 m_i (header 2; test-code fix, see NOTES)
                    tc.verifyTol(c.cpv(ia), 1 + 1.75 * mref(ia), 0.01 * mref(ia), 'abs', 'ANALYTIC', ...
                        'header 2: CPV at the corner', 'Quantity', sprintf('K2 CPV p%d', ia));
                end
            end
        end

        function neverFailsRobustToCap(tc)
            mref = [0.1 0.1];
            P = tUqCsr.problem(mref, @(th, k) 0.5 + 0.1 * tUqCsr.sc(th(1), 0.1)^2 - 0.05 * tUqCsr.sc(th(2), 0.1));
            c = vital.uq.csr(P, 'Search', tUqCsr.grid());
            tc.verifyEqual(c.status, 'ROBUST_TO_CAP', c.reason);
            tc.verifyEqual(c.alphaStar, 3);
            tc.verifyEqual(c.alphaLo, 3);
            tc.verifyEqual(c.alphaHi, Inf);
            tc.verifyTrue(all(isnan(c.cpv)));
            tc.verifyFalse(c.cpvConfirmed);
            tc.verifyEqual(c.nSearches, 1, 'header 3: one search (the cap box)');
            v = vital.uq.verdict(c, struct('cpLower', 0.99));
            tc.verifyEqual(v.verdict, 'ROBUST');
        end

        function nominalFails(tc)
            P = tUqCsr.problem(0.1, @(th, k) -0.05 + 0.1 * tUqCsr.sc(th, 0.1));
            c = vital.uq.csr(P, 'Search', tUqCsr.grid());
            tc.verifyEqual(c.status, 'OK', c.reason);
            tc.verifyEqual(c.alphaStar, 0);
            tc.verifyEqual(c.alphaHi, 0);
            tc.verifyEqual(c.cpv, 1, 'header 4: CPV = nominal');
            tc.verifyTrue(c.cpvConfirmed);
            tc.verifyTol(c.confirmation.margin, -0.05, 1e-15, 'abs', 'ANALYTIC', 'header 4', 'Quantity', 'K4 confirmation');
            tc.verifyEqual(c.nSearches, 0);
            v = vital.uq.verdict(c, struct('cpLower', 0.99));
            tc.verifyEqual(v.verdict, 'NOT_ROBUST');
        end

        function nonMonotoneKinkedBand(tc)
            f = @(th, k) abs(tUqCsr.sc(th, 0.1) - 1.2) - 0.1;
            tc.verifyGreaterThan(min(f(1 - 0.3, 1), f(1 + 0.3, 1)), 0, 'header 5: both cap endpoints are clean');
            P = tUqCsr.problem(0.1, f);
            c = vital.uq.csr(P, 'Search', tUqCsr.grid());
            tc.checkBracket(c, 1.1, 'K5');
            tc.verifyWithin(tUqCsr.sc(c.cpv, 0.1), 1.1, 1.11, 'ANALYTIC', 'header 5: CPV at the band edge', 'Quantity', 'K5 CPV s');
        end

        function threeParametersHybrid(tc)
            mref = [0.1 0.2 0.05];
            P = tUqCsr.problem(mref, @(th, k) 0.6 - 0.1 * sum(tUqCsr.sc(th, mref)));
            c = vital.uq.csr(P, 'Search', tUqCsr.hybrid());
            tc.checkBracket(c, 2.0, 'K6');
        end

        function equalPercentageShape(tc)
            f = @(th, k) 0.35 - (th(1) - 1) - 2 * (th(2) - 1);
            Pj = tUqCsr.problem([0.1 0.05], f);
            cj = vital.uq.csr(Pj, 'Search', tUqCsr.grid());
            Pe = tUqCsr.problem([0.1 0.1], f);
            ce = vital.uq.csr(Pe, 'Search', tUqCsr.grid());
            tc.checkBracket(ce, 7 / 6, 'K7');
            cp = vital.uq.csr(Pe, 'Search', tUqCsr.grid(), 'Prior', cj.searches);
            tc.checkBracket(cp, 7 / 6, 'K7 with prior');
            tc.verifyLessThanOrEqual(cp.nSearches, ce.nSearches, 'header 7: the prior saves searches');
        end

        function movingLimitInsideCsr(tc)
            f = @(th, k) (k == 1) * (0.35 - 0.1 * tUqCsr.sc(th, 0.1)) + (k == 2) * (0.2 - 0.1 * tUqCsr.sc(th, 0.1));
            P = tUqCsr.problem(0.1, f, {'c1', 'c2'});
            P.conditions = {1}; P.condLabels = {'c1'};
            c = vital.uq.csr(P, 'Search', tUqCsr.grid());
            tc.checkBracket(c, 2.0, 'K8');
            tc.verifyTrue(any(strcmp(c.condLabels, 'c2')), 'header 8: the moved condition is a candidate');
            tc.verifyEqual(c.cpvCond, 'c2');
        end

        function undecidableIsNotAssessable(tc)
            P = tUqCsr.problem(0.1, @(th, k) tUqCsr.k9(th));
            c = vital.uq.csr(P, 'Search', tUqCsr.grid(), 'DecideAt', 1);
            tc.verifyEqual(c.status, 'NOT_ASSESSABLE', c.reason);
            tc.verifySubstring(c.reason, 'INFEASIBLE');
            tc.verifyTrue(isnan(c.alphaStar));
            tc.verifyEqual(c.alphaLo, 1);
            tc.verifyEqual(c.alphaHi, Inf);
            tc.verifyFalse(c.cpvConfirmed);
            v = vital.uq.verdict(c, struct('cpLower', 0.99));
            % header 9 "R4 verdict NOT_ASSESSABLE": SUPERSEDED BY R5-2 (R(1) searched clean): ROBUST
            tc.verifyEqual(v.verdict, 'ROBUST', ['header 9 (R5-2): ' v.reason]);
        end

        function verdictTruthTableR4(tc)
            c = @(s, a, h, k) struct('status', s, 'alphaStar', a, 'alphaHi', h, 'cpvConfirmed', k);
            m = @(p) struct('cpLower', p);
            V = @(x, y) vital.uq.verdict(x, y);
            rows = {c('OK', 1.20, 1.21, true), 0.96, 'ROBUST'; ...
                    c('OK', 1.00, 1.01, true), 0.95, 'ROBUST'; ...
                    c('ROBUST_TO_CAP', 3, Inf, false), 0.99, 'ROBUST'; ...
                    c('OK', 0.80, 0.81, true), 0.99, 'NOT_ROBUST'; ...
                    c('OK', 0.99, 1.00, true), 0.99, 'NOT_ROBUST'; ...
                    c('ROBUST_TO_CAP', 3, Inf, false), 0.94, 'NOT_ROBUST'; ...
                    c('OK', 1.20, 1.21, true), 0.90, 'NOT_ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, Inf, false), 0.99, 'NOT_ASSESSABLE'; ...
                    c('NOT_ASSESSABLE', NaN, 0.70, true), 0.99, 'NOT_ROBUST'; ...
                    c('NOT_ASSESSABLE', NaN, 0.70, false), 0.99, 'NOT_ASSESSABLE'};
            for i = 1:size(rows, 1)
                v = V(rows{i, 1}, m(rows{i, 2}));
                tc.verifyEqual(v.verdict, rows{i, 3}, sprintf('header 10 row %d', i));
                tc.verifyNotEmpty(v.reason, sprintf('header 10 row %d reason', i));
            end
            tc.verifyError(@() vital.uq.verdict(struct('status', 'OK'), m(0.99)), 'vital:badInput');
        end

        function capRespectedWithFarPrior(tc)
            P = tUqCsr.problem(0.1, @(th, k) 0.5 - 0.1 * tUqCsr.sc(th, 0.1));
            pr = struct('lo', NaN, 'hi', NaN, 'status', 'VIOLATED', 'theta', 1.6, 'value', -0.1);
            c = vital.uq.csr(P, 'Search', tUqCsr.grid(), 'Prior', pr);
            tc.verifyEqual(c.status, 'ROBUST_TO_CAP', ['header 12: ' c.reason]);
            tc.verifyEqual(c.alphaStar, 3);
            tc.verifyGreaterThanOrEqual(c.nSearches, 1);
            tc.verifyTrue(all([c.searches.alpha] <= 3), sprintf('header 12: searched alphas %s', mat2str([c.searches.alpha], 4)));
        end

        function badInputs(tc)
            P = tUqCsr.problem(0.1, @(th, k) 0.15 - (th - 1));
            tc.verifyError(@() vital.uq.csr(P, 'AlphaMax', 0), 'vital:badInput');
            tc.verifyError(@() vital.uq.csr(P, 'Resolution', 0), 'vital:badInput');
            Q = P; Q.m = 0;
            tc.verifyError(@() vital.uq.csr(Q), 'vital:badInput');
            Q = P; Q.m = [0.1 0.1];
            tc.verifyError(@() vital.uq.csr(Q), 'vital:badInput');
            Q = P; Q.m = 0.5;
            tc.verifyError(@() vital.uq.csr(Q), 'vital:uq:negativeMultiplier');
        end
    end
end
