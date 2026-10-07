classdef (TestTags = {'M5'}) tSimCore < vital.test.VitalTestCase
%TSIMCORE  M5-B: the fixed-step RK4 core of vital.sim.run (CONVENTIONS 10).
%
%   PRE-REGISTERED expectations (written before vital.sim existed):
%   1. rk4OrderHarmonicOscillator (ANALYTIC). x'' = -x, x(0) = 1, x'(0) = 0,
%      exact x = cos t. vital.sim.rk4 with dt = 0.1, 0.05, 0.025 over 10 s;
%      error = max over the common 0.1 s grid of |[x v] - exact|. The ratio of
%      successive errors must lie in [15.5, 16.5]. Derivation: the RK4
%      amplification factor R(ih) differs from e^(ih) by -i h^5/120 + h^6/720,
%      so the global error is T h^4/120 (1 + 0.35 h^2 + ...); the ratio is
%      16 (1 + O(h^2)) = 16.04 at h = 0.1.
%   2. rk4OrderSmoothInputThroughRun (ANALYTIC). x'' + x = cos(2t) through
%      vital.sim.run with a two-state plant xdot = [x2; -x1 + u] and the input
%      du = cos(2t) given as a smooth function handle (evaluated at the RK4
%      stage times). Exact x = (4/3) cos t - (1/3) cos 2t. dt = 0.05, 0.025,
%      0.0125 over 10 s; ratio in [14, 18]: 16 (1 + (E5/E4) h) with the
%      next-order term |E5/E4| <= 5 for forcing frequency 2 rad/s. An input
%      sampled at the step start would give first order (ratio ~2).
%   3. zohControllerForcingIsFirstOrder (ANALYTIC). The same forced
%      oscillator, but the forcing cos(2t) comes from a Controller at
%      rate_hz = 1/dt, i.e. zero-order held across the RK4 stages as a
%      discrete controller is. dt = 0.1, 0.05, 0.025; ratio in [1.8, 2.2]:
%      the hold delays the forcing by dt/2 on average, a global error O(dt)
%      with an O(dt) relative correction (|c| <= 2). This proves the order
%      test can see a discrete element.
%   4. droppedMassIsExact (ANALYTIC). F-16 mass properties, loadsFcn returning
%      zero loads, level attitude, w_b = 0, v_b = [100 0 0] m/s, g = 9.80665:
%      z_n = z0 + g t^2/2, x_n = 100 t, w = g t. RK4 is exact for polynomial
%      solutions of degree <= 4; tolerances are round-off: 1e-8 m (z), 1e-9 m
%      (x), 1e-9 m/s (w) after 200 steps of 0.01 s.
%   5. torqueFreeRigidBodyConserves (ANALYTIC + REG tolerance). F-16 inertia
%      (with Ixz), zero loads, g = 0, w0 = [1 0.5 0.3] rad/s (not a principal
%      axis), 10 s at dt = 0.01. Rotational energy wJw/2 and |J w| are
%      invariants: relative drift <= 1e-7 (RK4 local error ~ (lambda dt)^5/120
%      ~ 1e-12 per step with lambda ~ 1.2 1/s; <= 1e-9 after 1000 steps; 100x
%      margin). | |q| - 1 | <= 1e-10 at every logged sample (norm-changing RK4
%      error ~5e-14 per step, damped by the k = 1 1/s stabilisation of
%      vital.eom.rigidBodyDerivs: equilibrium ~3e-12).
%      RESULT for the |q| part: FAILED in the first M5-B run (max 1.273e-10).
%      The derivation was wrong: it treated the norm error as that of the
%      pure rotation (|R(i w h/2)| = 1 - O(h^6)). But the RK4 stage states
%      q + h/2 k1 lie off the unit sphere by O((w h)^2), and the stabilisation
%      term k(1 - q'q)q acts on them. Superseded by hypothesis 9
%      (quaternionNormFollowsStabilisedRk4Error), which derives the error in
%      closed form; the energy and |H| checks of this test stand unchanged.
%   6. controllerHeldAndSampledAtRate (ANALYTIC). Plant x = [clock; acc],
%      xdot = [1; u]. Controller at 50 Hz with dt = 0.01 (hold 2 steps) returns
%      u = u_ref + t_sample. Over 0.2 s it is called exactly 10 times, at
%      t = 0, 0.02, ..., 0.18 (to 1e-12 s); every plant call at a stage
%      mid-point sees the held value; acc(0.2) = sum(0.02 j * 0.02, j=0..9)
%      = 0.018 exactly (to 1e-12), whereas a controller re-evaluated at every
%      stage would give the integral 0.02.
%   7. doubletAndStepSwitchOnStepBoundaries (ANALYTIC). Integrator plant,
%      u0 = 0.5, doublet(0.1, 0.05, 2, 1): acc = 0.5 t + 2 (clipped ramp),
%      exact to 1e-12 at 0.15, 0.20, 0.30 s; the logged input is the value
%      applied over the following step (2.5 at 0.10, -1.5 at 0.15, 0.5 at
%      0.20). A stage straddling a switch would leave an error 2 dt/6 = 3e-3.
%      stepInput(0.05, -1, 1) likewise: acc(0.2) = 0.5*0.2 - 0.15.
%   8. logHoldsStartAndFinalState (ANALYTIC). out.t = (0:N) dt, x(:,1) = x0,
%      status COMPLETED, stopTime = tFinal, x(:,end) the final state.
%   9. quaternionNormFollowsStabilisedRk4Error (ANALYTIC; added after
%      hypothesis 5 failed, registered BEFORE this test was run). For
%      qdot = A q + k(1 - q'q) q with A skew, A^2 = -om^2 I (om = |w|/2), one RK4
%      step from |q| = 1 changes |q|^2 by e = k om^2 h^5 (om^2 - 4k^2)/24
%      + O(h^6). This is an independent derivation: a 60-digit vpa evaluation
%      of the step for (k, om) = (1,1), (1,2), (2,1), (2,2) fixes the
%      coefficients of the only admissible h^5 monomials k om^4, k^3 om^2, k^5
%      as 1/24, -1/6, 0 (reports/fragments/sim/NOTES.md). The stabilisation
%      restores |q|^2 by the factor (1 - 2kh) per step, so the steady deviation
%      is |q| - 1 = -om^2 h^4 (4k^2 - om^2)/96. Case 5 (k = 1, h = 0.01,
%      |w| = 1.13...1.22 rad/s) predicts -1.23e-10 ... -1.40e-10. Checks:
%      (a) | |q| - 1 | <= 1.1 x the prediction at the largest logged |w|, at
%          every sample (10 % for the O(h) next-order terms);
%      (b) the final deviation equals the prediction at the final |w| to 15 %
%          (rel; the lag of the 0.5 s restoring time behind the slowly varying |w|);
%      (c) halving dt divides the deviation by 16 +/- 1.5 (the h^4 law).
%      Honesty note: the diagnostic run that exposed the failure (dt = 0.02,
%      0.01, 0.005: 2.05e-9, 1.27e-10, 7.9e-12, and 1.289e-10 for constant w)
%      was seen before (c) was written, so (c) restates an observation; (a) and
%      (b) rest on the closed form derived independently of that run.

    properties
        Ft = 0.3048
    end

    methods (Access = private)
        function out = oscillatorRun(~, dt, mode)
            x0 = [1; 0];
            switch mode
                case 'input'
                    out = vital.sim.run(struct(), struct(), x0, 0, 'dt', dt, 'tFinal', 10, ...
                        'Plant', @oscPlant, 'Inputs', @(t) cos(2*t));
                case 'zoh'
                    c = struct('rate_hz', 1/dt, 'init', 0, 'step', @(t, x, y, uref, s) deal(uref + cos(2*t), s));
                    out = vital.sim.run(struct(), struct(), x0, 0, 'dt', dt, 'tFinal', 10, ...
                        'Plant', @oscPlant, 'Controller', c);
            end
        end

        function e = forcedError(~, out, gridStep)
            t = out.t; sel = abs(t/gridStep - round(t/gridStep)) < 1e-6;
            t = t(sel); X = out.x(:, sel);
            ex = [4/3*cos(t) - 1/3*cos(2*t); -4/3*sin(t) + 2/3*sin(2*t)];
            e = max(vecnorm(X - ex, 2, 1));
        end

        function AC = zeroLoadF16(~)
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            AC.loadsFcn = @(varargin) deal(zeros(3,1), zeros(3,1), struct('outOfEnvelope', false));
        end
    end

    methods (Test)
        function rk4OrderHarmonicOscillator(tc)
            f = @(t, x) [x(2); -x(1)];
            dts = [0.1 0.05 0.025]; err = zeros(size(dts));
            for i = 1:numel(dts)
                N = round(10/dts(i));
                [X, t] = vital.sim.rk4(f, [1; 0], dts(i), N);
                sel = 1:round(0.1/dts(i)):N+1;
                err(i) = max(vecnorm(X(:, sel) - [cos(t(sel)); -sin(t(sel))], 2, 1));
            end
            ratio = err(1:end-1) ./ err(2:end);
            tc.verifyWithin(ratio, 15.5, 16.5, 'ANALYTIC', ...
                'RK4 global error T h^4/120 (1 + 0.35 h^2): ratio 16 per halving (class header 1)', ...
                'Quantity', 'RK4 error ratio, harmonic oscillator');
        end

        function rk4OrderSmoothInputThroughRun(tc)
            dts = [0.05 0.025 0.0125]; err = zeros(size(dts));
            for i = 1:numel(dts)
                out = tc.oscillatorRun(dts(i), 'input');
                tc.assertEqual(out.status, 'COMPLETED');
                err(i) = tc.forcedError(out, 0.05);
            end
            ratio = err(1:end-1) ./ err(2:end);
            tc.verifyWithin(ratio, 14, 18, 'ANALYTIC', ...
                'inputs evaluated at the RK4 stage times keep 4th order (class header 2)', ...
                'Quantity', 'RK4 error ratio, smooth input via run');
        end

        function zohControllerForcingIsFirstOrder(tc)
            dts = [0.1 0.05 0.025]; err = zeros(size(dts));
            for i = 1:numel(dts)
                out = tc.oscillatorRun(dts(i), 'zoh');
                tc.assertEqual(out.status, 'COMPLETED');
                err(i) = tc.forcedError(out, 0.1);
            end
            ratio = err(1:end-1) ./ err(2:end);
            tc.verifyWithin(ratio, 1.8, 2.2, 'ANALYTIC', ...
                'forcing held across stages (discrete controller) is first order (class header 3)', ...
                'Quantity', 'error ratio, ZOH forcing');
        end

        function droppedMassIsExact(tc)
            AC = tc.zeroLoadF16(); g = 9.80665;
            env = struct('g', g, 'wind_n', [0;0;0], 'deltaT', 0);
            x0 = [100; 0; 0; 0; 0; 0; 1; 0; 0; 0; 0; 0; -3000];
            out = vital.sim.run(AC, env, x0, [0; 0; 0; 0], 'dt', 0.01, 'tFinal', 2);
            tc.assertEqual(out.status, 'COMPLETED');
            t = out.t;
            c = 'free fall: z = z0 + g t^2/2; RK4 exact for polynomial solutions (class header 4)';
            tc.verifyTol(out.x(13, :), -3000 + 0.5*g*t.^2, 1e-8, 'abs', 'ANALYTIC', c, 'Quantity', 'z_n', 'Unit', 'm');
            tc.verifyTol(out.x(11, :), 100*t, 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'x_n', 'Unit', 'm');
            tc.verifyTol(out.x(3, :), g*t, 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', 'w_b', 'Unit', 'm/s');
        end

        function torqueFreeRigidBodyConserves(tc)
            AC = tc.zeroLoadF16(); J = AC.J;
            env = struct('g', 0, 'wind_n', [0;0;0], 'deltaT', 0);
            w0 = [1; 0.5; 0.3];
            x0 = [100; 0; 0; w0; 1; 0; 0; 0; 0; 0; -3000];
            g = struct('envelope', struct());          % air data are meaningless here
            out = vital.sim.run(AC, env, x0, [0; 0; 0; 0], 'dt', 0.01, 'tFinal', 10, 'Guards', g);
            tc.assertEqual(out.status, 'COMPLETED');
            W = out.x(4:6, :);
            E = 0.5 * sum(W .* (J*W), 1);
            H = vecnorm(J*W, 2, 1);
            c = 'torque-free rigid body invariants; RK4 drift bound in class header 5';
            tc.verifyTol(E, E(1)*ones(size(E)), 1e-7, 'rel', 'ANALYTIC', c, 'Quantity', 'rotational energy', 'Unit', 'J');
            tc.verifyTol(H, H(1)*ones(size(H)), 1e-7, 'rel', 'ANALYTIC', c, 'Quantity', '|H|', 'Unit', 'kg m2/s');
            % The |q| <= 1e-10 check of hypothesis 5 FAILED (1.27e-10) and is superseded
            % by quaternionNormFollowsStabilisedRk4Error (class header 9).
            tc.verifyTol(out.y.quatNorm, vecnorm(out.x(7:10, :), 2, 1), 1e-15, 'abs', 'ANALYTIC', ...
                'y.quatNorm is the norm of the incoming quaternion', 'Quantity', 'y.quatNorm');
        end

        function quaternionNormFollowsStabilisedRk4Error(tc)
            AC = tc.zeroLoadF16(); k = 1;                % k of vital.eom.rigidBodyDerivs
            env = struct('g', 0, 'wind_n', [0;0;0], 'deltaT', 0);
            x0 = [100; 0; 0; 1; 0.5; 0.3; 1; 0; 0; 0; 0; 0; -3000];
            pred = @(om, h) -om.^2 * h^4 .* (4*k^2 - om.^2) / 96;
            dev = zeros(1, 2); h = [0.01 0.005];
            for i = 1:2
                out = vital.sim.run(AC, env, x0, [0; 0; 0; 0], 'dt', h(i), 'tFinal', 10, 'Guards', struct('envelope', struct()));
                tc.assertEqual(out.status, 'COMPLETED');
                dn = vecnorm(out.x(7:10, :), 2, 1) - 1;
                om = vecnorm(out.x(4:6, :), 2, 1) / 2;
                dev(i) = dn(end);
                if i == 1
                    c = 'steady RK4 norm error of the stabilised kinematics, -om^2 h^4 (4k^2 - om^2)/96 (class header 9)';
                    tc.verifyWithin(max(abs(dn)), 0, 1.1 * max(abs(pred(om, h(i)))), 'ANALYTIC', [c ' (a)'], 'Quantity', 'max ||q| - 1|');
                    tc.verifyTol(dn(end), pred(om(end), h(i)), 0.15, 'rel', 'ANALYTIC', [c ' (b)'], 'Quantity', '|q| - 1 at 10 s');
                end
            end
            tc.verifyTol(dev(1) / dev(2), 16, 1.5, 'abs', 'ANALYTIC', 'deviation proportional to h^4 (class header 9c)', 'Quantity', 'norm error ratio per halving');
        end

        function controllerHeldAndSampledAtRate(tc)
            recorder('reset');
            c = struct('rate_hz', 50, 'init', struct('n', 0), 'step', @countingStep);
            out = vital.sim.run(struct(), struct(), [0; 0], 0, 'dt', 0.01, 'tFinal', 0.2, ...
                'Plant', @recPlant, 'Controller', c);
            tc.assertEqual(out.status, 'COMPLETED');
            tc.verifyExact(out.controller.nCalls, 10, 'ANALYTIC', '50 Hz over 0.2 s with dt = 0.01: one call per 2 steps', 'Quantity', 'controller calls');
            tc.verifyExact(out.controller.state.n, 10, 'ANALYTIC', 'controller state threaded through the calls', 'Quantity', 'state count');
            tc.verifyTol(out.controller.tSample, 0:0.02:0.18, 1e-12, 'abs', 'ANALYTIC', 'sample instants k*0.02 s', 'Quantity', 'sample times', 'Unit', 's');
            log = recorder('get');                       % [clock; u] of every plant call
            mid = abs(mod(log(1, :), 0.01) - 0.005) < 1e-9;   % stages 2 and 3
            held = floor(log(1, mid)/0.02 + 1e-9) * 0.02;
            tc.assertGreaterThan(nnz(mid), 0);
            tc.verifyTol(log(2, mid), held, 1e-12, 'abs', 'ANALYTIC', 'held command at the stage mid-points', 'Quantity', 'u at stages 2, 3');
            tc.verifyTol(out.x(2, end), 0.018, 1e-12, 'abs', 'ANALYTIC', ...
                'sum of held commands (0.02 j) * 0.02 s; 0.02 if re-evaluated per stage (class header 6)', 'Quantity', 'acc(0.2)');
            tc.verifyTol(out.u(1, 1:end-1), floor((0:19)/2)*0.02, 1e-12, 'abs', 'ANALYTIC', 'logged command = held command', 'Quantity', 'logged u');
        end

        function doubletAndStepSwitchOnStepBoundaries(tc)
            out = vital.sim.run(struct(), struct(), [0; 0], 0.5, 'dt', 0.01, 'tFinal', 0.3, ...
                'Plant', @intPlant, 'Inputs', vital.sim.doublet(0.1, 0.05, 2, 1));
            tc.assertEqual(out.status, 'COMPLETED');
            at = @(s) find(abs(out.t - s) < 1e-9, 1);
            c = 'exact integral of a doublet that switches on step boundaries (class header 7)';
            tc.verifyTol(out.x(2, [at(0.15) at(0.2) at(0.3)]), [0.5*0.15 + 0.1, 0.1, 0.15], 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'acc');
            tc.verifyTol(out.u(1, [at(0.1) at(0.15) at(0.2)]), [2.5 -1.5 0.5], 1e-15, 'abs', 'ANALYTIC', ...
                'logged input is the value applied over the following step', 'Quantity', 'u');
            out2 = vital.sim.run(struct(), struct(), [0; 0], 0.5, 'dt', 0.01, 'tFinal', 0.2, ...
                'Plant', @intPlant, 'Inputs', vital.sim.stepInput(0.05, -1, 1));
            tc.verifyTol(out2.x(2, end), 0.5*0.2 - 0.15, 1e-12, 'abs', 'ANALYTIC', 'exact integral of a step at 0.05 s', 'Quantity', 'acc step');
        end

        function logHoldsStartAndFinalState(tc)
            x0 = [0; 0];
            out = vital.sim.run(struct(), struct(), x0, 1, 'dt', 0.01, 'tFinal', 0.5, 'Plant', @intPlant);
            tc.verifyEqual(out.status, 'COMPLETED');
            tc.verifyEqual(out.stopReason, '');
            tc.verifyTol(out.t, (0:50)*0.01, 1e-15, 'abs', 'ANALYTIC', 't_k = k dt (no accumulated drift)', 'Quantity', 't', 'Unit', 's');
            tc.verifyExact(out.x(:, 1), x0, 'ANALYTIC', 'log starts with x0', 'Quantity', 'x(t=0)');
            tc.verifyTol(out.stopTime, 0.5, 1e-15, 'abs', 'ANALYTIC', 'completed run stops at tFinal', 'Quantity', 'stopTime', 'Unit', 's');
            tc.verifyTol(out.x(:, end), [0.5; 0.5], 1e-14, 'abs', 'ANALYTIC', 'final state logged', 'Quantity', 'x(tFinal)');
            tc.verifyEqual(size(out.u), [1 51]);
        end
    end
end

% ---- fake plants (layout-agnostic: any state size, y without guard fields) ----
function [xd, y] = oscPlant(x, u, ~, ~)
xd = [x(2); -x(1) + u(1)];
y = struct();
end

function [xd, y] = intPlant(x, u, ~, ~)
xd = [1; u(1)];
y = struct();
end

function [xd, y] = recPlant(x, u, ~, ~)
recorder('add', [x(1); u(1)]);
xd = [1; u(1)];
y = struct();
end

function [u, s] = countingStep(t, ~, ~, uref, s)
s.n = s.n + 1;
u = uref + t;
end

function v = recorder(cmd, rec)
persistent L
switch cmd
    case 'reset', L = zeros(2, 0);
    case 'add', L(:, end+1) = rec;
end
v = L;
end
