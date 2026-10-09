classdef (TestTags = {'M8'}) tUqR3 < vital.test.VitalTestCase
%TUQR3  M8 coverage tests added after independent review R3 (finding M6,
%   reports/review/R3_REVIEW.md section 6): six realistic defects of the M8
%   uncertainty chain that the M8 tests of 2026-10-08 do not catch. No
%   implementation change: these tests pin behaviour the M8 contract
%   (docs/PLAN_M5_M8.md M8, ADR-032 uq-1..3) already promises.
%   Small problems only: closed-form toys, single-point F-16 evaluations at the
%   README point, one bare-airframe vital.fq.assess over the 36 in-envelope
%   conditions (about 6 s) and one vital.uq.analyze with a 1-parameter spec at
%   the README point (about 15 s). Expected runtime of the file: under 1 min.
%   Expected values are pinned here (never read from reports/).
%
%   PRE-REGISTERED (written before the first run of this file):
%   1. MONTE CARLO WIDTH (sabotage S8R-1; ANALYTIC from the vital.uq.analyze and
%      vital.uq.monteCarlo contracts). analyze with the spec reduced to its
%      Cnr_table parameter (sigma 0.1, JUDGMENT, uq/f16_uncertainty.json),
%      group 3.3.1.1-CatA-other, README conditions, WidthScales [0.5 1.5],
%      NumLHS 0, NumStarts 1, MaxEvals 4, NumCandidates 1, N 4, Seed 2026:
%      at each width w the Monte Carlo sigma is w * 0.1 (1e-15 rel) and the
%      samples are theta = 1 + w * 0.1 * randn(RandStream('mt19937ar', 'Seed',
%      2026), 4, 1), regenerated here (1e-14 abs); the x1.5 deviations are
%      exactly 3 times the x0.5 deviations (1e-12 rel; same seed).
%   2. EVALUATION CACHE KEY (S8R-2; ANALYTIC: distinct theta are distinct
%      points). F16Evaluator({'Cnr_table'}) at the README point:
%      pointSummary(1) then pointSummary(1 + 1e-5) -> nPointEvals 2,
%      nCacheHits 0 (1e-5 is far above eps and far below a 4-digit key); the
%      second summary equals (isequaln) that of a FRESH evaluator at 1 + 1e-5;
%      repeating pointSummary(1) is a cache hit (nCacheHits 1) returning the
%      identical summary. The two 3.3.1.1-CatA-other Level-1 margins differ.
%   3. +Inf BOUND-WORST IS NOT A PASS (S8R-5; contract of vital.uq.verdict:
%      ROBUST needs bw.status 'OK'). Truth-table rows (cpLower 0.99 unless
%      stated): NOT_ASSESSABLE/+Inf -> NOT_ASSESSABLE; NOT_ASSESSABLE/NaN ->
%      NOT_ASSESSABLE; OK/NaN -> NOT_ASSESSABLE; NOT_ASSESSABLE/+Inf with
%      cpLower 0.90 -> NOT_ROBUST; OK/+Inf -> ROBUST (the contract: status OK and
%      value >= Reserve). Chain: a toy (d = 2, h = 0.2) whose margin is +Inf at
%      every point (no record applies, e.g. a stable spiral everywhere):
%      boundWorst status 'NOT_ASSESSABLE', value +Inf, converged false, reason
%      starting 'FC-901' (fmincon cannot start from a non-finite objective);
%      its verdict with cpLower 0.99 is NOT_ASSESSABLE.
%   4. NON-OK POINT WITH A PARTIAL MARGIN (S8R-6, FC-903 with two candidate
%      conditions; ANALYTIC). u = (theta - 1)/0.2, d = 2, conditions c1, c2:
%        c1: m = 0.5 + 0.05 u1 + 0.1 u2, always OK
%        c2: INFEASIBLE where u1 > 0.9, else m = 0.9 + 0.1 u2
%      A point with u1 > 0.9 is not OK but keeps the finite c1 margin. With
%      NumStarts 1 (the single start is the OK vertex u = (-1, -1)):
%      bw.nonOK is exactly the set of evaluated points with u1 > 0.9 (at least
%      the 2 corners with u1 = +1 and one LHS point of the top stratum), each
%      with a finite margin; status 'NOT_ASSESSABLE' with 'INFEASIBLE' and 'c2'
%      in the reason; value 0.35 at u = (-1, -1) (1e-12 abs; the corner is
%      evaluated exactly); converged true (a linear objective, minimum at the
%      start vertex).
%   5. EXCLUDED IN-ENVELOPE POINTS (S8R-7; F16Evaluator.levelMargin contract:
%      "NaN if a record has unrated in-envelope points"). Bare assessment over
%      vital.ctrl.inEnvelopeConditions, group 3.2.2.1.1-CatA, Level 1: the
%      margin equals the minimum over the group's applicable Level-1 records of
%      inEnvelope.minMargin, recomputed here (exact), with no record excluded
%      (guard). A copy of the result in which the arg-min record (and,
%      separately, another applicable record) reports nExcluded = 1 with its
%      minMargin and critical point unchanged (an in-envelope point that failed
%      to trim) -> margin NaN and cr.record = that record.
%   6. CANDIDATES ARE IN-ENVELOPE ONLY (S8R-8; plan M8: "only in-envelope points
%      count"). Same bare result, group 3.3.1.1-CatA-other, Level 1:
%      inEnvelopeMargins returns exactly the 30 IN points (REG: 30 IN, 6
%      EXTRAPOLATED, tCtrlSuggest header 1), sorted indices equal to
%      find(envelope == 'IN'); making every Level-1 record at one
%      EXTRAPOLATED point OK with margin -10 (the worst point of the grid)
%      leaves the table unchanged (isequaln).

    properties
        R
        Cr
        cReadme
        C36
        bare36
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.R = vital.fq.loadRules();
            tc.Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), ...
                'Grid', 'readme');
            tc.cReadme = vital.fq.gridPoints(tc.Cr);
            tc.C36 = vital.ctrl.inEnvelopeConditions();
            tc.bare36 = vital.fq.assess(tc.R, vital.fq.f16Factory(), tc.C36);
        end
    end

    methods (Static)
        function q = pt(m)
            q = struct('status', 'OK', 'margin', m, 'record', 'R1', 'reason', '');
        end

        function q = twoCond(th, k)
            u = (th - 1) / 0.2;
            if k == 1
                q = tUqR3.pt(0.5 + 0.05 * u(1) + 0.1 * u(2));
            elseif u(1) > 0.9
                q = struct('status', 'INFEASIBLE', 'margin', NaN, 'record', '', 'reason', 'trim: INFEASIBLE (toy)');
            else
                q = tUqR3.pt(0.9 + 0.1 * u(2));
            end
        end

        function P = toy(fcn, labels)
            P.names = {'p1', 'p2'};
            P.nominal = [1 1];
            P.lo = [0.8 0.8]; P.hi = [1.2 1.2];
            P.conditions = num2cell(1:numel(labels));
            P.condLabels = labels;
            P.pointFcn = fcn;
            P.confirmFcn = [];
        end
    end

    methods (Test)
        function monteCarloSigmaScalesWithWidth(tc)
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(strcmp({spec.parameters.aeroScale}, 'Cnr_table'));
            tc.assertNumElements(spec.parameters, 1);
            tc.verifyTol(spec.parameters.sigma, 0.1, 0, 'abs', 'REG', 'uq/f16_uncertainty.json Cnr_table sigma (JUDGMENT)', ...
                'Quantity', 'sigma Cnr_table');
            N = 4; seed = 2026;
            r = vital.uq.analyze('Groups', {'3.3.1.1-CatA-other'}, 'WidthScales', [0.5 1.5], 'Spec', spec, ...
                'Rules', tc.R, 'Conditions', tc.Cr, 'NumLHS', 0, 'NumStarts', 1, 'MaxEvals', 4, ...
                'NumCandidates', 1, 'N', N, 'Seed', seed);
            W = r.groups(1).widths;
            tc.assertNumElements(W, 2);
            z = randn(RandStream('mt19937ar', 'Seed', seed), N, 1);
            for k = 1:2
                w = W(k).widthScale;
                tc.verifyTol(W(k).mc.sigma, w * 0.1, 1e-15, 'rel', 'ANALYTIC', 'header 1: MC sigma = w sigma', ...
                    'Quantity', sprintf('MC sigma x%g', w));
                tc.verifyTol(W(k).mc.theta, 1 + w * 0.1 * z, 1e-14, 'abs', 'ANALYTIC', ...
                    'header 1: samples regenerated from the seeded stream', 'Quantity', sprintf('MC theta x%g', w));
            end
            tc.verifyTol((W(2).mc.theta - 1) ./ (W(1).mc.theta - 1), 3 * ones(N, 1), 1e-12, 'rel', 'ANALYTIC', ...
                'header 1: x1.5 / x0.5 deviations', 'Quantity', 'deviation ratio');
        end

        function cacheKeyDistinguishesNearbyTheta(tc)
            c = tc.cReadme;
            E = vital.uq.F16Evaluator({'Cnr_table'}, 'Rules', tc.R, 'Conditions', tc.Cr);
            S1 = E.pointSummary(1, c);
            S2 = E.pointSummary(1 + 1e-5, c);
            tc.verifyEqual(E.nPointEvals, 2, 'header 2: two distinct theta are two evaluations');
            tc.verifyEqual(E.nCacheHits, 0, 'header 2: no cache hit for a different theta');
            F = vital.uq.F16Evaluator({'Cnr_table'}, 'Rules', tc.R, 'Conditions', tc.Cr);
            tc.verifyTrue(isequaln(S2, F.pointSummary(1 + 1e-5, c)), 'header 2: the summary is that of theta itself');
            S1b = E.pointSummary(1, c);
            tc.verifyEqual(E.nCacheHits, 1, 'header 2: the same theta is a cache hit');
            tc.verifyTrue(isequaln(S1b, S1));
            g = '3.3.1.1-CatA-other';
            m1 = S1.groups(strcmp({S1.groups.group}, g)).marginTo(1);
            m2 = S2.groups(strcmp({S2.groups.group}, g)).marginTo(1);
            tc.verifyNotEqual(m2, m1, 'header 2: the margins of distinct theta differ');
        end

        function infBoundWorstIsNotRobust(tc)
            b = @(s, v) struct('status', s, 'value', v);
            m = @(p) struct('cpLower', p);
            V = @(varargin) vital.uq.verdict(varargin{:});
            tc.verifyEqual(V(b('NOT_ASSESSABLE', Inf), m(0.99)).verdict, 'NOT_ASSESSABLE', 'header 3: NA/+Inf');
            tc.verifyEqual(V(b('NOT_ASSESSABLE', NaN), m(0.99)).verdict, 'NOT_ASSESSABLE', 'header 3: NA/NaN');
            tc.verifyEqual(V(b('OK', NaN), m(0.99)).verdict, 'NOT_ASSESSABLE', 'header 3: OK/NaN');
            tc.verifyEqual(V(b('NOT_ASSESSABLE', Inf), m(0.90)).verdict, 'NOT_ROBUST', 'header 3: NA/+Inf, low P');
            tc.verifyEqual(V(b('OK', Inf), m(0.99)).verdict, 'ROBUST', 'header 3: OK/+Inf (contract)');
            P = tUqR3.toy(@(th, c) tUqR3.pt(Inf), {'c1'});
            bw = vital.uq.boundWorst(P);
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifyEqual(bw.value, Inf);
            tc.verifyFalse(bw.converged);
            tc.verifyTrue(startsWith(bw.reason, 'FC-901'), bw.reason);
            tc.verifyEqual(V(bw, m(0.99)).verdict, 'NOT_ASSESSABLE', 'header 3: an unsearched +Inf box is not ROBUST');
        end

        function partialMarginNonOKPointCounted(tc)
            P = tUqR3.toy(@(th, k) tUqR3.twoCond(th, k), {'c1', 'c2'});
            bw = vital.uq.boundWorst(P, 'NumStarts', 1);
            u1 = (bw.points.theta(:, 1) - 1) / 0.2;
            expected = find(u1 > 0.9).';
            tc.verifyGreaterThanOrEqual(numel(expected), 3, 'header 4: 2 corners + >= 1 LHS point in the hole');
            tc.verifyEqual(bw.nonOK, expected, 'header 4: nonOK = every evaluated point with u1 > 0.9');
            tc.verifyTrue(all(isfinite(bw.points.margin(expected))), 'header 4: the non-OK points keep a finite c1 margin');
            tc.verifyEqual(bw.status, 'NOT_ASSESSABLE', bw.reason);
            tc.verifySubstring(bw.reason, 'INFEASIBLE');
            tc.verifySubstring(bw.reason, 'c2');
            tc.verifyTol(bw.value, 0.35, 1e-12, 'abs', 'ANALYTIC', 'header 4: c1 at u = (-1, -1)', 'Quantity', 'bound-worst');
            tc.verifyTrue(bw.converged, 'header 4: the single start converges');
        end

        function excludedInEnvelopePointGivesNaN(tc)
            res = tc.bare36;
            g = '3.2.2.1.1-CatA'; L = 1;
            ir = find(strcmp({res.rules.group}, g) & [res.rules.level] == L);
            ie = [res.rules(ir).inEnvelope];
            app = ~strcmp({ie.status}, 'NOT_APPLICABLE');
            tc.assertGreaterThanOrEqual(sum(app), 2, 'two applicable Level-1 records');
            tc.verifyEqual([ie(app).nExcluded], zeros(1, sum(app)), 'guard: no excluded point in the real result');
            [mExp, j] = min([ie(app).minMargin]);
            [m, cr] = vital.uq.F16Evaluator.levelMargin(res, g, L);
            tc.verifyExact(m, mExp, 'ANALYTIC', 'header 5: min over records of the in-envelope minimum', 'Quantity', 'levelMargin');
            ia = ir(app);
            for jj = [j, find(1:numel(ia) ~= j, 1)]
                res2 = res;
                res2.rules(ia(jj)).inEnvelope.nExcluded = 1;
                [m2, cr2] = vital.uq.F16Evaluator.levelMargin(res2, g, L);
                tc.verifyTrue(isnan(m2), sprintf('header 5: excluded point in %s -> NaN (got %g)', res.rules(ia(jj)).id, m2));
                tc.verifyEqual(cr2.record, res.rules(ia(jj)).id);
            end
            tc.verifyNotEmpty(cr.record);
        end

        function candidatesAreInEnvelopeOnly(tc)
            res = tc.bare36;
            g = '3.3.1.1-CatA-other'; L = 1;
            inIdx = find(strcmp({res.points.envelope}, 'IN'));
            exIdx = find(strcmp({res.points.envelope}, 'EXTRAPOLATED'));
            tc.verifyNumElements(inIdx, 30, 'REG: 30 IN points');
            tc.verifyNumElements(exIdx, 6, 'REG: 6 EXTRAPOLATED points');
            T = vital.uq.F16Evaluator.inEnvelopeMargins(res, g, L);
            tc.verifyNumElements(T, 30, 'header 6: one candidate per IN point');
            tc.verifyEqual(sort([T.index]), inIdx, 'header 6: the candidates are exactly the IN points');
            res3 = res;
            ir = find(strcmp({res.rules.group}, g) & [res.rules.level] == L);
            for r = ir
                res3.rules(r).margin(exIdx(1)) = -10;
                res3.rules(r).pointClass{exIdx(1)} = 'OK';
            end
            T3 = vital.uq.F16Evaluator.inEnvelopeMargins(res3, g, L);
            tc.verifyTrue(isequaln(T3, T), 'header 6: an EXTRAPOLATED worst point never becomes a candidate');
        end
    end
end
