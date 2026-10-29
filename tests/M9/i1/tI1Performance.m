classdef (TestTags = {'M9', 'I1'}) tI1Performance < vital.test.VitalTestCase
%TI1PERFORMANCE  Increment I1 (ADR-043): per-call cost of the model through the plant.
%   PRE-REGISTERED (written before the implementation):
%   GATE (REG): at the README trim state (fixed altitude), the F-16 model
%   f16 = vital.AircraftModel.fromData(vital.aircraft.f16.data()) handed to the
%   plant, vital.plant.derivatives(x, u, f16, env), costs at most 1.05 x the legacy
%   struct plant vital.plant.derivatives(x, u, vital.aircraft.f16.config(), env),
%   both asked for [xdot, y], measured IN THE SAME RUN: 300 warm-up calls of each,
%   then 15 PAIRED batches of 500 calls (struct batch then model batch, adjacent
%   in time so that a load change affects both); the statistic is the median over
%   the batches of the per-batch ratio t_model / t_struct (robust to a slow
%   batch; finding F-11).
%   REPORTED, NOT GATED: the toRuntime-struct path ratio, model.derivatives called
%   directly, and the vital.FlightContext constructor's per-call cost (ADR-043
%   asks that it does not grow; ~97 us measured before I1 on this machine).

    methods (Test)
        function modelThroughPlantWithinTarget(tc)
            k = vital.units.constants();
            AC = vital.aircraft.f16.config();
            f16 = vital.AircraftModel.fromData(vital.aircraft.f16.data());
            R = f16.toRuntime();
            env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0));
            x = tr.x; u = tr.u;
            for i = 1:300
                [~, ~] = vital.plant.derivatives(x, u, AC, env);
                [~, ~] = vital.plant.derivatives(x, u, f16, env);
                [~, ~] = vital.plant.derivatives(x, u, R, env);
            end
            N = 500; B = 15;
            tS = zeros(1, B); tM = tS; tR = tS; tD = tS; tF = tS;
            names = f16.Controls; ref = f16.Ref;
            for b = 1:B
                t = tic; for i = 1:N, [~, ~] = vital.plant.derivatives(x, u, AC, env); end; tS(b) = toc(t) / N;
                t = tic; for i = 1:N, [~, ~] = vital.plant.derivatives(x, u, f16, env); end; tM(b) = toc(t) / N;
                t = tic; for i = 1:N, [~, ~] = vital.plant.derivatives(x, u, R, env); end; tR(b) = toc(t) / N;
                t = tic; for i = 1:N, [~, ~] = f16.derivatives(x, u, env); end; tD(b) = toc(t) / N;
                t = tic; for i = 1:N, fl = vital.FlightContext(x, u, env, names, ref); end; tF(b) = toc(t) / N; %#ok<NASGU>
            end
            ratio = median(tM ./ tS);
            msg = sprintf(['struct plant %.1f us | plant(model) %.1f us, ratio %.3f (gated) | plant(toRuntime) %.1f us, ' ...
                'ratio %.3f | model.derivatives %.1f us, ratio %.3f | FlightContext %.1f us (reported)'], ...
                1e6 * median(tS), 1e6 * median(tM), ratio, 1e6 * median(tR), median(tR ./ tS), ...
                1e6 * median(tD), median(tD ./ tS), 1e6 * median(tF));
            tc.log(1, msg);
            fprintf('[tI1Performance] %s\n', msg);
            tc.verifyWithin(ratio, 0, 1.05, 'REG', ['I1 criterion: model through the plant <= 1.05 x the struct plant; ' msg], ...
                'Quantity', 'plant(model)/plant(struct) time ratio (median of paired batches)');
        end
    end
end
