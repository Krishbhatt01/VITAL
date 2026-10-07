classdef (TestTags = {'M5'}) tLinearizeR1 < vital.test.VitalTestCase
%TLINEARIZER1  Findings of review R1 (reports/work/review1/REVIEW.md) for
%   vital.linear.linearize: B1, B2, M1, M2, M4, M12, MINOR 6 and 7.
%
%   PRE-REGISTERED (written before the fixes):
%   B1  Equilibrium. linearize requires ||W f0(1:8)||_inf <= TrimTol = 1e-8, with
%       W = [1/g x3, 1 (rad/s^2) x3, 1 (rad/s) x2]; otherwise
%       vital:linear:notEquilibrium.
%       Rationale: vital.trim.solve accepts a scaled residual < 1e-9, so an OK
%       trim is always inside 1e-8 (R1 measured 3e-16). The rows phi-dot and
%       theta-dot must vanish in a steady trim.
%       Cases that must be refused:
%         - a CG-25 % trim linearized with the CG-30 % aircraft (R1: qdot = 0.208 rad/s^2)
%         - a trim at g = 32.174 ft/s^2 linearized with g = 9.80665 m/s^2
%           (relative gravity error 1.5e-6, i.e. 1.5e-6 in W units)
%       run_f16_modes must pass its own CG and g on: CG 30 % and g = 32.0 ft/s^2 are OK.
%   B2  n_alpha_ss: MIL-F-8785C 6.2 (p.77; docs/MIL8785C_EXTRACT.md sec. 4), the
%       steady-state normal acceleration per alpha for an incremental
%       pitch-control deflection at constant speed. With dV = 0 the [alpha q]
%       rows give 0 = A_sp [alpha; q] + b_de de, and n/alpha = (V/g) q/alpha:
%         q/alpha = (M_a Z_d - Z_a M_d) / (M_d (1 + Z_q) - M_q Z_d)
%       where A_sp = [Z_a, 1 + Z_q; M_a, M_q] and b = [Z_d; M_d]. This holds in
%       level flight only; |gamma0| > 1e-6 gives NaN with status NOT_LEVEL.
%       Checks:
%         - ANALYTIC on a synthetic model (1e-12 relative)
%         - INDEP: equals vital.fq.metrics n_alpha_g_per_rad (fq agent's
%           implementation) at the README trim and at CG 30 %, 1e-10 relative
%         - INDEP: README value 14.766 g/rad (R1, REVIEW.md sec. 1), +/- 0.01
%         - lin.n_alpha (the alpha-only partial) is kept and differs from it
%   M1  Per-column status: lin.columnStatus (1x16, jacobian study statuses). At the
%       20,000 ft trim (565.6854 ft/s) the h column sits on the thrust-table
%       breakpoint (F16_prop bp2 = 0:10000:50000 ft):
%         - lin.status NOT_CONVERGED, reason names 'column 12 (h)' and 'kink'
%         - A(:,12) all NaN; columnStatus{12} = 'KINK', every other column 'OK'
%         - modes(lin) returns the five classic modes (it uses columns 1-8 only)
%         - modes(lin, 'IncludeHeight', true) -> vital:linear:notConverged
%   M2  The same case is the end-to-end FC-506/FC-510 check through linearize.
%   M4  vital.linear.eulerRates (used by linearize), tested at phi = 30 deg,
%       theta = 10 deg, [p q r] = [0.3 -0.2 0.1] rad/s against Euler rates
%       derived independently: central difference (h = 1e-5 s) of
%       dcm2eul(quat2dcm(expm(Omega t/2) q0)), within 1e-8 rad/s. R1 found
%       [0.29763767 -0.22320508 -0.013604137] (4.9e-11). Its Jacobian with
%       respect to (phi, theta, p, q, r) must equal the analytic partials to 1e-8:
%         d phidot/d phi = (q cphi - r sphi) tth,  d phidot/d theta = (q sphi + r cphi)/cth^2
%         d thetadot/d phi = -q sphi - r cphi
%         d psidot/d phi = (q cphi - r sphi)/cth,  d psidot/d theta = (q sphi + r cphi) sth/cth^2
%         d/d[p q r] = [1 sphi tth cphi tth; 0 cphi -sphi; 0 sphi/cth cphi/cth]
%   M12 Tighter checks (new; the old ones are kept):
%         - the lon/lat cross blocks of A and B at the README trim are exactly 0
%           (R1: error 0)
%         - the tF16Linearize (a) entries lie within 1e-8 FScale/ZScale
%   MINOR 6  gamma0 without tr.cond comes from f0: a 5 deg climb gives 5 deg to 1e-9.
%   MINOR 7  With a steady headwind (wind_n = [-10 0 0] m/s, heading north) the
%       air-axis converters T_lon, T_lat equal a central difference (1e-6) of
%       [V alpha beta](x_lin) with v_air = v_b - C_bn(phi, theta, psi) w_n, to 1e-8.

    properties
        AC
        env
        tr
        Ft = 0.3048
    end

    properties (Constant)
        ZSCALE = [10 10 10 1 1 1 1 1 1 1000 1000 1000 0.1 0.1 0.1 1]
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, tc.cond(565.6854, 10013, 0));
            tc.assertEqual(tc.tr.status, 'OK');
        end
    end

    methods (Access = private)
        function c = cond(tc, V, h, gam)
            c = struct('type', 'level', 'V', V * tc.Ft, 'h', h * tc.Ft, 'gamma', deg2rad(gam), 'psi', 0);
            if gam ~= 0, c.type = 'climb'; end
        end
    end

    methods (Static, Access = private)
        function e = quatEulerRates(ph, th, ps, w)
            q0 = vital.frames.eul2quat(ph, th, ps);
            Om = [0 -w(1) -w(2) -w(3); w(1) 0 w(3) -w(2); w(2) -w(3) 0 w(1); w(3) w(2) -w(1) 0];
            h = 1e-5;
            ep = vital.frames.dcm2eul(vital.frames.quat2dcm(expm(0.5 * Om * h) * q0));
            em = vital.frames.dcm2eul(vital.frames.quat2dcm(expm(-0.5 * Om * h) * q0));
            e = (ep - em) / (2 * h);
        end
    end

    methods (Test)
        % ---- B1 ------------------------------------------------------------------
        function cgMismatchIsNotAnEquilibrium(tc)
            AC30 = vital.aircraft.f16.config('CG_PCT_MAC', 30);
            tc.verifyError(@() vital.linear.linearize(AC30, tc.env, tc.tr), 'vital:linear:notEquilibrium');
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            tc.assertTrue(isfield(lin, 'equilibriumResidual'), 'R1 B1: lin.equilibriumResidual exists');
            tc.verifyWithin(lin.equilibriumResidual, 0, 1e-8, 'ANALYTIC', 'an OK trim is an equilibrium (B1)', ...
                'Quantity', 'weighted equilibrium residual');
        end

        function gravityMismatchIsNotAnEquilibrium(tc)
            e = tc.env; e.g = 9.80665;
            tc.verifyError(@() vital.linear.linearize(tc.AC, e, tc.tr), 'vital:linear:notEquilibrium');
        end

        function runF16ModesPassesItsOwnCgAndGravity(tc)
            r = run_f16_modes(565.6854, 10013, 'CG', 30);
            tc.verifyEqual(r.status, 'OK', r.reason);
            r = run_f16_modes(565.6854, 10013, 'g_ftps2', 32.0);
            tc.verifyEqual(r.status, 'OK', r.reason);
        end

        % ---- B2 ------------------------------------------------------------------
        function nAlphaSteadyClosedForm(tc)
            Za = -0.9; Zq = -0.02; Zd = -0.12; Ma = -6.1; Mq = -1.4; Md = -9.7; V = 170; g = 9.8;
            Aair = [-0.01 1 0 -9.8; 0.001 Za 1 + Zq 0; 0 Ma Mq 0; 0 0 1 0];
            Bair = [0.5 0 0 2; Zd 0 0 0; Md 0 0 0; 0 0 0 0];
            [n, st] = vital.linear.nAlphaSteady(Aair, Bair, V, g, 0);
            tc.verifyEqual(st, 'OK');
            e = (V / g) * (Ma * Zd - Za * Md) / (Md * (1 + Zq) - Mq * Zd);
            tc.verifyTol(n, e, 1e-12, 'rel', 'ANALYTIC', 'constant-speed steady state per de (B2 closed form)', ...
                'Quantity', 'n_alpha_ss synthetic', 'Unit', 'g/rad');
            [n, st] = vital.linear.nAlphaSteady(Aair, Bair, V, g, deg2rad(3));
            tc.verifyEqual(st, 'NOT_LEVEL');
            tc.verifyTrue(isnan(n), 'no number outside level flight');
        end

        function nAlphaSteadyEqualsFqMetric(tc)
            for cg = [25 30]
                AC = vital.aircraft.f16.config('CG_PCT_MAC', cg);
                tr = vital.trim.solve(AC, tc.env, tc.cond(565.6854, 10013, 0));
                tc.assertEqual(tr.status, 'OK');
                lin = vital.linear.linearize(AC, tc.env, tr);
                tc.assertTrue(isfield(lin, 'n_alpha_ss'), 'R1 B2: lin.n_alpha_ss exists');
                tc.verifyEqual(lin.n_alpha_ss_status, 'OK');
                M = vital.fq.metrics(lin, vital.linear.modes(lin));
                tc.verifyTol(lin.n_alpha_ss, M.n_alpha_g_per_rad.value, 1e-10, 'rel', 'INDEP', ...
                    'vital.fq.metrics n_alpha_g_per_rad (fq agent implementation of MIL-F-8785C 6.2 p.77)', ...
                    'Quantity', sprintf('n_alpha_ss vs fq, CG %d', cg), 'Unit', 'g/rad');
                if cg == 25
                    tc.verifyTol(lin.n_alpha_ss, 14.766, 0.01, 'abs', 'INDEP', ...
                        'R1 independent steady-state value (REVIEW.md section 1)', 'Quantity', 'n_alpha_ss README', 'Unit', 'g/rad');
                    tc.verifyGreaterThan(abs(lin.n_alpha - lin.n_alpha_ss), 0.05, ...
                        'n_alpha (alpha partial) is a different quantity from the MIL n/alpha');
                end
            end
        end

        % ---- M1 / M2 --------------------------------------------------------------
        function breakpointTrimIsNotConverged(tc)
            tr = vital.trim.solve(tc.AC, tc.env, tc.cond(565.6854, 20000, 0));
            tc.assertEqual(tr.status, 'OK');
            lin = vital.linear.linearize(tc.AC, tc.env, tr);
            tc.assertTrue(isfield(lin, 'columnStatus'), 'R1 M1: lin.columnStatus exists');
            tc.verifyEqual(lin.status, 'NOT_CONVERGED');
            tc.verifySubstring(lin.reason, 'column 12 (h)');
            tc.verifySubstring(lin.reason, 'kink');
            tc.verifyTrue(all(isnan(lin.A(:, 12))), 'the kinked column is NaN');
            exp = repmat({'OK'}, 1, 16); exp{12} = 'KINK';
            tc.verifyExact(lin.columnStatus, exp, 'ANALYTIC', 'only the h column sits on a breakpoint (20,000 ft)', ...
                'Quantity', 'columnStatus');
            m = vital.linear.modes(lin);
            tc.verifyExact(sort({m.name}), sort({'short_period','phugoid','dutch_roll','roll','spiral'}), 'ANALYTIC', ...
                'modes uses columns 1-8 only (M1)', 'Quantity', 'mode names at 20,000 ft');
            tc.verifyError(@() vital.linear.modes(lin, 'IncludeHeight', true), 'vital:linear:notConverged');
        end

        % ---- M4 ------------------------------------------------------------------
        function eulerRatesMatchQuaternionKinematics(tc)
            ph = deg2rad(30); th = deg2rad(10); ps = deg2rad(20); w = [0.3; -0.2; 0.1];
            e = vital.linear.eulerRates(ph, th, w(1), w(2), w(3));
            ref = tLinearizeR1.quatEulerRates(ph, th, ps, w);
            tc.verifyTol(e, ref, 1e-8, 'abs', 'INDEP', ...
                'central difference of dcm2eul along the quaternion rotation expm(Omega t/2) q0 (M4)', ...
                'Quantity', 'Euler rates, non-level', 'Unit', 'rad/s');
            tc.verifyTol(ref, [0.29763767; -0.22320508; -0.013604137], 1e-8, 'abs', 'INDEP', ...
                'R1 independent value (REVIEW.md section 1)', 'Quantity', 'quaternion-derived rates', 'Unit', 'rad/s');
        end

        function eulerRatesJacobianIsAnalytic(tc)
            ph = deg2rad(30); th = deg2rad(10); z0 = [ph; th; 0.3; -0.2; 0.1];
            [J, info] = vital.linear.jacobian(@(z) vital.linear.eulerRates(z(1), z(2), z(3), z(4), z(5)), z0, 1e-2);
            tc.assertEqual(info.status, 'OK');
            q = z0(4); r = z0(5); c1 = cos(ph); s1 = sin(ph); c2 = cos(th); s2 = sin(th); t2 = tan(th);
            Je = [(q*c1 - r*s1)*t2, (q*s1 + r*c1)/c2^2, 1, s1*t2, c1*t2;
                  -q*s1 - r*c1, 0, 0, c1, -s1;
                  (q*c1 - r*s1)/c2, (q*s1 + r*c1)*s2/c2^2, 0, s1/c2, c1/c2];
            tc.verifyTol(J, Je, 1e-8, 'abs', 'ANALYTIC', '3-2-1 kinematics partials (M4)', 'Quantity', 'd eulerRates / d(phi theta p q r)');
        end

        % ---- M12 -----------------------------------------------------------------
        function tighterLinearizationChecks(tc)
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            lon = [1 3 5 8]; lat = [2 4 6 7];
            tc.verifyExact([lin.A(lon, lat), lin.A(lat, lon).'], zeros(4, 8), 'ANALYTIC', ...
                'mirror symmetry: cross blocks exactly zero (M12)', 'Quantity', 'A cross blocks');
            tc.verifyExact([lin.B(lon, [2 3]), lin.B(lat, [1 4])], zeros(4, 4), 'ANALYTIC', ...
                'mirror symmetry: cross blocks exactly zero (M12)', 'Quantity', 'B cross blocks');
            g = tc.env.g; th = tc.tr.theta; u0 = tc.tr.x(1); w0 = tc.tr.x(3); V = tc.tr.y.V;
            fs = [g g g 1 1 1 1 1 1 V V V];
            e = {1, 8, -g * cos(th); 3, 8, -g * sin(th); 2, 7, g * cos(th); 7, 4, 1; 7, 6, tan(th); 8, 5, 1; ...
                 9, 6, 1 / cos(th); 12, 1, sin(th); 12, 3, -cos(th); 12, 8, u0 * cos(th) + w0 * sin(th)};
            for k = 1:size(e, 1)
                [i, j, v] = e{k, :};
                tc.verifyTol(lin.A(i, j), v, 1e-8 * fs(i) / tc.ZSCALE(j), 'abs', 'ANALYTIC', ...
                    'tF16Linearize (a) entry at 1e-8 FScale/ZScale (M12)', ...
                    'Quantity', sprintf('A(%s,%s) tight', lin.stateNames{i}, lin.stateNames{j}));
            end
        end

        % ---- MINOR 6 ---------------------------------------------------------------
        function gammaFromDerivativeWithoutCondition(tc)
            tr = vital.trim.solve(tc.AC, tc.env, tc.cond(565.6854, 10013, 5));
            tc.assertEqual(tr.status, 'OK');
            tr = rmfield(tr, 'cond');
            lin = vital.linear.linearize(tc.AC, tc.env, tr);
            tc.verifyTol(lin.gamma0, deg2rad(5), 1e-9, 'abs', 'ANALYTIC', 'gamma = asin(hdot/|pdot_n|), zero wind', ...
                'Quantity', 'gamma0 fallback', 'Unit', 'rad');
        end

        % ---- MINOR 7 ---------------------------------------------------------------
        function windAirAxisConverters(tc)
            env = tc.env; env.wind_n = [-10; 0; 0];
            tr = vital.trim.solve(tc.AC, env, tc.cond(565.6854, 10013, 0));
            tc.assertEqual(tr.status, 'OK');
            lin = vital.linear.linearize(tc.AC, env, tr);
            ang = @(xl) airAngles(xl, env.wind_n);
            G = zeros(3, 12); h = 1e-6;
            for j = 1:12
                d = zeros(12, 1); d(j) = h;
                G(:, j) = (ang(lin.x0 + d) - ang(lin.x0 - d)) / (2 * h);
            end
            lon = [1 3 5 8]; lat = [2 4 6 7];
            tc.verifyTol(lin.lon.air.T(1:2, :), G(1:2, lon), 1e-8, 'abs', 'ANALYTIC', ...
                'd[V alpha]/d[u w q theta] with the wind-attitude term (MINOR 7)', 'Quantity', 'T_lon with wind');
            tc.verifyTol(lin.lat.air.T(1, :), G(3, lat), 1e-8, 'abs', 'ANALYTIC', ...
                'd beta/d[v p r phi] with the wind-attitude term (MINOR 7)', 'Quantity', 'T_lat with wind');
            tc.verifyGreaterThan(abs(G(2, 8)), 1e-3, 'fixture: the headwind makes alpha depend on theta');
        end
    end
end

function a = airAngles(xl, wind)
va = xl(1:3) - vital.frames.dcm321(xl(7), xl(8), xl(9)) * wind;
V = norm(va);
a = [V; atan2(va(3), va(1)); asin(va(2) / V)];
end
