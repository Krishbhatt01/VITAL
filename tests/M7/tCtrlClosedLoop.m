classdef (TestTags = {'M7'}) tCtrlClosedLoop < vital.test.VitalTestCase
%TCTRLCLOSEDLOOP  M7 closed-loop checks (a), (b), (d): the closed-loop A of
%   vital.linear.linearize(..., 'Controller', c) against A_open + B_open K built BY
%   HAND from the gains and the measurement Jacobians; the direction in which the
%   modes move; a destabilizing (wrong-sign) gain is reported, never an improvement.
%
%   Condition: NESC README trim (565.6854 ft/s, 10,013 ft, CG 25 %).
%   x_lin = [u v w p q r phi theta psi pN pE h]; inputs [de da dr throttle].
%   PRE-REGISTERED (written with the stubs, before any implementation):
%   (a) HAND CLOSED LOOP (ANALYTIC). K_hand (4 x 12) from the gains and the
%       measurement Jacobians at the trim (zero wind, v0 = 0):
%         dalpha/du = -w0/(u0^2 + w0^2), dalpha/dw = u0/(u0^2 + w0^2)
%         dbeta/dv = 1/V0 (dbeta/du = dbeta/dw = 0 at v0 = 0)
%         dKEAS/d[u v w] = sqrt(rho/rho0) [u0 v0 w0]/V0 / kt
%         dKEAS/dh = V0/(2 sqrt(rho rho0)) drho/dh / kt, with the US 1976
%         troposphere drho/dH = -rho (g0/(R T) + Lb/T), Lb = -0.0065 K/m,
%         dH/dh = r0^2/(r0 + h)^2, r0 = 6,356,766 m
%         phi, theta, p, q, r are states (q, r measured as y.q, y.r).
%       pitchSas (Kq 0.2, Ka 0.5):  K(de,:) = Kq e_q + Ka dalpha/dx
%       yawDamper (Kr 0.5, Kari 0.1): K(dr,:) = Kr e_r; Kref = I + Kari e_dr e_da'
%       combine of the two: the sum of both K, Kref of the yaw damper
%       nescLqr (published gains, NESC_EXTRACT_F16 C.2, deg/rad as in tCtrlLaws):
%         K(de,:)  = 25 (K11 (pi/180) dKEAS/dx + K12 dalpha/dx + K13 (pi/180) e_q
%                    + K14 e_theta)
%         K(thr,:) = -(K21 dKEAS/dx + K22 (180/pi) dalpha/dx + K23 e_q
%                    + K24 (180/pi) e_theta)
%         K(da,:)  = 21.5 (L11 e_phi + L12 dbeta/dx + L13 (pi/180) e_p
%                    + L14 (pi/180) e_r)
%         K(dr,:)  = 30 (L21 e_phi + L22 dbeta/dx + L23 (pi/180) e_p
%                    + L24 (pi/180) e_r) + 0.008 K(da,:)
%         Kref = I (the reference command enters the law's trim/pilot inputs)
%       Checks, in step-study units (FScale = [g g g 1 1 1 1 1 1 V V V],
%       ZScale = [10 10 10 1 1 1 1 1 1 1000 1000 1000 | 0.1 0.1 0.1 1], output
%       scale of K [0.1 0.1 0.1 1]):
%         lin.K vs K_hand: |dK(j,c)| ZScale(c)/Fu(j) <= 2e-6 max(1, max_c
%           |K_hand(j,c)| ZScale(c)/Fu(j)) (row-relative, ADR-028 MINOR 10)
%         lin.Kref vs Kref_hand: 1e-8 abs (exact linear maps)
%         lin.A vs A_open + B_open K_hand, per entry:
%           |dA(r,c)| <= 2e-6 (FScale(r)/ZScale(c)) max(1, kappa(c)),
%           kappa(c) = sum_j |K_hand(j,c)| ZScale(c)/ZScale_u(j)
%         (three step-study estimates, each accurate to ~1e-6 of its column
%         scale; the B_open error is amplified by the gain in step units, which
%         kappa measures; the M5 test used 2e-6 for kappa <= 1)
%         lin.B vs B_open Kref_hand: |dB(r,j)| <= 2e-6 FScale(r)/ZScale_u(j) max(1,
%           sum_i |Kref(i,j)|)
%   (b) DIRECTION (sign of CONVENTIONS 7; REG for the LQR). vital.ctrl.closedLoop:
%         pitchSas Kq 0.2 (Ka 0): STABLE, zeta_sp increases, improvement true for
%           short_period
%         pitchSas Ka 0.5 (Kq 0): wn_sp increases
%         yawDamper Kr 0.5: STABLE, zeta_d increases
%         nescLqr: STABLE (all 8 closed-loop eigenvalues Re < 0); the 8-state
%           eigenvalues of lin.A equal those of A_open(1:8,1:8) + B_open(1:8,:)
%           K_hand(:,1:8) within 1e-4 max(1, |lambda|) (paired by nearest
%           distance); REG predictions: zeta_p and zeta_d of the LQR closed loop
%           exceed the bare values (theta/KEAS feedback damps the phugoid; the
%           r -> rudder gain 30 x 0.822 deg/(rad/s) > 0 adds yaw damping).
%           [FAILED HYPOTHESIS, first GREEN run: the zeta_d prediction held
%           (0.117 -> 0.231), but the LQR closed loop has NO oscillatory phugoid: the
%           theta/KEAS loops split it into two stable real roots (-16.0 and -0.76
%           1/s, NOT_OSCILLATORY), so zeta_p is NaN and "zeta_p increases" cannot
%           be evaluated. The prediction wrongly assumed the phugoid stays an
%           oscillation. Corrected check, same physical claim ("the LQR damps the
%           phugoid motion"), independent of the classifier's naming: the slowest
%           closed-loop longitudinal root (8 states, every root named short_period
%           or phugoid) decays faster than the bare phugoid, max Re(lambda_lon,cl)
%           < Re(lambda_phugoid,bare). The closed loop also couples roll and
%           spiral into an 'other' oscillation (-37.2 +/- 37.1i), see tCtrlFq.]
%   (d) DESTABILIZING GAIN (REG, derived from the README short period and Dutch
%       roll: M_q + M_de Kq > 0 makes the short-period trace positive; Kr = -0.5
%       removes more yaw damping than the bare 0.12 has):
%         pitchSas Kq = -0.3 -> status 'UNSTABLE', destabilized true, a
%           longitudinal mode (short_period, or its real roots) in r.unstable, and
%           NO row of r.improvement true
%         yawDamper Kr = -0.5 -> 'UNSTABLE', destabilized, dutch_roll unstable,
%           no improvement
%       Failure modes: a controller returning 3 values -> vital:ctrl:badOutputSize
%       (before linearizing); a controller without static = true ->
%       vital:linear:dynamicController.

    properties
        AC
        env
        tr
        y0
        x0l
        Ft = 0.3048
    end

    properties (Constant)
        ZS = [10 10 10 1 1 1 1 1 1 1000 1000 1000]
        ZU = [0.1 0.1 0.1 1]
        FU = [0.1 0.1 0.1 1]
        K1 = [-0.063009074230494 0.113230403179271 10.113432224566077 3.154983341632913]
        K2 = [0.997260602961658 -0.025467711176391 1.213308488207827 0.208744369535208]
        L1 = [3.078043941515770 0.032365863044163 4.557858908828332 0.589443156647647]
        L2 = [-0.705817452754520 -0.256362860634868 -1.073666149713151 0.822114635953878]
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
            [~, tc.y0] = vital.plant.derivatives(tc.tr.x, tc.tr.u, tc.AC, tc.env);
            x = tc.tr.x(:);
            tc.x0l = [x(1:6); vital.frames.dcm2eul(vital.frames.quat2dcm(x(7:10))); x(11); x(12); -x(13)];
        end
    end

    methods (Access = private)
        function J = meas(tc)
            % ANALYTIC measurement Jacobians (1 x 12 each) at the trim
            u0 = tc.x0l(1); v0 = tc.x0l(2); w0 = tc.x0l(3); h = tc.x0l(12);
            V = norm([u0 v0 w0]);
            J.alpha = zeros(1, 12); J.alpha([1 3]) = [-w0 u0] / (u0^2 + w0^2);
            J.beta = zeros(1, 12); J.beta(2) = 1 / V;
            g0 = 9.80665; R = 8314.32 / 28.9644; Lb = -0.0065; r0 = 6356766;
            atm = vital.env.atmosphereUS76(h);
            rho0 = 101325 / (R * 288.15); kt = 1852 / 3600;
            drhodh = -atm.rho * (g0 / (R * atm.T) + Lb / atm.T) * r0^2 / (r0 + h)^2;
            J.keas = zeros(1, 12);
            J.keas(1:3) = sqrt(atm.rho / rho0) * [u0 v0 w0] / V / kt;
            J.keas(12) = V / (2 * sqrt(atm.rho * rho0)) * drhodh / kt;
            e = eye(12);
            J.e = e;
        end

        function K = kSas(tc, Kq, Ka)
            J = tc.meas(); K = zeros(4, 12);
            K(1, :) = Kq * J.e(5, :) + Ka * J.alpha;
        end

        function [K, Kref] = kYaw(~, Kr, Kari)
            K = zeros(4, 12); K(3, 6) = Kr;
            Kref = eye(4); Kref(3, 2) = Kari;
        end

        function K = kLqr(tc)
            J = tc.meas(); d = pi / 180; e = J.e; K = zeros(4, 12);
            K(1, :) = 25 * (tc.K1(1) * d * J.keas + tc.K1(2) * J.alpha + tc.K1(3) * d * e(5, :) + tc.K1(4) * e(8, :));
            K(4, :) = -(tc.K2(1) * J.keas + tc.K2(2) / d * J.alpha + tc.K2(3) * e(5, :) + tc.K2(4) / d * e(8, :));
            K(2, :) = 21.5 * (tc.L1(1) * e(7, :) + tc.L1(2) * J.beta + tc.L1(3) * d * e(4, :) + tc.L1(4) * d * e(6, :));
            K(3, :) = 30 * (tc.L2(1) * e(7, :) + tc.L2(2) * J.beta + tc.L2(3) * d * e(4, :) + tc.L2(4) * d * e(6, :)) + 0.008 * K(2, :);
        end

        function checkHand(tc, lin, K, Kref, label)
            tc.assertEqual(lin.status, 'OK', lin.reason);
            V = tc.y0.V; g = tc.env.g;
            fs = [g g g 1 1 1 1 1 1 V V V].';
            % controller Jacobian
            Ks = (K ./ tc.FU.') .* tc.ZS;
            dKs = abs(lin.K - K) ./ tc.FU.' .* tc.ZS;
            ratioK = max(dKs ./ (2e-6 * max(1, max(abs(Ks), [], 2))), [], 'all');
            tc.verifyTol(ratioK, 0, 1, 'abs', 'ANALYTIC', 'lin.K = K_hand (header (a))', 'Quantity', [label ' K error / tolerance']);
            tc.verifyTol(lin.Kref, Kref, 1e-8, 'abs', 'ANALYTIC', 'Kref of a linear reference map', 'Quantity', [label ' Kref']);
            % closed-loop A
            kappa = sum(abs(K) .* tc.ZS ./ tc.ZU.', 1);
            tolA = 2e-6 * (fs ./ tc.ZS) .* max(1, kappa);
            E = lin.open.A + lin.open.B * K;
            ratioA = max(abs(lin.A - E) ./ tolA, [], 'all');
            tc.verifyTol(ratioA, 0, 1, 'abs', 'ANALYTIC', 'A_cl = A_open + B_open K_hand (header (a))', ...
                'Quantity', [label ' A_cl error / tolerance']);
            tolB = 2e-6 * (fs ./ tc.ZU) .* max(1, sum(abs(Kref), 1));
            ratioB = max(abs(lin.B - lin.open.B * Kref) ./ tolB, [], 'all');
            tc.verifyTol(ratioB, 0, 1, 'abs', 'ANALYTIC', 'B_cl = B_open Kref (header (a))', ...
                'Quantity', [label ' B_cl error / tolerance']);
        end

        function m = pick(~, modes, name)
            m = modes(strcmp({modes.name}, name));
            if ~isempty(m), m = m(1); end
        end
    end

    methods (Test)
        function handClosedLoopPitchSas(tc)
            c = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2, 'Ka', 0.5);
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.checkHand(lin, tc.kSas(0.2, 0.5), eye(4), 'pitchSas');
        end

        function handClosedLoopYawDamper(tc)
            c = vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5, 'Kari', 0.1);
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            [K, Kref] = tc.kYaw(0.5, 0.1);
            tc.checkHand(lin, K, Kref, 'yawDamper');
        end

        function handClosedLoopCombined(tc)
            c = vital.ctrl.combine(vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2, 'Ka', 0.5), ...
                vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5, 'Kari', 0.1));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            [Ky, Kref] = tc.kYaw(0.5, 0.1);
            tc.checkHand(lin, tc.kSas(0.2, 0.5) + Ky, Kref, 'combined');
        end

        function handClosedLoopNescLqr(tc)
            c = vital.ctrl.nescLqr(tc.AC, tc.env, tc.tr);
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            K = tc.kLqr();
            tc.checkHand(lin, K, eye(4), 'nescLqr');
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, c);
            tc.verifyEqual(r.status, 'STABLE', 'header (b): the NESC LQR closed loop is stable at its design point');
            lh = eig(lin.open.A(1:8, 1:8) + lin.open.B(1:8, :) * K(:, 1:8));
            ll = eig(r.aug.lin.A(1:8, 1:8));
            err = 0;
            for k = 1:numel(lh)
                [dmin, j] = min(abs(ll - lh(k)));
                err = max(err, dmin / max(1, abs(lh(k))));
                ll(j) = Inf;
            end
            tc.verifyTol(err, 0, 1e-4, 'abs', 'ANALYTIC', 'closed-loop eigenvalues = hand closed loop (header (b))', ...
                'Quantity', 'max rel eigenvalue error');
            pb = tc.pick(r.bare.modes, 'phugoid'); pa = tc.pick(r.aug.modes, 'phugoid');
            db = tc.pick(r.bare.modes, 'dutch_roll'); da = tc.pick(r.aug.modes, 'dutch_roll');
            tc.assertNotEmpty(pa, 'LQR closed loop has a phugoid'); tc.assertNotEmpty(da, 'LQR closed loop has a Dutch roll');
            % original registered check, kept: FAILED (zeta_p is NaN, split phugoid; header (b))
            % tc.verifyGreaterThan(pa.zeta, pb.zeta, 'REG (b): LQR damps the phugoid');
            lonA = r.aug.modes(ismember({r.aug.modes.name}, {'short_period', 'phugoid'}));
            tc.verifyLessThan(max(real([lonA.eigenvalue])), real(pb.eigenvalue), ...
                'corrected (b): the slowest LQR longitudinal root decays faster than the bare phugoid');
            tc.verifyGreaterThan(da.zeta, db.zeta, 'REG (b): LQR damps the Dutch roll');
        end

        function modesMoveInRegisteredDirection(tc)
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2));
            tc.verifyEqual(r.status, 'STABLE');
            sb = tc.pick(r.bare.modes, 'short_period'); sa = tc.pick(r.aug.modes, 'short_period');
            tc.verifyGreaterThan(sa.zeta, sb.zeta, 'Kq > 0 adds short-period damping (CONVENTIONS 7)');
            tc.verifyTrue(r.improvement(strcmp({r.table.name}, 'short_period')), 'short-period damping improvement reported');
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Ka', 0.5));
            sb = tc.pick(r.bare.modes, 'short_period'); sa = tc.pick(r.aug.modes, 'short_period');
            tc.verifyGreaterThan(sa.wn, sb.wn, 'Ka > 0 adds pitch stiffness: wn_sp increases');
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5));
            tc.verifyEqual(r.status, 'STABLE');
            db = tc.pick(r.bare.modes, 'dutch_roll'); da = tc.pick(r.aug.modes, 'dutch_roll');
            tc.verifyGreaterThan(da.zeta, db.zeta, 'Kr > 0 adds Dutch-roll damping (CONVENTIONS 7)');
        end

        function wrongSignIsReportedUnstable(tc)
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', -0.3));
            tc.verifyEqual(r.status, 'UNSTABLE', 'Kq = -0.3 (wrong sign) destabilizes the short period');
            tc.verifyTrue(r.destabilized);
            tc.verifyTrue(any(ismember({r.unstable.name}, {'short_period'})), 'the unstable mode is longitudinal (short period)');
            tc.verifyFalse(any(r.improvement), 'an unstable closed loop is never an improvement');
            r = vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', -0.5));
            tc.verifyEqual(r.status, 'UNSTABLE', 'Kr = -0.5 (wrong sign) destabilizes the Dutch roll');
            tc.verifyTrue(r.destabilized);
            tc.verifyTrue(any(strcmp({r.unstable.name}, 'dutch_roll')));
            tc.verifyFalse(any(r.improvement), 'an unstable closed loop is never an improvement');
        end

        function closedLoopFailureModes(tc)
            wrong = struct('rate_hz', 100, 'init', [], 'static', true, 'step', @(t, x, y, uref, s) deal(uref(1:3), s));
            tc.verifyError(@() vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, wrong), 'vital:ctrl:badOutputSize');
            c = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.1);
            c = rmfield(c, 'static');
            tc.verifyError(@() vital.ctrl.closedLoop(tc.AC, tc.env, tc.tr, c), 'vital:linear:dynamicController');
        end
    end
end
