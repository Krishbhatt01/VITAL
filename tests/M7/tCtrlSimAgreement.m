classdef (TestTags = {'M7'}) tCtrlSimAgreement < vital.test.VitalTestCase
%TCTRLSIMAGREEMENT  M7 check (c), INDEP: a small-perturbation sampled nonlinear
%   simulation (vital.sim.run, controller sampled at 1/dt, ADR-026) with each M7
%   controller agrees with the closed-loop linear prediction expm(A_cl t) dx0 of
%   vital.linear.linearize(..., 'Controller', c), as dt -> 0 (the method of
%   tests/M5/tClosedLoopSimAgreement.m).
%
%   Condition: NESC README trim. Duration 3 s.
%   PRE-REGISTERED (before any implementation):
%     e(dt) = max_t |dx_nl - dx_lin| / max_t |dx_lin| on the channels listed.
%     controller                         dx0               channels  dt pair
%     pitchSas Kq 0.2, Ka 0.5            dw = -0.3 m/s     w, q      0.01, 0.005
%     yawDamper Kr 0.5                   dv = +0.3 m/s     v, r      0.01, 0.005
%     nescLqr (longitudinal)             dw = -0.3 m/s     w, q      0.005, 0.0025
%     nescLqr (lateral)                  dv = +0.3 m/s     v, r      0.005, 0.0025
%     (the LQR uses the finer pair because its closed loop has a fast pole
%     near -40 1/s, ADR-N11r, so 0.01 s is not in the asymptotic regime)
%   1. e(finer dt) <= 2e-2 (as tClosedLoopSimAgreement).
%   2. The sample-and-hold is the only first-order difference, so
%      e(coarser)/e(finer) in [1.5, 2.5] (Taylor remainder at these amplitudes
%      ~1e-4, tLinearVsNonlinear, well below the sampling term).
%   [FAILED HYPOTHESIS (item 1, nescLqr longitudinal, q), first GREEN run:
%   e(0.0025) = 0.0367 > 2e-2 (w: 5.9e-4; lateral v, r: 5.0e-3, 6.7e-3 pass). The
%   LQR closed loop is much faster than the registered estimate assumed (short
%   period -23.4 +/- 17.1i, roll-spiral -37.2 +/- 37.1i 1/s), so the half-sample
%   hold error on q is still 3.7 % at 400 Hz. Item 2 held: e ratios 2.08 and
%   1.97 (0.005/0.0025/0.00125 s), i.e. the discrepancy is the first-order
%   sampling term, nothing else. The tolerance is NOT loosened. Corrected check
%   for the LQR (independent justification: first-order convergence demonstrated
%   by item 2 allows Richardson extrapolation to dt -> 0, the limit ADR-026 says
%   the linearization represents): x_R = 2 x(dt2) - x(dt1) on the coarse grid
%   must agree with expm(A_cl t) dx0 within the registered 2e-2 on every
%   channel. (Diagnostic run: x_R error 3.0e-3 on q, 3.5e-5 on w, 3e-4 to 4e-4
%   laterally.) The pitch SAS and yaw damper keep the original check.]

    properties
        AC
        env
        tr
        Ft = 0.3048
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
        end
    end

    methods (Access = private)
        function agree(tc, makeCtrl, dx0, ch, dts, label, richardson)
            if nargin < 7, richardson = false; end
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', makeCtrl(100));
            tc.assertEqual(lin.status, 'OK', lin.reason);
            e = zeros(2, numel(ch)); X = cell(1, 2);
            for k = 1:2
                c = makeCtrl(1 / dts(k));
                out = vital.sim.run(tc.AC, tc.env, vital.linear.toPlantState(lin, dx0), tc.tr.u, ...
                    'dt', dts(k), 'tFinal', 3, 'Controller', c);
                tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
                dn = vital.linear.fromPlantState(lin, out.x);
                dl = vital.linear.response(lin, dx0, out.t);
                X{k} = dn; if k == 1, dl1 = dl; end
                for i = 1:numel(ch)
                    e(k, i) = max(abs(dn(ch(i), :) - dl(ch(i), :))) / max(abs(dl(ch(i), :)));
                end
            end
            names = {'u', 'v', 'w', 'p', 'q', 'r'};
            step = round(dts(1) / dts(2));
            for i = 1:numel(ch)
                if richardson
                    xr = 2 * X{2}(ch(i), 1:step:end) - X{1}(ch(i), :);
                    eR = max(abs(xr - dl1(ch(i), :))) / max(abs(dl1(ch(i), :)));
                    tc.verifyWithin(eR, 0, 2e-2, 'INDEP', 'Richardson dt -> 0 sim vs linearization (corrected header 1)', ...
                        'Quantity', sprintf('%s rel discrepancy dt -> 0, %s', label, names{ch(i)}));
                else
                    tc.verifyWithin(e(2, i), 0, 2e-2, 'INDEP', 'sampled sim vs closed-loop linearization (header 1)', ...
                        'Quantity', sprintf('%s rel discrepancy dt %g, %s', label, dts(2), names{ch(i)}));
                end
                tc.verifyWithin(e(1, i) / e(2, i), 1.5, 2.5, 'INDEP', 'sampling error first order in dt (header 2)', ...
                    'Quantity', sprintf('%s dt ratio, %s', label, names{ch(i)}));
            end
        end
    end

    methods (Test)
        function pitchSasSimMatchesLinear(tc)
            mk = @(rate) vital.ctrl.pitchSas(tc.AC, tc.env, tc.tr, 'Kq', 0.2, 'Ka', 0.5, 'Rate', rate);
            dx0 = zeros(12, 1); dx0(3) = -0.3;
            tc.agree(mk, dx0, [3 5], [0.01 0.005], 'pitchSas');
        end

        function yawDamperSimMatchesLinear(tc)
            mk = @(rate) vital.ctrl.yawDamper(tc.AC, tc.env, tc.tr, 'Kr', 0.5, 'Rate', rate);
            dx0 = zeros(12, 1); dx0(2) = 0.3;
            tc.agree(mk, dx0, [2 6], [0.01 0.005], 'yawDamper');
        end

        function nescLqrSimMatchesLinear(tc)
            mk = @(rate) vital.ctrl.nescLqr(tc.AC, tc.env, tc.tr, 'Rate', rate);
            dx0 = zeros(12, 1); dx0(3) = -0.3;
            tc.agree(mk, dx0, [3 5], [0.005 0.0025], 'nescLqr lon', true);
            dx0 = zeros(12, 1); dx0(2) = 0.3;
            tc.agree(mk, dx0, [2 6], [0.005 0.0025], 'nescLqr lat', true);
        end
    end
end
