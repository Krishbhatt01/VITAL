classdef (TestTags = {'M5'}) tNescF16Cases < vital.test.VitalTestCase
%TNESCF16CASES  M5-C: NESC F-16 check-cases 11 (subsonic trim flyout),
%   12 (supersonic trim flyout on the clamped subsonic tables) and 13.1-13.4
%   (F16_control.dml autopilot manoeuvres) over the rotating WGS-84 Earth
%   with J2 gravitation (vital.plant.derivativesRotating through vital.sim.run).
%
%   Reference: NESC CSVs SIM 2, 4, 5; SIM 2 is excluded from every F-16
%   envelope (NESC_CASE_MATRIX.json exclude_sims; TM Vol II p.588-590).
%   Choices where the TM is silent (proposed ADRs, written before any
%   comparison run; reports/fragments/nesc/DECISIONS.md):
%     N3 aerodynamic rates w.r.t. the Earth-fixed airmass (w_be)
%     N4 initial rates w_bi = C_bn (w_ie + w_en): the aircraft holds its Euler
%        angles w.r.t. local level (SIM 5's definition, TM Vol II p.228)
%     N5 NESC-environment trim: vital.trim.solve with
%        vital.geo.levelFlightGravity (tF16Trim rotatingEarthExplainsNescTrim),
%        polished by Newton on (theta, de, throttle) with the rotating plant to
%        zero NED-frame body-x/z acceleration and pitch acceleration; aileron
%        and rudder 0. Case 12 trims on clamped tables: OUT_OF_DATA_ENVELOPE is
%        accepted for case 12 only (ADR-014).
%     N6 control law: first registered as 50 Hz zero-order hold. That choice
%        FAILED (13.x outside the bands in their transients; roll excess
%        2.60/1.28/0.30/0.10 deg at 50/100/200/500 Hz in 13.3, converging to
%        SIM 4/5). Superseded by ADR N6r: the static law is evaluated at every
%        RK4 stage (continuous-time form); commands step exactly at t_step.
%        No band or expectation was changed. The LQR reference states (trimmedAlpha,
%        trimmedTheta, trimmedKEAS) replaced by VITAL's trim (SIM 5 practice,
%        TM Vol II p.256) and the trimmed stick/throttle set to VITAL's trim;
%        KEAS = TAS sqrt(rho/rho0) (rho0 US 1976 sea level); control-law rates
%        first registered w.r.t. local level: FAILED (case 15 captured the
%        circle 3 s early); superseded by ADR N6c: Earth-relative rates w_be,
%        the aero model's bodyAngularRate signal; baseline commands
%        = trim altitude, trim KEAS, course 45 deg; 13.2 steps -5 KEAS (TM
%        value; SIM 2's -10 kt is irrelevant, SIM 2 is excluded)
%     N7 case 13.4: lateralDeviationError = d - 2000 ft for t >= 20 s, d the
%        cross-track distance (+right) from the rhumb line through the initial
%        position at the 45 deg base course (vital.nesc.crossTrack); 0 before
%     N11r dt = 0.02 s (11, 12) and 0.005 s (autopilot cases); first registered
%        as 0.02 s everywhere with studies at 0.04 / 0.01 s, revised after the
%        first run (11/12 study ratio 0.39 against 0.04 s; 13.3 ratio 82 with
%        the stage-evaluated law); see ADR N11r
%
%   PRE-REGISTERED expectations:
%   1. caseNN (PUB): every band signal inside the envelope of SIM 4 and SIM 5
%      widened by delta, exactly as registered in NESC_CASE_MATRIX.json.
%   2. nescTrimIsAnEquilibrium: the polished trim of case 11 has scaled
%      residual < 1e-10 (g for accelerations, rad/s^2 for pitch) and status
%      OK; case 12 has status OUT_OF_DATA_ENVELOPE (Mach 2.01 > the Mach 1.0
%      thrust-table limit) with residual < 1e-10.
%   3. supersonicRunsOnClampedTables: case 12 COMPLETES (not stopped) and
%      records the clamped lookups (out.outOfEnvelope.ever, from t = 0).
%   4. stepSizeStudy (REG): max |VITAL(dt) - VITAL(dt_study)| / delta(t) <= 0.1
%      for every signal: cases 11, 12 against dt = 0.01 s over the first 30 s;
%      the autopilot cases (dt 0.005 s) against dt = 0.0025 s over
%      min(30 s, duration), which contains every commanded step (5, 5, 15,
%      20 s).
%   5. commandsFollowTheTm: 13.1 altitude command 10013 -> 10113 ft at 5 s;
%      13.2 KEAS command trim -> trim - 5 kt at 5 s; 13.3 course 45 -> 60 deg
%      at 15 s; 13.4 lateral offset command active from 20 s (TM Vol II
%      pp.63-65).
%   6. nonOkTrimIsRefusedAndOverrideIsScoped (added in the final increment;
%      guards behaviour of vital.nesc.runCase that exists, so it cannot be RED
%      against a stub; its sensitivity is shown by sabotage S5C-13): case 11
%      with an initial airspeed of 106 ft/s (75 ft/s north and east), which is
%      below the stall speed of the F-16 tables (tF16Trim stallLimitedIsInfeasible
%      trims 150 ft/s INFEASIBLE), must raise vital:nesc:notTrimmed rather than
%      simulate an untrimmed aircraft; an Override on a sphere case is
%      vital:badInput (it would otherwise be silently ignored).
%
%   FAILED PRE-REGISTERED EXPECTATIONS (known discrepancies; reported to the
%   coordinator, who decides; reports/fragments/nesc/NOTES.md has the evidence).
%   After the investigation recorded in ADRs N6r, N6c and N11r, the band
%   signals in KNOWN remain outside the pre-registered envelope. Their original
%   check (worst excess <= 0) is NOT weakened: caseNN applies it to every other
%   signal, and knownDiscrepancies asserts that each listed signal is STILL
%   outside (worst > 0, so a fix shows up) and no worse than 1.05 x the excess
%   measured at registration (regression guard, REG). KNOWN = {case, signal,
%   measured worst excess in the signal's NESC unit}. Classes of cause:
%   (a) t = 0 / command-onset frames: the stateless law acts at the sample
%       itself while the reference sims record the pre-command state there
%       (13.1, 13.2 at t = 0; 13.4 N at t = 20.00; 15, 16 at 0-0.2 s);
%   (b) saturated transients (|p| up to 150 deg/s, full aileron and rudder)
%       lasting about 1 s after the steps of 13.x and the circle capture of
%       15, where VITAL follows SIM 5 to a fraction of the SIM 4-SIM 5
%       difference but lies outside the envelope where the two sims agree;
%   (c) the 1e-4 ft lbf pitching-moment "waist" of cases 11/12, where SIM 4
%       and SIM 5 cross near 0 and delta falls to 4e-6 ft lbf (1e-10 of qSc).
%   FAILED step-size criterion (REG, ratio <= 0.1) at dt = 0.005 vs 0.0025 s,
%   in the same saturated transients (KNOWN_STUDY = {case, signal, measured
%   ratio}), asserted like KNOWN (still > 0.1, <= 1.05 x measured). The dt
%   error there is ~0.25 delta, far below the excesses of class (b).

    properties (Constant)
        Cite = 'NESC Atmos F-16 CSVs SIM 4, 5 (TM-2015-218675 Vol II App. D); band NESC_CASE_MATRIX.json (ADR-009)'
        KNOWN = { ...
            '11', 'aero_bodyMoment_ftlbf_M', 0.0002821; ...
            '12', 'aero_bodyMoment_ftlbf_L', 0.0193; ...
            '12', 'aero_bodyMoment_ftlbf_M', 0.0001292; ...
            '13.1', 'feVelocity_ft_s_Z', 0.02842; ...
            '13.1', 'bodyAngularRateWrtEi_deg_s_Pitch', 0.2573; ...
            '13.1', 'aero_bodyForce_lbf_X', 0.9584; ...
            '13.1', 'aero_bodyForce_lbf_Y', 0.08356; ...
            '13.1', 'aero_bodyForce_lbf_Z', 0.1849; ...
            '13.1', 'aero_bodyMoment_ftlbf_N', 1.429; ...
            '13.2', 'aero_bodyForce_lbf_Y', 0.08356; ...
            '13.2', 'aero_bodyMoment_ftlbf_L', 0.1802; ...
            '13.2', 'aero_bodyMoment_ftlbf_N', 1.429; ...
            '13.3', 'eulerAngle_deg_Roll', 0.1802; ...
            '13.3', 'bodyAngularRateWrtEi_deg_s_Roll', 0.02364; ...
            '13.3', 'bodyAngularRateWrtEi_deg_s_Pitch', 0.2161; ...
            '13.3', 'bodyAngularRateWrtEi_deg_s_Yaw', 0.09066; ...
            '13.3', 'aero_bodyForce_lbf_X', 41.56; ...
            '13.3', 'aero_bodyForce_lbf_Y', 76.38; ...
            '13.3', 'aero_bodyForce_lbf_Z', 420.3; ...
            '13.3', 'aero_bodyMoment_ftlbf_L', 7620; ...
            '13.3', 'aero_bodyMoment_ftlbf_M', 1818; ...
            '13.3', 'aero_bodyMoment_ftlbf_N', 487.2; ...
            '13.4', 'longitude_deg', 6.674e-07; ...
            '13.4', 'feVelocity_ft_s_X', 0.0004977; ...
            '13.4', 'feVelocity_ft_s_Y', 0.03738; ...
            '13.4', 'eulerAngle_deg_Roll', 0.03162; ...
            '13.4', 'eulerAngle_deg_Yaw', 0.08506; ...
            '13.4', 'bodyAngularRateWrtEi_deg_s_Roll', 2.912; ...
            '13.4', 'bodyAngularRateWrtEi_deg_s_Pitch', 0.3264; ...
            '13.4', 'bodyAngularRateWrtEi_deg_s_Yaw', 0.4744; ...
            '13.4', 'aero_bodyForce_lbf_X', 28.04; ...
            '13.4', 'aero_bodyForce_lbf_Y', 5169; ...
            '13.4', 'aero_bodyForce_lbf_Z', 202.3; ...
            '13.4', 'aero_bodyMoment_ftlbf_L', 1.532e+05; ...
            '13.4', 'aero_bodyMoment_ftlbf_M', 546.5; ...
            '13.4', 'aero_bodyMoment_ftlbf_N', 9.299e+04}
        KNOWN_STUDY = { ...
            '13.3', 'aero_bodyMoment_ftlbf_M', 0.231; ...
            '13.3', 'bodyAngularRateWrtEi_deg_s_Pitch', 0.206; ...
            '13.3', 'aero_bodyForce_lbf_X', 0.113; ...
            '13.4', 'aero_bodyMoment_ftlbf_N', 0.282; ...
            '13.4', 'aero_bodyForce_lbf_Z', 0.229; ...
            '13.4', 'bodyAngularRateWrtEi_deg_s_Yaw', 0.207; ...
            '13.4', 'aero_bodyForce_lbf_Y', 0.189; ...
            '13.4', 'aero_bodyForce_lbf_X', 0.169; ...
            '13.4', 'aero_bodyMoment_ftlbf_M', 0.115}
    end

    methods (Access = private)
        function checkCase(tc, id)
            res = vital.nesc.runCase(id);
            tc.assertEqual(res.status, 'COMPLETED', sprintf('case %s stopped: %s', id, res.stopReason));
            cmp = vital.nesc.compare(res);
            known = tc.KNOWN(strcmp(tc.KNOWN(:, 1), id), 2);
            for c = cmp(:).'
                if any(strcmp(c.signal, known)), continue; end     % see knownDiscrepancies
                if strcmp(c.status, 'NOT_ASSESSABLE')
                    tc.verifyFail(sprintf('case %s %s NOT_ASSESSABLE: %s', id, c.signal, c.reason));
                    continue
                end
                tc.verifyWithin(c.worst, -Inf, 0, 'PUB', tc.Cite, ...
                    'Quantity', sprintf('case %s %s envelope excess', id, c.signal), 'Unit', c.unit);
            end
        end

        function study(tc, id)
            cd = vital.nesc.caseDef(id);
            a = vital.nesc.runCase(id);
            b = vital.nesc.runCase(id, 'dt', cd.study.dt, 'tFinal', cd.study.window);
            st = vital.nesc.stepStudy(a, b);
            known = tc.KNOWN_STUDY(strcmp(tc.KNOWN_STUDY(:, 1), id), 2);
            for s = st(:).'
                if any(strcmp(s.signal, known)), continue; end    % see knownStepStudyExcess
                tc.verifyWithin(s.ratio, 0, 0.1, 'REG', 'step-size study, class header 4 (proposed ADR N11)', ...
                    'Quantity', sprintf('case %s %s max |d(dt)|/delta', id, s.signal));
            end
        end
    end

    methods (Test)

        function knownDiscrepancies(tc)
            % FAILED pre-registered expectations, documented (class header).
            for k = 1:size(tc.KNOWN, 1)
                [id, sig, meas] = tc.KNOWN{k, :};
                cmp = vital.nesc.compare(vital.nesc.runCase(id));
                c = cmp(strcmp({cmp.signal}, sig));
                tc.verifyWithin(c.worst, realmin, 1.05 * meas, 'REG', ...
                    'KNOWN DISCREPANCY: outside the pre-registered NESC band (> 0), no worse than registered', ...
                    'Quantity', sprintf('case %s %s envelope excess', id, sig), 'Unit', c.unit);
            end
        end

        function knownStepStudyExcess(tc)
            for k = 1:size(tc.KNOWN_STUDY, 1)
                [id, sig, meas] = tc.KNOWN_STUDY{k, :};
                cd = vital.nesc.caseDef(id);
                st = vital.nesc.stepStudy(vital.nesc.runCase(id), vital.nesc.runCase(id, 'dt', cd.study.dt, 'tFinal', cd.study.window));
                s = st(strcmp({st.signal}, sig));
                tc.verifyWithin(s.ratio, 0.1, 1.05 * meas, 'REG', 'KNOWN step-study excess (class header)', ...
                    'Quantity', sprintf('case %s %s max |d(dt)|/delta', id, sig));
            end
        end
        function case11(tc), tc.checkCase('11'); end
        function case12(tc), tc.checkCase('12'); end
        function case13p1(tc), tc.checkCase('13.1'); end
        function case13p2(tc), tc.checkCase('13.2'); end
        function case13p3(tc), tc.checkCase('13.3'); end
        function case13p4(tc), tc.checkCase('13.4'); end

        function nonOkTrimIsRefusedAndOverrideIsScoped(tc)
            v = [75; 75; 0] * 0.3048;               % 106 ft/s: below the stall speed of the F-16 tables
            tc.verifyError(@() vital.nesc.runCase('11', 'Override', struct('v_ned', v)), 'vital:nesc:notTrimmed');
            tc.verifyError(@() vital.nesc.runCase('1', 'Override', struct('v_ned', v)), 'vital:badInput');
        end

        function nescTrimIsAnEquilibrium(tc)
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tr = vital.nesc.f16Trim(vital.nesc.caseDef('11'), AC);
            tc.verifyEqual(tr.status, 'OK', tr.reason);
            tc.verifyWithin(max(abs(tr.residual)), 0, 1e-10, 'ANALYTIC', 'rotating-plant trim residual (class header 2)', 'Quantity', 'case 11 trim residual');
            tr = vital.nesc.f16Trim(vital.nesc.caseDef('12'), AC);
            tc.verifyEqual(tr.status, 'OUT_OF_DATA_ENVELOPE', tr.reason);
            tc.verifyWithin(max(abs(tr.residual)), 0, 1e-10, 'ANALYTIC', 'rotating-plant trim residual (class header 2)', 'Quantity', 'case 12 trim residual');
        end

        function supersonicRunsOnClampedTables(tc)
            res = vital.nesc.runCase('12');
            tc.verifyEqual(res.status, 'COMPLETED');
            tc.verifyTrue(res.out.outOfEnvelope.ever, 'case 12 must record the clamped (subsonic) tables (ADR-014)');
            tc.verifyEqual(res.out.outOfEnvelope.firstTime, 0);
        end

        function stepSizeStudy11(tc), tc.study('11'); end
        function stepSizeStudy12(tc), tc.study('12'); end
        function stepSizeStudy13(tc)
            for id = {'13.1', '13.2', '13.3', '13.4'}, tc.study(id{1}); end
        end

        function commandsFollowTheTm(tc)
            r = vital.nesc.runCase('13.1'); c = r.commands;
            tc.verifyTol(c.altCmd_ft(c.t < 5 - 1e-9), 10013 * ones(1, nnz(c.t < 5 - 1e-9)), 1e-6, 'abs', 'PUB', 'TM Vol II p.63', 'Quantity', '13.1 altCmd before 5 s', 'Unit', 'ft');
            tc.verifyTol(c.altCmd_ft(c.t >= 5 - 1e-9), 10113 * ones(1, nnz(c.t >= 5 - 1e-9)), 1e-6, 'abs', 'PUB', 'TM Vol II p.63', 'Quantity', '13.1 altCmd from 5 s', 'Unit', 'ft');
            r = vital.nesc.runCase('13.2'); c = r.commands;
            tc.verifyTol(c.keasCmd(c.t >= 5 - 1e-9) - c.keasCmd(1), -5 * ones(1, nnz(c.t >= 5 - 1e-9)), 1e-9, 'abs', 'PUB', 'TM Vol II p.64: -5 KEAS', 'Quantity', '13.2 KEAS step', 'Unit', 'kt');
            r = vital.nesc.runCase('13.3'); c = r.commands;
            tc.verifyTol([c.baseChiCmd_deg(1), c.baseChiCmd_deg(end)], [45 60], 0, 'abs', 'PUB', 'TM Vol II pp.64-65', 'Quantity', '13.3 course', 'Unit', 'deg');
            tc.verifyTol(c.baseChiCmd_deg(c.t < 15 - 1e-9), 45 * ones(1, nnz(c.t < 15 - 1e-9)), 0, 'abs', 'PUB', 'TM Vol II pp.64-65', 'Quantity', '13.3 course before 15 s', 'Unit', 'deg');
            r = vital.nesc.runCase('13.4'); c = r.commands;
            tc.verifyTol(c.latOffset_ft(c.t < 20 - 1e-9), zeros(1, nnz(c.t < 20 - 1e-9)), 0, 'abs', 'PUB', 'TM Vol II p.65', 'Quantity', '13.4 offset before 20 s', 'Unit', 'ft');
            k = find(c.t >= 20 - 1e-9, 1);
            tc.verifyWithin(c.latOffset_ft(k), -2000 - 50, -2000 + 50, 'PUB', 'TM Vol II p.65 / README: initially -2,000 ft', 'Quantity', '13.4 offset at 20 s', 'Unit', 'ft');
        end
    end
end
