classdef (TestTags = {'M8'}) tUqR5F16 < vital.test.VitalTestCase
%TUQR5F16  M8 amendment R5 on the augmented NESC F-16 (docs/PLAN_M5_M8.md,
%   "Amendment R5", coordinator 2026-10-14; review R5, reports/review/
%   R5_REVIEW.md): the piecewise certificate on review R5's 1-D line through the
%   alpha = 5 deg breakpoint (R5-3), the evaluator's trim elevator (S8Q-6), the
%   analyze call site of the R4-9 gate (S8Q-8), and one small end-to-end run
%   with the R5 defaults (R5-2..R5-5). Toys are in tests/M8/tUqR5.m.
%   Budgets (stated before any run): line 1-D lattice over Cm_de, one
%   condition, 'MaxPoints' 400 (review R5's setting), no confirmation function
%   (as review R5), plus the same lattice without the switches (guard);
%   elevator pin 1 point; gate run: analyze on 3.3.1.1-CatA-other with a
%   2-parameter spec (Cm_q, Cn_r), ONE condition, 'Method' 'sqp', 'CSR'
%   false, NumLHS 4, NumStarts 1, MaxEvals 10, N 10; end-to-end: run_f16_uq on
%   3.2.2.1.2-CatA with a 2-parameter spec (Cm_de, Cn_r), ONE condition,
%   NumCandidates 1, NumLHS 4, N 10. Expected runtime about 3 min. Expected
%   values pinned here, never read from reports/.
%
%   The condition of every item: 13,000 ft / M 0.45 / CG 20 % (the critical
%   condition of 3.2.2.1.2-CatA, nominal trim alpha 5.050 deg; review R5 3.5).
%   Fields {Cm_q, Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table}; the line's
%   base point theta0 = [0.742417 1 1 1 1 1 1] (Cm_q at its x1 lower edge
%   1 - k1 0.1, review R5 reports/work/R5/f16_line2.txt).
%
%   PRE-REGISTERED (agent uq5, 2026-10-14, with the stubs, before any
%   implementation):
%   1. LINE (R5-3; review R5 3.6: the margin of 3.2.2.1.2-CatA is >= 0.017
%      along Cm_de in [0.85, 1.25] and jumps by +0.032 where the trim alpha
%      crosses 5 deg near Cm_de 1.071): a 1-D vital.uq.lattice over Cm_de
%      (nominal 1, judged m = the x1 half-width of Cm_de, k2 0.05 = 0.15174;
%      equal 0.10), the group's margin to Level 1 (its nominal Level) from
%      vital.uq.F16Evaluator.groupMargin, q.switchVals = the point's trim
%      [alpha_deg de_deg], problem.switches = the alpha and el breakpoints of
%      vital.uq.breakpoints (R4-7's lists), 'MaxPoints' 400:
%      a) the box R(1) (Cm_de 1 -/+ 0.15174) is 'OK' (certified) with
%         lowerBound in [0, 0.0172] (the bound cannot exceed the smallest
%         sampled margin, 0.01711 at Cm_de 1, REG review R5);
%      b) judged: lowerCertified true and alphaLo >= 1 (no longer
%         NOT_ASSESSABLE ('GRID') at alpha 0.4693 as in review R5);
%      c) discontinuity.present true; the crossing of 'alpha_deg' at the
%         breakpoint 5 is listed (discontinuity.crossings) with a jump in
%         [0.025, 0.040] (REG: +0.032 in review R5's line scan, plus the slope
%         over one base edge);
%      d) GUARD (review R5's finding, reproduced): the same lattice without
%         problem.switches gives R(1) 'NOT_ASSESSABLE' with 'GRID' in the reason.
%   2. TRIM ELEVATOR (S8Q-6): F16Evaluator.pointSummary at theta0 ('Bracket'
%      false): S.alpha_deg = 5.05032 and S.de_deg = -6.33014 (REG, review R5
%      f16_line2.txt, Cm_de 1.00, 5 decimals: 1e-4 abs); S.de_deg equals
%      (isequal) the info.de_deg of an independent vital.fq.evaluatePoint of the
%      same aircraft and condition, and differs from S.alpha_deg.
%   3. R4-9 GATE AT THE analyze CALL SITE (S8Q-8): a controller that couples
%      the axes (the augmented controller + a crossfeed dr += K q, de += K r,
%      K = 1e-3 rad per rad/s, so Cm_q reaches the lateral modes): the gate in
%      vital.uq.analyze must FAIL: plan.latCheck.passed false, plan.dropped
%      empty, 'Cm_q' among plan.fields, plan.mode 'full', and plan.latCheck.maxRel
%      in (1e-9, 1e-2) (REG probe 2026-10-14: 1.6e-5 relative at Cm_q 1 +/-
%      3 k1 0.1; a 1e-2 tolerance would pass it).
%   4. END TO END WITH THE R5 DEFAULTS (run_f16_uq; the 1-D lattice over Cm_de
%      of 3.2.2.1.2-CatA, Cn_r held at 1):
%      a) plan.method 'lattice'; r.options.LatticeCorners true (R5-5 M2);
%         r.options.LatticeTotalPoints finite (R5 m5); r.options.Piecewise true;
%      b) plan.lattice.discontinuity.present true with 'alpha_deg' and the
%         breakpoint 5 (REG hypothesis: the alpha = 5 surface crosses the
%         Cm_de lattice box [0.545, 1.455] near 1.07 at Cm_q 1, since Cm_q does
%         not move the q = 0 trim);
%      c) judged: lowerCertified true and alphaLo >= 1 (REG hypothesis: the
%         nominal margin 0.102 is far above the Cm_q-low line's 0.017);
%      d) plan.lattice.confirmations has evaluated items whose what starts
%         'corner R(1)' (the fresh assessments at the corners of R(1));
%      e) the staged run's band r.stages.band = vital.uq.stageBand of the R5-4
%         measured stage-1 errors (R54_ERRORS below: REG, the measurement of
%         ADR-036 uq5-4, recorded after the measurement), and it contains
%         [0.8, 1.2];
%      f) the Markdown contains every statement of vital.uq.statements('limits')
%         and ('judgments') verbatim, and no longer the stale R4b texts
%         'Lateral groups use the full box, because' and 'it is bracketed to
%         0.01 by searched boxes' (review R5 m1).

    properties
        R
        C
    end

    properties (Constant)
        F7 = {'Cm_q', 'Cm_basic', 'Cm_de', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'}
        THETA0 = [0.742417 1 1 1 1 1 1]
        GROUP = '3.2.2.1.2-CatA'
        R54_ERRORS = [0 0 0 0 0 0.07505 0]   % REG: R5-4 measurement (ADR-036 uq5-4), |stage 1 - stage 2| of the judged bracket ends: F-16 3.3.1.1-CatA-other, 3.3.1.3-CatA; toys LIN, QUAD, COND3, KINK (hi 0.07505), MIXED (reports/work/uq5/r5band_*.txt)
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.R = vital.fq.loadRules();
            tc.C = vital.ctrl.inEnvelopeConditions();
        end
    end

    methods (Access = private)
        function c = cond(tc, v)
            pts = vital.fq.gridPoints(tc.C);
            k = find(arrayfun(@(p) p.h_ft == v(1) && p.mach == v(2) && p.cg_pct_mac == v(3), pts));
            tc.assertNumElements(k, 1, sprintf('condition %s on the grid', mat2str(v)));
            c = pts(k);
        end

        function C1 = subGrid(tc, h, M, cg)
            C1 = tc.C;
            for a = 1:numel(C1.axes)
                switch C1.axes(a).name
                    case 'h_ft', C1.axes(a).values = h;
                    case 'mach', C1.axes(a).values = M;
                    case 'cg_pct_mac', C1.axes(a).values = cg;
                end
            end
        end

        function P = lineProblem(tc, E)
            c = tc.cond([13000 0.45 20]);
            B = vital.uq.box(vital.uq.loadSpec());
            m = B.halfWidth(strcmp(B.aeroScale, 'Cm_de'));
            bp = vital.uq.breakpoints();
            P.names = {'Cm_de'};
            P.nominal = 1;
            P.m = m;
            P.conditions = {c};
            P.condLabels = {vital.uq.F16Evaluator.condLabel(c)};
            P.pointFcn = @(th, cc) tUqR5F16.linePoint(E, tUqR5F16.THETA0, th, cc);
            P.groups = struct('name', tUqR5F16.GROUP, 'conds', 1, 'confirmFcn', {[]});
            P.shapes = struct('name', {'judged', 'equal'}, 'm', {m, 0.1});
            P.switches = struct('name', {'alpha_deg', 'de_deg'}, 'breakpoints', {bp.alpha_deg, bp.el_deg});
        end
    end

    methods (Static)
        function q = linePoint(E, base, th, c)
            t = base; t(3) = th;
            g = E.groupMargin(t, c, tUqR5F16.GROUP, 1);
            S = E.pointSummary(t, c);
            q = struct('status', {{g.status}}, 'margin', g.margin, 'record', {{g.record}}, 'reason', {{g.reason}}, ...
                'switchVals', [S.alpha_deg S.de_deg]);
        end

        function c = xfeed(K)
            c.rate_hz = 100;
            c.init = [];
            c.static = true;
            c.step = @(t, x, y, uref, s) tUqR5F16.xstep(y, uref, s, K);
            c.info = struct('name', 'crossfeed (test)', 'K', K);
        end

        function [u, s] = xstep(y, uref, s, K)
            u = uref(:);
            u(3) = u(3) + K * y.q;
            u(1) = u(1) + K * y.r;
        end
    end

    methods (Test)
        function lineCertifiedPiecewise(tc)
            C1 = tc.subGrid(13000, 0.45, 20);
            E = vital.uq.F16Evaluator(tc.F7, 'Conditions', C1);
            P = tc.lineProblem(E);
            res = vital.uq.lattice(P, 'MaxPoints', 400);
            m = P.m;
            st = res.box(1, 1 - m, 1 + m);
            tc.verifyEqual(st.status, 'OK', ['header 1a: R(1): ' st.reason]);
            tc.verifyWithin(st.lowerBound, 0, 0.0172, 'REG', 'header 1a: review R5 line, 0.01711 at Cm_de 1', ...
                'Quantity', 'certified lower bound over R(1) (line)');
            cj = res.groups(1).csr(1);
            [lo, ok, why] = vital.uq.lowerEnd(cj);
            tc.verifyTrue(ok, ['header 1b: ' why]);
            tc.verifyGreaterThanOrEqual(lo, 1, ['header 1b: ' cj.reason]);
            D = res.groups(1).discontinuity;
            tc.verifyTrue(D.present, 'header 1c');
            k = find(strcmp({D.crossings.variable}, 'alpha_deg') & [D.crossings.breakpoint] == 5, 1);
            tc.assertNotEmpty(k, 'header 1c: the alpha = 5 deg crossing is listed');
            tc.verifyWithin(D.crossings(k).maxJump, 0.025, 0.040, 'REG', 'header 1c: review R5 jump +0.032', ...
                'Quantity', 'margin jump at alpha = 5 deg', 'Unit', '-');
            P0 = rmfield(P, 'switches');
            r0 = vital.uq.lattice(P0, 'MaxPoints', 400);
            s0 = r0.box(1, 1 - m, 1 + m);
            tc.verifyEqual(s0.status, 'NOT_ASSESSABLE', ['header 1d (guard): ' s0.reason]);
            tc.verifySubstring(s0.reason, 'GRID', 'header 1d (guard)');
        end

        function trimElevatorPinned(tc)
            c = tc.cond([13000 0.45 20]);
            C1 = tc.subGrid(13000, 0.45, 20);
            E = vital.uq.F16Evaluator(tc.F7, 'Conditions', C1, 'Bracket', false);
            S = E.pointSummary(tc.THETA0, c);
            tc.assertEqual(S.status, 'OK', S.reason);
            tc.verifyTol(S.alpha_deg, 5.05032, 1e-4, 'abs', 'REG', 'header 2: review R5 f16_line2.txt', ...
                'Quantity', 'trim alpha at theta0', 'Unit', 'deg');
            tc.verifyTol(S.de_deg, -6.33014, 1e-4, 'abs', 'REG', 'header 2: review R5 f16_line2.txt', ...
                'Quantity', 'trim elevator at theta0', 'Unit', 'deg');
            s = cell2struct(num2cell(tc.THETA0(:)), tc.F7(:), 1);
            fac = vital.fq.f16Factory('AeroScale', s, 'Controller', vital.uq.augmentedBuilder());
            Pt = vital.fq.evaluatePoint(fac(c), c);
            tc.verifyEqual(S.de_deg, Pt.info.de_deg, 'header 2: the evaluator reports the trim elevator');
            tc.verifyNotEqual(S.de_deg, S.alpha_deg, 'header 2');
        end

        function latGateAtCallSite(tc)
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(ismember({spec.parameters.aeroScale}, {'Cm_q', 'Cn_r'}));
            tc.assertNumElements(spec.parameters, 2);
            G = {'3.3.1.1-CatA-other'};
            R = tc.R(ismember({tc.R.group}, G));
            C1 = tc.subGrid(13000, 0.45, 20);
            b0 = vital.uq.augmentedBuilder();
            b = @(AC, env, tr) vital.ctrl.combine(b0(AC, env, tr), tUqR5F16.xfeed(1e-3));
            r = vital.uq.analyze('Groups', G, 'Spec', spec, 'Rules', R, 'Conditions', C1, 'Controller', b, ...
                'NumCandidates', 1, 'NumLHS', 4, 'NumStarts', 1, 'MaxEvals', 10, 'N', 10, 'Method', 'sqp', ...
                'CSR', false, 'Quiet', true);
            g = r.groups(1);
            tc.assertEqual(g.status, 'DONE', g.reason);
            p = g.plan;
            tc.verifyFalse(p.latCheck.passed, ['header 3: ' p.latCheck.reason]);
            tc.verifyEmpty(p.dropped, 'header 3');
            tc.verifyTrue(any(strcmp(p.fields, 'Cm_q')), 'header 3: Cm_q searched again');
            tc.verifyEqual(p.mode, 'full', 'header 3');
            tc.verifyGreaterThan(p.latCheck.maxRel, 1e-9, 'header 3 (REG probe 1.6e-5)');
            tc.verifyLessThan(p.latCheck.maxRel, 1e-2, 'header 3 (REG probe 1.6e-5)');
        end

        function endToEndR5(tc)
            Ls = vital.uq.statements('limits');
            Js = vital.uq.statements('judgments');
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(ismember({spec.parameters.aeroScale}, {'Cm_de', 'Cn_r'}));
            tc.assertNumElements(spec.parameters, 2);
            G = {tc.GROUP};
            R = tc.R(ismember({tc.R.group}, G));
            C1 = tc.subGrid(13000, 0.45, 20);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            r = run_f16_uq('Groups', G, 'Spec', spec, 'Rules', R, 'Conditions', C1, 'NumCandidates', 1, ...
                'NumLHS', 4, 'N', 10, 'Label', 'r5test', 'ReportDir', d, 'Quiet', true);
            g = r.groups(1);
            tc.assertEqual(g.status, 'DONE', g.reason);
            % a)
            tc.verifyEqual(g.plan.method, 'lattice', 'header 4a');
            tc.verifyTrue(r.options.LatticeCorners, 'header 4a');
            tc.verifyTrue(isfinite(r.options.LatticeTotalPoints), 'header 4a');
            tc.verifyTrue(r.options.Piecewise, 'header 4a');
            % b)
            D = g.plan.lattice.discontinuity;
            tc.verifyTrue(D.present, 'header 4b (REG hypothesis)');
            tc.verifyTrue(any(strcmp({D.crossings.variable}, 'alpha_deg') & [D.crossings.breakpoint] == 5), ...
                'header 4b: alpha = 5 deg crossing');
            % c)
            [lo, ok, why] = vital.uq.lowerEnd(g.csr.judged);
            tc.verifyTrue(ok, ['header 4c: ' why]);
            tc.verifyGreaterThanOrEqual(lo, 1, ['header 4c: ' g.csr.judged.reason]);
            % d)
            it = g.plan.lattice.confirmations;
            k = startsWith({it.what}, 'corner R(1)');
            tc.verifyTrue(any(k), 'header 4d: corners of R(1) assessed');
            tc.verifyTrue(all([it(k).evaluated]), 'header 4d: fresh assessments');
            % e)
            tc.verifyEqual(r.stages.band, vital.uq.stageBand(tc.R54_ERRORS), 'header 4e');
            tc.verifyLessThanOrEqual(r.stages.band(1), 0.8, 'header 4e');
            tc.verifyGreaterThanOrEqual(r.stages.band(2), 1.2, 'header 4e');
            % f)
            md = fileread(r.files.md);
            for s = [Ls(:).' Js(:).']
                tc.verifySubstring(md, s{1}, 'header 4f');
            end
            for s = {'Lateral groups use the full box, because', 'it is bracketed to 0.01 by searched boxes'}
                tc.verifyFalse(contains(md, s{1}), ['header 4f: stale text "' s{1} '"']);
            end
        end
    end
end
