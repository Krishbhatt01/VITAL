classdef (TestTags = {'M9'}) tSlxEquivalence < vital.test.VitalTestCase
%TSLXEQUIVALENCE  M9-A: the generated Simulink model equals vital.sim.run
%   (docs/PLAN_M9.md section 7; registered before any Simulink run).
%
%   Condition: NESC README trim, CG 25 % MAC (vital.trim.solve level, as tests/M7).
%   Metric (computed HERE, not by vital.slx.compare): for each of the 13 states
%     e_i = max_k |x_slx,i - x_mat,i| / max(1, max_k |x_mat,i|),  E = max_i e_i.
%   E <= 1e-9 in every case. Reason: same plant at the same stage states and
%   commands; only floating-point operation order in the ode4 update can differ:
%   1000 steps x 2.2e-16 x e^6 ~ 1e-10, one decade of margin. A one-step hold
%   misalignment, ode1 or a sign error is >= 1e-4.
%   Source INDEP: Simulink's ode4, scheduler and ZOH are an independent
%   implementation of what vital.sim.run does by hand (the physics is shared on
%   purpose and verified in M3-M5, not here).
%     E1 open loop, 1 deg elevator doublet (0.5 s, 0.5 s), dt 0.01, 2 s; also
%        t = (0:N) dt (1e-12 s) and u(1..N) (1e-12)
%     E2 M7 SAS (pitchSas Kq 0.02 Ka 0.14 + yawDamper Kr 0.82), 100 Hz, dt 0.01,
%        10 s, elevator doublet (1 deg, 1 s, 0.5 s) + rudder doublet (1 deg, 4 s,
%        0.5 s); same number of controller samples
%     E3 M7 SAS at 50 Hz (nHold 2), dt 0.01, 5 s, elevator doublet
%     E4 NESC LQR, 200 Hz, dt 0.005, 3 s, initial dw = -0.3 m/s
%     E5 trim hold, dt 0.02, 10 s: tests/M5/tF16Sim.m bounds (REG) + E <= 1e-9
%     E6 the E1 response is not trivial: max |q| >= 1e-3 rad/s
%   vital.slx.compare is checked against a hand-built perturbation.

    properties
        AC
        env
        tr
        Ft = 0.3048
        Model
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
            % behaviour is tested on a FRESH build, so a builder change shows here too
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.addTeardown(@() bdclose('VitalPlant'));
            s = vital.slx.build('Folder', d); tc.Model = s.file;
        end
    end

    methods (Access = private)
        function [os, om] = both(tc, x0, varargin)
            os = vital.slx.simulate(tc.AC, tc.env, x0, tc.tr.u, varargin{:}, 'Model', tc.Model);
            om = vital.sim.run(tc.AC, tc.env, x0, tc.tr.u, varargin{:});
            tc.assertEqual(om.status, 'COMPLETED', om.stopReason);
            tc.assertEqual(os.status, 'COMPLETED', os.stopReason);
            tc.assertEqual(size(os.x), size(om.x), 'same number of samples');
        end

        function E = verifyEquivalent(tc, os, om, label)
            sc = max(1, max(abs(om.x), [], 2));
            e = max(abs(os.x - om.x), [], 2) ./ sc;
            E = max(e);
            tc.verifyWithin(E, 0, 1e-9, 'INDEP', ['Simulink ode4 + ZOH vs vital.sim.run (PLAN_M9 7, ' label ')'], ...
                'Quantity', [label ' max scaled state difference E']);
            fprintf('%s: E = %.3g\n', label, E);
        end

        function c = sas(tc, rate)
            c = vital.ctrl.combine(vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.02, 'Ka', 0.14, 'Rate', rate), ...
                vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.82, 'Rate', rate));
        end
    end

    methods (Test)
        function e1OpenLoopDoublet(tc)
            [os, om] = tc.both(tc.tr.x, 'dt', 0.01, 'tFinal', 2, ...
                'Inputs', vital.sim.doublet(0.5, 0.5, deg2rad(1), 'elevator'));
            tc.verifyEquivalent(os, om, 'E1');
            tc.verifyTol(os.t, (0:200) * 0.01, 1e-12, 'abs', 'ANALYTIC', 't_k = k dt', 'Quantity', 't', 'Unit', 's');
            tc.verifyTol(os.u(:, 1:end-1), om.u(:, 1:end-1), 1e-12, 'abs', 'INDEP', 'PLAN_M9 7 E1: same held command', ...
                'Quantity', 'u(1..N)', 'Unit', 'rad');
            % E6: a real response is compared
            tc.verifyWithin(max(abs(om.x(5, :))), 1e-3, Inf, 'REG', 'PLAN_M9 7 E6 non-vacuous', 'Quantity', 'max |q|', 'Unit', 'rad/s');
        end

        function e2ClosedLoopSas(tc)
            in = {vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'), vital.sim.doublet(4, 0.5, deg2rad(1), 'rudder')};
            [os, om] = tc.both(tc.tr.x, 'dt', 0.01, 'tFinal', 10, 'Inputs', in, 'Controller', tc.sas(100));
            tc.verifyEquivalent(os, om, 'E2');
            tc.verifyEqual(os.controller.nCalls, om.controller.nCalls, 'controller sample count');
        end

        function e3SasFiftyHz(tc)
            [os, om] = tc.both(tc.tr.x, 'dt', 0.01, 'tFinal', 5, ...
                'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'), 'Controller', tc.sas(50));
            tc.verifyEquivalent(os, om, 'E3');
            tc.verifyEqual(os.controller.nCalls, om.controller.nCalls, 'controller sample count');
        end

        function e4NescLqr(tc)
            x0 = tc.tr.x; x0(3) = x0(3) - 0.3;
            c = vital.ctrl.nescLqr(tc.AC, tc.env, tc.tr, 'Rate', 200);
            [os, om] = tc.both(x0, 'dt', 0.005, 'tFinal', 3, 'Controller', c);
            tc.verifyEquivalent(os, om, 'E4');
        end

        function e5TrimHold(tc)
            [os, om] = tc.both(tc.tr.x, 'dt', 0.02, 'tFinal', 10);
            tc.verifyEquivalent(os, om, 'E5');
            y = os.y; c = 'trim-hold bounds of tests/M5/tF16Sim.m header 1 (PLAN_M9 7 E5)';
            n = numel(y.V);
            tc.verifyTol(y.V, y.V(1) * ones(1, n), 1e-6, 'abs', 'REG', c, 'Quantity', 'V drift', 'Unit', 'm/s');
            tc.verifyTol(y.alpha, y.alpha(1) * ones(1, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'alpha drift', 'Unit', 'rad');
            tc.verifyTol(y.theta, y.theta(1) * ones(1, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'theta drift', 'Unit', 'rad');
            tc.verifyTol([y.p; y.q; y.r], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'body rates', 'Unit', 'rad/s');
            tc.verifyTol(y.h, y.h(1) * ones(1, n), 1e-4, 'abs', 'REG', c, 'Quantity', 'altitude drift', 'Unit', 'm');
            tc.verifyTol([y.beta; y.phi; y.psi], zeros(3, n), 1e-8, 'abs', 'REG', c, 'Quantity', 'lateral', 'Unit', 'rad');
        end

        function compareMetricIsRight(tc)
            om = struct('t', 0:2, 'x', [zeros(12, 3); 100 200 300], 'u', zeros(4, 3));
            os = om; os.x(13, 2) = os.x(13, 2) + 3e-6; os.x(1, 3) = 2e-7;
            c = vital.slx.compare(os, om);
            tc.verifyTol(c.e(13), 1e-8, 1e-15, 'abs', 'ANALYTIC', '3e-6 / max(1, 300) (tol 1e-15: (300 + 3e-6) - 300 carries the 5.7e-14 ulp of 300; the registered 1e-15 was a test arithmetic error, corrected at GREEN)', 'Quantity', 'e_13');
            tc.verifyTol(c.e(1), 2e-7, 1e-15, 'abs', 'ANALYTIC', '2e-7 / max(1, 0)', 'Quantity', 'e_1');
            tc.verifyTol(c.E, 2e-7, 1e-15, 'abs', 'ANALYTIC', 'max', 'Quantity', 'E');
        end
    end
end
