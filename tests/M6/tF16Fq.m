classdef (TestTags = {'M6'}) tF16Fq < vital.test.VitalTestCase
%TF16FQ  M6: MIL-F-8785C Class IV assessment of the bare-airframe NESC F-16 and
%   the user entry point run_f16_fq.
%
%   There is NO published MIL-F-8785C Level for the NESC F-16 model. Every F-16
%   Level here is REG (regression / pre-registered), never PUB.
%
%   PRE-REGISTERED expectations (before any F-16 assessment was run). Basis: the
%   M5-A REG mode table at the NESC README condition (565.6854 ft/s, 10,013 ft,
%   CG 25 % MAC; reports/fragments/linear/CHANGELOG.md): SP wn 2.503 rad/s,
%   zeta 0.452; phugoid zeta 0.095; DR wn 3.318 rad/s, zeta 0.117; roll tau
%   0.338 s; spiral lambda -0.0101 1/s (stable); alpha-only n_alpha 14.90 g/rad.
%   1. Levels at the README condition (grid 'readme'):
%        3.2.2.1.2-CatA  1  (0.452 in [0.35, 1.30])
%        3.2.2.1.2-CatB  1  (0.452 in [0.30, 2.00])
%        3.2.2.1.1-CatA  1  (CAP >= 2.503^2/14.90 = 0.42 and <= 3.6 since n/alpha
%                            > 1.74; omega 2.5 >= 1.0)
%        3.2.2.1.1-CatB  1  (CAP in [0.085, 3.6])
%        3.2.1.2-CatA/B  1  (zeta_p 0.095 >= 0.04)
%        3.3.1.1-CatA-COGA  2 and 3.3.1.1-CatA-other  2: zeta_d 0.117 is below the
%                            Level 1 minima 0.4 and 0.19 but above the Level 2
%                            0.02; zeta_d omega_nd = 0.388 exceeds 0.05 plus the
%                            largest plausible increment (0.009 x 13 for
%                            omega_nd^2|phi/beta|_d up to 33); omega 3.3 > 0.4
%        3.3.1.2-CatA/B  1  (tau_R 0.338 <= 1.0)
%        3.3.1.3-CatA/B  1  (stable spiral: T2 = Inf > 12 and 20 s)
%        3.3.1.4-CatA-COGA  1 (roll and spiral are separate real roots: no
%                            coupled roll-spiral mode)
%        3.3.1.4-CatB    NOT_APPLICABLE (no coupled roll-spiral mode)
%        3.2.1.1-CatA/B  worst Level 3 with levelsDefined = 3 only (no aperiodic
%                            speed divergence; Levels 1-2 are stick-force based
%                            and not assessed)
%        3.3.1.1-CatB    not registered (depends on |phi/beta|_d through the
%                            Table VI increment)
%   2. Category C: every Category C group and record is NOT_ASSESSABLE, with the
%      policy reason (no landing configuration in the NESC model), even though
%      the points trim.
%   3. Identity (ANALYTIC, definitional): the metrics stored by the engine equal
%      the fields of vital.linear.modes computed directly at the same trim
%      (zeta_sp = SP zeta, omega_nsp = SP wn, zeta_p, zeta_d, omega_nd, tau_R = roll
%      tau) exactly, and CAP = wn^2/(n/alpha) to 1e-14 relative.
%   3a. CHANGE BEFORE THE FIRST GREEN RUN (coordinator instruction after the
%      M5-X cross-check, 2026-09-29; not a tolerance change): the phugoid
%      metrics (zeta_p, T2_phugoid_s, T2_speed_divergence_s) use
%      vital.linear.modes(lin, 'IncludeHeight', true), because the 8-state
%      phugoid (zeta 0.095) is biased by the missing altitude-density/thrust
%      coupling and the nonlinear F-16 follows the 9-state phugoid (zeta 0.077,
%      tests/M5/tLinearVsNonlinear.m). As first registered, identity 3 compared
%      zeta_p with the 8-state phugoid; it now compares with the 9-state one.
%      The Level of pre-registration 1 is unchanged (0.077 >= 0.04).
%   3b. The short-period, Dutch-roll, roll and spiral metrics stay on the
%      8-state modes. Justification (REG band, registered with 3a before it was
%      run): the 9-state modes change the short-period wn and zeta by less than
%      1e-3 relative (the height coupling acts on the phugoid time scale), and the
%      Dutch roll, roll and spiral eigenvalues by less than 1e-9 relative (h does
%      not couple into the lateral modes at a symmetric trim).
%   4. A grid point that does not trim (Mach 0.3 at 35,000 ft: the M4 trim is
%      INFEASIBLE, throttle at its upper bound; observed while measuring the cost
%      per point) is excluded and counted as trim:INFEASIBLE in every assessed
%      record, and no point of the 'test' grid is an ERROR.
%   REVISION 2026-10-05 (review R2; coordinator decisions; superseded, not
%   failed physics): item 1's "3.2.1.1-CatA/B worst Level 3 with levelsDefined =
%   3" became Level 1 with levelsDefined [1 2 3], because 3.2.1.1 Levels 1-2
%   ("no tendency for airspeed to diverge aperiodically", p.11) are now encoded
%   (R2 M1); item 5's file names f16_fq.json/.md became f16_fq_<grid>_<AeroScale
%   tag> (R2 M9).
%   5. run_f16_fq prints, per group, the paragraph, category, metric, Level,
%      margin, critical condition and status, and the coverage table (classes
%      OUT-OF-SIM, PILOT, NOT-IMPLEMENTED), and writes <ReportDir>/f16_fq.json and
%      .md.
%   6. Cost: the measured cost per condition point (trim + linearize + modes +
%      metrics) is below 5 s (REG; measured about 0.15-0.25 s on the development
%      machine).

    properties
        File
        R
        Dir
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.File = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
            vital.io.requireDeliverable(tc.File);
            tc.R = vital.fq.loadRules();
            tc.Dir = tempname; mkdir(tc.Dir);
            tc.addTeardown(@() vital.test.removeTree(tc.Dir));
        end
    end

    methods (Static, Access = private)
        function g = grp(res, name)
            g = res.groups(strcmp({res.groups.group}, name));
        end

        function n = excl(r, reason)
            n = 0;
            k = strcmp({r.excludedBy.reason}, reason);
            if any(k), n = r.excludedBy(k).count; end
        end
    end

    methods (Test)
        function readmeConditionLevels(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'readme');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            tc.assertEqual({res.points.status}, {'OK'});
            reg = {'3.2.2.1.2-CatA', 1; '3.2.2.1.2-CatB', 1; '3.2.2.1.1-CatA', 1; '3.2.2.1.1-CatB', 1; ...
                '3.2.1.2-CatA', 1; '3.2.1.2-CatB', 1; '3.3.1.1-CatA-COGA', 2; '3.3.1.1-CatA-other', 2; ...
                '3.3.1.2-CatA', 1; '3.3.1.2-CatB', 1; '3.3.1.3-CatA', 1; '3.3.1.3-CatB', 1; '3.3.1.4-CatA-COGA', 1; ...
                '3.2.1.1-CatA', 1; '3.2.1.1-CatB', 1};   % revision 2026-10-05 (R2 M1): was 3 (Level 3 only defined)
            for k = 1:size(reg, 1)
                g = tF16Fq.grp(res, reg{k, 1});
                tc.verifyExact(g.worstLevel, reg{k, 2}, 'REG', 'pre-registration 1 (derived from the M5-A REG mode table)', ...
                    'Quantity', ['Level ' reg{k, 1}]);
            end
            tc.verifyEqual(tF16Fq.grp(res, '3.3.1.4-CatB').status, 'NOT_APPLICABLE');
            tc.verifyExact(tF16Fq.grp(res, '3.2.1.1-CatA').levelsDefined, [1 2 3], 'REG', 'pre-registration 1 revised 2026-10-05 (R2 M1)', 'Quantity', '3.2.1.1 Levels defined');
        end

        function categoryCNotAssessable(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'readme');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            gc = res.groups(strcmp({res.groups.category}, 'C'));
            rc = res.rules(strcmp({res.rules.category}, 'C'));
            tc.verifyNotEmpty(gc);
            tc.verifyTrue(all(strcmp({gc.status}, 'NOT_ASSESSABLE')), 'every Category C group NOT_ASSESSABLE (pre-registration 2)');
            tc.verifyTrue(all(strcmp({rc.status}, 'NOT_ASSESSABLE')), 'every Category C record NOT_ASSESSABLE');
            tc.verifyTrue(all(contains(lower({gc.reason}), 'landing')), 'the policy reason is reported');
            tc.verifyTrue(all(isnan([gc.worstLevel])), 'no Level for Category C');
        end

        function metricsEqualModesDirectly(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'readme');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            M = res.points(1).metrics;
            ft = 0.3048;
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * ft, 'h', 10013 * ft, 'gamma', 0, 'psi', 0));
            lin = vital.linear.linearize(AC, env, tr);
            m = vital.linear.modes(lin);
            mh = vital.linear.modes(lin, 'IncludeHeight', true);
            e = @(n) m(strcmp({m.name}, n));
            eh = @(n) mh(strcmp({mh.name}, n));
            c = 'ANALYTIC: definitional identity metric = mode field (pre-registration 3)';
            tc.verifyExact(M.zeta_sp.value, e('short_period').zeta, 'ANALYTIC', c, 'Quantity', 'zeta_sp');
            tc.verifyExact(M.omega_nsp_rad_s.value, e('short_period').wn, 'ANALYTIC', c, 'Quantity', 'omega_nsp');
            tc.verifyExact(M.zeta_p.value, eh('phugoid').zeta, 'ANALYTIC', [c ' (phugoid with height, 3a)'], 'Quantity', 'zeta_p');
            tc.verifyExact(M.zeta_d.value, e('dutch_roll').zeta, 'ANALYTIC', c, 'Quantity', 'zeta_d');
            tc.verifyExact(M.omega_nd_rad_s.value, e('dutch_roll').wn, 'ANALYTIC', c, 'Quantity', 'omega_nd');
            tc.verifyExact(M.tau_R_s.value, e('roll').tau, 'ANALYTIC', c, 'Quantity', 'tau_R');
            tc.verifyTol(M.CAP.value, e('short_period').wn^2 / M.n_alpha_g_per_rad.value, 1e-14, 'rel', 'ANALYTIC', c, 'Quantity', 'CAP');
            % the 6.2 n/alpha (with elevator lift) is below the alpha-only M5-A value, within 12 %
            tc.verifyWithin(M.n_alpha_g_per_rad.value / lin.n_alpha, 0.88, 1.0, 'REG', ...
                'tFqMutations M1 derivation: elevator lift reduces n/alpha by < 12 %', 'Quantity', 'n/alpha ratio');
        end

        function heightCouplingOnlyMovesPhugoid(tc)
            ft = 0.3048;
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * ft, 'h', 10013 * ft, 'gamma', 0, 'psi', 0));
            lin = vital.linear.linearize(AC, env, tr);
            m = vital.linear.modes(lin);
            mh = vital.linear.modes(lin, 'IncludeHeight', true);
            e = @(mm, n) mm(strcmp({mm.name}, n));
            c = 'REG: pre-registration 3b (8-state modes kept for the non-phugoid metrics)';
            tc.verifyTol(e(mh, 'short_period').wn, e(m, 'short_period').wn, 1e-3, 'rel', 'REG', c, 'Quantity', 'SP wn 9 vs 8 states');
            tc.verifyTol(e(mh, 'short_period').zeta, e(m, 'short_period').zeta, 1e-3, 'rel', 'REG', c, 'Quantity', 'SP zeta 9 vs 8 states');
            for n = {'dutch_roll', 'roll', 'spiral'}
                a = e(mh, n{1}).eigenvalue; b = e(m, n{1}).eigenvalue;
                tc.verifyTol(abs(a - b) / abs(b), 0, 1e-9, 'abs', 'REG', c, 'Quantity', [n{1} ' eigenvalue relative change']);
            end
            tc.verifyGreaterThan(abs(e(mh, 'phugoid').zeta - e(m, 'phugoid').zeta), 0.01, ...
                'the height coupling does move the phugoid (M5-X: zeta 0.095 -> 0.077)');
        end

        function testGridCountsExclusions(tc)
            C = vital.fq.loadConditions(tc.File, 'Grid', 'test');
            res = vital.fq.assess(tc.R, vital.fq.f16Factory(), C);
            tc.verifyFalse(any(strcmp({res.points.status}, 'ERROR')), 'no ERROR point');
            k = find(arrayfun(@(p) p.cond.mach == 0.3 && p.cond.h_ft == 35000, res.points));
            tc.assertNumElements(k, 1, 'the test grid contains Mach 0.3 at 35,000 ft');
            tc.verifyEqual(res.points(k).status, 'INFEASIBLE', 'pre-registration 4');
            ra = res.rules(~strcmp({res.rules.category}, 'C'));
            n = arrayfun(@(r) tF16Fq.excl(r, 'trim:INFEASIBLE'), ra);
            tc.verifyTrue(all(n >= 1), 'the infeasible point is counted in every assessed record');
            tc.verifyTrue(all(~strcmp({ra.status}, 'ASSESSED')), 'records with an excluded point are not fully ASSESSED');
            tc.verifyLessThan(res.timing.perPoint_s, 5, 'pre-registration 6: cost per condition point');
        end

        function entryPointPrintsAndWritesReport(tc)
            txt = evalc('res = run_f16_fq(''Grid'', ''readme'', ''ReportDir'', tc.Dir, ''Refine'', false);');
            for s = {'3.2.2.1.2', '3.3.1.1', 'Cat', 'Level', 'margin', 'critical', 'status', 'NOT_ASSESSABLE', ...
                    'OUT-OF-SIM', 'PILOT', 'NOT-IMPLEMENTED', 'zeta_sp', 'REG'}
                tc.verifySubstring(txt, s{1});
            end
            % revision 2026-10-05 (R2 M9): files are named by grid and AeroScale (were f16_fq.json/.md)
            tc.verifyTrue(isfile(fullfile(tc.Dir, 'f16_fq_readme_baseline.json')) && isfile(fullfile(tc.Dir, 'f16_fq_readme_baseline.md')), 'report files');
            j = jsondecode(fileread(fullfile(tc.Dir, 'f16_fq_readme_baseline.json')));
            tc.verifyTrue(isfield(j, 'coverage') && numel(j.coverage) > 10, 'coverage table in the report');
            tc.verifyEqual(numel(res.groups), numel(unique({tc.R.group})));
        end
    end
end
