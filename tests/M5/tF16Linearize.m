classdef (TestTags = {'M5'}) tF16Linearize < vital.test.VitalTestCase
%TF16LINEARIZE  M5-A: linear model of the NESC F-16 about a trim
%   (vital.linear.linearize), with every failure mode reported.
%
%   State x_lin = [u v w p q r phi theta psi pN pE h] (SI, rad), inputs
%   [de da dr throttle]. Trim: NESC README condition (565.6854 ft/s, 10,013 ft,
%   CG 25 % MAC, g = 32.174 ft/s^2), heading 45 deg so that the navigation rows
%   are not degenerate. Row scales FScale = [g g g 1 1 1 1 1 1 V V V] and typical
%   perturbations ZScale = [10 10 10 m/s, 1 1 1 rad/s, 1 1 1 rad, 1000 1000 1000 m,
%   0.1 0.1 0.1 rad, 1] are the weights linearize passes to the step study.
%
%   PRE-REGISTERED checks (written before the implementation existed):
%   (a) ANALYTIC entries at the wings-level trim (phi = p = q = r = v = 0, flat
%       Earth, env.g), each within 1e-6 * FScale(row) / ZScale(col), the accuracy
%       the step study is asked for (tLinearJacobian header):
%         d udot/d theta   = -g cos(theta0)          (gravity -g sin(theta) along x)
%         d wdot/d theta   = -g sin(theta0) cos(phi0)
%         d vdot/d phi     =  g cos(theta0) cos(phi0)
%         d udot/d q       = -w0 + qbar S cbar CXq / (2 V m)   (-q w term + NESC CXq)
%         d wdot/d q       =  u0 + qbar S cbar CZq / (2 V m)   (+q u term + NESC CZq)
%         d vdot/d p       =  w0 + qbar S b CYp / (2 V m)      (+p w term + NESC CYp)
%         d vdot/d r       = -u0 + qbar S b CYr / (2 V m)      (-r u term + NESC CYr)
%         d phidot/d p     = 1,  d phidot/d r = tan(theta0) cos(phi0)
%         d thetadot/d q   = cos(phi0),  d psidot/d r = cos(phi0) / cos(theta0)
%         d hdot/d u       = sin(theta0),  d hdot/d w = -cos(phi0) cos(theta0)
%         d hdot/d theta   = u0 cos(theta0) + w0 sin(theta0)   (= V at level flight)
%         d pNdot/d u      = cos(psi0) cos(theta0),  d pEdot/d u = sin(psi0) cos(theta0)
%         d pNdot/d psi    = -pEdot0,  d pEdot/d psi = pNdot0
%       (CXq, CZq, CYp, CYr from vital.models.f16.aero at the trim.) Exact zeros:
%       the pN and pE columns (flat Earth: nothing depends on them) and the
%       control columns of the kinematic rows (phi..h do not depend on u).
%   (b) First order: e(s) = ||W (f(z0 + s d) - f(z0) - [A B] s d)||_inf along a
%       fixed direction d, s = 1, 1/2, 1/4, 1/8: e(s)/e(s/2) in [3, 5]. The Taylor
%       remainder is O(s^2) (ratio 4); an A with an O(1e-3) relative error would
%       add a linear term (ratio -> 2). The ray stays inside one table cell
%       (alpha, de, Mach, altitude move away from breakpoints) so f is smooth on it.
%   (c) Symmetric aircraft (CY = Cl = Cn = 0 at beta = p = r = da = dr = 0): the
%       lon/lat cross blocks of A and B vanish to 1e-6 * FScale(row)/ZScale(col).
%       Partitions: lon = [u w q theta] = x_lin(1,3,5,8), lat = [v p r phi] =
%       x_lin(2,4,6,7), exact sub-blocks of A and B.
%   (d) Air-axis forms: lon [V alpha q theta] = T_lon [u w q theta] with
%       T = [u/V w/V; -w/V^2 u/V^2] (zero wind, v = 0), A_air = T A T^-1 (1e-12
%       relative); physics: d Vdot/d theta = -g cos(gamma0), d thetadot/d q = 1,
%       d betadot/d phi = g cos(theta0) / V (ANALYTIC, tolerance as in (a)).
%   (e) n_alpha = d n / d alpha (n = wind-axis normal load factor, non-gravity
%       forces, V, q, theta fixed) from the linear model, vs a direct central
%       difference of the plant's n at the trim (step 1e-4 rad): rel 1e-5, for
%       the level trim and a 5 deg climb. Derivation: at a wings-level trim,
%       dalphadot/dalpha = (cos a dFz/da - sin a dFx/da)/(m V) and
%       dF_zw/da = m V Z_alpha - F_xw, with F_xw = m g sin(gamma0), so
%       n_alpha = -(V/g) Z_alpha + sin(gamma0).
%   (f) FC-506 on the real plant: at alpha = 5 deg exactly (a breakpoint of every
%       NESC alpha table) the step study reports a kink: NOT_CONVERGED.
%   (g) Failure modes: a trim whose status is not OK -> vital:linear:notTrimmed;
%       non-finite state or gravity, or a trim without a state -> vital:badInput.
%   (h) Control ranges (PUB): NESC control-law scaling ail = -21.5 latStk,
%       rdr = -30 pedal with |stick|, |pedal| <= 1 (F16_control.dml:1117-1185,
%       docs/nesc/NESC_EXTRACT_F16.md C.2) -> da in [-21.5, 21.5] deg,
%       dr in [-30, 30] deg; lin.inputRange carries AC.limits in SI.

    properties
        AC
        env
        tr
        trClimb
        Ft = 0.3048
    end

    properties (Constant)
        ZSCALE =[10 10 10 1 1 1 1 1 1 1000 1000 1000 0.1 0.1 0.1 1]
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', deg2rad(45));
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
            cond.type = 'climb'; cond.gamma = deg2rad(5);
            tc.trClimb = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.trClimb.status, 'OK');
        end
    end

    methods (Access = private)
        function s = fscale(tc)
            V = tc.tr.y.V; g = tc.env.g;
            s = [g g g 1 1 1 1 1 1 V V V];
        end

        function tol = tolFor(tc, i, j)
            fs = tc.fscale();
            tol = 1e-6 * fs(i) / tc.ZSCALE(j);
        end

        function y = fLin(tc, z)
            % independent re-statement of the x_lin -> plant -> x_lin-dot map.
            % Euler rates are NOT the implementation's formulas (review R1 M4): they
            % are the central difference (h = 1e-6 s) of dcm2eul along the exact
            % quaternion rotation expm(Omega h/2) q, so the kinematics is derived
            % independently of vital.linear.eulerRates.
            q0 = vital.frames.eul2quat(z(7), z(8), z(9));
            x = [z(1:6); q0; z(10); z(11); -z(12)];
            xd = vital.plant.derivatives(x, z(13:16), tc.AC, tc.env);
            w = z(4:6);
            Om = [0 -w(1) -w(2) -w(3); w(1) 0 w(3) -w(2); w(2) -w(3) 0 w(1); w(3) w(2) -w(1) 0];
            h = 1e-6;
            ep = vital.frames.dcm2eul(vital.frames.quat2dcm(expm(0.5 * Om * h) * q0));
            em = vital.frames.dcm2eul(vital.frames.quat2dcm(expm(-0.5 * Om * h) * q0));
            y = [xd(1:6); (ep - em) / (2 * h); xd(11); xd(12); -xd(13)];
        end

        function n = loadFactor(tc, tr, a)
            % wind-axis normal load factor of the non-gravity forces, alpha = a
            x = tr.x; V = tr.y.V;
            x(1) = V * cos(a); x(3) = V * sin(a);
            [~, y] = vital.plant.derivatives(x, tr.u, tc.AC, tc.env);
            F = y.F_aero + y.F_prop;
            n = -(-sin(a) * F(1) + cos(a) * F(3)) / (tc.AC.mass * tc.env.g);
        end
    end

    methods (Test)
        function kinematicAndGravityEntriesAreExact(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            tc.verifyEqual(numel(lin.stepStudy), 16);
            tc.verifyExact(lin.stateNames, {'u','v','w','p','q','r','phi','theta','psi','pN','pE','h'}, ...
                'ANALYTIC', 'contract state order', 'Quantity', 'stateNames');
            tc.verifyExact(lin.inputNames, {'de','da','dr','throttle'}, 'ANALYTIC', 'contract input order', 'Quantity', 'inputNames');
            A = lin.A; g = tc.env.g; tr = tc.tr;
            u0 = tr.x(1); w0 = tr.x(3); th = tr.theta; ph = 0; psi = deg2rad(45);
            V = tr.y.V; qb = tr.y.qbar; m = tc.AC.mass; S = tc.AC.S; b = tc.AC.b; c = tc.AC.cbar;
            k = vital.units.constants();
            a = vital.models.f16.aero(struct('vt', V / k.ft, 'alpha', rad2deg(tr.alpha), 'beta', 0, ...
                'p', 0, 'q', 0, 'r', 0, 'el', rad2deg(tr.u(1)), 'ail', 0, 'rdr', 0));
            [U, Vv, W, P, Q, R, PHI, TH, PSI, PN, PE, H] = deal(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
            e = {U, TH, -g * cos(th), 'd udot/d theta = -g cos(theta)';
                 W, TH, -g * sin(th) * cos(ph), 'd wdot/d theta = -g sin(theta) cos(phi)';
                 Vv, PHI, g * cos(th) * cos(ph), 'd vdot/d phi = g cos(theta) cos(phi)';
                 U, Q, -w0 + qb * S * c * a.cxq / (2 * V * m), 'd udot/d q = -w0 + qbar S cbar CXq/(2Vm)';
                 W, Q, u0 + qb * S * c * a.czq / (2 * V * m), 'd wdot/d q = u0 + qbar S cbar CZq/(2Vm)';
                 Vv, P, w0 + qb * S * b * a.cyp / (2 * V * m), 'd vdot/d p = w0 + qbar S b CYp/(2Vm)';
                 Vv, R, -u0 + qb * S * b * a.cyr / (2 * V * m), 'd vdot/d r = -u0 + qbar S b CYr/(2Vm)';
                 PHI, P, 1, 'd phidot/d p = 1';
                 PHI, R, tan(th) * cos(ph), 'd phidot/d r = tan(theta) cos(phi)';
                 TH, Q, cos(ph), 'd thetadot/d q = cos(phi)';
                 PSI, R, cos(ph) / cos(th), 'd psidot/d r = cos(phi)/cos(theta)';
                 H, U, sin(th), 'd hdot/d u = sin(theta)';
                 H, W, -cos(ph) * cos(th), 'd hdot/d w = -cos(phi) cos(theta)';
                 H, TH, u0 * cos(th) + w0 * sin(th), 'd hdot/d theta = u0 cos(theta) + w0 sin(theta)';
                 PN, U, cos(psi) * cos(th), 'd pNdot/d u = cos(psi) cos(theta)';
                 PE, U, sin(psi) * cos(th), 'd pEdot/d u = sin(psi) cos(theta)';
                 PN, PSI, -tr.xdot(12), 'd pNdot/d psi = -pEdot0';
                 PE, PSI, tr.xdot(11), 'd pEdot/d psi = pNdot0'};
            for k2 = 1:size(e, 1)
                [i, j] = e{k2, 1:2};
                tc.verifyTol(A(i, j), e{k2, 3}, tc.tolFor(i, j), 'abs', 'ANALYTIC', ...
                    [e{k2, 4} ' (flat Earth, wings level; header (a))'], 'Quantity', e{k2, 4});
            end
            tc.verifyTol(A(TH, TH), 0, tc.tolFor(TH, TH), 'abs', 'ANALYTIC', 'zero rates: d thetadot/d theta = 0', 'Quantity', 'A(theta,theta)');
            tc.verifyExact(A(:, [PN PE]), zeros(12, 2), 'ANALYTIC', 'flat Earth: nothing depends on pN, pE', 'Quantity', 'A(:,[pN pE])');
            tc.verifyExact(lin.B(PHI:H, :), zeros(6, 4), 'ANALYTIC', 'kinematic rows do not depend on the controls', 'Quantity', 'B(phi:h,:)');
        end

        function firstOrderTaylorConsistency(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            z0 = [lin.x0; lin.u0];
            d = [1 0.5 0.5 0.02 0.02 0.02 0.02 0.01 0.01 10 10 10 0.005 0.005 0.005 0.01].';
            Wr = 1 ./ tc.fscale().';
            f0 = tc.fLin(z0);
            J = [lin.A lin.B];
            s = [1 0.5 0.25 0.125];
            e = zeros(size(s));
            for k = 1:numel(s)
                e(k) = max(abs(Wr .* (tc.fLin(z0 + s(k) * d) - f0 - J * (s(k) * d))));
            end
            for k = 1:numel(s) - 1
                tc.verifyWithin(e(k) / e(k + 1), 3, 5, 'ANALYTIC', 'Taylor remainder O(dx^2): ratio 4 per halving', ...
                    'Quantity', sprintf('remainder ratio s=%g', s(k)));
            end
        end

        function lonLatDecoupledAtSymmetricTrim(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            lon = [1 3 5 8]; lat = [2 4 6 7];
            tc.verifyExact(lin.lon.stateNames, {'u','w','q','theta'}, 'ANALYTIC', 'contract', 'Quantity', 'lon states');
            tc.verifyExact(lin.lat.stateNames, {'v','p','r','phi'}, 'ANALYTIC', 'contract', 'Quantity', 'lat states');
            tc.verifyExact(lin.lon.A, lin.A(lon, lon), 'ANALYTIC', 'partition = sub-block', 'Quantity', 'lon.A');
            tc.verifyExact(lin.lat.A, lin.A(lat, lat), 'ANALYTIC', 'partition = sub-block', 'Quantity', 'lat.A');
            tc.verifyExact(lin.lon.B, lin.B(lon, :), 'ANALYTIC', 'partition = sub-block', 'Quantity', 'lon.B');
            tc.verifyExact(lin.lat.B, lin.B(lat, :), 'ANALYTIC', 'partition = sub-block', 'Quantity', 'lat.B');
            blocks = {lon, lat, 'A'; lat, lon, 'A'};
            for k = 1:2
                rows = blocks{k, 1}; cols = blocks{k, 2};
                for i = rows
                    for j = cols
                        tc.verifyTol(lin.A(i, j), 0, tc.tolFor(i, j), 'abs', 'ANALYTIC', ...
                            'symmetric aircraft at a symmetric trim: lon/lat decoupled', ...
                            'Quantity', sprintf('A(%s,%s)', lin.stateNames{i}, lin.stateNames{j}));
                    end
                end
            end
            for i = lon
                for j = [2 3]
                    tc.verifyTol(lin.B(i, j), 0, tc.tolFor(i, 12 + j), 'abs', 'ANALYTIC', 'da, dr do not act longitudinally', ...
                        'Quantity', sprintf('B(%s,%s)', lin.stateNames{i}, lin.inputNames{j}));
                end
            end
            for i = lat
                for j = [1 4]
                    tc.verifyTol(lin.B(i, j), 0, tc.tolFor(i, 12 + j), 'abs', 'ANALYTIC', 'de, throttle do not act laterally', ...
                        'Quantity', sprintf('B(%s,%s)', lin.stateNames{i}, lin.inputNames{j}));
                end
            end
        end

        function airAxisForms(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            u0 = tc.tr.x(1); w0 = tc.tr.x(3); V = norm(tc.tr.x(1:3)); g = tc.env.g;
            T = [u0/V w0/V 0 0; -w0/V^2 u0/V^2 0 0; 0 0 1 0; 0 0 0 1];
            L = lin.lon.air;
            tc.verifyExact(L.stateNames, {'V','alpha','q','theta'}, 'ANALYTIC', 'contract', 'Quantity', 'lon air states');
            tc.verifyTol(L.A, T * lin.lon.A / T, 1e-12 * max(abs(L.A(:))), 'abs', 'ANALYTIC', ...
                'A_air = T A_lon T^-1', 'Quantity', 'lon air A');
            tc.verifyTol(L.B, T * lin.lon.B, 1e-12 * max(abs(L.B(:))), 'abs', 'ANALYTIC', 'B_air = T B_lon', 'Quantity', 'lon air B');
            gam = tc.tr.theta - tc.tr.alpha;
            tc.verifyTol(L.A(1, 4), -g * cos(gam), 1e-6 * g, 'abs', 'ANALYTIC', 'd Vdot/d theta = -g cos(gamma)', 'Quantity', 'dVdot/dtheta');
            tc.verifyTol(L.A(4, 3), 1, 1e-6, 'abs', 'ANALYTIC', 'wings level: thetadot = q', 'Quantity', 'dthetadot/dq');
            Lt = lin.lat.air;
            tc.verifyExact(Lt.stateNames, {'beta','p','r','phi'}, 'ANALYTIC', 'contract', 'Quantity', 'lat air states');
            Tl = diag([1/V 1 1 1]);
            tc.verifyTol(Lt.A, Tl * lin.lat.A / Tl, 1e-12 * max(abs(Lt.A(:))), 'abs', 'ANALYTIC', ...
                'beta = asin(v/V): d beta/d v = 1/V at beta = 0', 'Quantity', 'lat air A');
            tc.verifyTol(Lt.A(1, 4), g * cos(tc.tr.theta) / V, 1e-6 * g / V, 'abs', 'ANALYTIC', ...
                'd betadot/d phi = g cos(theta)/V', 'Quantity', 'dbetadot/dphi');
        end

        function nAlphaMatchesDirectLoadFactorSlope(tc)
            for tr = [tc.tr, tc.trClimb]
                lin = vital.linear.linearize(tc.AC, tc.env, tr);
                h = 1e-4;
                nd = (tc.loadFactor(tr, tr.alpha + h) - tc.loadFactor(tr, tr.alpha - h)) / (2 * h);
                tc.verifyTol(lin.n_alpha, nd, 1e-5, 'rel', 'ANALYTIC', ...
                    'n_alpha = -(V/g) Z_alpha + sin(gamma0) vs direct plant load-factor slope (header (e))', ...
                    'Quantity', sprintf('n_alpha, gamma %.0f deg', rad2deg(tr.cond.gamma)), 'Unit', '1/rad');
            end
        end

        function tableBreakpointIsReportedAsKink(tc)
            tr = tc.tr; V = tr.y.V;
            f = @(a) tc.plantAtAlpha(tr, V, a);
            [J, info] = vital.linear.jacobian(f, deg2rad(5), 1e-3, 'FScale', [9.8 9.8 9.8 1 1 1]);
            tc.verifyEqual(info.status, 'NOT_CONVERGED');
            tc.verifySubstring(info.reason, 'kink');
            tc.verifyTrue(all(isnan(J)), 'the derivative at a breakpoint is not reported');
        end

        function untrimmedIsRefused(tc)
            cond = struct('type', 'level', 'V', 150 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            bad = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(bad.status, 'INFEASIBLE');
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, bad), 'vital:linear:notTrimmed');
            fake = tc.tr; fake.status = 'OUT_OF_DATA_ENVELOPE';
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, fake), 'vital:linear:notTrimmed');
        end

        function badInputRefused(tc)
            t = tc.tr; t.x(1) = NaN;
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, t), 'vital:badInput');
            e = tc.env; e.g = NaN;
            tc.verifyError(@() vital.linear.linearize(tc.AC, e, tc.tr), 'vital:badInput');
            t = rmfield(tc.tr, 'x');
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, t), 'vital:badInput');
        end

        function controlRangesFromNescControlLaw(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            c = 'NESC F16_control.dml:1117-1185 scaling ail = -21.5 latStk, rdr = -30 pedal, |stick| <= 1 (NESC_EXTRACT_F16.md C.2)';
            tc.verifyExact(tc.AC.limits.da_deg, [-21.5 21.5], 'PUB', c, 'Quantity', 'aileron range', 'Unit', 'deg');
            tc.verifyExact(tc.AC.limits.dr_deg, [-30 30], 'PUB', c, 'Quantity', 'rudder range', 'Unit', 'deg');
            L = tc.AC.limits;
            tc.verifyTol(lin.inputRange, [deg2rad(L.de_deg); deg2rad(L.da_deg); deg2rad(L.dr_deg); L.throttle], 1e-15, 'abs', ...
                'ANALYTIC', 'input ranges in SI, rows de da dr throttle', 'Quantity', 'inputRange', 'Unit', 'rad, -');
        end
    end

    methods
        function y = plantAtAlpha(tc, tr, V, a)
            x = tr.x; x(1) = V * cos(a); x(3) = V * sin(a);
            xd = vital.plant.derivatives(x, tr.u, tc.AC, tc.env);
            y = xd(1:6);
        end
    end
end
