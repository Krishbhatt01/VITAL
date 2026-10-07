classdef (TestTags = {'M6'}) tF16FqR2 < vital.test.VitalTestCase
%TF16FQR2  M6, review R2 fixes on the NESC F-16 (REG, INDEP) and the entry point.
%
%   Findings covered (reports/work/review2/REVIEW.md): B1, B2, M1, M2, M3, M5,
%   M6, M8, M9, MINOR 6, and the escaped mutations R2-10 and R2-14.
%   No published MIL-F-8785C Level exists for this model: every Level is REG.
%
%   PRE-REGISTERED expectations (written before the fixes were implemented):
%   1. B1. The single point 37,000 ft / Mach 0.5 / CG 30 % (review E3: real
%      longitudinal roots -0.892 and +0.2029 1/s, T2 = 3.42 s) gets a failing
%      longitudinal verdict: 3.2.2.2-CatA and -CatB worse than Level 3 (4), and
%      3.2.2.1.2-CatA worse than Level 3 (split short period with an unstable
%      root = DIVERGENT). lon_divergence_rate_1_s = 0.2029 within 1e-3 relative
%      (REG, from R2 E3). [FAILED in the first run after the fix: 0.2060, the
%      9-state root; see the test body for the corrected checks.] On the aft-CG grid h {13,000, 21,000} ft x Mach {0.37,
%      0.5} x CG {35, 40} % every trimmed point with a positive rate is Level 4 in
%      3.2.2.2-CatA, and at least one such point exists (R2 E4: 7 of 8).
%   2. B2. At 29,000 ft / Mach 0.30 / CG 20 % (review E2) the roll mode is the
%      fallback root -0.2187 1/s: tau_R_s = 4.572 s within 1e-3 relative, status
%      OK with a 'fallback' reason, and 3.3.1.2-CatB is Level 3 there.
%   3. M8 + B2 on the registered default grid (no refinement):
%      - 37,000 ft / Mach 0.5 points are EXTRAPOLATED; 8,000 ft / Mach 0.5 /
%        CG 25 % is IN (about 285 KEAS);
%      - 3.3.1.2-CatB: extrapolated worst Level 3 (the low-speed roll modes,
%        tau_R 1.6-4.6 s, R2 E2); its in-envelope headline is NOT Level 2 by
%        accident of exclusion: it is complete or unrated;
%      - 3.2.2.2-CatA: extrapolated worst Level 4 (point of item 1); in-envelope
%        worst Level 1 (moderate alpha near the README point: no divergence);
%      - 3.3.1.2-CatA in-envelope headline Level 1 (tau_R about 0.26-0.34 s near
%        the README point); 3.3.1.1-CatA-other in-envelope worst Level 2 (zeta_d
%        about 0.11-0.12 < 0.19).
%   4. M3 (INDEP). A nonlinear constant-speed pull-up on vital.plant.derivatives
%      at the README trim (alpha0 +/- 1e-4 rad; alphadot = qdot = 0 solved for
%      q and elevator; V, throttle, h fixed; theta = alpha; n = V q / g) gives
%      n/alpha within 1e-6 relative of the metric n_alpha_g_per_rad, and of R2's
%      independent value 14.765869 g/rad.
%   5. R2-10. f16Factory at 35,000 ft, Mach 0.6 gives V = 0.6 a_US76(h) exactly
%      and KEAS = V sqrt(rho/rho0) / kt. (Also registered: V about 177.4 m/s,
%      +/- 0.1, copied from review R2. FAILED in RED: V = 177.97 m/s; R2's number
%      is wrong. Corrected check: the US 1976 troposphere closed form.)
%   6. M5. AeroScale 'Cn_beta' is renamed 'Cnt_table' (the NESC static sideslip
%      yawing-moment table cnt about the MRC); the old name is vital:badInput.
%      Effective CG derivatives at the README trim (finite differences of the
%      plant's moment about the CG; REG values from R2 E5): Cnt_table x 0.2 ->
%      body N_beta x 0.335 +/- 0.01; Cm_q x 0.3 -> M_q x 0.556 +/- 0.01; Cl_p x
%      0.4 -> L_p x 0.400 +/- 0.005.
%   7. M6 (POST-HOC REG, from the first GREEN run of tFqMutations; labelled as
%      such, not predictions): at the README point Cm_q x 0.3 gives zeta_sp 0.3413
%      and 3.2.2.1.2-CatA Level 1 -> 2 at both mutation points; Cnt_table x 0.2
%      gives omega_nd 2.035 rad/s, zeta_d 0.1927 and 3.3.1.1-CatA-other Level
%      2 -> 1 at both points; CG 30 % gives CAP 0.2054 and n/alpha 15.37; Cl_p x
%      0.4 gives tau_R 0.8239 s (all 1e-3 relative).
%   8. M9. run_f16_fq names its files f16_fq_<grid>_<AeroScale tag> (tag
%      'baseline' or e.g. 'Cm_q0.3'); an existing file is never overwritten
%      unless 'Overwrite' is true (a timestamped name is used instead); a 'test'
%      grid run leaves a default-grid report untouched.
%   9. R2-14 / M8. The printout of the test grid shows the exclusion counts
%      ('trim:INFEASIBLE x') and the envelope tag 'EXTRAPOLATED'.
%  10. MINOR 6. At 20,000 ft (thrust-table altitude breakpoint), Mach 0.5, CG 25 %
%      the point is used: the 8-state metrics are OK and zeta_p is excluded
%      (status NOT_CONVERGED, its reason names the h column).
%  11. M1 / M2 at the README condition: 3.2.1.1-CatA and -CatB Level 1 with
%      levelsDefined [1 2 3] (no speed divergence); 3.2.2.2-CatA/B Level 1;
%      3.3.1.4-CatA-other Level 1; the point is IN the validity envelope.

    properties
        File
        R
        Dir
        Ft = 0.3048
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.File = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
            tc.R = vital.fq.loadRules();
            tc.Dir = tempname; mkdir(tc.Dir);
            tc.addTeardown(@() vital.test.removeTree(tc.Dir));
        end
    end

    methods (Access = private)
        function res = run1(tc, h, mach, cg, varargin)
            C = vital.fq.loadConditions(tc.File, 'Axes', struct('h_ft', h, 'mach', mach, 'cg_pct_mac', cg));
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(varargin{:}), C);
        end

        function g = grp(tc, res, name)
            g = res.groups(strcmp({res.groups.group}, name));
            tc.assertNumElements(g, 1, ['group ' name]);
        end

        function [ac, tr, lin] = readme(tc, scale)
            if nargin < 2, scale = struct(); end
            fac = vital.fq.f16Factory('AeroScale', scale);
            ac = fac(struct('h_ft', 10013, 'V_ftps', 565.6854, 'cg_pct_mac', 25, 'gamma_deg', 0, 'g_ftps2', 32.174));
            tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
            tc.assertEqual(tr.status, 'OK');
            if nargout > 2, lin = vital.linear.linearize(ac.AC, ac.env, tr); end
        end
    end

    methods (Static, Access = private)
        function k = at(res, h, mach, cg)
            k = find(arrayfun(@(p) abs(p.cond.h_ft - h) < 1e-9 && abs(p.cond.mach - mach) < 1e-12 && ...
                abs(p.cond.cg_pct_mac - cg) < 1e-12, res.points));
        end

        function d = cgDerivs(ac, tr)
            % body-axis moment derivatives about the CG from the nonlinear plant
            x0 = tr.x(:); u0 = tr.u(:);
            V = norm(x0(1:3)); a = tr.alpha;
            mom = @(beta, w) momentAt(ac, x0, u0, V, a, beta, w);
            e = 1e-4;
            dN = (mom(e, [0;0;0]) - mom(-e, [0;0;0])) / (2 * e);
            dMq = (mom(0, [0; e; 0]) - mom(0, [0; -e; 0])) / (2 * e);
            dLp = (mom(0, [e; 0; 0]) - mom(0, [-e; 0; 0])) / (2 * e);
            d = [dN(3), dMq(2), dLp(1)];
            function M = momentAt(ac, x0, u0, V, a, beta, w)
                x = x0;
                x(1:3) = V * [cos(a) * cos(beta); sin(beta); sin(a) * cos(beta)];
                x(4:6) = w;
                xd = vital.plant.derivatives(x, u0, ac.AC, ac.env);
                M = ac.AC.J * xd(4:6) + cross(w, ac.AC.J * w);
            end
        end

        function na = pullup(ac, tr)
            % nonlinear constant-speed steady pull-up (pre-registration 4)
            V = norm(tr.x(1:3)); a0 = tr.alpha; u0 = tr.u(:); h = -tr.x(13); g = ac.env.g;
            d = 1e-4; qs = zeros(1, 2);
            for s = 1:2
                a = a0 + (2 * s - 3) * d;
                z = [0; u0(1)];
                for it = 1:40
                    F = res(z, a);
                    J = zeros(2);
                    for j = 1:2
                        dz = zeros(2, 1); dz(j) = 1e-7;
                        J(:, j) = (res(z + dz, a) - res(z - dz, a)) / 2e-7;
                    end
                    z = z - J \ F;
                    if norm(F) < 1e-14, break; end
                end
                qs(s) = z(1);
            end
            na = V / g * (qs(2) - qs(1)) / (2 * d);
            function F = res(z, a)
                u = u0; u(1) = z(2);
                x = [V * [cos(a); 0; sin(a)]; 0; z(1); 0; vital.frames.eul2quat(0, a, 0); 0; 0; -h];
                xd = vital.plant.derivatives(x, u, ac.AC, ac.env);
                F = [(x(1) * xd(3) - x(3) * xd(1)) / (x(1)^2 + x(3)^2); xd(5)];
            end
        end

        function s = sha(f)
            s = vital.io.sha256File(f);
        end
    end

    methods (Test)
        function pitchDivergencePointFails(tc)
            res = tc.run1(37000, 0.5, 30);
            tc.assertEqual({res.points.status}, {'OK'});
            M = res.points(1).metrics;
            c = 'REG: pre-registration 1 (review R2 B1, E3)';
            tc.assertTrue(isfield(M, 'lon_divergence_rate_1_s'), 'lon_divergence_rate_1_s exists');
            % FAILED HYPOTHESIS (first run after the fix, 2026-10-05): rate 0.2029 +/- 1e-3
            % rel was R2's 8-state root, but the registered definition (tFqMetricsR2
            % pre-registration 1) also takes the 9-state roots (with height), whose
            % divergent root is 0.2060 (+1.5 %: the altitude coupling the nonlinear
            % plant has, tests/M5/tLinearVsNonlinear.m). Corrected checks: the rate
            % equals the largest real root of the longitudinal blocks recomputed here
            % with eig ([u w q theta] and [u w q theta h], decoupled at beta = 0), and
            % is not below R2's 8-state value.
            fac = vital.fq.f16Factory();
            ac = fac(res.points(1).cond);
            tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
            lin = vital.linear.linearize(ac.AC, ac.env, tr);
            lam = [eig(lin.A([1 3 5 8], [1 3 5 8])); eig(lin.A([1 3 5 8 12], [1 3 5 8 12]))];
            lam = real(lam(abs(imag(lam)) <= 1e-9 * abs(lam)));
            tc.verifyTol(M.lon_divergence_rate_1_s.value, max(lam), 1e-9, 'rel', 'ANALYTIC', ...
                'largest real longitudinal root, recomputed with eig (corrects the failed 0.2029 hypothesis)', 'Quantity', 'lon divergence rate', 'Unit', '1/s');
            tc.verifyWithin(M.lon_divergence_rate_1_s.value, 0.2029, 0.2029 * 1.03, 'REG', [c ': at least R2''s 8-state root'], ...
                'Quantity', 'lon divergence rate', 'Unit', '1/s');
            tc.verifyTol(M.T2_aperiodic_divergence_s.value, log(2) / max(lam), 1e-9, 'rel', 'ANALYTIC', 'T2 = ln2/rate', 'Quantity', 'T2 aperiodic', 'Unit', 's');
            tc.verifyExact(tc.grp(res, '3.2.2.2-CatA').worstLevel, 4, 'REG', c, 'Quantity', '3.2.2.2 Cat A Level');
            tc.verifyExact(tc.grp(res, '3.2.2.2-CatB').worstLevel, 4, 'REG', c, 'Quantity', '3.2.2.2 Cat B Level');
            tc.verifyExact(tc.grp(res, '3.2.2.1.2-CatA').worstLevel, 4, 'REG', c, 'Quantity', '3.2.2.1.2 Cat A Level');
            % aft-CG grid: every divergent point fails 3.2.2.2
            C = vital.fq.loadConditions(tc.File, 'Axes', struct('h_ft', [13000 21000], 'mach', [0.37 0.5], 'cg_pct_mac', [35 40]));
            r2 = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            g = tc.grp(r2, '3.2.2.2-CatA');
            nDiv = 0;
            for i = 1:numel(r2.points)
                p = r2.points(i);
                if strcmp(p.status, 'OK') && p.metrics.lon_divergence_rate_1_s.value > 0
                    nDiv = nDiv + 1;
                    tc.verifyEqual(g.levelAtPoint(i), 4, sprintf('divergent point %d fails 3.2.2.2', i));
                end
            end
            tc.verifyGreaterThanOrEqual(nDiv, 1, 'pre-registration 1: the aft-CG grid has a divergent point');
        end

        function lowSpeedRollModeRated(tc)
            res = tc.run1(29000, 0.3, 20);
            tc.assertEqual({res.points.status}, {'OK'});
            t = res.points(1).metrics.tau_R_s;
            c = 'REG: pre-registration 2 (review R2 B2, E2)';
            tc.verifyEqual(t.status, 'OK', 'fallback roll mode');
            tc.verifyTol(t.value, 1 / 0.2187, 1e-3, 'rel', 'REG', c, 'Quantity', 'tau_R', 'Unit', 's');
            tc.verifySubstring(t.reason, 'fallback');
            tc.verifyExact(tc.grp(res, '3.3.1.2-CatB').levelAtPoint(1), 3, 'REG', c, 'Quantity', '3.3.1.2 Cat B Level');
        end

        function defaultGridHeadlineAndExtrapolation(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'default');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            tc.assertTrue(isfield(res.points, 'envelope'), 'points carry an envelope tag');
            A = @tF16FqR2.at;
            c = 'REG: pre-registration 3 (review R2 M8, B2)';
            k37 = [A(res, 37000, 0.5, 20) A(res, 37000, 0.5, 25) A(res, 37000, 0.5, 30)];
            tc.assertNumElements(k37, 3, '37,000 ft / Mach 0.5 points in the default grid');
            tc.verifyEqual(unique({res.points(k37).envelope}), {'EXTRAPOLATED'}, c);
            k8 = A(res, 8000, 0.5, 25);
            tc.assertNumElements(k8, 1, '8,000 ft / Mach 0.5 / CG 25 in the default grid');
            tc.verifyEqual(res.points(k8).envelope, 'IN', c);
            gB = tc.grp(res, '3.3.1.2-CatB');
            tc.verifyExact(gB.extrapolated.worstLevel, 3, 'REG', c, 'Quantity', '3.3.1.2 Cat B extrapolated Level');
            tc.verifyTrue(gB.inEnvelope.complete || isnan(gB.inEnvelope.levelHeadline), 'headline complete or unrated');
            tc.verifyExact(tc.grp(res, '3.2.2.2-CatA').extrapolated.worstLevel, 4, 'REG', c, 'Quantity', '3.2.2.2 Cat A extrapolated');
            tc.verifyExact(tc.grp(res, '3.2.2.2-CatA').inEnvelope.worstLevel, 1, 'REG', c, 'Quantity', '3.2.2.2 Cat A in-envelope');
            tc.verifyExact(tc.grp(res, '3.3.1.2-CatA').inEnvelope.levelHeadline, 1, 'REG', c, 'Quantity', '3.3.1.2 Cat A in-envelope headline');
            tc.verifyExact(tc.grp(res, '3.3.1.1-CatA-other').inEnvelope.worstLevel, 2, 'REG', c, 'Quantity', '3.3.1.1 A-other in-envelope');
        end

        function nonlinearPullupNAlpha(tc)
            [ac, tr, lin] = tc.readme();
            m = vital.linear.modes(lin);
            M = vital.fq.metrics(lin, m);
            na = tF16FqR2.pullup(ac, tr);
            tc.verifyTol(M.n_alpha_g_per_rad.value, na, 1e-6, 'rel', 'INDEP', ...
                'pre-registration 4: nonlinear constant-speed pull-up on vital.plant.derivatives (MIL-F-8785C 6.2 p.77)', ...
                'Quantity', 'n/alpha metric vs nonlinear pull-up', 'Unit', 'g/rad');
            tc.verifyTol(na, 14.765869, 1e-6, 'rel', 'INDEP', 'review R2 E1, independent pull-up implementation', ...
                'Quantity', 'n/alpha pull-up vs R2', 'Unit', 'g/rad');
        end

        function factoryMachUsesLocalSpeedOfSound(tc)
            fac = vital.fq.f16Factory();
            ac = fac(struct('h_ft', 35000, 'mach', 0.6, 'cg_pct_mac', 25));
            atm = vital.env.atmosphereUS76(35000 * tc.Ft);
            c = 'ANALYTIC: pre-registration 5 (V = M a(h), US 1976)';
            tc.verifyExact(ac.trimCond.V, 0.6 * atm.a, 'ANALYTIC', c, 'Quantity', 'V at 35,000 ft, Mach 0.6');
            % FAILED HYPOTHESIS (RED run 2026-10-05): the registered "about 177.4 m/s"
            % was copied from review R2's text; 0.6 a(35,000 ft) is 177.97 m/s (US 1976:
            % T = 218.81 K). Replaced by an independent closed form of the US 1976
            % troposphere (T = 288.15 - 0.0065 H, H geopotential, a = sqrt(1.4 R T)).
            H = 6356766 * (35000 * tc.Ft) / (6356766 + 35000 * tc.Ft);
            aT = sqrt(1.4 * 8314.32 / 28.9644 * (288.15 - 0.0065 * H));
            tc.verifyTol(ac.trimCond.V, 0.6 * aT, 1e-12, 'rel', 'ANALYTIC', ...
                'US 1976 troposphere closed form (corrects the failed 177.4 m/s hypothesis)', 'Quantity', 'V', 'Unit', 'm/s');
            tc.assertTrue(isfield(ac, 'keas'), 'factory gives KEAS');
            atm0 = vital.env.atmosphereUS76(0);
            tc.verifyTol(ac.keas, 0.6 * atm.a * sqrt(atm.rho / atm0.rho) / (1852 / 3600), 1e-12, 'rel', 'ANALYTIC', c, ...
                'Quantity', 'KEAS', 'Unit', 'kt');
        end

        function aeroScaleEffectiveDerivatives(tc)
            tc.verifyError(@() vital.aircraft.f16.config('AeroScale', struct('Cn_beta', 0.2)), 'vital:badInput');
            [ac, tr] = tc.readme();
            d0 = tF16FqR2.cgDerivs(ac, tr);
            c = 'REG: pre-registration 6 (review R2 M5, E5)';
            cases = {'Cnt_table', 0.2, 1, 0.335, 0.01; 'Cm_q', 0.3, 2, 0.556, 0.01; 'Cl_p', 0.4, 3, 0.400, 0.005};
            for k = 1:size(cases, 1)
                AC = vital.aircraft.f16.config('CG_PCT_MAC', 25, 'AeroScale', struct(cases{k, 1}, cases{k, 2}));
                d = tF16FqR2.cgDerivs(struct('AC', AC, 'env', ac.env), tr);
                tc.verifyTol(d(cases{k, 3}) / d0(cases{k, 3}), cases{k, 4}, cases{k, 5}, 'abs', 'REG', c, ...
                    'Quantity', sprintf('effective CG derivative ratio, %s x %g', cases{k, 1}, cases{k, 2}));
            end
        end

        function mutationOutcomesPinned(tc)
            C0 = vital.fq.loadConditions(tc.File, 'Grid', 'mutation');
            b = vital.fq.assess(tc.R, vital.fq.f16Factory(), C0);
            c = 'REG POST-HOC: pre-registration 7 (values of the first GREEN run of tFqMutations, 2026-09-29)';
            V = @(res, n) res.points(1).metrics.(n).value;
            L = @(res, g, i) res.groups(strcmp({res.groups.group}, g)).levelAtPoint(i);
            m2 = vital.fq.assess(tc.R, vital.fq.f16Factory('AeroScale', struct('Cm_q', 0.3)), C0);
            tc.verifyTol(V(m2, 'zeta_sp'), 0.3413, 1e-3, 'rel', 'REG', c, 'Quantity', 'zeta_sp Cm_q x 0.3');
            m3 = vital.fq.assess(tc.R, vital.fq.f16Factory('AeroScale', struct('Cnt_table', 0.2)), C0);
            tc.verifyTol(V(m3, 'omega_nd_rad_s'), 2.035, 1e-3, 'rel', 'REG', c, 'Quantity', 'omega_nd Cnt x 0.2');
            tc.verifyTol(V(m3, 'zeta_d'), 0.1927, 1e-3, 'rel', 'REG', c, 'Quantity', 'zeta_d Cnt x 0.2');
            m4 = vital.fq.assess(tc.R, vital.fq.f16Factory('AeroScale', struct('Cl_p', 0.4)), C0);
            tc.verifyTol(V(m4, 'tau_R_s'), 0.8239, 1e-3, 'rel', 'REG', c, 'Quantity', 'tau_R Cl_p x 0.4');
            C1 = vital.fq.loadConditions(tc.File, 'Grid', 'mutation', 'Axes', struct('h_ft', 10013, 'V_ftps', [565.6854 700], 'cg_pct_mac', 30));
            m1 = vital.fq.assess(tc.R, vital.fq.f16Factory(), C1);
            tc.verifyTol(V(m1, 'CAP'), 0.2054, 1e-3, 'rel', 'REG', c, 'Quantity', 'CAP CG 30');
            tc.verifyTol(V(m1, 'n_alpha_g_per_rad'), 15.37, 1e-3, 'rel', 'REG', c, 'Quantity', 'n/alpha CG 30');
            for i = 1:2
                tc.verifyExact([L(b, '3.2.2.1.2-CatA', i) L(m2, '3.2.2.1.2-CatA', i)], [1 2], 'REG', c, 'Quantity', sprintf('3.2.2.1.2-CatA Levels, Cm_q, point %d', i));
                tc.verifyExact([L(b, '3.3.1.1-CatA-other', i) L(m3, '3.3.1.1-CatA-other', i)], [2 1], 'REG', c, 'Quantity', sprintf('3.3.1.1-CatA-other Levels, Cnt, point %d', i));
            end
        end

        function reportNamingNeverOverwritesDefault(tc)
            sentinel = fullfile(tc.Dir, 'f16_fq_default_baseline.json');
            fid = fopen(sentinel, 'w'); fprintf(fid, 'sentinel'); fclose(fid);
            h0 = tF16FqR2.sha(sentinel);
            r1 = run_f16_fq('Grid', 'test', 'ReportDir', tc.Dir, 'Refine', false, 'Quiet', true);
            c = 'ANALYTIC: pre-registration 8 (review R2 M9)';
            tc.verifyEqual(r1.files.json, fullfile(tc.Dir, 'f16_fq_test_baseline.json'), c);
            tc.verifyEqual(tF16FqR2.sha(sentinel), h0, 'the default-grid report is untouched');
            h1 = tF16FqR2.sha(r1.files.json);
            r2 = run_f16_fq('Grid', 'test', 'ReportDir', tc.Dir, 'Refine', false, 'Quiet', true);
            tc.verifyNotEqual(r2.files.json, r1.files.json, 'a second run never overwrites');
            tc.verifyEqual(tF16FqR2.sha(r1.files.json), h1, 'the first report is unchanged');
            r3 = run_f16_fq('Grid', 'test', 'ReportDir', tc.Dir, 'Refine', false, 'Quiet', true, 'Overwrite', true);
            tc.verifyEqual(r3.files.json, r1.files.json, 'Overwrite true reuses the name');
            r4 = run_f16_fq('Grid', 'readme', 'ReportDir', tc.Dir, 'Refine', false, 'Quiet', true, 'AeroScale', struct('Cm_q', 0.3));
            tc.verifyEqual(r4.files.md, fullfile(tc.Dir, 'f16_fq_readme_Cm_q0.3.md'), c);
        end

        function printoutShowsExclusionsAndEnvelope(tc)
            txt = evalc('run_f16_fq(''Grid'', ''test'', ''ReportDir'', tc.Dir, ''Refine'', false);');
            tc.verifySubstring(txt, 'trim:INFEASIBLE x', 'pre-registration 9 (R2-14)');
            tc.verifySubstring(txt, 'EXTRAPOLATED', 'pre-registration 9 (M8)');
        end

        function breakpointAltitudeKeepsEightStateMetrics(tc)
            res = tc.run1(20000, 0.5, 25);
            p = res.points(1);
            tc.verifyEqual(p.status, 'OK', 'pre-registration 10: the point is used');
            tc.assertTrue(isfield(p.metrics, 'zeta_sp'), 'metrics computed');
            tc.verifyEqual(p.metrics.zeta_sp.status, 'OK');
            tc.verifyEqual(p.metrics.zeta_p.status, 'NOT_CONVERGED');
            tc.verifySubstring(p.metrics.zeta_p.reason, 'h');
        end

        function readmeRevisedRecords(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'readme');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            c = 'REG: pre-registration 11 (review R2 M1, M2, B1)';
            for gname = {'3.2.1.1-CatA', '3.2.1.1-CatB', '3.2.2.2-CatA', '3.2.2.2-CatB', '3.3.1.4-CatA-other'}
                tc.verifyExact(tc.grp(res, gname{1}).worstLevel, 1, 'REG', c, 'Quantity', ['Level ' gname{1}]);
            end
            tc.verifyExact(tc.grp(res, '3.2.1.1-CatA').levelsDefined, [1 2 3], 'REG', c, 'Quantity', '3.2.1.1 Levels defined');
            tc.assertTrue(isfield(res.points, 'envelope'));
            tc.verifyEqual(res.points(1).envelope, 'IN', c);
        end
    end
end
