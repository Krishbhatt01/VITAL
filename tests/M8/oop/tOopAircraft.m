classdef (TestTags = {'M8', 'OOP'}) tOopAircraft < vital.test.VitalTestCase
%TOOPAIRCRAFT  0.8.1-OOP: vital.Aircraft, vital.FlightCondition, vital.TrimResult,
%   vital.LinearModel and the vital.modes classes are a thin object layer over the
%   functional core (ADR-037, user decision 1).
%   PRE-REGISTERED (written before the classes existed):
%   1. toRuntime returns EXACTLY (isequal) the struct of vital.aircraft.f16.config
%      for the same options (default; CG 30 % with an AeroScale and a BFRP offset).
%   2. Aircraft.trim(FlightCondition) equals vital.trim.solve on the same
%      (AC, env, cond) to 1e-12 abs (x, u, alpha, theta); same status.
%   3. Aircraft.linearize / modes equal vital.linear.linearize / modes to 1e-12
%      (A, B, eigenvalues); each classical mode is an object of its class
%      (ShortPeriod, Phugoid, DutchRoll, Roll, Spiral).
%   4. FlightCondition.fromFeet builds exactly (isequal) the env and trim
%      condition of vital.fq.f16Factory for the NESC README point.
%   5. FlightCondition -> Aero.FixedWing.State (fixedWingState with
%      aircraftEnvironment(ac, 'ISA', H), H geopotential): density equals the core
%      atmosphere (1e-12 rel); DynamicPressure = rho V^2/2 and MachNumber = V/a
%      (1e-12 rel); at a trim, Alpha/Theta equal the trim (1e-12) and the
%      toolbox InertialToBodyMatrix equals VITAL's C_bn (INDEP, 1e-12 abs).
%   6. Aircraft.toFixedWing: ReferenceArea = S, ReferenceSpan = b,
%      ReferenceLength = cbar; the state carries mass, inertia (J) and CG (r_cg).
%   7. Validation: bad CG -> vital:badInput; non-positive speed, unknown
%      condition type -> vital:badInput; a TrimResult from a struct without the
%      trim fields -> vital:badInput; linearizing a failed trim ->
%      vital:linear:notTrimmed (from the core, unchanged).

    properties
        Readme
    end

    methods (TestClassSetup)
        function readme(tc)
            C = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            p = vital.fq.gridPoints(C);
            tc.Readme = p(1);
        end
    end

    methods (Test)
        function toRuntimeIsTheConfigStruct(tc)
            tc.verifyExact(vital.Aircraft().toRuntime(), vital.aircraft.f16.config(), 'ANALYTIC', 'delegation to vital.aircraft.f16.config');
            s = struct('Cm_q', 0.7, 'Cn_r', 1.2);
            a = vital.Aircraft('CG_PCT_MAC', 30, 'AeroScale', s, 'BfrpOffset', [0.1; 0; -0.2]);
            tc.verifyExact(a.toRuntime(), vital.aircraft.f16.config('CG_PCT_MAC', 30, 'AeroScale', s, 'BfrpOffset', [0.1; 0; -0.2]), ...
                'ANALYTIC', 'delegation with options');
            AC = a.toRuntime();
            tc.verifyEqual([a.S a.b a.cbar a.Mass], [AC.S AC.b AC.cbar AC.mass]);
            tc.verifyEqual(a.Inertia, AC.J);
            tc.verifyEqual(a.CG, AC.r_cg);
            tc.verifyEqual(a.CgPctMac, 30);
        end

        function aircraftValidation(tc)
            tc.verifyError(@() vital.Aircraft('CG_PCT_MAC', 120), 'vital:badInput');
            tc.verifyError(@() vital.Aircraft('AeroScale', struct('Cnr_table', 1)), 'vital:badInput');
        end

        function flightConditionMatchesFactory(tc)
            p = tc.Readme;
            fc = vital.FlightCondition.fromFeet(p.V_ftps, p.h_ft);
            ac = feval(vital.fq.f16Factory(), p);
            tc.verifyExact(fc.toEnv(), ac.env, 'ANALYTIC', 'same env as vital.fq.f16Factory');
            tc.verifyExact(fc.toTrimCond(), ac.trimCond, 'ANALYTIC', 'same trim condition as vital.fq.f16Factory');
            tc.verifyError(@() vital.FlightCondition('V', 0, 'h', 1000), 'vital:badInput');
            tc.verifyError(@() vital.FlightCondition('V', 100, 'h', 1000, 'Type', 'loop'), 'vital:badInput');
            tc.verifyError(@() vital.FlightCondition('V', 100, 'h', NaN), 'vital:badInput');
        end

        function trimEqualsFunctional(tc)
            p = tc.Readme;
            a = vital.Aircraft();
            fc = vital.FlightCondition.fromFeet(p.V_ftps, p.h_ft);
            tr = a.trim(fc);
            tc.verifyClass(tr, 'vital.TrimResult');
            t0 = vital.trim.solve(a.toRuntime(), fc.toEnv(), fc.toTrimCond());
            c = 'vital.trim.solve on the same (AC, env, cond)';
            tc.verifyEqual(tr.Status, t0.status);
            tc.verifyTol(tr.X, t0.x, 1e-12, 'abs', 'REG', c, 'Quantity', 'x trim');
            tc.verifyTol(tr.U, t0.u, 1e-12, 'abs', 'REG', c, 'Quantity', 'u trim');
            tc.verifyTol([tr.Alpha tr.Theta], [t0.alpha t0.theta], 1e-12, 'abs', 'REG', c, 'Quantity', 'alpha, theta', 'Unit', 'rad');
            tc.verifyTrue(tr.isOK());
            tc.verifyExact(tr.toStruct(), t0, 'REG', 'TrimResult.toStruct is the core struct');
        end

        function linearizeAndModesEqualFunctional(tc)
            p = tc.Readme;
            a = vital.Aircraft();
            fc = vital.FlightCondition.fromFeet(p.V_ftps, p.h_ft);
            tr = a.trim(fc);
            lin = a.linearize(tr);
            tc.verifyClass(lin, 'vital.LinearModel');
            l0 = vital.linear.linearize(a.toRuntime(), fc.toEnv(), tr.toStruct());
            c = 'vital.linear.linearize / modes on the same trim';
            tc.verifyTol(lin.A, l0.A, 1e-12, 'abs', 'REG', c, 'Quantity', 'A');
            tc.verifyTol(lin.B, l0.B, 1e-12, 'abs', 'REG', c, 'Quantity', 'B');
            tc.verifyEqual(lin.StateNames, l0.stateNames);
            m = a.modes(lin);
            m0 = vital.linear.modes(l0);
            tc.verifyEqual(numel(m), numel(m0));
            map = struct('short_period', 'vital.modes.ShortPeriod', 'phugoid', 'vital.modes.Phugoid', ...
                'dutch_roll', 'vital.modes.DutchRoll', 'roll', 'vital.modes.Roll', 'spiral', 'vital.modes.Spiral');
            for k = 1:numel(m0)
                tc.verifyTol([real(m{k}.Eigenvalue) imag(m{k}.Eigenvalue)], [real(m0(k).eigenvalue) imag(m0(k).eigenvalue)], 1e-12, 'abs', 'REG', c, 'Quantity', ['eigenvalue ' m0(k).name]);
                tc.verifyEqual(m{k}.Name, m0(k).name);
                tc.verifyEqual(m{k}.Zeta, m0(k).zeta);
                if isfield(map, m0(k).name), tc.verifyClass(m{k}, map.(m0(k).name)); end
                tc.verifyTrue(isa(m{k}, 'vital.modes.Mode'));
            end
            names = cellfun(@(x) x.Name, m, 'UniformOutput', false);
            tc.verifyTrue(all(ismember(fieldnames(map), names)), 'all five classical modes present at the README trim');
        end

        function fixedWingStateConsistent(tc)
            p = tc.Readme;
            a = vital.Aircraft();
            fc = vital.FlightCondition.fromFeet(p.V_ftps, p.h_ft);
            atm = vital.env.atmosphere(fc.h);
            st = fc.toFixedWingState(a);
            tc.verifyClass(st, 'Aero.FixedWing.State');
            ci = 'Aero.FixedWing.State derived quantities';
            tc.verifyTol(st.Environment.Density, atm.rho, 1e-12, 'rel', 'INDEP', 'aircraftEnvironment(ac, ''ISA'', H) vs core atmosphere', 'Quantity', 'rho', 'Unit', 'kg/m3');
            tc.verifyTol(st.DynamicPressure, 0.5 * atm.rho * fc.V^2, 1e-12, 'rel', 'INDEP', ci, 'Quantity', 'qbar', 'Unit', 'Pa');
            tc.verifyTol(st.MachNumber, fc.V / atm.a, 1e-12, 'rel', 'INDEP', ci, 'Quantity', 'Mach');
            tc.verifyTol(st.Airspeed, fc.V, 1e-12, 'rel', 'INDEP', ci, 'Quantity', 'V', 'Unit', 'm/s');
            tr = a.trim(fc);
            st = fc.toFixedWingState(a, tr);
            tc.verifyTol([st.Alpha st.Theta], [tr.Alpha tr.Theta], 1e-12, 'abs', 'INDEP', ci, 'Quantity', 'alpha, theta at trim', 'Unit', 'rad');
            tc.verifyTol(st.InertialToBodyMatrix, vital.frames.quat2dcm(tr.X(7:10)), 1e-12, 'abs', 'INDEP', ...
                'Aero.FixedWing.State InertialToBodyMatrix vs VITAL C_bn (CONVENTIONS 3)', 'Quantity', 'C_bn');
            tc.verifyTol(st.DynamicPressure, tr.toStruct().y.qbar, 1e-9, 'rel', 'INDEP', ci, 'Quantity', 'qbar at trim', 'Unit', 'Pa');
        end

        function toFixedWingGeometryAndMass(tc)
            a = vital.Aircraft('CG_PCT_MAC', 30);
            AC = a.toRuntime();
            [fw, st] = a.toFixedWing();
            tc.verifyClass(fw, 'Aero.FixedWing');
            c = 'vital.aircraft.f16.config (F16_aero.dml, F16_inertia.dml)';
            tc.verifyTol([fw.ReferenceArea fw.ReferenceSpan fw.ReferenceLength], [AC.S AC.b AC.cbar], 0, 'abs', 'REG', c, 'Quantity', 'S b cbar');
            tc.verifyTol(st.Mass, AC.mass, 0, 'abs', 'REG', c, 'Quantity', 'mass', 'Unit', 'kg');
            tc.verifyTol(st.Inertia.Variables, AC.J, 0, 'abs', 'REG', c, 'Quantity', 'J', 'Unit', 'kg m2');
            tc.verifyTol(st.CenterOfGravity, AC.r_cg.', 0, 'abs', 'REG', c, 'Quantity', 'r_cg', 'Unit', 'm');
        end

        function failedTrimNotLinearized(tc)
            a = vital.Aircraft();
            fc = vital.FlightCondition('V', 40, 'h', 3000);     % far below the stall speed
            tr = a.trim(fc);
            tc.verifyNotEqual(tr.Status, 'OK');
            tc.verifyFalse(tr.isOK());
            tc.verifyError(@() a.linearize(tr), 'vital:linear:notTrimmed');
            tc.verifyError(@() vital.TrimResult(struct('bogus', 1)), 'vital:badInput');
        end
    end
end
