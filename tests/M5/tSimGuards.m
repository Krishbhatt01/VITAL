classdef (TestTags = {'M5'}) tSimGuards < vital.test.VitalTestCase
%TSIMGUARDS  M5-B: run guards stop the simulation with an exact reason and
%   time (never an exception), and invalid set-ups are identified errors.
%
%   Definitions under test (vital.sim.run header): a guard is checked on the
%   plant output y of every logged sample t_k = k dt, including t = 0. A guard
%   that fires at t_k stops the run with stopTime = t_k, and t_k is the last
%   logged sample. A step whose stage evaluation fails (non-finite derivative
%   or plant error) is rejected: stopTime is the start t_k of that step, the
%   last accepted (finite) state.
%
%   PRE-REGISTERED expectations (written before vital.sim.run existed; all
%   stop times ANALYTIC, from the fake plants' closed forms, dt = 0.01):
%   1. nanStateStopsAtLastFiniteState: clock plant returning a NaN derivative
%      once clock > 1.003 s -> STOPPED, vital:sim:nanState, stopTime 1.00
%      (the step from 1.00 fails at its stage-2 time 1.005), every logged
%      state finite (FC-302).
%   2. nonFiniteF16LoadsAreNanState: F-16 at the README trim with a loadsFcn
%      that returns NaN when throttle > 0.5, and a +0.5 throttle step at
%      0.5 s: vital:plant:nonFinite inside the plant is reported as
%      vital:sim:nanState at stopTime 0.50, the plant identifier kept.
%   3. plantErrorStopsAndKeepsIdentifier: plant raising 'fake:boom' once
%      clock > 0.503 -> vital:sim:plantError at 0.50; out.stopDetail keeps
%      identifier 'fake:boom' and the message.
%   4. envelopeStopsAtFirstExcursion: y.alpha = clock, Guards.envelope.alpha
%      = [-Inf 0.255] -> vital:sim:envelope at 0.26 (FC-602).
%   5. envelopeDefaultsFromAircraftLimits: F-16 default guards take alpha and
%      beta limits from AC.limits (deg2rad([-10 45]), deg2rad([-30 30])).
%   6. alphaExcursionOnF16Stops: README trim, -5 deg elevator step, alpha
%      limit alpha_trim + 1 deg -> STOPPED vital:sim:envelope with
%      alpha(end) > limit >= every earlier alpha and stopTime = t(end) (REG:
%      the crossing time itself has no closed form).
%   7. groundStops: zero-load F-16 at h0 = 10 m, v = [100 0 0] m/s: h =
%      10 - g t^2/2 < 0 first at t = 1.43 s (h(1.42) = +0.113 m, h(1.43) =
%      -0.027 m) -> vital:sim:ground, stopTime 1.43; with hMin = 5 m, first
%      at 1.01 s (h(1.00) = 5.097, h(1.01) = 4.998).
%   8. quatNormStops: plant qdot = 0.01 q, |q| = exp(0.01 t); tolerance 1e-3
%      is first exceeded at t = 0.10 (|q|-1 = 1.0005e-3; 9.004e-4 at 0.09)
%      -> vital:sim:quatNorm at 0.10 (FC-601).
%   9. outOfEnvelopeRecordedNotStopped: y.outOfEnvelope true once clock >
%      0.305: run COMPLETED, first time 0.31 recorded; with
%      StopOnOutOfEnvelope -> vital:sim:outOfEnvelope at 0.31.
%   10. absentGuardFieldIsDisabledAndRecorded: a plant with no quatNorm,
%      alpha, beta or h in y runs to completion and out.guards lists each of
%      these guards as inactive with a reason (never silently assumed).
%   11-13. badStepErrors (FC-301), badInputErrors, badControllerRate: exact
%      identifiers vital:sim:badStep / vital:badInput.

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

        function out = clockRun(~, AC, tFinal, varargin)
            out = vital.sim.run(AC, struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', tFinal, 'Plant', @clockPlant, varargin{:});
        end

        function verifyStop(tc, out, reason, tStop, why)
            tc.verifyEqual(out.status, 'STOPPED');
            tc.verifyEqual(out.stopReason, reason);
            tc.verifyTol(out.stopTime, tStop, 1e-9, 'abs', 'ANALYTIC', why, 'Quantity', 'stopTime', 'Unit', 's');
            tc.verifyTol(out.t(end), out.stopTime, 0, 'abs', 'ANALYTIC', 'the stop sample is the last logged sample', 'Quantity', 't(end)', 'Unit', 's');
            tc.verifyTrue(all(isfinite(out.x(:))), 'every logged state is finite');
        end

        function [AC, env, x0] = droppedF16(~, h0)
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            AC.loadsFcn = @(varargin) deal(zeros(3,1), zeros(3,1), struct('outOfEnvelope', false));
            env = struct('g', 9.80665, 'wind_n', [0;0;0], 'deltaT', 0);
            x0 = [100; 0; 0; 0; 0; 0; 1; 0; 0; 0; 0; 0; -h0];
        end
    end

    methods (Test)
        function nanStateStopsAtLastFiniteState(tc)
            out = tc.clockRun(struct('nanAfter', 1.003), 2);
            tc.verifyStop(out, 'vital:sim:nanState', 1.00, 'step from 1.00 s fails at stage time 1.005 s (header 1)');
        end

        function nonFiniteF16LoadsAreNanState(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            AC.loadsFcn = @nanLoads;
            out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 1, 'Inputs', vital.sim.stepInput(0.5, 0.5, 'throttle'));
            tc.verifyStop(out, 'vital:sim:nanState', 0.50, 'throttle step at 0.5 s makes the loads NaN (header 2)');
            tc.verifyEqual(out.stopDetail.identifier, 'vital:plant:nonFinite');
        end

        function plantErrorStopsAndKeepsIdentifier(tc)
            out = tc.clockRun(struct('errorAfter', 0.503), 1);
            tc.verifyStop(out, 'vital:sim:plantError', 0.50, 'plant raises once clock > 0.503 s (header 3)');
            tc.verifyEqual(out.stopDetail.identifier, 'fake:boom');
            tc.verifySubstring(out.stopDetail.message, 'fake plant failure');
        end

        function envelopeStopsAtFirstExcursion(tc)
            out = tc.clockRun(struct('alpha', true), 1, 'Guards', struct('envelope', struct('alpha', [-Inf 0.255])));
            tc.verifyStop(out, 'vital:sim:envelope', 0.26, 'y.alpha = t exceeds 0.255 first at 0.26 s (header 4)');
            tc.verifyEqual(out.stopDetail.field, 'alpha');
        end

        function envelopeDefaultsFromAircraftLimits(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.02);
            G = out.guards;
            ga = G(strcmp({G.name}, 'envelope:alpha'));
            gb = G(strcmp({G.name}, 'envelope:beta'));
            tc.assertNumElements(ga, 1); tc.assertNumElements(gb, 1);
            tc.verifyTrue(ga.active && gb.active, 'alpha and beta guards active for the F-16');
            % R1 MINOR 3: this is plumbing (AC.limits -> guard), so ANALYTIC, not PUB.
            tc.verifyTol(ga.limit, deg2rad([-10 45]), 1e-15, 'abs', 'ANALYTIC', 'deg2rad(AC.limits.alpha_deg) of vital.aircraft.f16.config', 'Quantity', 'alpha limits', 'Unit', 'rad');
            tc.verifyTol(gb.limit, deg2rad([-30 30]), 1e-15, 'abs', 'ANALYTIC', 'deg2rad(AC.limits.beta_deg) of vital.aircraft.f16.config', 'Quantity', 'beta limits', 'Unit', 'rad');
            names = {G([G.active]).name};
            tc.verifyTrue(all(ismember({'quatNorm', 'ground', 'outOfEnvelope'}, names)), 'F-16 y provides quatNorm, h, outOfEnvelope');
        end

        function alphaExcursionOnF16Stops(tc)
            [AC, env, x0, u0, tr] = tc.f16Trim();
            lim = tr.alpha + deg2rad(1);
            out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 3, ...
                'Inputs', vital.sim.stepInput(0, deg2rad(-5), 'elevator'), ...
                'Guards', struct('envelope', struct('alpha', [-Inf lim])));
            tc.verifyEqual(out.status, 'STOPPED');
            tc.verifyEqual(out.stopReason, 'vital:sim:envelope');
            tc.verifyTol(out.t(end), out.stopTime, 0, 'abs', 'ANALYTIC', 'stop sample is the last logged sample', 'Quantity', 't(end)', 'Unit', 's');
            tc.verifyWithin(out.y.alpha(end) - lim, 0, Inf, 'REG', 'alpha beyond the limit at the stop sample', 'Quantity', 'alpha(stop) - limit', 'Unit', 'rad');
            tc.verifyWithin(max(out.y.alpha(1:end-1)) - lim, -Inf, 0, 'REG', 'no earlier sample beyond the limit', 'Quantity', 'max earlier alpha - limit', 'Unit', 'rad');
        end

        function groundStops(tc)
            [AC, env, x0] = tc.droppedF16(10);
            out = vital.sim.run(AC, env, x0, [0;0;0;0], 'dt', 0.01, 'tFinal', 3);
            tc.verifyStop(out, 'vital:sim:ground', 1.43, 'h = 10 - g t^2/2 < 0 first at 1.43 s (header 7)');
            out = vital.sim.run(AC, env, x0, [0;0;0;0], 'dt', 0.01, 'tFinal', 3, 'Guards', struct('hMin', 5));
            tc.verifyStop(out, 'vital:sim:ground', 1.01, 'h < 5 m first at 1.01 s (header 7)');
        end

        function quatNormStops(tc)
            out = vital.sim.run(struct(), struct(), [1; 0; 0; 0], 0, 'dt', 0.01, 'tFinal', 1, ...
                'Plant', @driftPlant, 'Guards', struct('quatNormTol', 1e-3));
            tc.verifyStop(out, 'vital:sim:quatNorm', 0.10, '|q| = exp(0.01 t) exceeds 1 + 1e-3 first at 0.10 s (header 8)');
        end

        function outOfEnvelopeRecordedNotStopped(tc)
            out = tc.clockRun(struct('oobAfter', 0.305), 0.5);
            tc.verifyEqual(out.status, 'COMPLETED');
            tc.verifyTrue(out.outOfEnvelope.ever);
            tc.verifyTol(out.outOfEnvelope.firstTime, 0.31, 1e-9, 'abs', 'ANALYTIC', 'first clamped sample (header 9)', 'Quantity', 'first outOfEnvelope', 'Unit', 's');
            out = tc.clockRun(struct('oobAfter', 0.305), 0.5, 'Guards', struct('stopOnOutOfEnvelope', true));
            tc.verifyStop(out, 'vital:sim:outOfEnvelope', 0.31, 'optional stop on clamped tables (header 9)');
        end

        function absentGuardFieldIsDisabledAndRecorded(tc)
            AC = struct('limits', struct('alpha_deg', [-10 45], 'beta_deg', [-30 30]));
            out = vital.sim.run(AC, struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.1, 'Plant', @clockPlant);
            tc.verifyEqual(out.status, 'COMPLETED');
            G = out.guards;
            for name = {'quatNorm', 'envelope:alpha', 'envelope:beta', 'ground', 'outOfEnvelope'}
                gi = G(strcmp({G.name}, name{1}));
                tc.assertNumElements(gi, 1, name{1});
                tc.verifyFalse(gi.active, [name{1} ' must be inactive']);
                tc.verifySubstring(gi.note, 'absent', [name{1} ' records why it is disabled']);
            end
        end

        function badStepErrors(tc)
            p = {'Plant', @clockPlant};
            r = @(varargin) vital.sim.run(struct(), struct(), [0; 0], 0, p{:}, varargin{:});
            tc.verifyError(@() r('dt', 0, 'tFinal', 1), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', -0.01, 'tFinal', 1), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', NaN, 'tFinal', 1), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', Inf, 'tFinal', 1), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', 0.01, 'tFinal', 0), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', 0.01, 'tFinal', Inf), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', 0.01, 'tFinal', 0.015), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', 0.01), 'vital:sim:badStep');
            tc.verifyError(@() r('dt', 0.01, 'tFinal', 1, 'Inputs', vital.sim.doublet(0.105, 0.1, 1, 1)), 'vital:sim:badStep');
        end

        function badControllerRate(tc)
            mk = @(hz) struct('rate_hz', hz, 'init', 0, 'step', @(t, x, y, u, s) deal(u, s));
            r = @(c) vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 1, 'Plant', @clockPlant, 'Controller', c);
            tc.verifyError(@() r(mk(30)), 'vital:sim:badStep');     % 1/(30*0.01) = 3.33 steps
            tc.verifyError(@() r(mk(200)), 'vital:sim:badStep');    % faster than the base step
            tc.verifyError(@() r(mk(0)), 'vital:sim:badStep');
        end

        function badInputErrors(tc)
            [AC, env, x0, u0] = tc.f16Trim();
            x = x0; x(2) = NaN;
            tc.verifyError(@() vital.sim.run(AC, env, x, u0, 'dt', 0.01, 'tFinal', 0.1), 'vital:badInput');
            tc.verifyError(@() vital.sim.run(AC, env, x0(1:12), u0, 'dt', 0.01, 'tFinal', 0.1), 'vital:badInput');
            tc.verifyError(@() vital.sim.run(AC, env, [], u0, 'dt', 0.01, 'tFinal', 0.1), 'vital:badInput');
            u = u0; u(1) = Inf;
            tc.verifyError(@() vital.sim.run(AC, env, x0, u, 'dt', 0.01, 'tFinal', 0.1), 'vital:badInput');
            tc.verifyError(@() vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.1, 'Guards', struct('altMin', 3)), 'vital:badInput');
            tc.verifyError(@() vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 0.1, 'Inputs', vital.sim.stepInput(0, 1, 'flaps')), 'vital:badInput');
        end
    end
end

% ---- fake plants ----------------------------------------------------------------
function [xd, y] = clockPlant(x, u, P, ~)
% x(1) is a clock (xdot = 1). Behaviour switched by fields of the "aircraft" P.
y = struct();
xd = [1; u(1)];
if isfield(P, 'nanAfter') && x(1) > P.nanAfter, xd(2) = NaN; end
if isfield(P, 'errorAfter') && x(1) > P.errorAfter
    error('fake:boom', 'fake plant failure at clock %.4f', x(1));
end
if isfield(P, 'alpha'), y.alpha = x(1); end
if isfield(P, 'oobAfter'), y.outOfEnvelope = x(1) > P.oobAfter; end
end

function [xd, y] = driftPlant(x, ~, ~, ~)
xd = 0.01 * x;
y = struct('quatNorm', norm(x));
end

function [F, M, info] = nanLoads(ad, u, h, atm, AC)
[F, M, info] = vital.aircraft.f16.loads(ad, u, h, atm, AC);
if u(4) > 0.5, F(1) = NaN; end
end
