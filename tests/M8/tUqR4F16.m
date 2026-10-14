classdef (TestTags = {'M8'}) tUqR4F16 < vital.test.VitalTestCase
%TUQR4F16  M8 amendment R4 on the NESC F-16 (docs/PLAN_M5_M8.md, "Amendment R4:
%   judgment-light robustness", coordinator 2026-10-13): the split of the
%   pitching-moment table (R4-5), the rename Cnr_table -> Cn_r (R4-6), the
%   extended lon/lat invariance gate, the effective CG-derivative ratios of the
%   new fields, and one small end-to-end CSR run through run_f16_uq (R4-1,
%   R4-2, R4-3) with its report.
%   Budgets (stated before any run): invariance 30 closed-loop evaluatePoint
%   calls; ratios on the bare trim; the end-to-end run uses a 1-parameter
%   spec (Cm_de only), the group 3.2.2.1.1-CatA's records only, ONE condition
%   (13,000 ft / M 0.45 / CG 30 %, IN, the CAP critical condition of
%   tests/M8/tF16Uq.m), NumCandidates 1, NumLHS 4, N 10 (about 150-300
%   single-point evaluations). Expected runtime about 2-3 min. Expected values
%   pinned here, never read from reports/.
%
%   PRE-REGISTERED (agent uq3, 2026-10-13, with the stubs, before any
%   implementation):
%   1. R4-5 SPLIT OF cmt (ANALYTIC, 1e-15 abs on the coefficient, the other five
%      coefficients isequal; general state alpha 7 deg, beta 3 deg, p q r
%      non-zero, el -2.5 deg): cmt0 = cmt(alpha, el = 0) from the generated
%      model itself (vital.models.f16.aero with el = 0), dcmt = cmt - cmt0.
%        Cm_basic s = 0.87: dCm = (s - 1) cmt0
%        Cm_de    s = 1.13: dCm = (s - 1) dcmt
%        Cm_basic 0.9, Cm_de 1.1, Cm_q 0.8, Cm_table 1.05 together:
%          cm = 1.05 (0.9 cmt0 + 1.1 dcmt) + cq2v (0.8 cmq)
%      Legacy: Cm_table 1.1 alone (Cm_basic = Cm_de = 1) gives loads isequal to
%      cm = 1.1 cmt + cq2v cmq computed the R3 way (the split block is skipped).
%   2. DEFAULT PATH BIT-IDENTICAL (guard, as ADR ctrl-4): config().aeroScale has
%      exactly the fields Cm_q, Cl_p, Cnt_table, Cm_table, Cl_table, Cn_r,
%      Cm_basic, Cm_de, all 1; config with all of them 1 is isequal to
%      config(); loads isequal to a configuration without the aeroScale field.
%      R4-6: 'Cn_r' is accepted and scales cnr (dCn = (s - 1) b2v cnr r,
%      1e-15); 'Cnr_table' is now unknown (vital:badInput).
%   3. LON/LAT INVARIANCE, EXTENDED (the R3-M3(a) gate with the R4-5 fields;
%      ANALYTIC symmetry argument as tests/M8/tUqR3F16.m header 1): augmented
%      aircraft at 13,000/0.45/30, 5,000/0.55/20, 8,000/0.50/25; lon
%      (Cm_q, Cm_basic, Cm_de) at 1 and at the lower corner of the x1.5 box;
%      lateral (Cl_p, Cn_r, Cl_table, Cnt_table) at 1 and at four corners of
%      the CSR cap box of the judged shape (3 x k_g sigma: all lower, all upper,
%      lo/hi/lo/hi, hi/lo/hi/lo). Every longitudinal metric (the ten of
%      tUqR3F16) has the same status and a value within 1e-9 relative. Guards:
%      every point OK; zeta_d moves by more than 1e-3 relative at the
%      all-lower lateral corner; the lon corner changes Cm by more than 1e-4
%      at the general state of item 1 (the lon multipliers act).
%   4. EFFECTIVE CG-DERIVATIVE RATIOS OF Cm_basic AND Cm_de (bare trim
%      13,000 ft / M 0.45 / CG 30 %, x1 box edges k = 1 -/+ k2 0.05,
%      k2 = sqrt(chi2inv(0.99, 2)); finite differences step 1e-4 as tUqR3F16):
%      a) ANALYTIC: affine: the ratios at the two edges sum to 2 (M_alpha and
%         M_de, each field, 1e-8 abs).
%      b) ANALYTIC: Cm_basic leaves M_de,cg unchanged (ratio 1, 1e-9 abs:
%         cmt(alpha, 0) does not depend on the elevator); both leave L_beta,
%         N_beta, N_r unchanged (1e-12 abs).
%      c) ANALYTIC (independent decomposition through the aero table): with
%         A0 = qbar S cbar d cmt(alpha, 0)/d alpha and A = qbar S cbar
%         d cmt(alpha, el_trim)/d alpha (central differences on
%         vital.models.f16.aero at the trim), Cm_basic k gives
%         M_alpha,cg ratio 1 + (k - 1) A0/d0 and Cm_de k gives
%         1 + (k - 1)(A - A0)/d0 (1e-8 abs); Cm_de k gives M_de,cg ratio
%         (k Ade + Bde)/(Ade + Bde) with Ade the MRC part (plant at CG 35 %),
%         Bde the transfer part (1e-8 abs).
%      d) REG predictions: Cm_de at the lower edge kL = 0.8483: M_de,cg ratio in
%         [kL, kL + 0.03]; its M_alpha,cg ratio within 0.05 of 1; Cm_basic at
%         kL: M_alpha,cg ratio in [1, 1.1] (the MRC static slope is
%         destabilizing here: tUqR3F16 failed hypothesis 2e).
%   5. END-TO-END CSR (run_f16_uq with the budget above; plan defaults
%      otherwise; R4-1/R4-2/R4-3):
%      a) default widths: r.widthScales = 1 (no x0.5 / x1.5); one width.
%      b) shapes: csr.judged.m = the x1 half-width of Cm_de (k2 0.05, exact,
%         from vital.uq.box); csr.equal.m = 0.10 (exact); AlphaMax 3,
%         resolution 0.01.
%      c) REG: the 1-parameter group is searched on the grid (plan.method
%         'grid', x1 bw.label 'grid-certified (Lipschitz estimate)'); the x1
%         status is 'OK' or 'VIOLATED' (decided); both CSR statuses are 'OK' or
%         'ROBUST_TO_CAP'.
%      d) nesting (ANALYTIC): x1 'OK' => judged alphaLo >= 1; x1 'VIOLATED' =>
%         judged alphaHi <= 1.
%      e) independent re-check (a fresh vital.fq.assess by THIS test): for an
%         'OK' CSR the margin at the CPV equals (isequaln) csr.confirmation.margin
%         and is < 0, alphaHi - alphaStar <= 0.01 (+1e-12), psm = alphaStar m;
%         for every CSR the two end points of R(alphaStar) have margin >= 0.
%      f) 1-D shapes (ANALYTIC): both shapes are the same family of intervals
%         in one parameter, so the tolerated deviations agree: the intervals
%         [alphaLo m, alphaHi m] of the two shapes intersect.
%      g) R4 verdict = the truth table of tests/M8/tUqCsr.m header 10 applied
%         to (csr.judged, mc) (recomputed here from the fields).
%      h) report: the Markdown contains 'Critical Similitude Ratio',
%         'parametric safety margin', 'equal percentage', 'JUDGMENT',
%         'grid-certified (Lipschitz estimate)', the group and its R4 verdict;
%         the JSON decodes and has groups(1).csr.judged.status.
%
%   SUPERSEDED BY R4b (agent uq4, 2026-10-14; docs/PLAN_M5_M8.md "Amendment
%   R4b", R4-3 corrected): the longitudinal search, whatever its dimension
%   (<= 3), now uses the shared adaptive lattice, so the 1-parameter group of
%   item 5 has plan.method 'lattice', not 'grid'. The part "plan.method
%   'grid'" of 5c is SUPERSEDED (text above kept); its replacement is
%   tests/M8/tUqR4bF16.m header 3d (plan.method 'lattice'). Everything else in
%   item 5 is unchanged (the lattice keeps the label 'grid-certified
%   (Lipschitz estimate)').

    properties
        R
        C
    end

    properties (Constant)
        LON = {'zeta_sp', 'omega_nsp_rad_s', 'n_alpha_g_per_rad', 'CAP', 'zeta_p', 'T2_phugoid_s', ...
            'T2_speed_divergence_s', 'speed_divergence_rate_1_s', 'lon_divergence_rate_1_s', 'T2_aperiodic_divergence_s'}
        CONDS = [13000 0.45 30; 5000 0.55 20; 8000 0.50 25]
        FIELDS = {'Cm_q', 'Cl_p', 'Cnt_table', 'Cm_table', 'Cl_table', 'Cn_r', 'Cm_basic', 'Cm_de'}
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

        function C1 = oneCondition(tc, v)
            c = tc.cond(v);
            C1 = tc.C;
            for a = 1:numel(C1.axes)
                C1.axes(a).values = c.(C1.axes(a).name);
            end
        end
    end

    methods (Static)
        function [ad, u, h, atm, a, a0] = generalState()
            V = 180; al = deg2rad(7); be = deg2rad(3);
            v = V * [cos(al) * cos(be); sin(be); sin(al) * cos(be)];
            w = [0.4; -0.15; 0.25];
            h = 3000;
            atm = vital.env.atmosphereUS76(h);
            AC = vital.aircraft.f16.config();
            ad = vital.airdata.airData(v, w, eye(3), [0; 0; 0], atm, struct('b', AC.b, 'cbar', AC.cbar));
            u = [deg2rad(-2.5); deg2rad(4); deg2rad(-6); 0.4];
            k = vital.units.constants();
            in = struct('vt', ad.V / k.ft, 'alpha', rad2deg(ad.alpha), 'beta', rad2deg(ad.beta), ...
                'p', ad.w_air(1), 'q', ad.w_air(2), 'r', ad.w_air(3), 'el', rad2deg(u(1)), 'ail', rad2deg(u(2)), 'rdr', rad2deg(u(3)));
            a = vital.models.f16.aero(in);
            in.el = 0;
            a0 = vital.models.f16.aero(in);
        end

        function d = cgDerivs(AC, env, tr)
            x0 = tr.x(:); u0 = tr.u(:);
            V = norm(x0(1:3)); a = tr.alpha;
            e = 1e-4;
            M = @(al, be, w, de) tUqR4F16.momentAt(AC, env, x0, u0, V, al, be, w, de);
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

        function P = evalAt(fields, theta, b, c)
            s = cell2struct(num2cell(theta(:)), fields(:), 1);
            fac = vital.fq.f16Factory('AeroScale', s, 'Controller', b);
            P = vital.fq.evaluatePoint(fac(c), c);
        end

        function AC = scaledAC(name, k, c)
            fac = vital.fq.f16Factory('AeroScale', struct(name, k));
            ac = fac(c);
            AC = ac.AC;
        end

        function v = r4verdict(cs, cp)
            if cp < 0.95 || (cs.cpvConfirmed && cs.alphaHi <= 1)
                v = 'NOT_ROBUST';
            elseif (strcmp(cs.status, 'OK') && cs.alphaStar >= 1) || strcmp(cs.status, 'ROBUST_TO_CAP')
                v = 'ROBUST';
            else
                v = 'NOT_ASSESSABLE';
            end
        end
    end

    methods (Test)
        function splitPitchingMomentTable(tc)
            [ad, u, h, atm, a, a0] = tUqR4F16.generalState();
            tc.assertGreaterThan(abs(a.cmt - a0.cmt), 1e-4, 'the state has an elevator increment');
            [~, ~, I] = vital.aircraft.f16.loads(ad, u, h, atm, vital.aircraft.f16.config());
            cmt0 = a0.cmt; dcmt = a.cmt - a0.cmt;
            cases = {struct('Cm_basic', 0.87), a.cm + (0.87 - 1) * cmt0; ...
                     struct('Cm_de', 1.13), a.cm + (1.13 - 1) * dcmt; ...
                     struct('Cm_basic', 0.9, 'Cm_de', 1.1, 'Cm_q', 0.8, 'Cm_table', 1.05), ...
                     1.05 * (0.9 * cmt0 + 1.1 * dcmt) + a.cq2v * (0.8 * a.cmq)};
            for j = 1:size(cases, 1)
                AC = vital.aircraft.f16.config('AeroScale', cases{j, 1});
                [~, ~, Is] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
                tc.verifyTol(Is.coeff(5), cases{j, 2}, 1e-15, 'abs', 'ANALYTIC', sprintf('header 1 case %d', j), ...
                    'Quantity', sprintf('Cm, case %d', j));
                tc.verifyExact(Is.coeff([1:4 6]), I.coeff([1:4 6]), 'ANALYTIC', 'header 1: other coefficients unchanged', ...
                    'Quantity', sprintf('other coefficients, case %d', j));
            end
            AC = vital.aircraft.f16.config('AeroScale', struct('Cm_table', 1.1));
            [~, ~, Is] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
            tc.verifyExact(Is.coeff(5), 1.1 * a.cmt + a.cq2v * (1 * a.cmq), 'ANALYTIC', 'header 1: legacy Cm_table path', ...
                'Quantity', 'Cm, Cm_table 1.1');
        end

        function defaultPathAndRename(tc)
            AC = vital.aircraft.f16.config();
            tc.verifyEqual(sort(fieldnames(AC.aeroScale)), sort(tc.FIELDS(:)), 'header 2: AeroScale fields');
            tc.verifyTrue(all(structfun(@(v) v == 1, AC.aeroScale)), 'header 2: all 1');
            ones8 = cell2struct(num2cell(ones(numel(tc.FIELDS), 1)), tc.FIELDS(:), 1);
            tc.verifyExact(vital.aircraft.f16.config('AeroScale', ones8), AC, 'ANALYTIC', 'header 2', 'Quantity', 'AC');
            [ad, u, h, atm, a] = tUqR4F16.generalState();
            [F, M, I] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
            [F0, M0, I0] = vital.aircraft.f16.loads(ad, u, h, atm, rmfield(AC, 'aeroScale'));
            tc.verifyExact({F, M, I.coeff}, {F0, M0, I0.coeff}, 'ANALYTIC', 'header 2', 'Quantity', 'loads vs no aeroScale');
            ACr = vital.aircraft.f16.config('AeroScale', struct('Cn_r', 0.7));
            [~, ~, Ir] = vital.aircraft.f16.loads(ad, u, h, atm, ACr);
            tc.verifyTol(Ir.coeff(6) - I.coeff(6), (0.7 - 1) * a.b2v * a.cnr * a.r, 1e-15, 'abs', 'ANALYTIC', ...
                'header 2: Cn_r scales cnr', 'Quantity', 'dCn (Cn_r 0.7)');
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cnr_table', 0.7)), 'vital:badInput');
        end

        function lonLatInvarianceR4(tc)
            spec = vital.uq.loadSpec();
            B15 = vital.uq.box(spec, 'WidthScale', 1.5);
            f = B15.aeroScale;
            iLon = find(ismember(f, {'Cm_q', 'Cm_basic', 'Cm_de'}));
            iLat = find(ismember(f, {'Cl_p', 'Cn_r', 'Cl_table', 'Cnt_table'}));
            tc.assertNumElements(iLon, 3); tc.assertNumElements(iLat, 4);
            hcap = 3 * B15.kg(iLat) .* B15.sigma(iLat);
            lo = 1 - hcap; hi = 1 + hcap;
            latC = [lo; hi; lo(1) hi(2) lo(3) hi(4); hi(1) lo(2) hi(3) lo(4)];
            lonS = [1 1 1; B15.lo(iLon)];
            % guard: the longitudinal multipliers act (Cm changes at a general state)
            [ad, u, h, atm] = tUqR4F16.generalState();
            [~, ~, I0] = vital.aircraft.f16.loads(ad, u, h, atm, vital.aircraft.f16.config());
            sL = cell2struct(num2cell(lonS(2, :).'), f(iLon).', 1);
            [~, ~, I1] = vital.aircraft.f16.loads(ad, u, h, atm, vital.aircraft.f16.config('AeroScale', sL));
            tc.verifyGreaterThan(abs(I1.coeff(5) - I0.coeff(5)), 1e-4, 'guard: the lon corner changes Cm');
            b = vital.uq.augmentedBuilder();
            worst = 0;
            for ic = 1:size(tc.CONDS, 1)
                c = tc.cond(tc.CONDS(ic, :));
                for il = 1:2
                    th = ones(1, numel(f)); th(iLon) = lonS(il, :);
                    P0 = tUqR4F16.evalAt(f, th, b, c);
                    tc.assertEqual(P0.status, 'OK', sprintf('guard: point OK (%s)', P0.reason));
                    for k = 1:size(latC, 1)
                        t = th; t(iLat) = latC(k, :);
                        P1 = tUqR4F16.evalAt(f, t, b, c);
                        tc.assertEqual(P1.status, 'OK', sprintf('guard: point OK (%s)', P1.reason));
                        where = sprintf('%s theta %s', mat2str(tc.CONDS(ic, :)), mat2str(t, 5));
                        for n = tc.LON
                            m0 = P0.metrics.(n{1}); m1 = P1.metrics.(n{1});
                            tc.verifyEqual(m1.status, m0.status, ['header 3: status of ' n{1} ' at ' where]);
                            tc.verifyTrue(tUqR4F16.sameValue(m1.value, m0.value), sprintf( ...
                                'header 3: %s = %.17g vs %.17g at %s', n{1}, m1.value, m0.value, where));
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
            tc.log(1, sprintf('R4 lon/lat invariance: largest relative deviation %.3g', worst));
            tc.verifyTol(worst, 0, 1e-9, 'abs', 'ANALYTIC', 'header 3: largest relative deviation', ...
                'Quantity', 'lon/lat invariance R4 (relative)');
        end

        function effectiveDerivativeRatiosR4(tc)
            c = tc.cond([13000 0.45 30]);
            fac0 = vital.fq.f16Factory();
            ac = fac0(c);
            tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
            tc.assertEqual(tr.status, 'OK');
            d0 = tUqR4F16.cgDerivs(ac.AC, ac.env, tr);
            k2 = sqrt(chi2inv(0.99, 2));
            kL = 1 - k2 * 0.05; kH = 1 + k2 * 0.05;
            r = @(name, k) tUqR4F16.cgDerivs(tUqR4F16.scaledAC(name, k, c), ac.env, tr) ./ d0;
            bL = r('Cm_basic', kL); bH = r('Cm_basic', kH);
            eL = r('Cm_de', kL); eH = r('Cm_de', kH);
            tc.log(1, sprintf(['Cm_basic %.6f: M_alpha x %.6f, M_de x %.9f; Cm_de %.6f: M_alpha x %.6f, M_de x %.6f; ' ...
                'Cm_basic %.6f: M_alpha x %.6f; Cm_de %.6f: M_alpha x %.6f, M_de x %.6f'], kL, bL(1), bL(2), kL, eL(1), ...
                eL(2), kH, bH(1), kH, eH(1), eH(2)));
            tc.verifyTol([bL(1:2) + bH(1:2), eL(1:2) + eH(1:2)], [2 2 2 2], 1e-8, 'abs', 'ANALYTIC', 'header 4a: affine', ...
                'Quantity', 'ratio sums (Cm_basic, Cm_de)');
            tc.verifyTol([bL(2) bH(2)], [1 1], 1e-9, 'abs', 'ANALYTIC', 'header 4b: Cm_basic leaves M_de', ...
                'Quantity', 'M_de ratio (Cm_basic)');
            tc.verifyTol([bL(3:5) eL(3:5)], ones(1, 6), 1e-12, 'abs', 'ANALYTIC', 'header 4b: lateral unchanged', ...
                'Quantity', 'L_beta, N_beta, N_r ratios (Cm_basic, Cm_de)');
            % header 4c: decomposition through the aero table at the trim
            k = vital.units.constants();
            AC = ac.AC;
            V = norm(tr.x(1:3)); e = 1e-4;
            atm = vital.env.atmosphereUS76(ac.trimCond.h);
            qbar = 0.5 * atm.rho * V^2;
            cm = @(al, el) vital.models.f16.aero(struct('vt', V / k.ft, 'alpha', rad2deg(al), 'beta', 0, 'p', 0, 'q', 0, ...
                'r', 0, 'el', el, 'ail', 0, 'rdr', 0)).cmt;
            elT = rad2deg(tr.u(1));
            A0 = qbar * AC.S * AC.cbar * (cm(tr.alpha + e, 0) - cm(tr.alpha - e, 0)) / (2 * e);
            A = qbar * AC.S * AC.cbar * (cm(tr.alpha + e, elT) - cm(tr.alpha - e, elT)) / (2 * e);
            tc.verifyTol(bL(1), 1 + (kL - 1) * A0 / d0(1), 1e-8, 'abs', 'ANALYTIC', 'header 4c: Cm_basic M_alpha', ...
                'Quantity', 'M_alpha ratio (Cm_basic, lower edge)');
            tc.verifyTol(eL(1), 1 + (kL - 1) * (A - A0) / d0(1), 1e-8, 'abs', 'ANALYTIC', 'header 4c: Cm_de M_alpha', ...
                'Quantity', 'M_alpha ratio (Cm_de, lower edge)');
            AC35 = vital.aircraft.f16.config('CG_PCT_MAC', 35);
            tc.assertEqual(AC35.r_cg, zeros(3, 1), 'guard: CG 35 % MAC is the MRC');
            dm = tUqR4F16.cgDerivs(AC35, ac.env, tr);
            Ade = dm(2); Bde = d0(2) - Ade;
            tc.verifyTol([eL(2) eH(2)], [(kL * Ade + Bde) (kH * Ade + Bde)] / d0(2), 1e-8, 'abs', 'ANALYTIC', ...
                'header 4c: Cm_de M_de = (k A + B)/(A + B)', 'Quantity', 'M_de ratio (Cm_de)');
            % header 4d: REG predictions
            tc.verifyWithin(eL(2), kL, kL + 0.03, 'REG', 'header 4d (prediction)', 'Quantity', 'M_de,cg ratio (Cm_de lower edge)');
            tc.verifyWithin(eL(1), 0.95, 1.05, 'REG', 'header 4d (prediction)', 'Quantity', 'M_alpha,cg ratio (Cm_de lower edge)');
            tc.verifyWithin(bL(1), 1, 1.1, 'REG', 'header 4d (prediction)', 'Quantity', 'M_alpha,cg ratio (Cm_basic lower edge)');
        end

        function endToEndCsr(tc)
            spec = vital.uq.loadSpec();
            spec.parameters = spec.parameters(strcmp({spec.parameters.aeroScale}, 'Cm_de'));
            tc.assertNumElements(spec.parameters, 1);
            B = vital.uq.box(spec);
            g0 = '3.2.2.1.1-CatA';
            R = tc.R(strcmp({tc.R.group}, g0));
            C1 = tc.oneCondition([13000 0.45 30]);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            r = run_f16_uq('Groups', {g0}, 'Spec', spec, 'Rules', R, 'Conditions', C1, 'NumCandidates', 1, ...
                'NumLHS', 4, 'N', 10, 'Label', 'r4test', 'ReportDir', d, 'Quiet', true);
            % a) default widths
            tc.verifyEqual(r.widthScales, 1, 'header 5a');
            g = r.groups(1);
            tc.assertEqual(g.status, 'DONE', g.reason);
            tc.verifyNumElements(g.widths, 1);
            % b) shapes
            cj = g.csr.judged; ce = g.csr.equal;
            tc.verifyEqual(cj.m, B.halfWidth, 'header 5b: judged shape = x1 half-width');
            tc.verifyEqual(ce.m, 0.10, 'header 5b: equal percentage 10 %');
            tc.verifyEqual([cj.alphaMax ce.alphaMax cj.resolution], [3 3 0.01]);
            % c) grid, decided
            % header 5c "plan.method 'grid'": SUPERSEDED BY R4b (see the header; tUqR4bF16 header 3d)
            bw = g.widths(1).bw;
            tc.verifyEqual(bw.label, 'grid-certified (Lipschitz estimate)', 'header 5c');
            tc.verifyTrue(any(strcmp(bw.status, {'OK', 'VIOLATED'})), ['header 5c (REG): ' bw.reason]);
            tc.verifyTrue(any(strcmp(cj.status, {'OK', 'ROBUST_TO_CAP'})), ['header 5c (REG) judged: ' cj.reason]);
            tc.verifyTrue(any(strcmp(ce.status, {'OK', 'ROBUST_TO_CAP'})), ['header 5c (REG) equal: ' ce.reason]);
            % d) nesting
            if strcmp(bw.status, 'OK'), tc.verifyGreaterThanOrEqual(cj.alphaLo, 1, 'header 5d'); end
            if strcmp(bw.status, 'VIOLATED'), tc.verifyLessThanOrEqual(cj.alphaHi, 1, 'header 5d'); end
            % e) independent re-check
            b = vital.uq.augmentedBuilder();
            mAt = @(t) vital.uq.F16Evaluator.levelMargin(vital.fq.assess(R, ...
                vital.fq.f16Factory('AeroScale', struct('Cm_de', t), 'Controller', b), C1), g0, g.level0);
            for cs = {cj, ce}
                x = cs{1};
                if strcmp(x.status, 'OK')
                    mc = mAt(x.cpv);
                    tc.verifyTrue(isequaln(mc, x.confirmation.margin), sprintf('header 5e: %g vs %g', mc, x.confirmation.margin));
                    tc.verifyLessThan(mc, 0, 'header 5e: the CPV fails');
                    tc.verifyLessThanOrEqual(x.alphaHi - x.alphaStar, 0.01 + 1e-12, 'header 5e: bracket');
                    tc.verifyEqual(x.psm, x.alphaStar * x.m, 'header 5e: psm');
                end
                for t = [1 - x.alphaStar * x.m, 1 + x.alphaStar * x.m]
                    tc.verifyGreaterThanOrEqual(mAt(t), 0, sprintf('header 5e: end point %.6g of R(alphaStar) clean', t));
                end
            end
            % f) 1-D shapes agree
            tc.verifyLessThanOrEqual(max(cj.alphaLo * cj.m, ce.alphaLo * ce.m), min(cj.alphaHi * cj.m, ce.alphaHi * ce.m), ...
                'header 5f: the tolerated deviations of the two shapes intersect');
            % g) R4 verdict
            tc.verifyEqual(g.verdict.verdict, tUqR4F16.r4verdict(cj, g.widths(1).mc.cpLower), 'header 5g');
            % h) report
            md = fileread(r.files.md);
            for s = {'Critical Similitude Ratio', 'parametric safety margin', 'equal percentage', 'JUDGMENT', ...
                    'grid-certified (Lipschitz estimate)', g0, g.verdict.verdict}
                tc.verifySubstring(md, s{1}, 'header 5h');
            end
            J = jsondecode(fileread(r.files.json));
            tc.verifyEqual(J.groups(1).csr.judged.status, cj.status, 'header 5h: JSON');
        end
    end
end
