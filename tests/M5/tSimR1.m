classdef (TestTags = {'M5'}) tSimR1 < vital.test.VitalTestCase
%TSIMR1  M5-B fixes for review R1 (reports/work/review1/REVIEW.md): controller
%   measurement semantics (ADR-026), controller failures, command limits, guard
%   edge cases, run_f16_sim channel map, piecewise-input validation.
%
%   PRE-REGISTERED expectations (written before the fixes):
%   1. controllerSeesAppliedCommand (ADR-026; R1 M8, escape R1-S7). F-16 README
%      trim, pilot elevator step +1 deg at t = 0 (u_ref), 100 Hz controller
%      u = u_ref + [K (y.nz - nz0); 0; 0; 0], K = -0.1 rad/g, dt = 0.01, 0.1 s.
%      An independent loop (vital.plant.derivatives + vital.sim.rk4Step, with
%      y evaluated at the command held over the step ending at t_k, and at
%      u_ref(0) for k = 0) must reproduce the logged commands to 1e-12 rad and
%      the state at 0.1 s to 1e-9 (same arithmetic; round-off only). Power
%      check (REG): the ADR-021 alternative (y at u_ref) changes the command at
%      the second sample by >= 1e-6 rad (estimate: K * dnz/dde * 3e-3 rad ~ 5e-4).
%   2. controllerErrorIsAStop (ADR-026). A controller raising 'fake:ctrl' once
%      t > 0.05 s (50 Hz, samples 0, 0.02, ...) -> STOPPED,
%      vital:sim:controllerError at 0.06 s, identifier and message kept.
%   3. nonFiniteControllerOutputIsNanState (ADR-026; escape R1-S12). NaN output
%      from t = 0.04 s -> STOPPED vital:sim:nanState at 0.04 s, detected at the
%      controller sample (stopDetail.stage 'controller sample'), not later by
%      the plant.
%   4. wrongSizeControllerOutputIsBadInput. 2 values for nu = 1 -> vital:badInput.
%   5. aileronBeyondLimitIsRecordedNotClipped (R1 M6). 60 deg aileron step at
%      0.05 s from the README trim (limit 21.5 deg, config.m): COMPLETED;
%      out.controlLimit.ever, firstTime 0.05 s, channel 'da', value 60 deg; the
%      logged command is the unclipped 60 deg (1e-15). With
%      Guards.stopOnControlLimit: STOPPED vital:sim:controlLimit at 0.05 s.
%   6. elevatorBetweenLimitAndTableEdgeIsFlagged (R1 M6). de = 24.5 deg (limit
%      24, table edge 25): controlLimit.ever at 0 s while outOfEnvelope.ever is
%      false; de = 23.5 deg: not flagged. Default limits (controlLimits) are
%      AC.limits: de +/-24, da +/-21.5, dr +/-30 deg, throttle [0 1].
%      RESULT: the "outOfEnvelope.ever is false" part FAILED in the first run.
%      Its premise (R1 M6: "the de table clamps at 25 deg") is wrong: the
%      elevator breakpoints DE1 end at +/-24 deg (F16_aero.dml:969, and
%      independentVarRef el max="24.0" extrapolate="neither" at :987), so a
%      24.5 deg command IS clamped and flagged. Corrected expectation (6b): at
%      24.5 deg BOTH flags fire. The silent case R1 found is real for the
%      aileron (dail = ail/20 enters linearly, F16_aero.dml:253, no clamp):
%      check 5b, outOfEnvelope.ever false for the 60 deg aileron step, so there
%      only the command-limit monitor sees it.
%   7-10. Guard edge cases (ADR-021; R1 M7, escapes R1-S1..S4), clock plant,
%      dt = 0.01, all stop times ANALYTIC:
%      7. y.alpha = t + 0.3, limit [-Inf 0.255]: STOPPED at 0 with 1 sample.
%      8. y.alpha = t, limit [-Inf 0.995], tFinal 1: STOPPED at 1.00 (the
%         final sample), 101 samples, not COMPLETED.
%      9. y.quatNorm NaN once t > 0.095: vital:sim:quatNorm at 0.10.
%      10. y.alpha NaN once t > 0.045: vital:sim:envelope at 0.05.
%   11. defaultQuatNormTolerance (MINOR 8; escape R1-S10). Default guards,
%      |q| = exp(0.01 t): the default tolerance 1e-6 is exceeded at the first
%      step (|q| - 1 = 1.00005e-4 at 0.01 s) -> vital:sim:quatNorm at 0.01;
%      out.guards lists the limit 1e-6 exactly.
%   12. finalSampleLogsLeftLimitCommand (MINOR 8; escape R1-S9). Smooth input
%      du = t, u0 = 0, tFinal 0.1: out.u(end) = 0.1 and out.u(end-1) = 0.09
%      (1e-15).
%   13. piecewiseStructMustBeConstant (MINOR 4). A struct input whose fcn varies
%      inside a step (cos 2t, breakpoint 0) is refused before the run with
%      vital:sim:inputNotPiecewiseConstant; a user struct that is constant
%      between its breakpoints is accepted and integrated exactly (1e-12).
%   14. runF16SimChannelMap (R1 M10; escape R1-S6). run_f16_sim step at 0 s,
%      0.1 s: 'aileron' changes only u(2) by deg2rad(1), 'rudder' only u(3),
%      'throttle' only u(4) by Amplitude_pct/100 (1e-15; other channels exact).
%   15. tighterConservationLocks (R1 M12, REG; registered after seeing the M5-B
%      provenance, which R1 quotes): torque-free energy and |H| relative drift
%      <= 1e-10 (measured 8.5e-12, 2.4e-12); dropped-mass z_n <= 1e-11 m
%      (measured 4.6e-13). Tighter NEW checks; the original checks stand.

    properties
        Ft = 0.3048
    end

    methods (Access = private)
        function [AC, env, x0, u0, tr] = f16Trim(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'CG', 25, 'g_ftps2', 32.174);
            tc.assertEqual(r.status, 'OK');
            tr = r.trim;
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            env = struct('g', 32.174 * tc.Ft, 'wind_n', [0;0;0], 'deltaT', 0);
            x0 = tr.x; u0 = tr.u;
        end

        function out = clock(~, P, tFinal, varargin)
            out = vital.sim.run(P, struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', tFinal, 'Plant', @fakePlant, varargin{:});
        end

        function verifyStop(tc, out, reason, tStop, why)
            tc.verifyEqual(out.status, 'STOPPED');
            tc.verifyEqual(out.stopReason, reason);
            tc.verifyTol(out.stopTime, tStop, 1e-9, 'abs', 'ANALYTIC', why, 'Quantity', 'stopTime', 'Unit', 's');
            tc.verifyTol(out.t(end), out.stopTime, 0, 'abs', 'ANALYTIC', 'stop sample is the last logged sample', 'Quantity', 't(end)', 'Unit', 's');
        end
    end

    methods (Test)
        % ---- ADR-026: controller measurement and failures ---------------------------
        function controllerSeesAppliedCommand(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            [~, y0] = vital.plant.derivatives(x0, u0, AC, env);
            K = -0.1; dt = 0.01;
            ctrl = struct('rate_hz', 100, 'init', struct('nz0', y0.nz), ...
                'step', @(t, x, y, uref, s) deal(uref + [K * (y.nz - s.nz0); 0; 0; 0], s));
            uref = u0 + [deg2rad(1); 0; 0; 0];
            % independent re-statement of ADR-026
            x = x0; uApp = uref; s = ctrl.init; Uexp = zeros(4, 10); alt = NaN;
            for k = 0:9
                t = k * dt;
                [~, y] = vital.plant.derivatives(x, uApp, AC, env);
                [u, s] = vital.sim.sampleController(ctrl, t, x, y, uref, s, 4);
                if k == 1
                    [~, yr] = vital.plant.derivatives(x, uref, AC, env);      % ADR-021 alternative
                    alt = uref(1) + K * (yr.nz - s.nz0);
                end
                Uexp(:, k+1) = u;
                x = vital.sim.rk4Step(@(tau, xs) vital.plant.derivatives(xs, u, AC, env), t, x, dt);
                uApp = u;
            end
            out = vital.sim.run(AC, env, x0, u0, 'dt', dt, 'tFinal', 0.1, 'Controller', ctrl, ...
                'Inputs', vital.sim.stepInput(0, deg2rad(1), 'elevator'));
            tc.assertEqual(out.status, 'COMPLETED');
            c = 'ADR-026: controller y at (x_k, command held over the step ending at t_k); independent loop (header 1)';
            tc.verifyTol(out.u(:, 1:10), Uexp, 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'commands', 'Unit', 'rad');
            tc.verifyTol(out.x(:, 11), x, 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'x(0.1 s)');
            tc.verifyWithin(abs(alt - Uexp(1, 2)), 1e-6, Inf, 'REG', ...
                'the test can tell ADR-026 from the ADR-021 choice (header 1)', 'Quantity', '|u(ADR-021) - u(ADR-026)| at sample 2', 'Unit', 'rad');
        end

        function controllerErrorIsAStop(tc)
            ctrl = struct('rate_hz', 50, 'init', 0, 'step', @errCtl);
            [~, ~, stop] = vital.sim.sampleController(ctrl, 0.06, [0; 0], struct(), 0, 0, 1);
            tc.verifyEqual(stop.reason, 'vital:sim:controllerError');
            out = vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.2, 'Plant', @fakePlant, 'Controller', ctrl);
            tc.verifyStop(out, 'vital:sim:controllerError', 0.06, 'first sample after 0.05 s at 50 Hz (header 2)');
            tc.verifyEqual(out.stopDetail.identifier, 'fake:ctrl');
            tc.verifySubstring(out.stopDetail.message, 'fake controller failure');
            tc.verifyTrue(all(isfinite(out.x(:))), 'logged states finite');
        end

        function nonFiniteControllerOutputIsNanState(tc)
            ctrl = struct('rate_hz', 50, 'init', 0, 'step', @nanCtl);
            [~, ~, stop] = vital.sim.sampleController(ctrl, 0.04, [0; 0], struct(), 0, 0, 1);
            tc.verifyEqual(stop.reason, 'vital:sim:nanState');
            out = vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.2, 'Plant', @fakePlant, 'Controller', ctrl);
            tc.verifyStop(out, 'vital:sim:nanState', 0.04, 'NaN output from 0.04 s (header 3)');
            tc.verifyEqual(out.stopDetail.stage, 'controller sample');
        end

        function wrongSizeControllerOutputIsBadInput(tc)
            ctrl = struct('rate_hz', 50, 'init', 0, 'step', @(t, x, y, u, s) deal([u; u], s));
            tc.verifyError(@() vital.sim.sampleController(ctrl, 0, [0; 0], struct(), 0, 0, 1), 'vital:badInput');
            tc.verifyError(@() vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.1, ...
                'Plant', @fakePlant, 'Controller', ctrl), 'vital:badInput');
        end

        % ---- command limits (R1 M6) ------------------------------------------------------
        function aileronBeyondLimitIsRecordedNotClipped(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            lim = vital.sim.controlLimits(AC, 4);
            tc.verifyTol([lim.lo(2) lim.hi(2)], deg2rad([-21.5 21.5]), 1e-15, 'abs', 'ANALYTIC', ...
                'AC.limits.da_deg (vital.aircraft.f16.config)', 'Quantity', 'da limits', 'Unit', 'rad');
            in = vital.sim.stepInput(0.05, deg2rad(60), 'aileron');
            out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.1, 'Inputs', in);
            tc.verifyEqual(out.status, 'COMPLETED');
            cl = out.controlLimit;
            tc.verifyTrue(cl.ever, 'a 60 deg aileron command must be flagged');
            tc.verifyTol(cl.firstTime, 0.05, 1e-9, 'abs', 'ANALYTIC', 'step at 0.05 s (header 5)', 'Quantity', 'first limit time', 'Unit', 's');
            tc.verifyEqual(cl.channel, 'da');
            tc.verifyTol(cl.value, deg2rad(60), 1e-15, 'abs', 'ANALYTIC', 'recorded command', 'Quantity', 'value', 'Unit', 'rad');
            tc.verifyTol(out.u(2, end), deg2rad(60), 1e-15, 'abs', 'ANALYTIC', 'never silently clipped', 'Quantity', 'logged da', 'Unit', 'rad');
            tc.verifyFalse(out.outOfEnvelope.ever, '5b: aileron enters linearly (dail = ail/20, F16_aero.dml:253): no table clamp, only the limit monitor sees it');
            out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.1, 'Inputs', in, 'Guards', struct('stopOnControlLimit', true));
            tc.verifyStop(out, 'vital:sim:controlLimit', 0.05, 'optional stop on a command beyond AC.limits (header 5)');
        end

        function elevatorBetweenLimitAndTableEdgeIsFlagged(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            lim = vital.sim.controlLimits(AC, 4);
            tc.verifyTol([lim.lo lim.hi], [deg2rad([-24 -21.5 -30]) 0; deg2rad([24 21.5 30]) 1].', 1e-15, 'abs', 'ANALYTIC', ...
                'AC.limits de_deg, da_deg, dr_deg, throttle (header 6)', 'Quantity', 'default limits');
            simAt = @(de) vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.1, ...
                'Inputs', vital.sim.stepInput(0, deg2rad(de) - u0(1), 'elevator'));
            out = simAt(24.5);
            tc.verifyTrue(out.controlLimit.ever, 'de 24.5 deg beyond the 24 deg limit');
            tc.verifyTol(out.controlLimit.firstTime, 0, 1e-12, 'abs', 'ANALYTIC', 'command applied from t = 0', 'Quantity', 'first time', 'Unit', 's');
            % Pre-registered 'outOfEnvelope false' FAILED: DE1 ends at 24 deg (header 6, RESULT).
            tc.verifyTrue(out.outOfEnvelope.ever, '6b: DE1 breakpoints end at 24 deg (F16_aero.dml:969, :987): 24.5 deg is clamped');
            out = simAt(23.5);
            tc.verifyFalse(out.controlLimit.ever, 'de 23.5 deg is inside the limit');
            tc.verifyTrue(out.controlLimit.monitored);
        end

        % ---- guard edge cases (R1 M7) ------------------------------------------------------
        function guardFiresAtTimeZero(tc)
            out = tc.clock(struct('alphaOffset', 0.3), 1, 'Guards', struct('envelope', struct('alpha', [-Inf 0.255])));
            tc.verifyStop(out, 'vital:sim:envelope', 0, 'violated at t = 0 (header 7)');
            tc.verifyEqual(numel(out.t), 1);
        end

        function guardFiresAtFinalSample(tc)
            out = tc.clock(struct('alphaOffset', 0), 1, 'Guards', struct('envelope', struct('alpha', [-Inf 0.995])));
            tc.verifyStop(out, 'vital:sim:envelope', 1.00, 'violated first at the final sample (header 8)');
            tc.verifyEqual(numel(out.t), 101);
        end

        function nanQuatNormTrips(tc)
            out = tc.clock(struct('quatNanAfter', 0.095), 1);
            tc.verifyStop(out, 'vital:sim:quatNorm', 0.10, 'NaN quatNorm trips its guard (header 9)');
        end

        function nanEnvelopeValueTrips(tc)
            out = tc.clock(struct('alphaNanAfter', 0.045), 1, 'Guards', struct('envelope', struct('alpha', [-1 1])));
            tc.verifyStop(out, 'vital:sim:envelope', 0.05, 'NaN alpha trips its guard (header 10)');
        end

        % ---- MINOR 8 -------------------------------------------------------------------
        function defaultQuatNormTolerance(tc)
            out = vital.sim.run(struct(), struct(), [1; 0; 0; 0], 0, 'dt', 0.01, 'tFinal', 1, 'Plant', @driftPlant);
            tc.verifyStop(out, 'vital:sim:quatNorm', 0.01, 'default tolerance 1e-6 exceeded at the first step (header 11)');
            g = out.guards(strcmp({out.guards.name}, 'quatNorm'));
            tc.verifyExact(g.limit, 1e-6, 'ANALYTIC', 'documented default quatNormTol', 'Quantity', 'default quatNormTol');
        end

        function finalSampleLogsLeftLimitCommand(tc)
            out = vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.1, 'Plant', @fakePlant, 'Inputs', @(t) t);
            tc.verifyTol(out.u(end-1:end), [0.09 0.1], 1e-15, 'abs', 'ANALYTIC', ...
                'final sample logs the stage-4 command of the last step (header 12)', 'Quantity', 'u at 0.09, 0.10 s');
        end

        % ---- MINOR 4 -------------------------------------------------------------------
        function piecewiseStructMustBeConstant(tc)
            bad = struct('channel', 1, 'fcn', @(t) cos(2*t), 'breakpoints', 0);
            tc.verifyError(@() tc.clock(struct(), 0.1, 'Inputs', bad), 'vital:sim:inputNotPiecewiseConstant');
            good = struct('channel', 1, 'fcn', @(t) 2 * (t >= 0.05), 'breakpoints', 0.05);
            out = tc.clock(struct(), 0.1, 'Inputs', good);
            tc.verifyTol(out.x(2, end), 2 * 0.05, 1e-12, 'abs', 'ANALYTIC', 'exact integral of a user piecewise input (header 13)', 'Quantity', 'acc');
        end

        % ---- R1 M10 --------------------------------------------------------------------
        function runF16SimChannelMap(tc)
            cases = {'aileron', 2, deg2rad(1); 'rudder', 3, deg2rad(1); 'throttle', 4, 0.05};
            for i = 1:size(cases, 1)
                out = run_f16_sim(565.6854, 10013, 'Input', 'step', 'Channel', cases{i, 1}, 'Start_s', 0, ...
                    'Amplitude_deg', 1, 'Amplitude_pct', 5, 'Duration_s', 0.1, 'Quiet', true);
                tc.assertEqual(out.status, 'COMPLETED');
                d = out.u - out.trim.trim.u;
                ch = cases{i, 2}; other = setdiff(1:4, ch);
                tc.verifyTol(d(ch, :), cases{i, 3} * ones(1, numel(out.t)), 1e-15, 'abs', 'ANALYTIC', ...
                    ['run_f16_sim channel ' cases{i, 1} ' (header 14)'], 'Quantity', ['du ' cases{i, 1}]);
                tc.verifyExact(d(other, :), zeros(3, numel(out.t)), 'ANALYTIC', 'other channels untouched', 'Quantity', ['others ' cases{i, 1}]);
            end
        end

        % ---- R1 M12 --------------------------------------------------------------------
        function tighterConservationLocks(tc)
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25); J = AC.J;
            AC.loadsFcn = @(varargin) deal(zeros(3,1), zeros(3,1), struct('outOfEnvelope', false));
            out = vital.sim.run(AC, struct('g', 0, 'wind_n', [0;0;0], 'deltaT', 0), ...
                [100; 0; 0; 1; 0.5; 0.3; 1; 0; 0; 0; 0; 0; -3000], zeros(4, 1), 'dt', 0.01, 'tFinal', 10, ...
                'Guards', struct('envelope', struct()));
            W = out.x(4:6, :); E = 0.5 * sum(W .* (J*W), 1); H = vecnorm(J*W, 2, 1);
            c = 'R1 M12 tighter lock on tSimCore torqueFreeRigidBodyConserves (header 15)';
            tc.verifyTol(E, E(1)*ones(size(E)), 1e-10, 'rel', 'REG', c, 'Quantity', 'energy (tight)', 'Unit', 'J');
            tc.verifyTol(H, H(1)*ones(size(H)), 1e-10, 'rel', 'REG', c, 'Quantity', '|H| (tight)', 'Unit', 'kg m2/s');
            g = 9.80665;
            out = vital.sim.run(AC, struct('g', g, 'wind_n', [0;0;0], 'deltaT', 0), ...
                [100; 0; 0; 0; 0; 0; 1; 0; 0; 0; 0; 0; -3000], zeros(4, 1), 'dt', 0.01, 'tFinal', 2);
            tc.verifyTol(out.x(13, :), -3000 + 0.5*g*out.t.^2, 1e-11, 'abs', 'REG', ...
                'R1 M12 tighter lock on droppedMassIsExact (header 15)', 'Quantity', 'z_n (tight)', 'Unit', 'm');
        end
    end
end

% ---- fakes ------------------------------------------------------------------------------
function [xd, y] = fakePlant(x, u, P, ~)
% x(1) is a clock; behaviour switched by fields of the "aircraft" P.
xd = [1; u(1)];
y = struct();
if isstruct(P) && isfield(P, 'alphaOffset'), y.alpha = x(1) + P.alphaOffset; end
if isstruct(P) && isfield(P, 'alphaNanAfter')
    y.alpha = x(1); if x(1) > P.alphaNanAfter, y.alpha = NaN; end
end
if isstruct(P) && isfield(P, 'quatNanAfter')
    y.quatNorm = 1; if x(1) > P.quatNanAfter, y.quatNorm = NaN; end
end
end

function [xd, y] = driftPlant(x, ~, ~, ~)
xd = 0.01 * x;
y = struct('quatNorm', norm(x));
end

function [u, s] = errCtl(t, ~, ~, u, s)
if t > 0.05, error('fake:ctrl', 'fake controller failure at t = %.3f s', t); end
end

function [u, s] = nanCtl(t, ~, ~, u, s)
if t > 0.04 - 1e-9, u = NaN; end
end
