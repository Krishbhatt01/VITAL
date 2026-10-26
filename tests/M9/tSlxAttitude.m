classdef (TestTags = {'M9'}) tSlxAttitude < vital.test.VitalTestCase
%TSLXATTITUDE  M9-A attitude sanity through the Simulink path (PLAN_M9 7 A1-A3),
%   the signs of tests/M5/tF16Sim.m (CONVENTIONS 7), 0.1 s from the README trim,
%   dt 0.01, every logged sample after t = 0:
%     A1 +1 deg elevator (TED) doublet from t = 0 -> q < -1e-6 rad/s, theta(end) < theta(0)
%     A2 +1 deg aileron step                     -> p < -1e-6 rad/s, phi(end) < 0
%     A3 +1 deg rudder (TEL) step                -> r < -1e-6 rad/s, psi(end) < 0
%   The angles come from the logged quaternion through vital.frames (y.phi, theta, psi).

    properties
        AC
        env
        tr
        Model
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            r = vital.aircraft.f16.trimLevel(565.6854, 10013, 'CG', 25, 'g_ftps2', 32.174);
            tc.assertEqual(r.status, 'OK');
            tc.tr = r.trim;
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * 0.3048, 'wind_n', [0; 0; 0], 'deltaT', 0);
            d = tempname; mkdir(d); tc.addTeardown(@() rmdir(d, 's'));
            tc.addTeardown(@() bdclose('VitalPlant'));
            s = vital.slx.build('Folder', d); tc.Model = s.file;   % fresh build (PLAN_M9 9)
        end
    end

    methods (Access = private)
        function y = sim(tc, in)
            out = vital.slx.simulate(tc.AC, tc.env, tc.tr.x, tc.tr.u, 'dt', 0.01, 'tFinal', 0.1, 'Inputs', in, 'Model', tc.Model);
            tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
            y = out.y;
        end
    end

    methods (Test)
        function elevatorPitchesNoseDown(tc)
            y = tc.sim(vital.sim.doublet(0, 0.5, deg2rad(1), 'elevator'));
            c = 'CONVENTIONS 7: +de (TED) -> nose-down moment';
            tc.verifyWithin(max(y.q(2:end)), -Inf, -1e-6, 'ANALYTIC', c, 'Quantity', 'max q', 'Unit', 'rad/s');
            tc.verifyWithin(y.theta(end) - y.theta(1), -Inf, -1e-9, 'ANALYTIC', c, 'Quantity', 'theta change', 'Unit', 'rad');
        end

        function aileronRollsLeft(tc)
            y = tc.sim(vital.sim.stepInput(0, deg2rad(1), 'aileron'));
            c = 'CONVENTIONS 7: +da (right TED down) -> left roll';
            tc.verifyWithin(max(y.p(2:end)), -Inf, -1e-6, 'ANALYTIC', c, 'Quantity', 'max p', 'Unit', 'rad/s');
            tc.verifyWithin(y.phi(end), -Inf, -1e-9, 'ANALYTIC', c, 'Quantity', 'phi(end)', 'Unit', 'rad');
        end

        function rudderYawsLeft(tc)
            y = tc.sim(vital.sim.stepInput(0, deg2rad(1), 'rudder'));
            c = 'CONVENTIONS 7: +dr (TEL) -> nose-left yaw';
            tc.verifyWithin(max(y.r(2:end)), -Inf, -1e-6, 'ANALYTIC', c, 'Quantity', 'max r', 'Unit', 'rad/s');
            tc.verifyWithin(y.psi(end), -Inf, -1e-9, 'ANALYTIC', c, 'Quantity', 'psi(end)', 'Unit', 'rad');
        end
    end
end
