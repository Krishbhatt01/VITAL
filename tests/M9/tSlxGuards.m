classdef (TestTags = {'M9'}) tSlxGuards < vital.test.VitalTestCase
%TSLXGUARDS  M9-A guards and error identifiers (docs/PLAN_M9.md section 3).
%   PRE-REGISTERED:
%   1. dt/tFinal not an integer number of steps, or a controller rate that does
%      not divide 1/dt -> vital:sim:badStep (as vital.sim.run).
%   2. non-finite x0 -> vital:badInput.
%   3. a smooth function-handle input -> vital:slx:unsupportedInput.
%   4. a model file that does not exist -> vital:slx:modelMissing.
%   5. the kernel called without a context (model run outside vital.slx.simulate)
%      -> vital:slx:noContext.
%   6. |q| = 1.001 at x0, tol 1e-6 -> STOPPED vital:sim:quatNorm at t = 0, one sample,
%      the same status, reason and stop time as vital.sim.run.
%   7. a controller whose output is NaN from t = 0.5 s -> STOPPED vital:sim:nanState,
%      stop time and log equal to vital.sim.run (E <= 1e-9 as PLAN_M9 7).
%   8. a controller that raises 'test:boom' from t = 0.3 s -> STOPPED
%      vital:sim:controllerError, stopDetail.identifier 'test:boom', same stop time.

    properties
        AC
        env
        tr
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'CG', 25, 'g_ftps2', 32.174);
            tc.assertEqual(r.status, 'OK');
            tc.tr = r.trim;
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * 0.3048, 'wind_n', [0; 0; 0], 'deltaT', 0);
        end
    end

    methods (Access = private)
        function out = slx(tc, x0, varargin)
            out = vital.slx.simulate(tc.AC, tc.env, x0, tc.tr.u, varargin{:});
        end

        function sameStop(tc, os, om)
            tc.verifyEqual(os.status, 'STOPPED');
            tc.verifyEqual(os.stopReason, om.stopReason);
            tc.verifyTol(os.stopTime, om.stopTime, 1e-12, 'abs', 'INDEP', 'same stop sample as vital.sim.run', ...
                'Quantity', 'stopTime', 'Unit', 's');
            tc.assertEqual(size(os.x), size(om.x), 'same truncated log');
            e = max(max(abs(os.x - om.x), [], 2) ./ max(1, max(abs(om.x), [], 2)));
            tc.verifyWithin(e, 0, 1e-9, 'INDEP', 'PLAN_M9 7 metric on the truncated log', 'Quantity', 'E');
        end
    end

    methods (Test)
        function badStepIsError(tc)
            tc.verifyError(@() tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 0.015), 'vital:sim:badStep');
            c = vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Rate', 30);
            tc.verifyError(@() tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 0.1, 'Controller', c), 'vital:sim:badStep');
        end

        function nonFiniteStateIsError(tc)
            x0 = tc.tr.x; x0(2) = NaN;
            tc.verifyError(@() tc.slx(x0, 'dt', 0.01, 'tFinal', 0.1), 'vital:badInput');
        end

        function smoothInputUnsupported(tc)
            tc.verifyError(@() tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 0.1, 'Inputs', @(t) zeros(4, 1)), ...
                'vital:slx:unsupportedInput');
        end

        function missingModelIsError(tc)
            f = fullfile(tempdir, 'noSuchDir', 'VitalPlant.slx');
            tc.verifyError(@() tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 0.1, 'Model', f), 'vital:slx:modelMissing');
        end

        function kernelWithoutContextIsError(tc)
            vital.slx.context('clear');
            tc.verifyError(@() vital.slx.kernel('plant', tc.tr.x, tc.tr.u), 'vital:slx:noContext');
        end

        function quatNormGuardStops(tc)
            x0 = tc.tr.x; x0(7:10) = 1.001 * x0(7:10);
            g = struct('quatNormTol', 1e-6);
            os = tc.slx(x0, 'dt', 0.01, 'tFinal', 0.5, 'Guards', g);
            om = vital.sim.run(tc.AC, tc.env, x0, tc.tr.u, 'dt', 0.01, 'tFinal', 0.5, 'Guards', g);
            tc.verifyEqual(os.stopReason, 'vital:sim:quatNorm');
            tc.verifyNumElements(os.t, 1);
            tc.sameStop(os, om);
        end

        function nanControllerStops(tc)
            c = struct('rate_hz', 100, 'init', [], 'step', @(t, x, y, uref, s) nanAfter(t, uref, s));
            os = tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 1, 'Controller', c);
            om = vital.sim.run(tc.AC, tc.env, tc.tr.x, tc.tr.u, 'dt', 0.01, 'tFinal', 1, 'Controller', c);
            tc.verifyEqual(os.stopReason, 'vital:sim:nanState');
            tc.sameStop(os, om);
        end

        function controllerErrorStops(tc)
            c = struct('rate_hz', 100, 'init', [], 'step', @(t, x, y, uref, s) boomAfter(t, uref, s));
            os = tc.slx(tc.tr.x, 'dt', 0.01, 'tFinal', 1, 'Controller', c);
            om = vital.sim.run(tc.AC, tc.env, tc.tr.x, tc.tr.u, 'dt', 0.01, 'tFinal', 1, 'Controller', c);
            tc.verifyEqual(os.stopReason, 'vital:sim:controllerError');
            tc.verifyEqual(os.stopDetail.identifier, 'test:boom');
            tc.sameStop(os, om);
        end
    end
end

function [u, s] = nanAfter(t, uref, s)
u = uref;
if t >= 0.5 - 1e-9, u(1) = NaN; end
end

function [u, s] = boomAfter(t, uref, s)
u = uref;
if t >= 0.3 - 1e-9, error('test:boom', 'controller failure injected at t = %g', t); end
end
