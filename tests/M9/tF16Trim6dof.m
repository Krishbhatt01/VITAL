classdef (TestTags = {'M9'}) tF16Trim6dof < vital.test.VitalTestCase
%TF16TRIM6DOF  The NESC F-16 trimmed, flown 10 s in a Simulink model built on the
%   Aerospace Blockset 6DOF (Quaternion) block: a trimmed aircraft must fly
%   "flat lines". Model: models/F16Trim6DOF.slx (vital.slx.buildTrim6dof).
%
%   Loop: state from the 6DOF block (V_b, w_b, DCM_be, X_e) -> VITAL F-16 loads
%   from the NASA DAVE-ML data (aero + thrust, about the CG, body axes;
%   vital.slx.f16LoadsCg) + weight m*DCM_be*[0 0 g]' -> 6DOF equations of motion
%   (MathWorks, independent of VITAL's vital.eom) -> state. Controls u = trim u
%   (+ an optional perturbation du).
%
%   Condition: NESC check case 11 start / README reference trim (docs/nesc/
%   NESC_EXTRACT_F16.md): 10013 ft, 565.6854 ft/s TAS (velocity [400 400 0]
%   ft/s, heading 45 deg), CG 25 % MAC, wings level, constant g 32.174 ft/s2,
%   flat Earth, no wind.
%
%   Criteria (registered before the first Simulink run):
%   T1 trim equals the NESC README table (PUB; tolerances of tests/M4/tF16Trim):
%      theta 2.6538 deg (0.02), elevator -3.2410 deg (0.02), throttle 13.9019 % (0.1).
%   T2 at the trim the loads the 6DOF block receives balance: total force
%      (aero + thrust + weight) / weight <= 1e-8 and total moment about the CG
%      <= 1e-8 * weight * cbar (ANALYTIC: a trim is zero net force and moment;
%      trim residual ~1e-16, tests/M4/tF16Trim).
%   T3 10 s hold, dt 0.01, ode4: the bounds of tests/M5/tF16Sim#trimHoldSixtySeconds
%      (REG, derived there for 60 s): V 1e-6 m/s; alpha, theta 1e-8 rad; p, q, r
%      1e-8 rad/s; h 1e-4 m; beta, phi 1e-8 rad; psi - 45 deg 1e-8 rad.
%   T4 position ramps exactly along the heading: x_N = x_E = (V/sqrt 2) t,
%      |error| <= 1e-6 m over 10 s (ANALYTIC; V constant to 1e-6 m/s by T3,
%      so 10 s x 1e-6 m/s = 1e-5 m is the drift bound; 1e-6 m is the measured
%      claim at trim, residual ~1e-16).
%   T5 the 6DOF model is LIVE: a 1 deg elevator doublet (0.5 s + 0.5 s at 1 s)
%      changes alpha by >= 0.05 deg and the first q response is nose-down
%      (+de TED -> q < 0; CONVENTIONS 7) (ANALYTIC).
%   T6 independent EOM: with that doublet, the MathWorks 6DOF block and VITAL's
%      own EOM (vital.sim.run, RK4, dt 0.01, same loads) agree over 10 s:
%      E = max_i max_k |x_6dof - x_vital| / max(1, max_k |x_vital|) <= 1e-6
%      (INDEP; both are 4th-order RK on the same ODE at dt 0.01; the RK4 global
%      error for the fastest mode here (short period, |lambda| ~ 2/s) is
%      ~(lambda dt)^4 ~ 2e-7 relative; quaternion normalisation differs).
%   T7 the hold is not flat because nothing is connected: with the weight block
%      removed (vital.slx.simulateTrim6dof 'NoWeight') the aircraft leaves trim
%      (|dh| > 1 m in 10 s) (ANALYTIC).
%   Amendment A (2026-10-28, user request: everything from the NASA data objects;
%   results from Simulink alone; registered before the change):
%   T8 the mass, inertia and c-bar given to the 6DOF block and the weight block are
%      the NASA data objects' values (f16_data.mass.massSI/inertiaSI,
%      f16_data.geometry.cbar), exactly; the loads come from an AircraftModel; the
%      trim through that model equals the config-struct trim to 1e-12 (REG anchor).
%   T9 the plotted air data are Simulink signals computed by Aerospace Blockset
%      blocks from the 6DOF states (Incidence, Sideslip & Airspeed; ISA Atmosphere;
%      Mach Number): V = norm(V_b), alpha = atan2(w, u), beta = asin(v/V),
%      h = -X_e(3), hdot = -V_e(3) to 1e-12 (ANALYTIC); Mach equals VITAL's
%      atmosisa-based Mach to 1e-6 relative (INDEP; ISA constants differ ~7e-7).
%   T10 the Simulink-only result: 10 s hold judged on those Simulink signals with
%      the T3 bounds plus |hdot| <= 1e-6 m/s; and pressing Run (sim with no
%      output argument) makes the model's StopFcn write the three result figures
%      from its own logged data (no VITAL simulation involved).

    properties
        P
        Hold
        Ft = 0.3048
        Folder
    end

    methods (TestClassSetup)
        function setupOnce(tc)
            tc.Folder = tempname; mkdir(tc.Folder);
            tc.addTeardown(@() rmdir(tc.Folder, 's'));
            tc.addTeardown(@() bdclose('F16Trim6DOF'));
            s = vital.slx.buildTrim6dof('Folder', tc.Folder);
            tc.P = vital.slx.trim6dofSetup();
            tc.P.model = s.file;
            tc.Hold = vital.slx.simulateTrim6dof(tc.P, 'tFinal', 10, 'dt', 0.01);
            tc.assertEqual(tc.Hold.status, 'COMPLETED');
        end
    end

    methods (Test)
        function t1TrimEqualsNescReadme(tc)
            tr = tc.P.tr; c = 'NESC README trim table (README.html:1879-1891)';
            tc.verifyTol(rad2deg(tr.theta), 2.6538, 0.02, 'abs', 'PUB', c, 'Quantity', 'theta', 'Unit', 'deg');
            tc.verifyTol(rad2deg(tr.u(1)), -3.2410, 0.02, 'abs', 'PUB', c, 'Quantity', 'elevator', 'Unit', 'deg');
            tc.verifyTol(100 * tr.u(4), 13.9019, 0.1, 'abs', 'PUB', c, 'Quantity', 'throttle', 'Unit', '%');
        end

        function t2LoadsBalanceAtTrim(tc)
            h = tc.Hold; W = tc.P.m * tc.P.g;
            c = 'trim = zero net force and moment about the CG';
            tc.verifyTol(h.F_total(:, 1) / W, [0; 0; 0], 1e-8, 'abs', 'ANALYTIC', c, 'Quantity', 'F_total/W at t0');
            tc.verifyTol(h.M_total(:, 1) / (W * tc.P.cbar), [0; 0; 0], 1e-8, 'abs', 'ANALYTIC', c, 'Quantity', 'M_cg/(W cbar) at t0');
        end

        function t3TenSecondHoldIsFlat(tc)
            y = tc.Hold.y; n = numel(y.V); c = 'tests/M5/tF16Sim trim-hold bounds';
            tc.verifyTol(y.V, y.V(1) * ones(1, n), 1e-6, 'abs', 'REG', c, 'Quantity', 'V drift', 'Unit', 'm/s');
            tc.verifyTol(y.alpha, tc.P.tr.alpha * ones(1, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'alpha drift', 'Unit', 'rad');
            tc.verifyTol(y.theta, tc.P.tr.theta * ones(1, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'theta drift', 'Unit', 'rad');
            tc.verifyTol([y.p; y.q; y.r], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'body rates', 'Unit', 'rad/s');
            tc.verifyTol(y.h, y.h(1) * ones(1, n), 1e-4, 'abs', 'REG', c, 'Quantity', 'altitude drift', 'Unit', 'm');
            tc.verifyTol([y.beta; y.phi; y.psi - deg2rad(45)], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'lateral', 'Unit', 'rad');
        end

        function t4PositionRampsAlongHeading(tc)
            h = tc.Hold; V = tc.P.V;
            ramp = V / sqrt(2) * h.t;
            tc.verifyTol([h.y.xN; h.y.xE], [ramp; ramp], 1e-6, 'abs', 'ANALYTIC', ...
                'x = V t along heading 45 deg', 'Quantity', 'north/east position', 'Unit', 'm');
        end

        function t5DoubletShowsTheModelIsLive(tc)
            o = vital.slx.simulateTrim6dof(tc.P, 'tFinal', 10, 'dt', 0.01, ...
                'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'));
            tc.assertEqual(o.status, 'COMPLETED');
            tc.verifyWithin(rad2deg(max(abs(o.y.alpha - tc.P.tr.alpha))), 0.05, Inf, 'ANALYTIC', ...
                'a 1 deg elevator doublet moves alpha', 'Quantity', 'max dalpha', 'Unit', 'deg');
            k = find(o.t > 1 + 1e-9, 1);
            tc.verifyWithin(o.y.q(k), -Inf, -1e-9, 'ANALYTIC', 'CONVENTIONS 7: +de TED -> q < 0', ...
                'Quantity', 'q just after +de', 'Unit', 'rad/s');
        end

        function t6AgreesWithVitalEom(tc)
            in = vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator');
            o = vital.slx.simulateTrim6dof(tc.P, 'tFinal', 10, 'dt', 0.01, 'Inputs', in);
            m = vital.sim.run(tc.P.AC, tc.P.env, tc.P.tr.x, tc.P.tr.u, 'dt', 0.01, 'tFinal', 10, 'Inputs', in);
            tc.assertEqual(m.status, 'COMPLETED');
            tc.assertEqual(size(o.x), size(m.x));
            E = max(max(abs(o.x - m.x), [], 2) ./ max(1, max(abs(m.x), [], 2)));
            tc.verifyWithin(E, 0, 1e-6, 'INDEP', 'MathWorks 6DOF (Quaternion) vs vital.sim.run', ...
                'Quantity', 'scaled state difference E', 'Unit', '-');
        end

        function t8InputsAreTheNasaDataObjects(tc)
            d = vital.aircraft.f16.data('CG_PCT_MAC', 25); c = 'NASA F16_inertia.dml / F16_aero.dml via vital.data';
            tc.verifyTol(tc.P.m, d.mass.massSI(), 0, 'abs', 'PUB', c, 'Quantity', 'mass', 'Unit', 'kg');
            tc.verifyTol(tc.P.J, d.mass.inertiaSI(), 0, 'abs', 'PUB', c, 'Quantity', 'inertia', 'Unit', 'kg m2');
            tc.verifyTol(tc.P.cbar, d.geometry.cbar.si(), 0, 'abs', 'PUB', c, 'Quantity', 'cbar', 'Unit', 'm');
            tc.verifyClass(tc.P.f16, 'vital.AircraftModel');
            ref = vital.trim.solve(vital.aircraft.f16.config('CG_PCT_MAC', 25), tc.P.env, tc.P.cond);
            tc.verifyTol([tc.P.tr.x; tc.P.tr.u], [ref.x; ref.u], 1e-12, 'abs', 'REG', ...
                'trim through the AircraftModel = trim through the config struct', 'Quantity', 'trim x, u');
        end

        function t9AirDataAreSimulinkBlocks(tc)
            s = tc.Hold.sl; x = tc.Hold.x; c = 'Aerospace Blockset air-data blocks on the 6DOF states';
            V = vecnorm(x(1:3, :));
            tc.verifyTol(s.V, V, 1e-12 * max(V), 'abs', 'ANALYTIC', c, 'Quantity', 'V', 'Unit', 'm/s');
            tc.verifyTol(s.alpha, atan2(x(3, :), x(1, :)), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'alpha', 'Unit', 'rad');
            tc.verifyTol(s.beta, asin(x(2, :) ./ V), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'beta', 'Unit', 'rad');
            tc.verifyTol(s.h, -x(13, :), 1e-12 * tc.P.h, 'abs', 'ANALYTIC', c, 'Quantity', 'h', 'Unit', 'm');
            tc.verifyTol(s.mach, tc.Hold.y.mach, 1e-6, 'rel', 'INDEP', 'ISA block vs atmosisa', 'Quantity', 'Mach');
        end

        function t10SimulinkOnlyResult(tc)
            s = tc.Hold.sl; n = numel(s.V); c = 'tests/M5/tF16Sim trim-hold bounds, on Simulink signals';
            tc.verifyTol(s.V, s.V(1) * ones(1, n), 1e-6, 'abs', 'REG', c, 'Quantity', 'V drift', 'Unit', 'm/s');
            tc.verifyTol([s.alpha; s.theta], [tc.P.tr.alpha; tc.P.tr.theta] * ones(1, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'alpha, theta', 'Unit', 'rad');
            tc.verifyTol([s.p; s.q; s.r], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'body rates', 'Unit', 'rad/s');
            tc.verifyTol(s.h, s.h(1) * ones(1, n), 1e-4, 'abs', 'REG', c, 'Quantity', 'altitude', 'Unit', 'm');
            tc.verifyTol(s.hdot, zeros(1, n), 1e-6, 'abs', 'REG', c, 'Quantity', 'climb rate', 'Unit', 'm/s');
            tc.verifyTol([s.beta; s.phi; s.psi - deg2rad(45)], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'lateral', 'Unit', 'rad');
            d = fullfile(tc.Folder, 'figs'); P = tc.P; P.plotDir = d; P.plot = true;
            assignin('base', 'P6dof', P);
            vital.slx.f16LoadsCg('setup', P);
            [~, name] = fileparts(P.model);
            evalin('base', sprintf('sim(''%s'');', name));
            close all
            for f = {'1_trim_hold_states.png', '2_trim_hold_deviation_log.png', '3_trim_hold_net_loads.png'}
                tc.verifyTrue(isfile(fullfile(d, f{1})), ['StopFcn wrote ' f{1}]);
            end
        end

        function t7HoldIsNotVacuous(tc)
            o = vital.slx.simulateTrim6dof(tc.P, 'tFinal', 10, 'dt', 0.01, 'NoWeight', true);
            tc.verifyWithin(max(abs(o.y.h - o.y.h(1))), 1, Inf, 'ANALYTIC', ...
                'without the weight block the trim is broken', 'Quantity', 'max |dh| no weight', 'Unit', 'm');
        end
    end
end
