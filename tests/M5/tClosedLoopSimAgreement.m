classdef (TestTags = {'M5'}) tClosedLoopSimAgreement < vital.test.VitalTestCase
%TCLOSEDLOOPSIMAGREEMENT  ADR-026 (INDEP): the sampled nonlinear simulation with an
%   nz-feedback controller agrees with the closed-loop linearization as dt -> 0.
%
%   Two code paths:
%     - vital.sim.run: the controller samples y(x_k, u_applied) at rate 1/dt
%     - vital.linear.linearize(..., 'Controller'): the continuous limit
%       u = step(x, y(x, u)), propagated with expm(A_cl t)
%   HELD OUT of the gate until the coordinator confirms that vital.sim.run
%   implements ADR-026. Against the old semantics (y at u_ref), the controller
%   sees about 10 % more loop gain, a dt-independent discrepancy, and the test
%   must fail.
%
%   Controller: de = de_ref + Knz (y.nz - nz0), Knz = 0.05 rad/g, static.
%   Case: README trim, dw = -0.3 m/s, 3 s; dt = 0.01 and 0.005 s (rate 1/dt).
%   PRE-REGISTERED (before any run):
%   1. Relative discrepancy e(dt) = max_t |dx_nl - dx_lin| / max_t |dx_lin| on w, q.
%      e(0.005) <= 2e-2.
%   2. Sampling is the only first-order difference (sample-and-hold, and the loop
%      solved once per sample). The Taylor remainder at this amplitude is about
%      6e-5 (tLinearVsNonlinear SP: 7.9e-4 at dw = -1.5 m/s, scaled linearly), so
%      e(0.01) / e(0.005) in [1.5, 2.5].

    methods (Test)
        function nzControllerSimMatchesLinearization(tc)
            Ft = 0.3048;
            AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            env = struct('g', 32.174 * Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * Ft, 'h', 10013 * Ft, 'gamma', 0, 'psi', 0);
            tr = vital.trim.solve(AC, env, cond);
            tc.assertEqual(tr.status, 'OK');
            [~, y0] = vital.plant.derivatives(tr.x, tr.u, AC, env);
            nz0 = y0.nz; Knz = 0.05;
            stepFcn = @(t, x, y, uref, s) deal(uref + [Knz * (y.nz - nz0); 0; 0; 0], s);
            lin = vital.linear.linearize(AC, env, tr, 'Controller', struct('rate_hz', 100, 'init', 0, 'static', true, 'step', stepFcn));
            tc.assertEqual(lin.status, 'OK', lin.reason);
            dx0 = zeros(12, 1); dx0(3) = -0.3;
            dts = [0.01 0.005]; e = zeros(2, 2);
            for k = 1:2
                c = struct('rate_hz', 1 / dts(k), 'init', 0, 'step', stepFcn);
                out = vital.sim.run(AC, env, vital.linear.toPlantState(lin, dx0), tr.u, 'dt', dts(k), 'tFinal', 3, 'Controller', c);
                tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
                dn = vital.linear.fromPlantState(lin, out.x);
                dl = vital.linear.response(lin, dx0, out.t);
                for i = 1:2
                    ch = [3 5]; ch = ch(i);
                    e(k, i) = max(abs(dn(ch, :) - dl(ch, :))) / max(abs(dl(ch, :)));
                end
            end
            names = {'w', 'q'};
            for i = 1:2
                tc.verifyWithin(e(2, i), 0, 2e-2, 'INDEP', 'sampled sim vs continuous-limit closed-loop linearization (ADR-026)', ...
                    'Quantity', ['rel discrepancy dt 0.005, ' names{i}]);
                tc.verifyWithin(e(1, i) / e(2, i), 1.5, 2.5, 'INDEP', 'sampling error is first order in dt (ADR-026)', ...
                    'Quantity', ['dt ratio, ' names{i}]);
            end
        end
    end
end
