classdef (TestTags = {'M5'}) tRotatingEom < vital.test.VitalTestCase
%TROTATINGEOM  M5-C: rotating-Earth (ECEF) equations of motion, checked
%   ANALYTICALLY and against an INDEPENDENT inertial integration before any
%   NESC comparison is attempted.
%
%   Plant under test: vital.plant.derivativesRotating (state layout
%   [r_e; v_e; q_be; w_bi], see its header) and vital.eom.rotatingRigidBody.
%   Constants: TM Vol II Table 73 (vital.geo.constants).
%
%   PRE-REGISTERED expectations (written before the plant existed; no run was
%   made to choose them):
%   1. restInEcefWithSupportForce (ANALYTIC). A sphere (isotropic J) at rest
%      relative to the rotating Earth, co-rotating (w_bi = C_be w_ie), with an
%      applied force equal to minus m times GRAVITY (gravitation minus the
%      centrifugal term, -g + w x (w x r)):
%        |vdot_e| <= 1e-12 m/s^2 (round-off of a sum of ~10 m/s^2 terms is
%        ~1e-15), rdot = 0 exactly, |qdot| <= 1e-15, |wdot| <= 1e-15 rad/s^2.
%      60 s through vital.sim.run (dt = 0.1): position drift <= 1e-6 m,
%      velocity <= 1e-9 m/s, attitude (Euler w.r.t. NED) <= 1e-10 rad.
%   2. coriolisAccelerationAndDeflection (ANALYTIC). Same support force, the
%      body moving horizontally (100 m/s east at the Equator; 100 m/s north
%      at 45 deg N), body axes fixed in ECEF:
%        (a) vdot_e = -2 w x v_e to 1e-12 m/s^2 at t = 0;
%        (b) after T = 2 s (dt = 0.01): r(T) - r0 - v0 T = -(w x v0) T^2 within
%            7e-4 m per component. Neglected terms (derived): gravity
%            gradient along the path <= 3 (mu/r^3) v0 T^3 / 6 = 6.1e-4 m;
%            second-order Coriolis <= 4 w^2 v0 T^3/6 = 2.8e-6 m. The signal is
%            w v0 T^2 = 0.029 m, so a Coriolis sign error (0.058 m) fails.
%   3. matchesInertialIntegration (INDEP: ode45 in ECI, RelTol 1e-12). The NESC
%      brick (anisotropic) tumbling at [10 20 30] deg/s, no aero, J2 gravitation,
%      rotating Earth, 30 s at dt = 0.01. The ECI solution is mapped to ECEF
%      (ECI = ECEF at t = 0, TM Vol II p.603). At t = 30 s:
%        |r_e| error <= 1e-4 m, |v_e| <= 1e-6 m/s, attitude <= 1e-8 rad,
%        |w_bi| <= 1e-8 rad/s.
%      Rationale: ode45 with RelTol 1e-12 on |r| = 6.4e6 m leaves ~1e-5 m;
%      RK4 truncation at dt = 0.01 is ~1e-10 rad in attitude (w dt = 0.0065,
%      (w dt)^5/120 per step, 3000 steps) and negligible in position.
%   4. torqueFreeConservesInertialInvariants (ANALYTIC). The same run: the
%      rotational energy 1/2 w'Jw and the INERTIAL angular momentum C_ib J w_bi
%      (relative change <= 1e-10); the specific orbital energy with the J2
%      potential U = mu/r [1 - J2/2 (a/r)^2 (3 z^2/r^2 - 1)] and the polar
%      component of r_i x v_i (relative change <= 1e-11). The J2 field is
%      axisymmetric and time-invariant in ECI, so both are exact invariants.
%   5. j2GravitationMatchesAerospaceToolbox (INDEP). A particle at inertial rest
%      (v_e = -w x r_e), no loads: the inertial acceleration
%      vdot_e + 2 w x v_e + w x (w x r_e) equals gravityzonal(r, 'Custom', a,
%      mu, [J2 0 0]) to 1e-12 relative at 5 positions; y.localGravity equals
%      its magnitude (1e-12 relative; CONVENTIONS 4: NESC localGravity is the
%      gravitation magnitude, no centrifugal). Sphere with central gravitation:
%      -mu r/|r|^3 (ANALYTIC, 1e-13 relative).
%   6. rotationOffFlatEarthLimit (ANALYTIC limit). With rotation OFF, central
%      gravitation and a sphere 1000 times the Earth radius (mu scaled by 1e6
%      so that the surface gravitation is unchanged), the rotating plant must
%      reproduce vital.plant.derivatives (g = mu'/(R'+h)^2) for the NESC F-16
%      README trim with a 1 deg elevator doublet, 3 s at dt = 0.01:
%        |dV| <= 1e-4 m/s, |dalpha|, |dtheta| <= 1e-6 rad, |dq| <= 1e-6 rad/s,
%        |dh| <= 1e-3 m, |dbeta|, |dphi|, |dpsi|, |dp|, |dr| <= 1e-9.
%      Derived: the only differences are curvature terms V^2/R' = 4.6e-6
%      m/s^2 (dw <= 1.4e-5 m/s, dalpha <= 8e-8 rad, dh <= 2e-5 m) and the
%      transport rate V/R' = 2.7e-8 rad/s.
%   7. outputsAtKnownState (ANALYTIC + PUB). At the NESC case-11 initial
%      state with the SIM 5 attitude (theta 2.638926115 deg), y reproduces the
%      inputs (lat/lon 1e-12 rad, h 1e-6 m, Euler 1e-12 rad, V 1e-9 m/s,
%      alpha = theta 1e-12, beta 0, quatNorm 1 to 1e-15), and:
%        localGravity = 32.188575449192165 ft/s^2 (CSV Atmos_11 sim 5, t = 0;
%        tol 1e-9 ft/s^2 given the Table 73 constants);
%        w_bi = C_bn (w_ie + w_en) = [0.00253332038 -0.00393929166
%        -0.00313861707] deg/s (CSV sim 5 t = 0, 9 digits; tol 2e-11 deg/s).
%        The SIM 5 rate definition was checked with an independent Python
%        evaluation before registration (docs/nesc NESC_EXTRACT_F16 A, case 11).
%   8. Failure modes (exact identifiers): wrong state size, zero quaternion,
%      missing env field, unknown Earth model -> vital:badInput; altitude
%      100 km -> vital:env:altitudeOutOfRange; non-finite loads ->
%      vital:plant:nonFinite; a non-unit quaternion in vital.sim.run stops
%      with vital:sim:quatNorm (the rotating plant opts into the FC-601 guard).

    properties
        Ft = 0.3048
        K
        Env
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.K = vital.geo.constants('wgs84');
            tc.Env = struct('earth', 'wgs84', 'rotation', true, 'gravity', 'J2', ...
                'wind_n', [0;0;0], 'windGradient_n', [0;0;0], 'deltaT', 0);
        end
    end

    methods (Access = private)
        function [AC, x0, F0] = supportedSphere(tc, latd, lond, h, v_ned)
            % Sphere co-rotating with the Earth, supported against GRAVITY.
            K = tc.K; w = [0; 0; K.omega];
            lat = deg2rad(latd); lon = deg2rad(lond);
            C_ne = vital.geo.dcmEcefToNed(lat, lon);
            C_bn = vital.frames.dcm321(0, 0, 0);
            w_bi = C_bn * C_ne * w;
            x0 = vital.eom.rotatingState(lat, lon, h, v_ned, [0; 0; 0], w_bi, K);
            r = x0(1:3);
            gravity_e = vital.geo.gravitation(r, K) - cross(w, cross(w, r));
            AC = vital.nesc.vehicle('cannonball');
            C_be = C_bn * C_ne;
            F0 = -AC.mass * C_be * gravity_e;
            AC.loadsFcn = @(ad, u, hh, atm, A) constantLoad(F0);
        end
    end

    methods (Test)
        function restInEcefWithSupportForce(tc)
            [AC, x0] = tc.supportedSphere(36.0191667, -75.6744444, 3000, [0; 0; 0]);
            [xd, y] = vital.plant.derivativesRotating(x0, [], AC, tc.Env);
            c = 'body at rest in ECEF, support = -m (gravitation + centrifugal); class header 1';
            tc.verifyTol(xd(4:6), zeros(3,1), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'vdot_e', 'Unit', 'm/s2');
            tc.verifyTol(xd(1:3), zeros(3,1), 0, 'abs', 'ANALYTIC', c, 'Quantity', 'rdot_e', 'Unit', 'm/s');
            tc.verifyTol(xd(7:10), zeros(4,1), 1e-15, 'abs', 'ANALYTIC', c, 'Quantity', 'qdot', 'Unit', '1/s');
            tc.verifyTol(xd(11:13), zeros(3,1), 1e-15, 'abs', 'ANALYTIC', c, 'Quantity', 'wdot', 'Unit', 'rad/s2');
            tc.verifyTol(y.V, 0, 0, 'abs', 'ANALYTIC', c, 'Quantity', 'airspeed', 'Unit', 'm/s');
            out = vital.sim.run(AC, tc.Env, x0, [], 'dt', 0.1, 'tFinal', 60, 'Plant', @vital.plant.derivativesRotating);
            tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
            tc.verifyTol(out.x(1:3, end), x0(1:3), 1e-6, 'abs', 'ANALYTIC', c, 'Quantity', 'position drift 60 s', 'Unit', 'm');
            tc.verifyTol(out.x(4:6, end), zeros(3,1), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'velocity 60 s', 'Unit', 'm/s');
            e = [out.y.phi; out.y.theta; out.y.psi];
            tc.verifyTol(e(:, end), e(:, 1), 1e-10, 'abs', 'ANALYTIC', c, 'Quantity', 'attitude drift 60 s', 'Unit', 'rad');
        end

        function coriolisAccelerationAndDeflection(tc)
            w = [0; 0; tc.K.omega];
            cases = {0, 0, [0; 100; 0]; 45, 10, [100; 0; 0]};
            for k = 1:size(cases, 1)
                [AC, x0] = tc.supportedSphere(cases{k, 1}, cases{k, 2}, 1000, cases{k, 3});
                v0 = x0(4:6);
                xd = vital.plant.derivativesRotating(x0, [], AC, tc.Env);
                tc.verifyTol(xd(4:6), -2 * cross(w, v0), 1e-12, 'abs', 'ANALYTIC', ...
                    'Coriolis acceleration -2 w x v (support cancels gravity); class header 2a', ...
                    'Quantity', sprintf('vdot_e at lat %g', cases{k, 1}), 'Unit', 'm/s2');
                T = 2;
                out = vital.sim.run(AC, tc.Env, x0, [], 'dt', 0.01, 'tFinal', T, 'Plant', @vital.plant.derivativesRotating);
                tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
                defl = out.x(1:3, end) - x0(1:3) - v0 * T;
                tc.verifyTol(defl, -cross(w, v0) * T^2, 7e-4, 'abs', 'ANALYTIC', ...
                    'Coriolis deflection -(w x v0) T^2; neglected terms derived in class header 2b', ...
                    'Quantity', sprintf('deflection at lat %g', cases{k, 1}), 'Unit', 'm');
            end
        end

        function matchesInertialIntegration(tc)
            [out, AC, x0] = tumblingBrick(tc.K, tc.Env, 30);
            w = tc.K.omega;
            s0 = vital.eom.rotatingToInertial(x0, 0, w);
            q0 = vital.frames.dcm2quat(s0.C_bi);
            z0 = [s0.r_i; s0.v_i; q0; x0(11:13)];
            opt = odeset('RelTol', 1e-12, 'AbsTol', [1e-7*ones(3,1); 1e-10*ones(3,1); 1e-14*ones(4,1); 1e-14*ones(3,1)]);
            [~, Z] = ode45(@(t, z) eciRhs(z, AC.J, tc.K), [0 15 30], z0, opt);
            z = Z(end, :).';
            Cei = [cos(w*30) sin(w*30) 0; -sin(w*30) cos(w*30) 0; 0 0 1];
            r_e = Cei * z(1:3);
            v_e = Cei * z(4:6) - cross([0; 0; w], r_e);
            C_be = vital.frames.quat2dcm(z(7:10) / norm(z(7:10))) * Cei.';
            xe = out.x(:, end);
            C_vit = vital.frames.quat2dcm(xe(7:10) / norm(xe(7:10)));
            dC = C_vit * C_be.';
            ang = norm([dC(2,3) - dC(3,2); dC(3,1) - dC(1,3); dC(1,2) - dC(2,1)]) / 2;
            c = 'ode45 (RelTol 1e-12) in ECI, mapped to ECEF; class header 3';
            tc.verifyTol(xe(1:3), r_e, 1e-4, 'abs', 'INDEP', c, 'Quantity', 'r_e at 30 s', 'Unit', 'm');
            tc.verifyTol(xe(4:6), v_e, 1e-6, 'abs', 'INDEP', c, 'Quantity', 'v_e at 30 s', 'Unit', 'm/s');
            tc.verifyTol(ang, 0, 1e-8, 'abs', 'INDEP', c, 'Quantity', 'attitude error at 30 s', 'Unit', 'rad');
            tc.verifyTol(xe(11:13), z(11:13), 1e-8, 'abs', 'INDEP', c, 'Quantity', 'w_bi at 30 s', 'Unit', 'rad/s');
        end

        function torqueFreeConservesInertialInvariants(tc)
            [out, AC] = tumblingBrick(tc.K, tc.Env, 30);
            n = numel(out.t); w = tc.K.omega; K = tc.K;
            Erot = zeros(1, n); H = zeros(3, n); E = zeros(1, n); hz = zeros(1, n);
            for i = 1:n
                s = vital.eom.rotatingToInertial(out.x(:, i), out.t(i), w);
                wb = out.x(11:13, i);
                Erot(i) = 0.5 * wb.' * AC.J * wb;
                H(:, i) = s.C_bi.' * (AC.J * wb);
                r = norm(s.r_i);
                U = K.mu / r * (1 - K.J2 / 2 * (K.a / r)^2 * (3 * (s.r_i(3) / r)^2 - 1));
                E(i) = 0.5 * (s.v_i.' * s.v_i) - U;
                hv = cross(s.r_i, s.v_i); hz(i) = hv(3);
            end
            c = 'torque-free body in the axisymmetric J2 field: exact invariants in ECI; class header 4';
            tc.verifyTol(max(abs(Erot - Erot(1))) / Erot(1), 0, 1e-10, 'abs', 'ANALYTIC', c, 'Quantity', 'rotational energy (rel)');
            tc.verifyTol(max(vecnorm(H - H(:, 1))) / norm(H(:, 1)), 0, 1e-10, 'abs', 'ANALYTIC', c, 'Quantity', 'inertial angular momentum (rel)');
            tc.verifyTol(max(abs(E - E(1))) / abs(E(1)), 0, 1e-11, 'abs', 'ANALYTIC', c, 'Quantity', 'orbital energy (rel)');
            tc.verifyTol(max(abs(hz - hz(1))) / abs(hz(1)), 0, 1e-11, 'abs', 'ANALYTIC', c, 'Quantity', 'polar angular momentum (rel)');
        end

        function j2GravitationMatchesAerospaceToolbox(tc)
            K = tc.K; w = [0; 0; K.omega];
            AC = vital.nesc.vehicle('cannonball');
            AC.loadsFcn = @(ad, u, hh, atm, A) constantLoad([0; 0; 0]);
            P = [0 0 1000; 36.0191667 -75.6744444 3052; -60 120 9144; 80 -45 100; 89.95 -45 3048];
            for k = 1:size(P, 1)
                lat = deg2rad(P(k, 1)); lon = deg2rad(P(k, 2));
                r = vital.geo.lla2ecef(lat, lon, P(k, 3), K);
                v_ned = vital.geo.dcmEcefToNed(lat, lon) * (-cross(w, r));
                x = vital.eom.rotatingState(lat, lon, P(k, 3), v_ned, [0; 0; 0], [0; 0; 0], K);
                [xd, y] = vital.plant.derivativesRotating(x, [], AC, tc.Env);
                ve = x(4:6);
                a_i = xd(4:6) + 2 * cross(w, ve) + cross(w, cross(w, x(1:3)));
                [gx, gy, gz] = gravityzonal(x(1:3).', 'Custom', K.a, K.mu, [K.J2 0 0]);
                gref = [gx; gy; gz];
                % 1e-12 relative to |g| (components are exactly 0 on the Equator)
                tc.verifyTol(a_i, gref, 1e-12 * norm(gref), 'abs', 'INDEP', 'Aerospace Toolbox gravityzonal, Custom J2 (TM Table 73 constants); tol 1e-12 |g|', ...
                    'Quantity', sprintf('inertial acceleration at lat %g', P(k, 1)), 'Unit', 'm/s2');
                tc.verifyTol(y.localGravity, norm(gref), 1e-12, 'rel', 'INDEP', 'gravitation magnitude (CONVENTIONS 4)', ...
                    'Quantity', sprintf('localGravity at lat %g', P(k, 1)), 'Unit', 'm/s2');
            end
            envS = tc.Env; envS.earth = 'sphere'; envS.gravity = 'central';
            KS = vital.geo.constants('sphere');
            x = vital.eom.rotatingState(0.3, 0.4, 5000, [0; 0; 0], [0; 0; 0], [0; 0; 0], KS);
            x(4:6) = -cross(w, x(1:3));
            xd = vital.plant.derivativesRotating(x, [], AC, envS);
            a_i = xd(4:6) + 2 * cross(w, x(4:6)) + cross(w, cross(w, x(1:3)));
            gc = -KS.mu * x(1:3) / norm(x(1:3))^3;
            tc.verifyTol(a_i, gc, 1e-13 * norm(gc), 'abs', 'ANALYTIC', 'inverse square (TM eq. 27); tol 1e-13 |g|', ...
                'Quantity', 'sphere inertial acceleration', 'Unit', 'm/s2');
        end

        function rotationOffFlatEarthLimit(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'g_ftps2', 32.174);
            tc.assertEqual(r.status, 'OK');
            KS = vital.geo.constants('sphere');
            KS.R = 1000 * KS.R; KS.a = KS.R; KS.b = KS.R; KS.mu = KS.mu * 1e6;
            h = 10013 * tc.Ft;
            env = struct('earth', KS, 'rotation', false, 'gravity', 'central', 'wind_n', [0;0;0], 'windGradient_n', [0;0;0], 'deltaT', 0);
            envF = struct('g', KS.mu / (KS.R + h)^2, 'wind_n', [0;0;0], 'deltaT', 0);
            tr = vital.trim.solve(vital.aircraft.f16.config(), envF, ...
                struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', h, 'gamma', 0, 'psi', 0));
            tc.assertEqual(tr.status, 'OK');
            AC = vital.aircraft.f16.config();
            C_bn = vital.frames.quat2dcm(tr.x(7:10));
            v_ned = C_bn.' * tr.x(1:3);
            nav = vital.eom.navRates(0, h, v_ned, KS, 0);
            w_bi = tr.x(4:6) + C_bn * nav.w_en_n;
            x0 = vital.eom.rotatingState(0, 0, h, v_ned, [0; tr.theta; 0], w_bi, KS);
            in = vital.sim.doublet(0.5, 0.5, deg2rad(1), 'elevator');
            oF = vital.sim.run(AC, envF, tr.x, tr.u, 'dt', 0.01, 'tFinal', 3, 'Inputs', in);
            oR = vital.sim.run(AC, env, x0, tr.u, 'dt', 0.01, 'tFinal', 3, 'Inputs', in, 'Plant', @vital.plant.derivativesRotating);
            tc.assertEqual(oR.status, 'COMPLETED', oR.stopReason);
            c = 'flat-earth limit of the rotating plant (R x 1000, rotation off); bounds derived in class header 6';
            tc.verifyTol(oR.y.V, oF.y.V, 1e-4, 'abs', 'ANALYTIC', c, 'Quantity', 'V', 'Unit', 'm/s');
            tc.verifyTol(oR.y.alpha, oF.y.alpha, 1e-6, 'abs', 'ANALYTIC', c, 'Quantity', 'alpha', 'Unit', 'rad');
            tc.verifyTol(oR.y.theta, oF.y.theta, 1e-6, 'abs', 'ANALYTIC', c, 'Quantity', 'theta', 'Unit', 'rad');
            tc.verifyTol(oR.y.w_bn(2, :), oF.y.q, 1e-6, 'abs', 'ANALYTIC', c, 'Quantity', 'q (w.r.t. local level)', 'Unit', 'rad/s');
            tc.verifyTol(oR.y.h, oF.y.h, 1e-3, 'abs', 'ANALYTIC', c, 'Quantity', 'h', 'Unit', 'm');
            tc.verifyTol([oR.y.beta; oR.y.phi; oR.y.psi; oR.y.w_bn([1 3], :)], ...
                [oF.y.beta; oF.y.phi; oF.y.psi; oF.y.p; oF.y.r], 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'lateral states', 'Unit', 'rad, rad/s');
        end

        function outputsAtKnownState(tc)
            K = tc.K; ft = tc.Ft;
            lat = deg2rad(36.01916667); lon = deg2rad(-75.67444444); h = 10013 * ft;
            v_ned = [400; 400; 0] * ft; th = deg2rad(2.638926115); ps = deg2rad(45);
            C_bn = vital.frames.dcm321(0, th, ps);
            nav = vital.eom.navRates(lat, h, v_ned, K, K.omega);
            x = vital.eom.rotatingState(lat, lon, h, v_ned, [0; th; ps], C_bn * nav.w_in_n, K);
            [~, y] = vital.plant.derivativesRotating(x, [0; 0; 0; 0.14], vital.aircraft.f16.config(), tc.Env);
            c = 'plant outputs reproduce the state (ANALYTIC)';
            tc.verifyTol([y.lat; y.lon], [lat; lon], 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'lat, lon', 'Unit', 'rad');
            tc.verifyTol(y.h, h, 1e-6, 'abs', 'ANALYTIC', c, 'Quantity', 'h', 'Unit', 'm');
            tc.verifyTol([y.phi; y.theta; y.psi], [0; th; ps], 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'Euler w.r.t. NED', 'Unit', 'rad');
            tc.verifyTol(y.V, norm(v_ned), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'TAS (still air)', 'Unit', 'm/s');
            tc.verifyTol([y.alpha; y.beta], [th; 0], 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'alpha, beta (level)', 'Unit', 'rad');
            tc.verifyTol(y.quatNorm, 1, 1e-15, 'abs', 'ANALYTIC', c, 'Quantity', '|q|');
            tc.verifyTol(y.v_ned, v_ned, 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'v_ned', 'Unit', 'm/s');
            tc.verifyTol(y.localGravity / ft, 32.188575449192165, 1e-9, 'abs', 'PUB', ...
                'NESC Atmos_11_sim_05.csv t = 0 localGravity_ft_s2 (TM Vol II Table 75)', 'Quantity', 'localGravity', 'Unit', 'ft/s2');
            tc.verifyTol(rad2deg(y.w_bi), [0.00253332038; -0.00393929166; -0.00313861707], 2e-11, 'abs', 'PUB', ...
                'NESC Atmos_11_sim_05.csv t = 0 bodyAngularRateWrtEi (SIM 5 holds Euler angles w.r.t. local level, TM Vol II p.228)', ...
                'Quantity', 'w_bi', 'Unit', 'deg/s');
            tc.verifyFalse(logical(y.outOfEnvelope), 'case-11 state is inside the F-16 tables');
        end

        % ---- failure modes -----------------------------------------------------------
        function badStateAndEnvRejected(tc)
            AC = vital.nesc.vehicle('cannonball');
            x = vital.eom.rotatingState(0, 0, 9144, [0; 0; 0], [0; 0; 0], [0; 0; 0], tc.K);
            tc.verifyError(@() vital.plant.derivativesRotating(x(1:12), [], AC, tc.Env), 'vital:badInput');
            xz = x; xz(7:10) = 0;
            tc.verifyError(@() vital.plant.derivativesRotating(xz, [], AC, tc.Env), 'vital:badInput');
            e1 = rmfield(tc.Env, 'rotation');
            tc.verifyError(@() vital.plant.derivativesRotating(x, [], AC, e1), 'vital:badInput');
            e2 = tc.Env; e2.earth = 'flat';
            tc.verifyError(@() vital.plant.derivativesRotating(x, [], AC, e2), 'vital:badInput');
            xh = vital.eom.rotatingState(0, 0, 100e3, [0; 0; 0], [0; 0; 0], [0; 0; 0], tc.K);
            tc.verifyError(@() vital.plant.derivativesRotating(xh, [], AC, tc.Env), 'vital:env:altitudeOutOfRange');
            AC.loadsFcn = @(ad, u, hh, atm, A) constantLoad([NaN; 0; 0]);
            tc.verifyError(@() vital.plant.derivativesRotating(x, [], AC, tc.Env), 'vital:plant:nonFinite');
        end

        function quaternionGuardStopsRotatingRun(tc)
            AC = vital.nesc.vehicle('cannonball');
            x = vital.eom.rotatingState(0, 0, 9144, [0; 0; 0], [0; 0; 0], [0; 0; 0], tc.K);
            x(7:10) = 1.1 * x(7:10);
            out = vital.sim.run(AC, tc.Env, x, [], 'dt', 0.01, 'tFinal', 1, 'Plant', @vital.plant.derivativesRotating);
            tc.verifyEqual(out.status, 'STOPPED');
            tc.verifyEqual(out.stopReason, 'vital:sim:quatNorm');
        end
    end
end

% ---- local functions ----------------------------------------------------------------
function [F_R, M_R, info] = constantLoad(F0)
F_R = F0(:); M_R = [0; 0; 0];
info = struct('outOfEnvelope', false, 'F_aero', F0(:), 'M_aero', [0; 0; 0]);
end

function [out, AC, x0] = tumblingBrick(K, env, T)
AC = vital.nesc.vehicle('brick');
AC.loadsFcn = @(ad, u, hh, atm, A) constantLoad([0; 0; 0]);
lat = deg2rad(20); lon = deg2rad(30);
x0 = vital.eom.rotatingState(lat, lon, 9144, [100; -50; -30], deg2rad([10; 20; 30]), deg2rad([10; 20; 30]), K);
out = vital.sim.run(AC, env, x0, [], 'dt', 0.01, 'tFinal', T, 'Plant', @vital.plant.derivativesRotating);
if ~strcmp(out.status, 'COMPLETED')
    error('vital:test:runStopped', 'tumbling-brick run stopped: %s', out.stopReason);
end
end

function zd = eciRhs(z, J, K)
r = z(1:3); v = z(4:6); q = z(7:10); w = z(11:13);
g = vital.geo.gravitation(r, K);
p = w(1); qq = w(2); rr = w(3);
Om = [0 -p -qq -rr; p 0 rr -qq; qq -rr 0 p; rr qq -p 0];
zd = [v; g; 0.5 * Om * q; J \ (-cross(w, J * w))];
end
