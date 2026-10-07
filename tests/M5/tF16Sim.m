classdef (TestTags = {'M5'}) tF16Sim < vital.test.VitalTestCase
%TF16SIM  M5-B: time simulation of the NESC F-16 from the README trim.
%
%   Condition: vital.aircraft.f16.trimLevel(565.6854, 10013), g = 32.174 ft/s^2,
%   CG 25 % MAC (NESC README Table 11; trim residual ~3e-16, tF16Trim).
%
%   PRE-REGISTERED expectations (written before vital.sim.run existed; no
%   simulation was run to choose them):
%   1. trimHoldSixtySeconds (REG bound, derived). 60 s at dt = 0.02 s with no
%      input. The only forcing is the trim residual r (xdot at x0) plus
%      round-off: |r| <= 1e-12 in m/s^2 or rad/s^2 (the scaled residual is
%      3e-16; 1e-12 allows 3 decades for scaling and eps * |state|). A linear
%      mode with growth rate sigma turns r into at most r T e^(sigma T) (rate
%      states) and r T^2/2 e^(sigma T) (position). Allowing sigma <= 0.1 1/s
%      (the F-16 at CG 25 % is statically stable; its slowest modes, phugoid
%      and spiral, have |Re lambda| of order 0.01 1/s) gives e^6 ~ 400:
%        |dV| <= 1e-12*60*400 = 2.4e-8 m/s         registered 1e-6 m/s
%        |dalpha|, |dtheta| <= 2.4e-8/172 rad      registered 1e-8 rad
%        |q|, |p|, |r| (same order)                registered 1e-8 rad/s
%        |dh| <= 1e-12*1800*400 = 7.2e-7 m         registered 1e-4 m
%        |beta|, |phi|, |psi| (lateral: not forced by a symmetric trim, beta = 0
%        exactly)                                  registered 1e-8 rad
%      Round-off: 3000 steps x ulp(172 m/s) = 8e-11 m/s, far inside the bounds.
%      A failure means an unstable mode faster than 0.1 1/s or a driver bug
%      (u0 not applied, state reordered, env not passed); it must be explained,
%      not re-toleranced.
%      RESULT (M5-B, R1 MINOR 1): every deviation is exactly 0 (|q| <= 1e-16):
%      the residual increments (dt x 3e-15 m/s^2) are below half an ulp of the
%      states, so the trim is a floating-point fixed point of RK4. This test is
%      therefore PLUMBING evidence only (u0 applied, env passed, no spurious
%      input); stability evidence is tests/M5/tLinearVsNonlinear.m (agent linear).
%   2. Control-sign tests (ANALYTIC sign; CONVENTIONS 7 and tF16Plant
%      controlSignsMatchVitalConventions), 0.1 s from the README trim, every
%      logged sample after t = 0 must have the sign:
%        +1 deg elevator (TED) doublet from t = 0  -> q < -1e-6 rad/s
%        +1 deg aileron (right TED down) step      -> p < -1e-6 rad/s
%        +1 deg rudder (TEL) step                  -> r < -1e-6 rad/s
%          (rdot ~ (Ixx N + Ixz L)/(Ixx Izz - Ixz^2): Ixx|N_dr| >> Ixz|L_dr|)
%        +10 % throttle step (no engine lag, ADR-014) -> u_b - u_b(0) > 1e-6 m/s
%      1e-6 is far above round-off (1e-12) and far below the expected ~1e-3
%      rad/s after one step.
%   3. diagnosticsAtTrim (ANALYTIC): y.theta = trim theta (1e-12 rad),
%      y.phi = y.psi = 0 (1e-12), y.quatNorm = 1 (1e-14), and the body-axis
%      normal load factor y.nz = cos(theta) (1e-9): in unaccelerated level
%      flight the aero + propulsive force balances gravity, whose body z
%      component is m g cos(theta).
%   4. runF16SimPrintsSummaryAndReturns: run_f16_sim with an elevator doublet
%      prints a summary (status, stop reason, alpha, q, V, altitude) and
%      returns the simulation output (COMPLETED, 2 s, 201 samples).
%   5. runF16SimNonOkTrimNotSimulated: at 150 ft/s the trim is INFEASIBLE
%      (tF16Trim stallLimitedIsInfeasible); run_f16_sim reports the status and
%      does not simulate (status NOT_SIMULATED, no time history).

    properties
        Ft = 0.3048
        AC
        Env
        Tr
    end

    methods (TestMethodSetup)
        function setup(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'CG', 25, 'g_ftps2', 32.174);
            tc.assertEqual(r.status, 'OK');
            tc.Tr = r.trim;
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.Env = struct('g', 32.174 * tc.Ft, 'wind_n', [0;0;0], 'deltaT', 0);
        end
    end

    methods (Access = private)
        function out = sim(tc, T, varargin)
            out = vital.sim.run(tc.AC, tc.Env, tc.Tr.x, tc.Tr.u, 'dt', 0.01, 'tFinal', T, varargin{:});
            tc.assertEqual(out.status, 'COMPLETED', ['stopped: ' out.stopReason]);
        end
    end

    methods (Test)
        function trimHoldSixtySeconds(tc)
            out = vital.sim.run(tc.AC, tc.Env, tc.Tr.x, tc.Tr.u, 'dt', 0.02, 'tFinal', 60);
            tc.assertEqual(out.status, 'COMPLETED', ['stopped: ' out.stopReason]);
            tc.verifyTol(out.t(end), 60, 1e-12, 'abs', 'ANALYTIC', 'full 60 s logged', 'Quantity', 't(end)', 'Unit', 's');
            y = out.y; c = 'trim-hold bound derived in class header 1';
            tc.verifyTol(y.V, y.V(1)*ones(size(y.V)), 1e-6, 'abs', 'REG', c, 'Quantity', 'V drift', 'Unit', 'm/s');
            tc.verifyTol(y.alpha, tc.Tr.alpha*ones(size(y.V)), 1e-8, 'abs', 'REG', c, 'Quantity', 'alpha drift', 'Unit', 'rad');
            tc.verifyTol(y.theta, tc.Tr.theta*ones(size(y.V)), 1e-8, 'abs', 'REG', c, 'Quantity', 'theta drift', 'Unit', 'rad');
            tc.verifyTol([y.p; y.q; y.r], zeros(3, numel(y.V)), 1e-8, 'abs', 'REG', c, 'Quantity', 'body rates', 'Unit', 'rad/s');
            tc.verifyTol(y.h, y.h(1)*ones(size(y.V)), 1e-4, 'abs', 'REG', c, 'Quantity', 'altitude drift', 'Unit', 'm');
            tc.verifyTol([y.beta; y.phi; y.psi], zeros(3, numel(y.V)), 1e-8, 'abs', 'REG', c, 'Quantity', 'lateral', 'Unit', 'rad');
        end

        function elevatorPulseGivesNoseDownRate(tc)
            out = tc.sim(0.1, 'Inputs', vital.sim.doublet(0, 0.5, deg2rad(1), 'elevator'));
            tc.verifyWithin(max(out.y.q(2:end)), -Inf, -1e-6, 'ANALYTIC', ...
                'CONVENTIONS 7: +de (TED) -> nose-down moment -> q < 0', 'Quantity', 'max q after +de', 'Unit', 'rad/s');
        end

        function aileronGivesLeftRoll(tc)
            out = tc.sim(0.1, 'Inputs', vital.sim.stepInput(0, deg2rad(1), 'aileron'));
            tc.verifyWithin(max(out.y.p(2:end)), -Inf, -1e-6, 'ANALYTIC', ...
                'CONVENTIONS 7: +da (right TED down) -> roll left -> p < 0', 'Quantity', 'max p after +da', 'Unit', 'rad/s');
        end

        function rudderGivesNoseLeftRate(tc)
            out = tc.sim(0.1, 'Inputs', vital.sim.stepInput(0, deg2rad(1), 'rudder'));
            tc.verifyWithin(max(out.y.r(2:end)), -Inf, -1e-6, 'ANALYTIC', ...
                'CONVENTIONS 7: +dr (TEL) -> nose left -> r < 0', 'Quantity', 'max r after +dr', 'Unit', 'rad/s');
        end

        function throttleStepAccelerates(tc)
            out = tc.sim(0.1, 'Inputs', vital.sim.stepInput(0, 0.10, 'throttle'));
            tc.verifyWithin(min(out.x(1, 2:end) - out.x(1, 1)), 1e-6, Inf, 'ANALYTIC', ...
                'more thrust along body x (no engine lag, ADR-014) -> udot > 0', 'Quantity', 'min du_b after +throttle', 'Unit', 'm/s');
        end

        function diagnosticsAtTrim(tc)
            out = tc.sim(0.02);
            y = out.y; th = tc.Tr.theta;
            tc.verifyTol(y.theta(1), th, 1e-12, 'abs', 'ANALYTIC', 'Euler 3-2-1 from the trim quaternion', 'Quantity', 'theta', 'Unit', 'rad');
            tc.verifyTol([y.phi(1) y.psi(1)], [0 0], 1e-12, 'abs', 'ANALYTIC', 'wings level, heading 0', 'Quantity', 'phi, psi', 'Unit', 'rad');
            tc.verifyTol(y.quatNorm(1), 1, 1e-14, 'abs', 'ANALYTIC', 'unit trim quaternion', 'Quantity', 'quatNorm');
            tc.verifyTol(y.nz(1), cos(th), 1e-9, 'abs', 'ANALYTIC', ...
                'level unaccelerated flight: body-axis nz = cos(theta) (class header 3)', 'Quantity', 'nz');
            for f = {'V', 'alpha', 'beta', 'mach', 'qbar', 'h', 'phi', 'theta', 'psi', 'nz', 'p', 'q', 'r'}
                tc.verifyEqual(size(y.(f{1})), [1 numel(out.t)], ['logged series y.' f{1}]);
            end
        end

        function runF16SimPrintsSummaryAndReturns(tc)
            txt = evalc(['out = run_f16_sim(565.6854, 10013, ''Input'', ''doublet'', ''Channel'', ''elevator'', ' ...
                '''Amplitude_deg'', 1, ''Start_s'', 0.5, ''Width_s'', 0.5, ''Duration_s'', 2);']);
            tc.verifyEqual(out.status, 'COMPLETED');
            tc.verifyEqual(numel(out.t), 201);
            for s = {'COMPLETED', 'alpha', 'q', 'V', 'altitude', 'stop reason'}
                tc.verifySubstring(txt, s{1}, ['summary mentions ' s{1}]);
            end
            tc.verifyEqual(out.trim.status, 'OK');
        end

        function runF16SimNonOkTrimNotSimulated(tc)
            txt = evalc('out = run_f16_sim(150, 10013, ''Duration_s'', 1);');
            tc.verifyEqual(out.status, 'NOT_SIMULATED');
            tc.verifyEqual(out.trim.status, 'INFEASIBLE');
            tc.verifySubstring(txt, 'INFEASIBLE');
            tc.verifySubstring(txt, 'not simulated');
            tc.verifyFalse(isfield(out, 't'), 'no time history for a non-OK trim');
        end
    end
end
