classdef (TestTags = {'M4'}) tF16Trim < vital.test.VitalTestCase
%TF16TRIM  M4: wings-level trim of the NESC F-16, against published answers,
%   with every failure mode reported by status (CONVENTIONS.md section 9).
%
%   PRE-REGISTERED known answers (written before the solver existed):
%   1. NESC F-16 README Table 11 (README.html:1646-1714): 10,013 ft,
%      565.6854 ft/s, CG 25 %, constant g = 32.174 ft/s^2:
%        theta 2.6538 deg, elevator -3.2410 deg, throttle 13.9019 %.
%      Tolerances +/-0.02 deg and +/-0.1 % points: NASA's run used an oblate
%      rotating Earth and a TABULAR US 1976 atmosphere; VITAL trims flat-earth
%      with the US 1976 equations. The Coriolis + curvature terms are ~0.2 % of
%      weight (~0.005 deg of alpha) and table-interpolation density errors
%      ~1e-4 (~0.0005 deg); the printed values have 4 decimals.
%   2. NESC check-case 11 (TM Vol II Table 35 p.62; CSV sims 4 and 5, t = 0):
%      pitch attitude, with local J2 gravity minus centrifugal at the IC,
%      inside the pre-registered Euler band (floor 0.05 deg, NESC_CASE_MATRIX).
%   3. The README-vs-NESC theta difference (2.6538 vs ~2.6389 deg) is caused
%      by gravity alone: VITAL must reproduce it to +/-0.005 deg.
%      RESULT: FAILED in the first M4 run (0.0074 vs 0.0150 deg). Superseded by
%      rotatingEarthExplainsNescTrim (Coriolis and curvature included), which
%      keeps the registered 0.005 deg tolerance. See reports/CHANGELOG.md.

    properties
        AC
        Ft = 0.3048
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
        end
    end

    methods (Access = private)
        function env = envG(tc, g_ftps2)
            env = struct('g', g_ftps2 * tc.Ft, 'wind_n', [0;0;0], 'deltaT', 0);
        end

        function cond = readmeCondition(tc)
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', deg2rad(45));
        end

        function g = nescEffectiveGravity(tc)
            % Down component of J2 gravitation minus the centrifugal acceleration of
            % Earth rotation at the case-11 initial position (36.01916667 N, 75.67444444 W, 10013 ft).
            K = vital.geo.constants('wgs84');
            lat = deg2rad(36.01916667); lon = deg2rad(-75.67444444); h = 10013 * tc.Ft;
            r = vital.geo.lla2ecef(lat, lon, h, K);
            wE = [0; 0; K.omega];
            geff = vital.geo.gravitation(r, K) - cross(wE, cross(wE, r));
            gn = vital.geo.dcmEcefToNed(lat, lon) * geff;
            g = gn(3);
        end
    end

    methods (Test)
        function readmeTrimTable11(tc)
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition());
            tc.assertEqual(tr.status, 'OK', ['trim status ' tr.status ': ' tr.reason]);
            c = 'NESC F16 README.html Table 11 (lines 1661-1714); tolerance rationale in class header';
            tc.verifyTol(rad2deg(tr.theta), 2.6538, 0.02, 'abs', 'PUB', c, 'Quantity', 'theta', 'Unit', 'deg');
            tc.verifyTol(rad2deg(tr.u(1)), -3.2410, 0.02, 'abs', 'PUB', c, 'Quantity', 'elevator', 'Unit', 'deg');
            tc.verifyTol(100 * tr.u(4), 13.9019, 0.1, 'abs', 'PUB', c, 'Quantity', 'throttle (PLA)', 'Unit', '%');
        end

        function nescCase11PitchAttitude(tc)
            cond = tc.readmeCondition(); cond.V = norm([400 400]) * tc.Ft;
            env = struct('g', tc.nescEffectiveGravity(), 'wind_n', [0;0;0], 'deltaT', 0);   % gravitation + centrifugal only
            tr = vital.trim.solve(tc.AC, env, cond);
            tc.assertEqual(tr.status, 'OK');
            M = jsondecode(fileread(fullfile(vital.paths('docs'), 'NESC_CASE_MATRIX.json')));
            band = M.cases(strcmp({M.cases.id}, '11')).band;
            b = band(strcmp({band.signal}, 'eulerAngle_deg_Pitch'));
            ref = [];
            for sim = [4 5]
                t = vital.io.readNescCsv('Atmos_11_TrimCheckSubsonicF16', sim);
                ref(end+1) = t.eulerAngle_deg_Pitch(1); %#ok<AGROW>
            end
            r = vital.verify.envelopeCheck(0, {0, 0}, num2cell(ref - rad2deg(tr.theta)), b, max(abs(ref)));
            tc.verifyWithin(r.worst, -Inf, 0, 'PUB', ...
                'NESC Atmos_11 sims 4, 5 at t = 0 (TM Vol II Table 35); envelope ADR-009', 'Quantity', 'theta envelope excess', 'Unit', 'deg');
        end

        function rotatingEarthExplainsNescTrim(tc)
            % Pre-registered hypothesis 3 ("gravity alone explains README vs NESC") FAILED in
            % the first M4 run: gravity gives 0.0074 of the 0.0150 deg (reports/CHANGELOG.md).
            % Corrected physics: steady level flight over the rotating ellipsoid also carries
            % the Coriolis (Eotvos) and path-curvature terms. With them, the flat-earth trim
            % must reproduce the NESC tools' pitch attitude to the 0.005 deg registered for
            % hypothesis 3, as well as lying in the pre-registered Euler band.
            cond = tc.readmeCondition(); cond.V = norm([400 400]) * tc.Ft;
            K = vital.geo.constants('wgs84');
            g = vital.geo.levelFlightGravity(deg2rad(36.01916667), deg2rad(-75.67444444), 10013 * tc.Ft, [400; 400; 0] * tc.Ft, K);
            tr = vital.trim.solve(tc.AC, struct('g', g, 'wind_n', [0;0;0], 'deltaT', 0), cond);
            tc.assertEqual(tr.status, 'OK');
            ref = [];
            for sim = [4 5]
                t = vital.io.readNescCsv('Atmos_11_TrimCheckSubsonicF16', sim);
                ref(end+1) = t.eulerAngle_deg_Pitch(1); %#ok<AGROW>
            end
            tc.verifyTol(rad2deg(tr.theta), mean(ref), 0.005, 'abs', 'PUB', ...
                'NESC Atmos_11 sims 4, 5 theta at t = 0; flat trim with level-flight gravity (tLevelFlightGravity)', ...
                'Quantity', 'theta vs NESC', 'Unit', 'deg');
        end

        function trimIsAnEquilibrium(tc)
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition());
            g = 32.174 * tc.Ft;
            tc.verifyTol(tr.xdot(1:3) / g, [0;0;0], 1e-8, 'abs', 'ANALYTIC', 'trimmed: no linear acceleration', 'Quantity', 'vdot/g');
            tc.verifyTol(tr.xdot(4:6), [0;0;0], 1e-8, 'abs', 'ANALYTIC', 'trimmed: no angular acceleration', 'Quantity', 'wdot', 'Unit', 'rad/s2');
            tc.verifyTol(tr.xdot(13), 0, 1e-8, 'abs', 'ANALYTIC', 'level: no climb rate', 'Quantity', 'hdot', 'Unit', 'm/s');
        end

        function climbTrimKinematics(tc)
            cond = tc.readmeCondition(); cond.type = 'climb'; cond.gamma = deg2rad(3);
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), cond);
            tc.assertEqual(tr.status, 'OK');
            tc.verifyTol(tr.theta - tr.alpha, cond.gamma, 1e-12, 'abs', 'ANALYTIC', 'wings level, beta = 0: theta = alpha + gamma', 'Quantity', 'theta - alpha', 'Unit', 'rad');
            tc.verifyTol(-tr.xdot(13), cond.V * sin(cond.gamma), 1e-6, 'abs', 'ANALYTIC', 'climb rate V sin(gamma)', 'Quantity', 'climb rate', 'Unit', 'm/s');
        end

        function speedSweepAlphaDecreases(tc)
            V = (450:75:900) * tc.Ft; a = zeros(size(V));
            for k = 1:numel(V)
                cond = tc.readmeCondition(); cond.V = V(k);
                tr = vital.trim.solve(tc.AC, tc.envG(32.174), cond);
                tc.assertEqual(tr.status, 'OK', sprintf('V = %.0f ft/s', V(k)/tc.Ft));
                a(k) = tr.alpha;
            end
            tc.verifyTrue(all(diff(a) < 0), 'level flight: angle of attack falls as speed rises (REG)');
        end

        % ---- failure modes (FC-501 ... FC-505) ----------------------------------------
        function stallLimitedIsInfeasible(tc)
            cond = tc.readmeCondition(); cond.V = 150 * tc.Ft;
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), cond);
            tc.verifyEqual(tr.status, 'INFEASIBLE');
            tc.verifySubstring(tr.reason, 'alpha', 'reason names the limiting unknown (stall-limited)');
        end

        function controlBoundIsInfeasible(tc)
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition(), 'Bounds', struct('de_deg', [-1 1]));
            tc.verifyEqual(tr.status, 'INFEASIBLE');
            tc.verifySubstring(tr.reason, 'de');
        end

        function nonConvergenceIsReported(tc)
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition(), 'MaxIterations', 1, 'Retries', 0);
            tc.verifyEqual(tr.status, 'NOT_CONVERGED');
        end

        function outOfDataEnvelopeIsNotOk(tc)
            cond = tc.readmeCondition(); cond.h = 55000 * tc.Ft; cond.V = 900 * tc.Ft;   % prop tables end at 50,000 ft
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), cond);
            tc.verifyTrue(any(strcmp(tr.status, {'OUT_OF_DATA_ENVELOPE', 'INFEASIBLE'})), ['status ' tr.status]);
            tc.verifyTrue(tr.outOfEnvelope);
        end

        function nonSquareSpecificationRejected(tc)
            tc.verifyError(@() vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition(), 'Unknowns', {'alpha', 'de'}), ...
                'vital:trim:notSquare');
        end

        function badConditionRejected(tc)
            cond = tc.readmeCondition(); cond.V = 0;
            tc.verifyError(@() vital.trim.solve(tc.AC, tc.envG(32.174), cond), 'vital:trim:badCondition');
            cond = tc.readmeCondition(); cond.type = 'hover';
            tc.verifyError(@() vital.trim.solve(tc.AC, tc.envG(32.174), cond), 'vital:trim:badCondition');
            tc.verifyError(@() vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition(), 'Unknowns', {'alpha', 'de', 'flaps'}), ...
                'vital:trim:badCondition');
        end

        function okStatusMeansConvergedAndInsideData(tc)
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition());
            tc.verifyEqual(tr.status, 'OK');
            tc.verifyLessThan(tr.residual, tr.tol);
            tc.verifyFalse(tr.outOfEnvelope);
        end

        function userTrimFunctionReportsPublishedUnits(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'g_ftps2', 32.174);
            tr = vital.trim.solve(tc.AC, tc.envG(32.174), tc.readmeCondition());
            tc.verifyTol([r.theta_deg r.alpha_deg r.elevator_deg r.throttle_pct], ...
                [rad2deg(tr.theta) rad2deg(tr.alpha) rad2deg(tr.u(1)) 100*tr.u(4)], 1e-9, 'abs', 'ANALYTIC', ...
                'report equals the solver in published units (deg, %)', 'Quantity', 'report');
            tc.verifyEqual(r.status, 'OK');
        end
    end
end
