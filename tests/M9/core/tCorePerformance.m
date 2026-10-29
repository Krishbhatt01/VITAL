classdef (TestTags = {'M9', 'CORE'}) tCorePerformance < vital.test.VitalTestCase
%TCOREPERFORMANCE  0.9.1-CORE performance (PLAN_CORE_FRAMES 2.10, 5).
%   PRE-REGISTERED (written before the classes existed):
%   The compiled F-16 model, f16 = vital.aircraft.f16.model() (compiled by the
%   builder), is timed against vital.plant.derivatives with the config struct IN
%   THE SAME RUN, at the README trim state (fixed altitude: the trim,
%   linearization, flying-qualities and uncertainty pattern), interleaved:
%   alternating batches after 200 warm-up calls. Both paths are asked for
%   [xdot, y] (the plant always builds y), so they do the same work.
%   GATE (REG): ratio <= 1.25.
%   Statistic (amended in I1, finding F-11, ADR-043; the 1.25 bound unchanged):
%   15 PAIRED batches of 500 calls (plant batch, then model batch, adjacent in
%   time), ratio = the median over the batches of t_model / t_plant. A load
%   change during the run then scales both members of a pair instead of one
%   path's median (the 0.9.2-I0 gate measured 1.239 with the former statistic
%   median(t_model) / median(t_plant) over 7 batches of 1,000; it is still
%   reported).
%   REPORTED, NOT GATED: the object path (derivativesObject) ratio, and the
%   new-altitude pattern (h stepped by 0.01 m per call) ratio of the compiled path.

    methods (Test)
        function compiledWithinTarget(tc)
            k = vital.units.constants();
            AC = vital.aircraft.f16.config();
            f16 = vital.aircraft.f16.model();
            env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0));
            x = tr.x; u = tr.u;
            N = 500; B = 15;
            for i = 1:200, [~, ~] = vital.plant.derivatives(x, u, AC, env); [~, ~] = f16.derivatives(x, u, env); end
            tP = zeros(1, B); tM = tP;
            for b = 1:B
                t = tic; for i = 1:N, [~, ~] = vital.plant.derivatives(x, u, AC, env); end; tP(b) = toc(t) / N;
                t = tic; for i = 1:N, [~, ~] = f16.derivatives(x, u, env); end; tM(b) = toc(t) / N;
            end
            ratio = median(tM ./ tP);
            ratioOld = median(tM) / median(tP);
            tO = zeros(1, 3);
            for b = 1:3
                t = tic; for i = 1:200, [~, ~] = f16.derivativesObject(x, u, env); end; tO(b) = toc(t) / 200;
            end
            objRatio = median(tO) / median(tP);
            xs = x; M = 300; tSP = zeros(1, 3); tSM = tSP;
            for b = 1:3
                t = tic; for i = 1:M, xs(13) = x(13) - 0.01 * (i + b * M); [~, ~] = vital.plant.derivatives(xs, u, AC, env); end; tSP(b) = toc(t) / M;
                t = tic; for i = 1:M, xs(13) = x(13) - 0.01 * (i + 4 * M + b * M); [~, ~] = f16.derivatives(xs, u, env); end; tSM(b) = toc(t) / M;
            end
            simRatio = median(tSM) / median(tSP);
            msg = sprintf(['fixed h: plant %.1f us, model (compiled) %.1f us, ratio %.3f (paired median; ratio of medians %.3f) ' ...
                '| object path %.1f us, ratio %.2f (reported) | new h each call: plant %.1f us, model %.1f us, ratio %.3f (reported)'], ...
                1e6 * median(tP), 1e6 * median(tM), ratio, ratioOld, 1e6 * median(tO), objRatio, 1e6 * median(tSP), 1e6 * median(tSM), simRatio);
            tc.log(1, msg);
            fprintf('[tCorePerformance] %s\n', msg);
            tc.verifyWithin(ratio, 0, 1.25, 'REG', ['PLAN 2.10 target: compiled model <= 1.25 x plant; ' msg], ...
                'Quantity', 'model/plant time ratio (fixed h)');
        end
    end
end
