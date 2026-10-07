classdef (TestTags = {'M7'}) tCtrlFq < vital.test.VitalTestCase
%TCTRLFQ  M7: closed-loop flying-qualities assessment. vital.fq.f16Factory gains a
%   'Controller' option (a builder ctrl = b(AC, env, tr) called after the trim);
%   vital.fq.evaluatePoint then linearizes the closed loop
%   (vital.linear.linearize(..., 'Controller', ctrl)) and vital.fq.assess grades the
%   AUGMENTED aircraft. The equivalent system of MIL-F-8785C 3.1.12 is the
%   closed-loop modes themselves (static controllers add no state); a point whose
%   closed-loop modes are not the classical set is FLAGGED (proposed ADR).
%
%   PRE-REGISTERED (with the stubs, before any implementation):
%   1. DEFAULT PATH UNCHANGED (REG guard). f16Factory() and f16Factory('Controller',
%      []) build identical ac structs and identical evaluatePoint results
%      (isequal) at the README point, and P.info has no closedLoop field. At the
%      two in-envelope critical points of reports/fq/f16_fq_default_baseline.json
%      the metrics are reproduced: CAP = 0.2016412953889394 at 13,000 ft / Mach
%      0.63 / CG 30 % and zeta_d = 0.10858768179438416 at 13,000 ft / Mach 0.63 /
%      CG 20 % (1e-12 relative). (Expected VACUOUS in RED: a guard on the M6 path.)
%   2. AUGMENTED POINT (README point, pitchSas Kq 0.2, Ka 0.5): status OK,
%      info.closedLoop true, info.equivalentSystem 'CLASSICAL'; ANALYTIC: the
%      metric n/alpha is invariant under static elevator feedback (the steady
%      state per elevator increment at constant speed is the same physical state,
%      reparametrized), so n_alpha_aug = n_alpha_bare within 1e-6 relative;
%      CAP_aug = omega_nsp_aug^2 / n_alpha_aug (1e-12 rel); omega_nsp increases;
%      omega_nsp and zeta_sp equal the short period of vital.ctrl.closedLoop at
%      the same trim (1e-12 rel: the same chain).
%   3. EQUIVALENT-SYSTEM FLAG (REG): yawDamper Kr = 3 at the README point splits
%      the Dutch roll (two real roots; at 13,000 ft / Mach 0.63 Kr = 2 already
%      did in the bare-derivative design sweep), so info.equivalentSystem is
%      'FLAGGED' and a note mentions 3.1.12.
%   4. NON-STATIC LAW (failure mode): a builder whose controller does not declare
%      static = true. Every point is ERROR (stage 'point') with a reason that
%      starts 'vital:linear:dynamicController'; every assessed group is
%      NOT_ASSESSABLE in the envelope with levelHeadline NaN: never a Level.
%   5. WRONG-SIGN GAIN (REG): pitchSas Kq = -0.3 at the README point: group
%      3.2.2.1.2-CatA (zeta_sp) is Level 4 (worse than Level 3) for the augmented
%      aircraft, against Level 1 bare: never presented as an improvement.
%   6. YAW DAMPER LEVEL (REG, bare-derivative estimate: Kr 0.5 raises zeta_d by
%      about 0.3): at the README point 3.3.1.1-CatA-other is Level 2 bare and
%      Level 1 with yawDamper Kr 0.5.

    properties
        R
        Creadme
        cReadme
        file
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.file = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json');
            tc.R = vital.fq.loadRules();
            tc.Creadme = vital.fq.loadConditions(tc.file, 'Grid', 'readme');
            tc.cReadme = vital.fq.gridPoints(tc.Creadme);
        end
    end

    methods (Test)
        function defaultPathBitIdentical(tc)
            f0 = vital.fq.f16Factory(); f1 = vital.fq.f16Factory('Controller', []);
            c = tc.cReadme;
            tc.verifyExact(f1(c), f0(c), 'REG', 'header 1: default factory unchanged', 'Quantity', 'ac');
            P0 = vital.fq.evaluatePoint(f0(c), c); P1 = vital.fq.evaluatePoint(f1(c), c);
            % (after RED: isequal -> isequaln; P holds NaN metric values, e.g. wn of real roots,
            % and isequal(NaN, NaN) is false, so the RED check failed on identical structs)
            tc.verifyTrue(isequaln(P1, P0), 'header 1: default evaluatePoint unchanged (isequaln)');
            tc.verifyFalse(isfield(P0.info, 'closedLoop'), 'the default path adds no field');
            base = struct('gamma_deg', 0, 'g_ftps2', 32.174);
            c = base; c.h_ft = 13000; c.mach = 0.63; c.cg_pct_mac = 30;
            c = orderfields(c, {'h_ft', 'mach', 'cg_pct_mac', 'gamma_deg', 'g_ftps2'});
            P = vital.fq.evaluatePoint(f1(c), c);
            tc.verifyTol(P.metrics.CAP.value, 0.2016412953889394, 1e-12, 'rel', 'REG', ...
                'reports/fq/f16_fq_default_baseline.json, CAP L1 CatA in-envelope critical value', 'Quantity', 'CAP 13000/0.63/30');
            c.cg_pct_mac = 20;
            P = vital.fq.evaluatePoint(f1(c), c);
            tc.verifyTol(P.metrics.zeta_d.value, 0.10858768179438416, 1e-12, 'rel', 'REG', ...
                'reports/fq/f16_fq_default_baseline.json, zeta_d L1 CatA in-envelope critical value', 'Quantity', 'zeta_d 13000/0.63/20');
        end

        function augmentedPointMetrics(tc)
            c = tc.cReadme;
            b = @(AC, env, tr) vital.ctrl.pitchSas(AC, env, tr, 'Kq', 0.2, 'Ka', 0.5);
            ac = vital.fq.f16Factory('Controller', b);
            P = vital.fq.evaluatePoint(ac(c), c);
            fb = vital.fq.f16Factory();
            Pb = vital.fq.evaluatePoint(fb(c), c);
            tc.assertEqual(P.status, 'OK', P.reason);
            tc.verifyTrue(P.info.closedLoop);
            tc.verifyEqual(P.info.equivalentSystem, 'CLASSICAL');
            tc.verifyTol(P.metrics.n_alpha_g_per_rad.value, Pb.metrics.n_alpha_g_per_rad.value, 1e-6, 'rel', 'ANALYTIC', ...
                'n/alpha invariant under static elevator feedback (header 2)', 'Quantity', 'n/alpha aug vs bare', 'Unit', 'g/rad');
            tc.verifyTol(P.metrics.CAP.value, P.metrics.omega_nsp_rad_s.value^2 / P.metrics.n_alpha_g_per_rad.value, 1e-12, ...
                'rel', 'ANALYTIC', 'CAP = wn^2/(n/alpha)', 'Quantity', 'CAP aug');
            tc.verifyGreaterThan(P.metrics.omega_nsp_rad_s.value, Pb.metrics.omega_nsp_rad_s.value, 'Ka > 0 raises wn_sp');
            a = ac(c);
            tr = vital.trim.solve(a.AC, a.env, a.trimCond);
            r = vital.ctrl.closedLoop(a.AC, a.env, tr, b(a.AC, a.env, tr));
            sp = r.aug.modes(strcmp({r.aug.modes.name}, 'short_period'));
            tc.verifyTol(P.metrics.omega_nsp_rad_s.value, sp.wn, 1e-12, 'rel', 'ANALYTIC', 'same chain as vital.ctrl.closedLoop', 'Quantity', 'wn_sp');
            tc.verifyTol(P.metrics.zeta_sp.value, sp.zeta, 1e-12, 'rel', 'ANALYTIC', 'same chain as vital.ctrl.closedLoop', 'Quantity', 'zeta_sp');
        end

        function equivalentSystemFlag(tc)
            c = tc.cReadme;
            ac = vital.fq.f16Factory('Controller', @(AC, env, tr) vital.ctrl.yawDamper(AC, env, tr, 'Kr', 3));
            P = vital.fq.evaluatePoint(ac(c), c);
            tc.verifyEqual(P.info.equivalentSystem, 'FLAGGED', 'REG header 3: Kr = 3 splits the Dutch roll');
            tc.verifyTrue(any(contains(P.info.notes, '3.1.12')), 'the flag is explained in the notes');
        end

        function nonStaticLawIsNotAssessable(tc)
            dyn = @(AC, env, tr) struct('rate_hz', 100, 'init', 0, 'step', @(t, x, y, uref, s) deal(uref, s));
            res = vital.fq.assess(tc.R, vital.fq.f16Factory('Controller', dyn), tc.Creadme);
            tc.verifyEqual(res.points(1).status, 'ERROR');
            tc.verifyTrue(startsWith(res.points(1).reason, 'vital:linear:dynamicController'), res.points(1).reason);
            G = res.groups(~strcmp({res.groups.category}, 'C'));
            ie = [G.inEnvelope];
            tc.verifyTrue(all(strcmp({ie.status}, 'NOT_ASSESSABLE')), 'no Level from a refused controller');
            tc.verifyTrue(all(isnan([ie.levelHeadline])));
        end

        function wrongSignGivesLevel4(tc)
            ac = vital.fq.f16Factory('Controller', @(AC, env, tr) vital.ctrl.pitchSas(AC, env, tr, 'Kq', -0.3));
            res = vital.fq.assess(tc.R, ac, tc.Creadme);
            bare = vital.fq.assess(tc.R, vital.fq.f16Factory(), tc.Creadme);
            g = tcGroup(res, '3.2.2.1.2-CatA'); gb = tcGroup(bare, '3.2.2.1.2-CatA');
            tc.verifyEqual(gb.inEnvelope.levelHeadline, 1, 'bare zeta_sp Level 1');
            tc.verifyEqual(g.inEnvelope.levelHeadline, 4, 'REG header 5: wrong-sign Kq is worse than Level 3');
        end

        function yawDamperRaisesDutchRollLevel(tc)
            ac = vital.fq.f16Factory('Controller', @(AC, env, tr) vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.5));
            res = vital.fq.assess(tc.R, ac, tc.Creadme);
            bare = vital.fq.assess(tc.R, vital.fq.f16Factory(), tc.Creadme);
            tc.verifyEqual(tcGroup(bare, '3.3.1.1-CatA-other').inEnvelope.levelHeadline, 2, 'bare Level 2');
            tc.verifyEqual(tcGroup(res, '3.3.1.1-CatA-other').inEnvelope.levelHeadline, 1, 'REG header 6: Kr 0.5 gives Level 1');
        end
    end
end

function g = tcGroup(res, name)
g = res.groups(strcmp({res.groups.group}, name));
end
