classdef (TestTags = {'M8', 'OOP'}) tOopPerformance < vital.test.VitalTestCase
%TOOPPERFORMANCE  0.8.1-OOP performance gate (ADR-037): the plant with the
%   atmosisa-based atmosphere stays within 10 % of the 0.8.0 plant.
%   PRE-REGISTERED (written before the wrapper existed):
%   Baseline = tests/reference/plantBaseline.m, a frozen copy of the 0.8.0
%   vital.plant.derivatives with VITAL's own US 1976 (us76Reference), measured
%   IN THE SAME RUN, interleaved with the new plant (7 alternating batches of
%   2000 calls; median per-call time of each).
%   GATE (REG): at a fixed altitude (the README trim state: the trim, linearize,
%   flying-qualities and uncertainty pattern, where all calls of one solve share
%   h), median(new) <= 1.10 median(baseline).
%   REPORTED, NOT GATED: the time-simulation pattern, where every call has a new
%   altitude (h stepped by 0.01 m per call); its ratio is logged in the test
%   diagnostics and in the gate report (atmosisa's argument validation costs
%   ~0.3 ms per call at a new altitude; ADR-037).
%   Also: both plants give the same derivative to 1e-6 relative (US76 vs ISA).

    methods (TestClassSetup)
        function addReference(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
        end
    end

    methods (Test)
        function plantWithinTenPercent(tc)
            AC = vital.aircraft.f16.config();
            env = struct('g', 32.174 * 0.3048, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * 0.3048, 'h', 10013 * 0.3048, 'gamma', 0, 'psi', 0));
            x = tr.x; u = tr.u;
            vital.env.atmosphere(-x(13));              % the plant under test uses the atmosisa wrapper
            d1 = vital.plant.derivatives(x, u, AC, env);
            d0 = plantBaseline(x, u, AC, env);
            tc.verifyTol(d1, d0, 1e-6 * max(abs(d0)), 'abs', 'INDEP', 'frozen 0.8.0 plant (US 1976)', 'Quantity', 'xdot at trim');
            N = 2000; B = 7;
            tNew = zeros(1, B); tOld = zeros(1, B);
            for k = 1:200, vital.plant.derivatives(x, u, AC, env); plantBaseline(x, u, AC, env); end
            for b = 1:B
                t = tic; for k = 1:N, vital.plant.derivatives(x, u, AC, env); end; tNew(b) = toc(t) / N;
                t = tic; for k = 1:N, plantBaseline(x, u, AC, env); end; tOld(b) = toc(t) / N;
            end
            ratio = median(tNew) / median(tOld);
            % time-simulation pattern (reported only)
            xs = x; M = 300;
            tSimNew = zeros(1, 3); tSimOld = zeros(1, 3);
            for b = 1:3
                t = tic; for k = 1:M, xs(13) = x(13) - 0.01 * (k + b * M); vital.plant.derivatives(xs, u, AC, env); end; tSimNew(b) = toc(t) / M;
                t = tic; for k = 1:M, xs(13) = x(13) - 0.01 * (k + b * M); plantBaseline(xs, u, AC, env); end; tSimOld(b) = toc(t) / M;
            end
            simRatio = median(tSimNew) / median(tSimOld);
            msg = sprintf(['fixed-h plant: new %.4f ms, baseline %.4f ms, ratio %.3f | ' ...
                'new-h plant (reported only): new %.4f ms, baseline %.4f ms, ratio %.3f'], ...
                1e3 * median(tNew), 1e3 * median(tOld), ratio, 1e3 * median(tSimNew), 1e3 * median(tSimOld), simRatio);
            tc.log(1, msg);
            fprintf('[tOopPerformance] %s\n', msg);
            tc.verifyWithin(ratio, 0, 1.10, 'REG', ['pre-registered 10 % plant performance gate (ADR-037); ' msg], ...
                'Quantity', 'plant time ratio new/baseline (fixed h)');
        end
    end
end
