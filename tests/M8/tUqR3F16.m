classdef (TestTags = {'M8'}) tUqR3F16 < vital.test.VitalTestCase
%TUQR3F16  M8 design fixes after review R3 on the NESC F-16 (docs/PLAN_M5_M8.md,
%   "Amendment after review R3", 2026-10-09): the lon/lat invariance that gates
%   the longitudinal-only search (R3-M3(a)), the effective CG-derivative ratios
%   of the M8 multipliers (R3-M5) and the candidate ranking of +Inf groups by
%   the spiral surrogate (R3-M3(b)). One augmented vital.fq.assess over the 36
%   in-envelope conditions (about 10 s) and about 40 single-point evaluations.
%   Expected runtime under 1 min. Expected values pinned here (never read from
%   reports/).
%
%   PRE-REGISTERED (agent uq2, 2026-10-09, before any implementation of the
%   amendment and before any run of this file):
%   1. LON/LAT INVARIANCE (the gate of R3-M3(a); ANALYTIC symmetry argument:
%      at a wings-level, beta = 0 trim of the symmetric airframe the lateral
%      multipliers scale clt(beta, alpha) (zero at beta = 0), cnt (zero at
%      beta = 0), clp p and cnr r (p = r = 0): they change neither the trim nor
%      any longitudinal row or column of the linear model; R3 3.5 measured
%      1.6e-16 at one point). The augmented aircraft (M7 gains) at three IN
%      conditions, 13,000 ft / M 0.45 / CG 30 %, 5,000 ft / M 0.55 / CG 20 %
%      and 8,000 ft / M 0.50 / CG 25 %; longitudinal multipliers at 1 and at
%      the x1.5 lower corner (Cm_q, Cm_table); lateral multipliers (Cl_p,
%      Cnr_table, Cl_table, Cnt_table) at 1 and at four corners of the x1.5 box
%      (all lower, all upper, lo/hi/lo/hi, hi/lo/hi/lo; the x1.5 box contains
%      the x0.5 and x1 boxes). Every longitudinal metric of vital.fq.metrics
%      (zeta_sp, omega_nsp_rad_s, n_alpha_g_per_rad, CAP, zeta_p, T2_phugoid_s,
%      T2_speed_divergence_s, speed_divergence_rate_1_s,
%      lon_divergence_rate_1_s, T2_aperiodic_divergence_s) has the same status
%      and a value within 1e-9 relative of the value with the lateral
%      multipliers at 1 (NaN = NaN, Inf = Inf, 0 exactly 0). Guards: every
%      point is OK; every metric of every 3.2.x group is in that list (so every
%      3.2.x margin is invariant too); zeta_d moves by more than 1e-3 relative
%      at the all-lower lateral corner (the lateral multipliers do act).
%   2. EFFECTIVE CG-DERIVATIVE RATIOS (R3-M5; finite differences, step 1e-4, of
%      the plant's body-axis moment about the CG at the BARE trim at 13,000 ft /
%      M 0.45 / CG 30 %, the CAP critical condition, state and controls held at
%      the nominal trim). Box edges at x1: Cm_table 1 -/+ k1 0.05 (k1 =
%      2.5758), Cl_table and Cnr_table 1 - k2 sigma (k2 = 3.0349).
%      a) ANALYTIC: the moment is affine in each multiplier, so the ratios at
%         the two symmetric Cm_table edges sum to 2 (M_alpha and M_de, 1e-8).
%      b) ANALYTIC: Cm_table leaves L_beta, N_beta and N_r unchanged (ratio 1,
%         1e-12 abs); Cl_table and Cnr_table leave M_alpha and M_de unchanged.
%      c) ANALYTIC: Cl_table x k scales L_beta about the CG by exactly k (1e-9
%         rel): DYCG = DZCG = 0, so the side force adds no rolling moment about
%         the CG, and da = dr = 0 at the trim. N_beta unchanged (1e-12 abs).
%      d) REG prediction: Cm_table at its lower edge k = 0.8712 scales M_de,cg
%         by a ratio in [k, k + 0.03]: the MRC part (Cm_de) scales by k; the
%         transfer term DXCG Z_de (CG 5 % MAC ahead of the MRC) is unchanged,
%         small, and of the same sign (nose-down).
%      e) REG prediction: M_alpha,cg ratio at the lower edge in [k, 1]: the MRC
%         part scales by k, the transfer term DXCG Z_alpha is unchanged; at the
%         MRC (35 % MAC, near the neutral point) M_alpha is the smaller part.
%      FAILED HYPOTHESIS 2e (first run, 2026-10-09, before any implementation of
%      the amendment; text above kept, tolerance unchanged): the measured ratio
%      is 1.0407 (> 1): Cm_table x 0.871 makes M_alpha about the CG LARGER in
%      magnitude (more stable), not smaller. The assumption that the MRC part of
%      M_alpha has the same sign as the CG total was wrong: at this condition
%      the pitching-moment slope about the MRC (35 % MAC) is DESTABILIZING
%      (positive) and the transfer term DXCG Z_alpha is stabilizing and larger,
%      so ratio = (k A + B)/(A + B) with A/(A + B) < 0 exceeds 1 for k < 1.
%      2e' CORRECTED (ANALYTIC, independent decomposition): A = the moment slope
%      about the MRC, measured with the plant at CG 35 % MAC (r_cg = 0, so the
%      plant's moment about the CG IS the MRC moment; the forces at the fixed
%      state do not depend on the CG), B = d0 - A. Then the ratio at k equals
%      (k A + B)/(A + B) within 1e-8 abs, for M_alpha and M_de at both edges;
%      and A/(A + B) < 0 for M_alpha (REG, observed: the MRC slope is
%      destabilizing here), > 0 for M_de.
%      f) REG prediction: Cnr_table at k = 0.6965 scales N_r,cg by a ratio in
%         [k, k + 0.03] (transfer -DXCG Y_r, arm 0.57 ft against b = 30 ft,
%         same sign as N_r for cyr > 0); the two edges sum to 2 (1e-8).
%      The measured ratios are written to the test log (diagnostic) and to
%      reports/fragments/uq2/NOTES.md.
%   3. CANDIDATES OF A +Inf GROUP BY THE SURROGATE (R3-M3(b)). Nominal augmented
%      assessment over vital.ctrl.inEnvelopeConditions, group 3.3.1.3-CatA,
%      Level 1:
%      a) guard: every in-envelope margin (inEnvelopeMargins) is +Inf, so a
%         ranking by margin is grid order (R3 M3);
%      b) F16Evaluator.inEnvelopeSurrogate returns the 30 IN points; its
%         surrogate value is the real part of the point's 'spiral' mode
%         (res.points(i).info.modes, recomputed here, exact), sorted
%         non-increasing (most unstable first);
%      c) F16Evaluator.candidates(res, g, L, 'surrogate') equals it (isequaln);
%         candidates(..., 'full') and (..., 'longitudinal') equal
%         inEnvelopeMargins (isequaln);
%      d) REG (R3 3.8: the x1 corner maximum and the x1.5 moving-limit
%         condition): 5,000 ft / M 0.55 / CG 20 % is among the first 4.

    properties
        R
        C
        res
        pts
    end

    properties (Constant)
        LON = {'zeta_sp', 'omega_nsp_rad_s', 'n_alpha_g_per_rad', 'CAP', 'zeta_p', 'T2_phugoid_s', ...
            'T2_speed_divergence_s', 'speed_divergence_rate_1_s', 'lon_divergence_rate_1_s', 'T2_aperiodic_divergence_s'}
        CONDS = [13000 0.45 30; 5000 0.55 20; 8000 0.50 25]
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.R = vital.fq.loadRules();
            tc.C = vital.ctrl.inEnvelopeConditions();
            tc.res = vital.fq.assess(tc.R, vital.fq.f16Factory('Controller', vital.uq.augmentedBuilder()), tc.C);
            tc.pts = vital.fq.gridPoints(tc.C);
        end
    end

    methods (Access = private)
        function c = cond(tc, v)
            k = find(arrayfun(@(p) p.h_ft == v(1) && p.mach == v(2) && p.cg_pct_mac == v(3), tc.pts));
            tc.assertNumElements(k, 1, sprintf('condition %s on the grid', mat2str(v)));
            c = tc.pts(k);
            i = find(arrayfun(@(p) isequal(p.cond, c), tc.res.points), 1);
            tc.assertEqual(tc.res.points(i).envelope, 'IN', sprintf('condition %s is in the envelope', mat2str(v)));
        end
    end

    methods (Static)
        function d = cgDerivs(AC, env, tr)
            % body-axis moment derivatives about the CG at the trim state:
            % [M_alpha, M_de, L_beta, N_beta, N_r] (N m per rad, per rad/s)
            x0 = tr.x(:); u0 = tr.u(:);
            V = norm(x0(1:3)); a = tr.alpha;
            e = 1e-4;
            M = @(al, be, w, de) tUqR3F16.momentAt(AC, env, x0, u0, V, al, be, w, de);
            z = [0; 0; 0];
            dA = (M(a + e, 0, z, u0(1)) - M(a - e, 0, z, u0(1))) / (2 * e);
            dE = (M(a, 0, z, u0(1) + e) - M(a, 0, z, u0(1) - e)) / (2 * e);
            dB = (M(a, e, z, u0(1)) - M(a, -e, z, u0(1))) / (2 * e);
            dR = (M(a, 0, [0; 0; e], u0(1)) - M(a, 0, [0; 0; -e], u0(1))) / (2 * e);
            d = [dA(2), dE(2), dB(1), dB(3), dR(3)];
        end

        function Mo = momentAt(AC, env, x0, u0, V, al, be, w, de)
            x = x0;
            x(1:3) = V * [cos(al) * cos(be); sin(be); sin(al) * cos(be)];
            x(4:6) = w;
            u = u0; u(1) = de;
            xd = vital.plant.derivatives(x, u, AC, env);
            Mo = AC.J * xd(4:6) + cross(w, AC.J * w);
        end

        function ok = sameValue(a, b)
            if isnan(b), ok = isnan(a);
            elseif isinf(b) || b == 0, ok = a == b;
            else, ok = abs(a - b) <= 1e-9 * abs(b);
            end
        end
    end

    methods (Test)
        function lonLatInvariance(tc)
            spec = vital.uq.loadSpec();
            B = vital.uq.box(spec, 'WidthScale', 1.5);
            f = B.aeroScale;
            iLon = find(ismember(f, {'Cm_q', 'Cm_table'}));
            iLat = find(ismember(f, {'Cl_p', 'Cnr_table', 'Cl_table', 'Cnt_table'}));
            tc.assertNumElements(iLon, 2); tc.assertNumElements(iLat, 4);
            g32 = tc.R(startsWith({tc.R.group}, '3.2.'));
            tc.verifyTrue(all(ismember(unique({g32.metric}), tc.LON)), 'guard: every 3.2.x metric is in the longitudinal list');
            lo = B.lo(iLat); hi = B.hi(iLat);
            latC = [lo; hi; lo(1) hi(2) lo(3) hi(4); hi(1) lo(2) hi(3) lo(4)];
            lonS = [1 1; B.lo(iLon)];
            b = vital.uq.augmentedBuilder();
            worst = 0;
            for ic = 1:size(tc.CONDS, 1)
                c = tc.cond(tc.CONDS(ic, :));
                for il = 1:2
                    th = ones(1, 6); th(iLon) = lonS(il, :);
                    P0 = tUqR3F16.evalAt(f, th, b, c);
                    tc.assertEqual(P0.status, 'OK', sprintf('guard: point OK (%s)', P0.reason));
                    for k = 1:size(latC, 1)
                        t = th; t(iLat) = latC(k, :);
                        P1 = tUqR3F16.evalAt(f, t, b, c);
                        tc.assertEqual(P1.status, 'OK', sprintf('guard: point OK (%s)', P1.reason));
                        where = sprintf('%s theta %s', mat2str(tc.CONDS(ic, :)), mat2str(t, 5));
                        for n = tc.LON
                            m0 = P0.metrics.(n{1}); m1 = P1.metrics.(n{1});
                            tc.verifyEqual(m1.status, m0.status, ['header 1: status of ' n{1} ' at ' where]);
                            tc.verifyTrue(tUqR3F16.sameValue(m1.value, m0.value), sprintf( ...
                                'header 1: %s = %.17g vs %.17g at %s', n{1}, m1.value, m0.value, where));
                            if isfinite(m0.value) && m0.value ~= 0
                                worst = max(worst, abs(m1.value - m0.value) / abs(m0.value));
                            end
                        end
                        if k == 1
                            z0 = P0.metrics.zeta_d.value; z1 = P1.metrics.zeta_d.value;
                            tc.verifyGreaterThan(abs(z1 - z0), 1e-3 * abs(z0), 'guard: the lateral multipliers act on zeta_d');
                        end
                    end
                end
            end
            tc.log(1, sprintf('lon/lat invariance: largest relative deviation of a longitudinal metric %.3g', worst));
            tc.verifyTol(worst, 0, 1e-9, 'abs', 'ANALYTIC', 'header 1: largest relative deviation', ...
                'Quantity', 'lon/lat invariance (relative)');
        end

        function effectiveDerivativeRatios(tc)
            c = tc.cond([13000 0.45 30]);
            fac0 = vital.fq.f16Factory();
            ac = fac0(c);
            tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
            tc.assertEqual(tr.status, 'OK');
            d0 = tUqR3F16.cgDerivs(ac.AC, ac.env, tr);
            k1 = sqrt(2) * erfinv(0.99); k2 = sqrt(chi2inv(0.99, 2));
            r = @(name, k) tUqR3F16.cgDerivs(tUqR3F16.scaledAC(name, k, c), ac.env, tr) ./ d0;
            % Cm_table
            kl = 1 - k1 * 0.05; kh = 1 + k1 * 0.05;
            rl = r('Cm_table', kl); rh = r('Cm_table', kh);
            tc.log(1, sprintf('Cm_table %.6f: M_alpha x %.6f, M_de x %.6f; %.6f: M_alpha x %.6f, M_de x %.6f', ...
                kl, rl(1), rl(2), kh, rh(1), rh(2)));
            tc.verifyTol(rl(1:2) + rh(1:2), [2 2], 1e-8, 'abs', 'ANALYTIC', 'header 2a: affine in Cm_table', 'Quantity', 'M_alpha, M_de ratio sums');
            tc.verifyTol(rl(3:5), [1 1 1], 1e-12, 'abs', 'ANALYTIC', 'header 2b', 'Quantity', 'L_beta, N_beta, N_r ratios (Cm_table)');
            tc.verifyWithin(rl(2), kl, kl + 0.03, 'REG', 'header 2d (prediction)', 'Quantity', 'M_de,cg ratio at Cm_table lower edge');
            % header 2e (ratio in [k, 1]) FAILED (1.0407); replaced by 2e' below
            % header 2e' (corrected): decomposition into the MRC part A and the transfer part B
            AC35 = vital.aircraft.f16.config('CG_PCT_MAC', 35);
            tc.assertEqual(AC35.r_cg, zeros(3, 1), 'guard: CG 35 % MAC is the MRC');
            dm = tUqR3F16.cgDerivs(AC35, ac.env, tr);
            A = dm(1:2); Bt = d0(1:2) - A;
            tc.log(1, sprintf('MRC parts A/(A+B): M_alpha %.4f, M_de %.4f', A(1) / d0(1), A(2) / d0(2)));
            tc.verifyTol(rl(1:2), (kl * A + Bt) ./ d0(1:2), 1e-8, 'abs', 'ANALYTIC', 'header 2e'': (k A + B)/(A + B), lower edge', ...
                'Quantity', 'M_alpha, M_de ratios from the MRC decomposition');
            tc.verifyTol(rh(1:2), (kh * A + Bt) ./ d0(1:2), 1e-8, 'abs', 'ANALYTIC', 'header 2e'': (k A + B)/(A + B), upper edge', ...
                'Quantity', 'M_alpha, M_de ratios from the MRC decomposition');
            tc.verifyLessThan(A(1) / d0(1), 0, 'header 2e'' (REG, observed): the MRC M_alpha is destabilizing here');
            tc.verifyGreaterThan(A(2) / d0(2), 0, 'header 2e'': the MRC M_de has the sign of the total');
            % Cl_table
            kc = 1 - k2 * 0.05;
            rc = r('Cl_table', kc);
            tc.log(1, sprintf('Cl_table %.6f: L_beta x %.9f, N_beta x %.9f', kc, rc(3), rc(4)));
            tc.verifyTol(rc(3), kc, 1e-9, 'rel', 'ANALYTIC', 'header 2c', 'Quantity', 'L_beta,cg ratio (Cl_table)');
            tc.verifyTol(rc([1 2 4]), [1 1 1], 1e-12, 'abs', 'ANALYTIC', 'header 2b/2c', 'Quantity', 'M_alpha, M_de, N_beta ratios (Cl_table)');
            % Cnr_table
            kn = 1 - k2 * 0.10; knh = 1 + k2 * 0.10;
            rn = r('Cnr_table', kn); rnh = r('Cnr_table', knh);
            tc.log(1, sprintf('Cnr_table %.6f: N_r x %.6f; %.6f: N_r x %.6f', kn, rn(5), knh, rnh(5)));
            tc.verifyTol(rn(5) + rnh(5), 2, 1e-8, 'abs', 'ANALYTIC', 'header 2f: affine in Cnr_table', 'Quantity', 'N_r ratio sum');
            tc.verifyTol(rn(1:4), [1 1 1 1], 1e-12, 'abs', 'ANALYTIC', 'header 2b', 'Quantity', 'other ratios (Cnr_table)');
            tc.verifyWithin(rn(5), kn, kn + 0.03, 'REG', 'header 2f (prediction)', 'Quantity', 'N_r,cg ratio at Cnr_table lower edge');
        end

        function surrogateCandidates(tc)
            g = '3.3.1.3-CatA'; L = 1;
            T0 = vital.uq.F16Evaluator.inEnvelopeMargins(tc.res, g, L);
            tc.verifyTrue(all([T0.margin] == Inf), 'header 3a guard: every in-envelope margin is +Inf');
            T = vital.uq.F16Evaluator.inEnvelopeSurrogate(tc.res, g, L);
            inIdx = find(strcmp({tc.res.points.envelope}, 'IN'));
            tc.verifyNumElements(T, 30, 'header 3b');
            tc.verifyEqual(sort([T.index]), inIdx, 'header 3b: the IN points');
            for k = 1:numel(T)
                md = tc.res.points(T(k).index).info.modes;
                re = [md(strcmp({md.name}, 'spiral')).re];
                tc.assertNumElements(re, 1);
                tc.verifyEqual(T(k).surrogate, re, 'header 3b: surrogate = Re(spiral root)');
            end
            s = [T.surrogate];
            tc.verifyTrue(all(diff(s) <= 0), sprintf('header 3b: sorted most unstable first %s', mat2str(s, 4)));
            tc.verifyTrue(isequaln(vital.uq.F16Evaluator.candidates(tc.res, g, L, 'surrogate'), T), 'header 3c');
            tc.verifyTrue(isequaln(vital.uq.F16Evaluator.candidates(tc.res, g, L, 'full'), T0), 'header 3c');
            g2 = '3.2.2.1.1-CatA';
            tc.verifyTrue(isequaln(vital.uq.F16Evaluator.candidates(tc.res, g2, L, 'longitudinal'), ...
                vital.uq.F16Evaluator.inEnvelopeMargins(tc.res, g2, L)), 'header 3c');
            top = arrayfun(@(t) [t.cond.h_ft t.cond.mach t.cond.cg_pct_mac], T(1:4), 'UniformOutput', false);
            tc.verifyTrue(any(cellfun(@(v) isequal(v, [5000 0.55 20]), top)), ...
                sprintf('header 3d (REG): 5,000 ft / M 0.55 / CG 20 %% among the first 4 (%s)', strjoin({T(1:4).label}, '; ')));
        end
    end

    methods (Static)
        function AC = scaledAC(name, k, c)
            fac = vital.fq.f16Factory('AeroScale', struct(name, k));
            ac = fac(c);
            AC = ac.AC;
        end

        function P = evalAt(fields, theta, b, c)
            s = cell2struct(num2cell(theta(:)), fields(:), 1);
            fac = vital.fq.f16Factory('AeroScale', s, 'Controller', b);
            P = vital.fq.evaluatePoint(fac(c), c);
        end
    end
end
