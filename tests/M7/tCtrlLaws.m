classdef (TestTags = {'M7'}) tCtrlLaws < vital.test.VitalTestCase
%TCTRLLAWS  M7: the control laws themselves (vital.ctrl.pitchSas, yawDamper,
%   combine, nescLqr): references, exact law identities, CONVENTIONS 7 signs,
%   limits flagged (never clipped) and the failure modes.
%
%   Condition: NESC README trim (565.6854 ft/s, 10,013 ft, CG 25 %, g 32.174 ft/s^2).
%   PRE-REGISTERED (written with the stubs, before any implementation):
%   1. Equilibrium (ANALYTIC). At the trim, with y = plant(x_trim, u_trim) and
%      u_ref = u_trim, pitchSas (Kq 0.2, Ka 0.5) and yawDamper (Kr 0.5, Kari 0.1)
%      return u_trim EXACTLY (isequal): every feedback term is (measurement -
%      reference) with the reference taken from the same plant output.
%      nescLqr returns u_trim within 1e-12 abs (rad, and throttle fraction): the
%      deg/rad conversions of the NASA law are not exact in floating point.
%   2. Law identities (ANALYTIC) at a perturbed state (dw = +0.5 m/s, dq = +0.02
%      rad/s, dv = +0.4 m/s, dr = +0.03 rad/s), y from the plant at (x, u_ref):
%        pitchSas  de - de_ref = Kq (y.q - q0) + Ka (y.alpha - alpha0), 1e-15 abs;
%                  da, dr, throttle = u_ref exactly
%        yawDamper dr - dr_ref = Kr (y.r - r0) + Kari (da_ref - da_trim), 1e-15
%                  abs (u_ref with da_ref = da_trim + 0.01 rad); others exact
%        combine(pitchSas, yawDamper) = u_ref + both deviations, 1e-15 abs
%   3. Signs (CONVENTIONS 7, ANALYTIC). Kq > 0 and q > 0 give de > de_ref and a
%      nose-DOWN change of the plant pitching moment M_cg(2) (opposes q). Kr > 0
%      and r > 0 give dr > dr_ref and a nose-LEFT change of M_cg(3) (opposes r).
%   4. nescLqr = NASA's published law (INDEP: the LQR gain table of
%      docs/nesc/NESC_EXTRACT_F16.md C.2, typed in this test; nescLqr must call
%      the generated vital.models.f16.control instead). At a perturbed state
%      (dw 0.5 m/s, du 1 m/s, dq 0.02, dp 0.03, dr 0.02 rad/s, dtheta 0.01,
%      dphi 0.02 rad, dv 0.4 m/s), with KEAS = V sqrt(rho(h)/rho0) (rho from
%      vital.env.atmosphereUS76: a different route from the law's qbar), the
%      four commands equal the hand law within 1e-10 abs:
%        de  = de_ref + 25 (K11 dKEAS + K12 dalpha + K13 q + K14 dtheta) deg
%        thr = thr_ref - (K21 dKEAS + K22 dalpha + K23 q + K24 dtheta)
%        da  = da_ref + 21.5 (L11 phi + L12 beta + L13 p + L14 r) deg
%        dr  = dr_ref + 30 (L21 phi + L22 beta + L23 p + L24 r) deg
%              + 0.008 x 21.5 (L11 phi + L12 beta + L13 p + L14 r) deg
%      (angles in deg, rates in rad/s, KEAS in kt).
%      [FAILED HYPOTHESIS, first GREEN run: the registered perturbation drives
%      NASA's law into its own stick limiters (lateral stick total about -3.7,
%      longitudinal about 1.9, both clamped to +/-1), where the linear hand law
%      does not apply; mismatch 1.7 rad. A fixture error, not a law error.
%      Corrected check: the same hand law and tolerance at a perturbation ten
%      times smaller, with lawState asserting first that no limiter of the law is
%      active. A second fixture error appeared at once: with du = +0.1 m/s the
%      KEAS -> throttle gain (K21 = 0.997 per kt) drives the throttle total below
%      idle (0.139 - 0.19 < 0). The corrected perturbation is therefore du = -0.05
%      m/s, dv 0.04, dw 0.05 m/s; dp 0.003, dq 0.002, dr 0.002 rad/s; dphi 0.002,
%      dtheta 0.001 rad (all limiters inactive, asserted). The original call is kept, and must show
%      the saturation flags set.] The source of nescLqr.m calls
%      vital.models.f16.control and contains none of the gain literals (REG).
%      lawState: no limiter active at the trim; with q = 1 rad/s the longitudinal
%      stick total is saturated (|25 x 10.11 x 1| / 25 > 1).
%   5. Limits are flagged, never clipped (ADR-027). vital.sim.run with pitchSas
%      Kq = 5 s from dq0 = +0.1 rad/s, dt 0.01 s, 0.2 s: out.controlLimit.ever is
%      true with channel 'de', and the logged elevator command exceeds the 24 deg
%      limit (max(out.u(1,:)) > deg2rad(24)).
%   6. Failure modes (exact identifiers): a trim whose status is not OK ->
%      vital:ctrl:notTrimmed (pitchSas, yawDamper, nescLqr); a NaN gain or Rate 0
%      -> vital:badInput; combine with different rates -> vital:ctrl:rateMismatch;
%      a combine member returning 3 values -> step raises vital:ctrl:badOutputSize,
%      and vital.sim.run records it as a STOP vital:sim:controllerError with
%      stopDetail.identifier vital:ctrl:badOutputSize; combine of a member without
%      static = true is not static (c.static false).

    properties
        AC
        env
        tr
        y0
        Ft = 0.3048
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
            [~, tc.y0] = vital.plant.derivatives(tc.tr.x, tc.tr.u, tc.AC, tc.env);
        end
    end

    methods (Access = private)
        function x = perturbed(tc, dv_b, dw_b, deul)
            % 13-state plant state: body velocity and rates added, Euler angles added
            x = tc.tr.x(:);
            x(1:3) = x(1:3) + dv_b(:);
            x(4:6) = x(4:6) + dw_b(:);
            e = vital.frames.dcm2eul(vital.frames.quat2dcm(x(7:10)));
            e = e(:) + deul(:);
            x(7:10) = vital.frames.eul2quat(e(1), e(2), e(3));
        end

        function [u, y] = callAt(tc, c, x, uref)
            [~, y] = vital.plant.derivatives(x, uref, tc.AC, tc.env);
            [u, ~] = c.step(0, x, y, uref, c.init);
            u = u(:);
        end
    end

    methods (Test)
        function lawsReturnTrimAtTrim(tc)
            u0 = tc.tr.u(:);
            cp = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2, 'Ka', 0.5);
            cy = vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5, 'Kari', 0.1);
            cn = vital.ctrl.nescLqr(tc.AC, tc.env, tc.tr);
            tc.verifyExact(cp.static, true, 'ANALYTIC', 'declared static (ADR-024)', 'Quantity', 'pitchSas static');
            tc.verifyExact(cy.static, true, 'ANALYTIC', 'declared static (ADR-024)', 'Quantity', 'yawDamper static');
            tc.verifyExact(cn.static, true, 'ANALYTIC', 'declared static (ADR-024)', 'Quantity', 'nescLqr static');
            tc.verifyExact(tc.callAt(cp, tc.tr.x, u0), u0, 'ANALYTIC', 'header 1: references from the same y', 'Quantity', 'pitchSas u(trim)');
            tc.verifyExact(tc.callAt(cy, tc.tr.x, u0), u0, 'ANALYTIC', 'header 1', 'Quantity', 'yawDamper u(trim)');
            tc.verifyTol(tc.callAt(cn, tc.tr.x, u0), u0, 1e-12, 'abs', 'ANALYTIC', 'header 1: deg/rad round trip', ...
                'Quantity', 'nescLqr u(trim)');
        end

        function lawIdentities(tc)
            Kq = 0.2; Ka = 0.5; Kr = 0.5; Kari = 0.1;
            x = tc.perturbed([0 0.4 0.5], [0 0.02 0.03], [0 0 0]);
            u0 = tc.tr.u(:);
            uref = u0; uref(2) = u0(2) + 0.01;
            cp = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', Kq, 'Ka', Ka);
            cy = vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', Kr, 'Kari', Kari);
            [up, y] = tc.callAt(cp, x, uref);
            dp = Kq * (y.q - tc.y0.q) + Ka * (y.alpha - tc.y0.alpha);
            tc.verifyTol(up(1) - uref(1), dp, 1e-15, 'abs', 'ANALYTIC', 'de = de_ref + Kq dq + Ka dalpha', 'Quantity', 'pitchSas de', 'Unit', 'rad');
            tc.verifyExact(up(2:4), uref(2:4), 'ANALYTIC', 'other channels pass u_ref', 'Quantity', 'pitchSas da dr thr');
            uy = tc.callAt(cy, x, uref);
            dy = Kr * (y.r - tc.y0.r) + Kari * (uref(2) - u0(2));
            tc.verifyTol(uy(3) - uref(3), dy, 1e-15, 'abs', 'ANALYTIC', 'dr = dr_ref + Kr dr + Kari dda_ref', 'Quantity', 'yawDamper dr', 'Unit', 'rad');
            tc.verifyExact(uy([1 2 4]), uref([1 2 4]), 'ANALYTIC', 'other channels pass u_ref', 'Quantity', 'yawDamper de da thr');
            cc = vital.ctrl.combine(cp, cy);
            tc.verifyExact(cc.static, true, 'ANALYTIC', 'all members static', 'Quantity', 'combine static');
            uc = tc.callAt(cc, x, uref);
            tc.verifyTol(uc, uref + [dp; 0; dy; 0], 1e-15, 'abs', 'ANALYTIC', 'u_ref + sum of deviations', 'Quantity', 'combine u');
        end

        function signsFollowConventions7(tc)
            u0 = tc.tr.u(:);
            cp = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2);
            x = tc.perturbed([0 0 0], [0 0.05 0], [0 0 0]);
            [up, y] = tc.callAt(cp, x, u0);
            tc.verifyGreaterThan(up(1) - u0(1), 0, 'Kq > 0, q > 0 -> +de (TED)');
            [~, ys] = vital.plant.derivatives(x, up, tc.AC, tc.env);
            tc.verifyLessThan(ys.M_cg(2) - y.M_cg(2), 0, 'CONVENTIONS 7: +de gives a nose-down moment change (opposes q > 0)');
            cy = vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5);
            x = tc.perturbed([0 0 0], [0 0 0.05], [0 0 0]);
            [uy, y] = tc.callAt(cy, x, u0);
            tc.verifyGreaterThan(uy(3) - u0(3), 0, 'Kr > 0, r > 0 -> +dr (TEL)');
            [~, ys] = vital.plant.derivatives(x, uy, tc.AC, tc.env);
            tc.verifyLessThan(ys.M_cg(3) - y.M_cg(3), 0, 'CONVENTIONS 7: +dr gives a nose-left moment change (opposes r > 0)');
        end

        function nescLqrIsNasaPublishedLaw(tc)
            % published gains, docs/nesc/NESC_EXTRACT_F16.md C.2 (F16_control.dml:574-651)
            K1 = [-0.063009074230494 0.113230403179271 10.113432224566077 3.154983341632913];
            K2 = [0.997260602961658 -0.025467711176391 1.213308488207827 0.208744369535208];
            L1 = [3.078043941515770 0.032365863044163 4.557858908828332 0.589443156647647];
            L2 = [-0.705817452754520 -0.256362860634868 -1.073666149713151 0.822114635953878];
            cn = vital.ctrl.nescLqr(tc.AC, tc.env, tc.tr);
            u0 = tc.tr.u(:);
            xBig = tc.perturbed([1 0.4 0.5], [0.03 0.02 0.02], [0.02 0.01 0]);   % registered; saturates (header 4)
            [~, yBig] = vital.plant.derivatives(xBig, u0, tc.AC, tc.env);
            sBig = cn.lawState(yBig, u0);
            tc.verifyTrue(sBig.saturated.latStk && sBig.saturated.longStk, 'the registered perturbation saturates the law (failed hypothesis)');
            x = tc.perturbed([-0.05 0.04 0.05], [0.003 0.002 0.002], [0.002 0.001 0]);   % corrected
            [un, y] = tc.callAt(cn, x, u0);
            sx = cn.lawState(y, u0);
            tc.assertFalse(sx.saturated.longStk || sx.saturated.latStk || sx.saturated.pedal || sx.saturated.throttle || ...
                sx.saturated.pilotInputs, 'corrected perturbation: no limiter active');
            rho0 = 101325 / (8314.32 / 28.9644 * 288.15); kt = 1852 / 3600;
            keas = @(yy) yy.V * sqrt(vital.env.atmosphereUS76(yy.h).rho / rho0) / kt;
            dK = keas(y) - keas(tc.y0);
            da = rad2deg(y.alpha - tc.y0.alpha); dth = rad2deg(y.theta - tc.y0.theta);
            ph = rad2deg(y.phi); be = rad2deg(y.beta);
            lon = [dK da y.q dth];
            lat = [ph be y.p y.r];
            e = [u0(1) + deg2rad(25 * (K1 * lon.'));
                   u0(2) + deg2rad(21.5 * (L1 * lat.'));
                   u0(3) + deg2rad(30 * (L2 * lat.') + 0.008 * 21.5 * (L1 * lat.'));
                   u0(4) - K2 * lon.'];
            tc.verifyTol(un, e, 1e-10, 'abs', 'INDEP', 'NESC_EXTRACT_F16 C.2 gain table, hand law (header 4)', ...
                'Quantity', 'nescLqr [de da dr thr]');
            src = fileread(which('vital.ctrl.nescLqr'));
            tc.verifySubstring(src, 'vital.models.f16.control', 'nescLqr evaluates the generated law');
            for g = {'10.1134', '3.15498', '4.55785', '0.82211'}
                tc.verifyFalse(contains(src, g{1}), sprintf('gain literal %s must not be re-typed in nescLqr.m', g{1}));
            end
            s0 = cn.lawState(tc.y0, u0);
            tc.verifyFalse(s0.saturated.longStk || s0.saturated.latStk || s0.saturated.pedal || s0.saturated.throttle, ...
                'no limiter active at the trim');
            [~, yq] = vital.plant.derivatives(tc.perturbed([0 0 0], [0 1 0], [0 0 0]), u0, tc.AC, tc.env);
            s1 = cn.lawState(yq, u0);
            tc.verifyTrue(s1.saturated.longStk, 'q = 1 rad/s saturates the longitudinal stick total (header 4)');
        end

        function limitsFlaggedNeverClipped(tc)
            cp = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 5);
            x = tc.perturbed([0 0 0], [0 0.1 0], [0 0 0]);
            out = vital.sim.run(tc.AC, tc.env, x, tc.tr.u, 'dt', 0.01, 'tFinal', 0.2, 'Controller', cp);
            tc.verifyTrue(out.controlLimit.ever, 'the elevator command beyond 24 deg is flagged');
            tc.verifyEqual(out.controlLimit.channel, 'de');
            tc.verifyGreaterThan(max(out.u(1, :)), deg2rad(24), 'the logged command is not clipped (ADR-027)');
        end

        function failureModes(tc)
            bad = tc.tr; bad.status = 'INFEASIBLE';
            tc.verifyError(@() vital.ctrl.pitchSas(tc.AC, tc.env, bad, 'Kq', 0.1), 'vital:ctrl:notTrimmed');
            tc.verifyError(@() vital.ctrl.yawDamper(tc.AC, tc.env, bad, 'Kr', 0.1), 'vital:ctrl:notTrimmed');
            tc.verifyError(@() vital.ctrl.nescLqr(tc.AC, tc.env, bad), 'vital:ctrl:notTrimmed');
            tc.verifyError(@() vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', NaN), 'vital:badInput');
            tc.verifyError(@() vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Rate', 0), 'vital:badInput');
            cp = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.1, 'Rate', 100);
            cy = vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.1, 'Rate', 50);
            tc.verifyError(@() vital.ctrl.combine(cp, cy), 'vital:ctrl:rateMismatch');
            wrong = struct('rate_hz', 100, 'init', [], 'static', true, 'step', @(t, x, y, uref, s) deal(uref(1:3), s));
            cw = vital.ctrl.combine(cp, wrong);
            tc.verifyError(@() cw.step(0, tc.tr.x, tc.y0, tc.tr.u(:), cw.init), 'vital:ctrl:badOutputSize');
            out = vital.sim.run(tc.AC, tc.env, tc.tr.x, tc.tr.u, 'dt', 0.01, 'tFinal', 0.05, 'Controller', cw);
            tc.verifyEqual(out.status, 'STOPPED');
            tc.verifyEqual(out.stopReason, 'vital:sim:controllerError');
            tc.verifyEqual(out.stopDetail.identifier, 'vital:ctrl:badOutputSize');
            dyn = struct('rate_hz', 100, 'init', 0, 'step', @(t, x, y, uref, s) deal(uref, s + 1));
            cd = vital.ctrl.combine(cp, dyn);
            tc.verifyFalse(cd.static, 'a member without static = true makes the sum non-static');
        end
    end
end
