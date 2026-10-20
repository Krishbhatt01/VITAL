classdef (TestTags = {'M8'}) tUqR4bF16 < vital.test.VitalTestCase
%TUQR4BF16  M8 amendment R4b on the augmented NESC F-16 (docs/PLAN_M5_M8.md,
%   "Amendment R4b", coordinator 2026-10-14): the R4-7 known case (breakpoint
%   bracketing), the R4-9 gate (lateral metrics do not depend on Cm_q), and one
%   small staged end-to-end run (R4-8 with the R4-3 lattice and R4-9 inside
%   vital.uq.analyze / run_f16_uq).
%   Budgets (stated before any run): known case 3 closed-loop point
%   evaluations (+3 for the unbracketed reference); invariance 18 evaluatePoint
%   calls; end-to-end: a 2-parameter spec (Cm_q, Cn_r), the records of
%   3.2.2.1.1-CatA and 3.3.1.1-CatA-other only, TWO in-envelope conditions
%   (13,000 ft / M 0.45 / CG 20 % and 30 %, the two groups' nominal critical
%   conditions), NumCandidates 2 (full budget), stage 1 NumCandidates 1,
%   NumLHS 4, N 10. Expected runtime about 5 min. Expected values pinned here,
%   never read from reports/.
%
%   PRE-REGISTERED (agent uq4, 2026-10-14, with the stubs, before any
%   implementation):
%   1. R4-7 KNOWN CASE (coordinator investigation 2026-10-14, reports/uq/
%      f16_uq_r4smoke.json group 2 point 151): theta = [0.9455579044985837
%      0.8633569252076247 1.0590958190905375 0.7882821321355422
%      0.7936364373298957 1.0187263201768573 1.121582436306137] for {Cm_q,
%      Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table}, 13,000 ft / M 0.45 /
%      CG 20 %, augmented aircraft (vital.uq.F16Evaluator default):
%      a) guard (REG, coordinator): with 'Bracket' false the point is
%         NOT_CONVERGED at stage 'linearize'; its trim alpha is within 1e-4 deg
%         of 5 (5.000036).
%      b) with 'Bracket' true: status 'OK'; S.bracket.status 'BRACKETED',
%         variable 'alpha', breakpoint 5, d 1e-3; side alphas 5.000692 (factor
%         1 - 1e-3) and 4.999388 (factor 1 + 1e-3) (REG, coordinator; 1e-6 abs);
%      c) the margin of 3.3.1.1-CatA-other and of 3.2.2.1.1-CatA at Level 1 is
%         EXACTLY the smaller of the two sides' margins, each side evaluated
%         by a separate evaluator with 'Bracket' false (isequal);
%      d) both values are reported: E.bracketed has one entry whose
%         sides(k).groups marginTo of 3.3.1.1-CatA-other at Level 1 equal the
%         two side margins (isequal), with the label 'BRACKETED';
%      e) the evaluator ran exactly 3 point evaluations (the point and its two
%         sides; nPointEvals 3); a second pointSummary is a cache hit.
%   2. R4-9 GATE (ANALYTIC symmetry: Cm_q scales cq2v cmq, zero at a q = 0
%      trim, so the trim and every lateral row of the linear model are
%      unchanged): augmented aircraft at 13,000/0.45/30, 5,000/0.55/20,
%      8,000/0.50/25; Cm_q at the AlphaMax (3) judged box ends 1 -/+ 3 k1 0.1
%      (k1 = sqrt(chi2inv(0.99, 1))), lateral multipliers at 1 and at the x1
%      lower corner (1 - k2 sigma, k2 = sqrt(chi2inv(0.99, 2))): every lateral
%      metric (zeta_d, omega_nd_rad_s, zeta_d_omega_nd_rad_s, phi_beta_d,
%      omega_nd2_phi_beta_d, tau_R_s, spiral_T2_s, coupled_roll_spiral_present,
%      zeta_RS_omega_nRS_rad_s) has the same status and a value within 1e-9
%      relative of Cm_q = 1, and so does Re(spiral root). Guards: every point
%      OK; zeta_sp moves by more than 1e-3 relative (Cm_q acts).
%   3. STAGED END-TO-END (run_f16_uq with the budget above, 'Stage1'
%      struct('NumCandidates', 1), 'Stage2Band' [0 Inf] so that every
%      searched non-lattice group goes to stage 2):
%      a) r.options.Staged true; r.stages.stage1 has NumCandidates 1,
%         DEPopulation 8, DEGenerations 4; r.stages.stage2Groups is exactly
%         {'3.3.1.1-CatA-other'}.
%      b) R4-9: 3.3.1.1-CatA-other has plan.mode 'lateral', plan.dropped
%         {'Cm_q'}, plan.latCheck.passed true, plan.fields {'Cn_r'};
%         csr.judged.searchNames {'Cn_r'}; every x1 evaluated point has Cm_q
%         exactly 1.
%      c) R4-8: 3.3.1.1-CatA-other: stage.decidedBy 2, its stage-1 result
%         (stage.stage1) had 1 candidate condition, the final result has 2;
%         3.2.2.1.1-CatA: stage.decidedBy 1 with a reason containing 'lattice'.
%      d) R4-3: 3.2.2.1.1-CatA has plan.method 'lattice' (SUPERSEDES
%         tests/M8/tUqR4F16.m header 5c 'grid'); csr.judged and csr.equal have
%         method 'lattice', nSearches 0 and status 'OK' or 'ROBUST_TO_CAP'
%         (REG: decided); the x1 bound-worst has method 'lattice' and label
%         'grid-certified (Lipschitz estimate)'.
%      e) independent re-check (a fresh vital.fq.assess by THIS test over the
%         two conditions): for an 'OK' judged CSR of 3.2.2.1.1-CatA the margin
%         at the CPV is < 0 and equals (isequaln) csr.confirmation.margin; the
%         two end points of R(alphaStar) (Cm_q = 1 -/+ alphaStar m, Cn_r 1)
%         have margin >= 0.
%      f) report: the Markdown contains 'stage 2', 'stage 1 (lattice)',
%         'R4-9' and 'BRACKETED' (the bracketing rule is stated even when no
%         point was bracketed).
%      g) ADDED 2026-10-14 after GREEN (agent uq4), because the all-M8
%         sabotage run showed S8W-2 no longer reached: tests/M8/tUqR4F16.m
%         #endToEndCsr now runs its longitudinal group on the lattice, so the
%         equal-percentage shape of the NON-lattice CSR path was untested on the
%         F-16. ANALYTIC (R4-1(b)): csr.equal.m = 0.10 exactly for every searched
%         parameter of both groups (Cn_r of the lateral group: non-lattice CSR;
%         Cm_q of the longitudinal group: lattice), and csr.judged.m = the x1
%         half-width (vital.uq.box).
%         (Note, found by the sabotage re-run: Cn_r has sigma 0.10 = EqualPct,
%         so this check cannot tell "m = sigma" from "m = 10 %" for the lateral
%         group; item 4 below does.)
%   4. NON-LATTICE EQUAL SHAPE (ADDED 2026-10-14 after GREEN, agent uq4, for
%      the same reason as 3g; ANALYTIC, R4-1(b)): run_f16_uq with a 1-parameter
%      spec (Cm_de, sigma 0.05), the group 3.2.2.1.1-CatA's records, ONE
%      condition (13,000 ft / M 0.45 / CG 30 %), 'Lattice' false, 'Staged'
%      false, NumCandidates 1, NumLHS 4, N 10 (the R4 path of
%      tests/M8/tUqR4F16.m#endToEndCsr before R4b): plan.method 'grid'
%      (vital.uq.searchMethod(1)); csr.equal.m = 0.10 exactly (not sigma 0.05,
%      not the half-width k2 0.05); csr.judged.m = the x1 half-width.

    properties
        R
        C
    end

    properties (Constant)
        F7 = {'Cm_q', 'Cm_basic', 'Cm_de', 'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'}
        THETA = [0.9455579044985837 0.8633569252076247 1.0590958190905375 0.7882821321355422 ...
            0.7936364373298957 1.0187263201768573 1.121582436306137]
        LAT = {'zeta_d', 'omega_nd_rad_s', 'zeta_d_omega_nd_rad_s', 'phi_beta_d', 'omega_nd2_phi_beta_d', 'tau_R_s', ...
            'spiral_T2_s', 'coupled_roll_spiral_present', 'zeta_RS_omega_nRS_rad_s'}
        CONDS = [13000 0.45 30; 5000 0.55 20; 8000 0.50 25]
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
    end

    methods (Static)
        function ok = sameValue(a, b)
            if isnan(b), ok = isnan(a);
            elseif isinf(b) || b == 0, ok = a == b;
            else, ok = abs(a - b) <= 1e-9 * abs(b);
            end
        end

        function P = evalAt(fields, theta, b, c)
            s = cell2struct(num2cell(theta(:)), fields(:), 1);
            fac = vital.fq.f16Factory('AeroScale', s, 'Controller', b);
            P = vital.fq.evaluatePoint(fac(c), c);
        end
    end

    methods (Test)
        function bracketKnownCase(tc)
            c = tc.cond([13000 0.45 20]);
            C1 = tc.subGrid(13000, 0.45, 20);
            th = tc.THETA;
            E = vital.uq.F16Evaluator(tc.F7, 'Conditions', C1, 'Bracket', true);
            S = E.pointSummary(th, c);
            E0 = vital.uq.F16Evaluator(tc.F7, 'Conditions', C1, 'Bracket', false);
            S0 = E0.pointSummary(th, c);
            tc.verifyEqual({S0.status, S0.stage}, {'NOT_CONVERGED', 'linearize'}, 'header 1a (guard)');
            tc.verifyTol(S0.alpha_deg, 5, 1e-4, 'abs', 'REG', 'header 1a: coordinator 5.000036', ...
                'Quantity', 'trim alpha at the known point', 'Unit', 'deg');
            tc.verifyEqual(S.status, 'OK', 'header 1b');
            b = S.bracket;
            tc.verifyEqual({b.status, b.variable, b.breakpoint, b.d}, {'BRACKETED', 'alpha', 5, 1e-3}, 'header 1b');
            % re-baselined 2026-10-19 for atmosisa (ADR-037), was [5.000692 4.999388], now
            % [5.000695 4.999390] (measured 5.000694527, 4.999390015); user-approved.
            % Tolerance unchanged. Header 1a (5.000036 -> 5.000038, within its 1e-4) holds.
            tc.verifyTol([b.sides.alpha_deg], [5.000695 4.999390], 1e-6, 'abs', 'REG', 'header 1b: coordinator', ...
                'Quantity', 'side trim alphas', 'Unit', 'deg');
            for gname = {'3.3.1.1-CatA-other', '3.2.2.1.1-CatA'}
                q = E.groupMargin(th, c, gname{1}, 1);
                qa = E0.groupMargin(th * (1 - 1e-3), c, gname{1}, 1);
                qb = E0.groupMargin(th * (1 + 1e-3), c, gname{1}, 1);
                tc.assertEqual({qa.status, qb.status}, {'OK', 'OK'}, 'sides OK');
                tc.verifyEqual(q.status, 'OK', ['header 1c ' gname{1}]);
                tc.verifyEqual(q.margin, min(qa.margin, qb.margin), ['header 1c: worse of the two sides, ' gname{1}]);
                if strcmp(gname{1}, '3.3.1.1-CatA-other'), sm = [qa.margin qb.margin]; end
            end
            tc.assertNumElements(E.bracketed, 1, 'header 1d');
            Bk = E.bracketed(1);
            tc.verifyEqual(Bk.label, 'BRACKETED', 'header 1d');
            m2 = arrayfun(@(sd) sd.groups(strcmp({sd.groups.group}, '3.3.1.1-CatA-other')).marginTo(1), Bk.sides);
            tc.verifyEqual(m2, sm, 'header 1d: both values reported');
            tc.verifyEqual(E.nPointEvals, 3, 'header 1e');
            h0 = E.nCacheHits;
            E.pointSummary(th, c);
            tc.verifyEqual([E.nPointEvals, E.nCacheHits], [3, h0 + 1], 'header 1e: cache hit');
        end

        function lateralInvarianceCmq(tc)
            f = tc.F7;
            k1 = sqrt(chi2inv(0.99, 1)); k2 = sqrt(chi2inv(0.99, 2));
            qx = [1 - 3 * k1 * 0.1, 1 + 3 * k1 * 0.1];
            latLo = 1 - k2 * [0.10 0.10 0.05 0.05];             % Cl_p, Cn_r, Cl_table, Cnt_table (x1 lower)
            b = vital.uq.augmentedBuilder();
            worst = 0;
            for ic = 1:size(tc.CONDS, 1)
                c = tc.cond(tc.CONDS(ic, :));
                for il = 1:2
                    th0 = ones(1, 7);
                    if il == 2, th0(4:7) = latLo; end
                    P0 = tUqR4bF16.evalAt(f, th0, b, c);
                    tc.assertEqual(P0.status, 'OK', sprintf('guard: point OK (%s)', P0.reason));
                    for q = qx
                        t = th0; t(1) = q;
                        P1 = tUqR4bF16.evalAt(f, t, b, c);
                        tc.assertEqual(P1.status, 'OK', sprintf('guard: point OK (%s)', P1.reason));
                        where = sprintf('%s theta %s', mat2str(tc.CONDS(ic, :)), mat2str(t, 5));
                        for n = tc.LAT
                            m0 = P0.metrics.(n{1}); m1 = P1.metrics.(n{1});
                            tc.verifyEqual(m1.status, m0.status, ['header 2: status of ' n{1} ' at ' where]);
                            tc.verifyTrue(tUqR4bF16.sameValue(m1.value, m0.value), sprintf( ...
                                'header 2: %s = %.17g vs %.17g at %s', n{1}, m1.value, m0.value, where));
                            if isfinite(m0.value) && m0.value ~= 0
                                worst = max(worst, abs(m1.value - m0.value) / abs(m0.value));
                            end
                        end
                        s0 = vital.uq.F16Evaluator.spiralRe(P0); s1 = vital.uq.F16Evaluator.spiralRe(P1);
                        tc.verifyTrue(tUqR4bF16.sameValue(s1, s0), sprintf('header 2: spiral Re %.17g vs %.17g at %s', ...
                            s1, s0, where));
                        if isfinite(s0) && s0 ~= 0, worst = max(worst, abs(s1 - s0) / abs(s0)); end
                        z0 = P0.metrics.zeta_sp.value; z1 = P1.metrics.zeta_sp.value;
                        tc.verifyGreaterThan(abs(z1 - z0), 1e-3 * abs(z0), 'guard: Cm_q acts on zeta_sp');
                    end
                end
            end
            tc.log(1, sprintf('R4-9 lateral invariance to Cm_q: largest relative deviation %.3g', worst));
            tc.verifyTol(worst, 0, 1e-9, 'abs', 'ANALYTIC', 'header 2: largest relative deviation', ...
                'Quantity', 'lateral invariance to Cm_q (relative)');
        end

        function stagedEndToEnd(tc)
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(ismember({spec.parameters.aeroScale}, {'Cm_q', 'Cn_r'}));
            tc.assertNumElements(spec.parameters, 2);
            G = {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other'};
            R = tc.R(ismember({tc.R.group}, G));
            C2 = tc.subGrid(13000, 0.45, [20 30]);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            r = run_f16_uq('Groups', G, 'Spec', spec, 'Rules', R, 'Conditions', C2, 'NumCandidates', 2, ...
                'NumLHS', 4, 'N', 10, 'Stage1', struct('NumCandidates', 1), 'Stage2Band', [0 Inf], ...
                'Label', 'r4btest', 'ReportDir', d, 'Quiet', true);
            % a) stages
            tc.verifyTrue(r.options.Staged, 'header 3a');
            s1 = r.stages.stage1;
            tc.verifyEqual([s1.NumCandidates s1.DEPopulation s1.DEGenerations], [1 8 4], 'header 3a');
            tc.verifyEqual(r.stages.stage2Groups, {'3.3.1.1-CatA-other'}, 'header 3a');
            gl = r.groups(strcmp({r.groups.group}, '3.3.1.1-CatA-other'));
            gL = r.groups(strcmp({r.groups.group}, '3.2.2.1.1-CatA'));
            tc.assertEqual({gl.status, gL.status}, {'DONE', 'DONE'}, [gl.reason gL.reason]);
            % b) R4-9
            p = gl.plan;
            tc.verifyEqual({p.mode, p.dropped, p.fields}, {'lateral', {'Cm_q'}, {'Cn_r'}}, 'header 3b');
            tc.verifyTrue(p.latCheck.passed, ['header 3b: ' p.latCheck.reason]);
            tc.verifyEqual(gl.csr.judged.searchNames, {'Cn_r'}, 'header 3b');
            B = vital.uq.box(spec);
            for gg = [gl gL]
                ix = gg.csr.equal.searchIndex;
                tc.verifyEqual(gg.csr.equal.m(ix), 0.10 * ones(1, numel(ix)), ['header 3g: equal shape 10 % ' gg.group]);
                tc.verifyEqual(gg.csr.judged.m(ix), B.halfWidth(ix), ['header 3g: judged shape ' gg.group]);
            end
            iq = strcmp(gl.widths(1).bw.names, 'Cm_q');
            tc.verifyTrue(all(gl.widths(1).bw.points.theta(:, iq) == 1), 'header 3b: Cm_q held at 1');
            % c) R4-8
            tc.verifyEqual(gl.stage.decidedBy, 2, 'header 3c');
            tc.verifyNumElements(gl.stage.stage1.candidates.labels, 1, 'header 3c: stage 1 candidates');
            tc.verifyNumElements(gl.candidates.labels, 2, 'header 3c: stage 2 candidates');
            tc.verifyEqual(gL.stage.decidedBy, 1, 'header 3c');
            tc.verifySubstring(gL.stage.reason, 'lattice', 'header 3c');
            % d) R4-3
            tc.verifyEqual(gL.plan.method, 'lattice', 'header 3d');
            for cs = {gL.csr.judged, gL.csr.equal}
                x = cs{1};
                tc.verifyEqual({x.method, x.nSearches}, {'lattice', 0}, 'header 3d');
                tc.verifyTrue(any(strcmp(x.status, {'OK', 'ROBUST_TO_CAP'})), ['header 3d (REG): ' x.reason]);
            end
            bw = gL.widths(1).bw;
            tc.verifyEqual({bw.method, bw.label}, {'lattice', 'grid-certified (Lipschitz estimate)'}, 'header 3d');
            % e) independent re-check
            b = vital.uq.augmentedBuilder();
            RL = R(strcmp({R.group}, G{1}));
            mAt = @(t) vital.uq.F16Evaluator.levelMargin(vital.fq.assess(RL, ...
                vital.fq.f16Factory('AeroScale', struct('Cm_q', t), 'Controller', b), C2), G{1}, gL.level0);
            cj = gL.csr.judged;
            iq = strcmp(cj.names, 'Cm_q');
            if strcmp(cj.status, 'OK')
                mc = mAt(cj.cpv(iq));
                tc.verifyLessThan(mc, 0, 'header 3e: the CPV fails');
                tc.verifyTrue(isequaln(mc, cj.confirmation.margin), sprintf('header 3e: %g vs %g', mc, cj.confirmation.margin));
            end
            if isfinite(cj.alphaStar)
                for t = [1 - cj.alphaStar * cj.m(iq), 1 + cj.alphaStar * cj.m(iq)]
                    tc.verifyGreaterThanOrEqual(mAt(t), 0, sprintf('header 3e: end point %.6g of R(alphaStar)', t));
                end
            end
            % f) report
            md = fileread(r.files.md);
            for s = {'stage 2', 'stage 1 (lattice)', 'R4-9', 'BRACKETED'}
                tc.verifySubstring(md, s{1}, 'header 3f');
            end
        end

        function nonLatticeEqualShape(tc)
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(strcmp({spec.parameters.aeroScale}, 'Cm_de'));
            tc.assertNumElements(spec.parameters, 1);
            tc.assertNotEqual(spec.parameters.sigma, 0.10, 'guard: sigma differs from the equal percentage');
            B = vital.uq.box(spec);
            g0 = '3.2.2.1.1-CatA';
            R = tc.R(strcmp({tc.R.group}, g0));
            C1 = tc.subGrid(13000, 0.45, 30);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            r = run_f16_uq('Groups', {g0}, 'Spec', spec, 'Rules', R, 'Conditions', C1, 'NumCandidates', 1, ...
                'NumLHS', 4, 'N', 10, 'Lattice', false, 'Staged', false, 'Label', 'r4bnl', 'ReportDir', d, 'Quiet', true);
            g = r.groups(1);
            tc.assertEqual(g.status, 'DONE', g.reason);
            tc.verifyEqual(g.plan.method, 'grid', 'header 4');
            tc.verifyEqual(g.csr.equal.m, 0.10, 'header 4: equal shape 10 %');
            tc.verifyEqual(g.csr.judged.m, B.halfWidth, 'header 4: judged shape');
        end
    end
end
