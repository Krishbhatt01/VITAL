classdef (TestTags = {'M9', 'DATA'}) tDataPerformance < vital.test.VitalTestCase
%TDATAPERFORMANCE  D1 (docs/PLAN_DATA_LAYER.md) criterion 8, timing part: the plant
%   built from the data object costs the same per call.
%   PRE-REGISTERED (written before the classes existed):
%   m = vital.AircraftModel.fromData(vital.aircraft.f16.data()) (what
%   vital.aircraft.f16.model() now returns) is timed against the FROZEN 0.9.1-CORE
%   model (private/legacyF16Model) IN THE SAME RUN at the README trim state:
%   200 warm-up calls each, then 9 interleaved batches of 1,000 calls each of
%   [xdot, y] = derivatives(x, u, env); median per-call time of each.
%   GATE (REG, PLAN 3.8): median(fromData) / median(0.9.1-CORE) <= 1.05.
%   REPORTED, NOT GATED: the time to build the data object (first call, then cached
%   reads) and to build the model from it.
%
%   CORRECTION AFTER THE FIRST GREEN RUN (documented, bound unchanged): the first run
%   measured 1.069 with the batches always in the order 0.9.1-CORE then fromData,
%   while another agent ran a test suite on the same machine. An investigation in the
%   same conditions timed the frozen model against a SECOND COPY OF ITSELF: 1.027,
%   the same as fromData against it (1.025); the two models run the same functions
%   with equal arguments (tDataModel/sameModelStructure). So the excess was order and
%   load noise. The measurement now alternates the order in every batch pair
%   (A B, then B A), uses 15 pairs, and also times the frozen model against its own
%   copy as a REPORTED noise floor. The gate (1.05 on the ratio of medians) is the
%   pre-registered one.

    methods (Test)
        function plantTimeUnchanged(tc)
            k = vital.units.constants();
            AC = vital.aircraft.f16.config();
            env = struct('g', 32.174 * k.ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            tr = vital.trim.solve(AC, env, struct('type', 'level', 'V', 565.6854 * k.ft, 'h', 10013 * k.ft, 'gamma', 0, 'psi', 0));
            x = tr.x; u = tr.u;
            t = tic; d = vital.aircraft.f16.data(); tData = toc(t);
            t = tic; m = vital.AircraftModel.fromData(d); tModel = toc(t);
            t = tic; vital.aircraft.f16.model(); tBuilder = toc(t);
            L = legacyF16Model();
            L2 = legacyF16Model();
            N = 1000; B = 15;
            for i = 1:200, [~, ~] = L.derivatives(x, u, env); [~, ~] = m.derivatives(x, u, env); [~, ~] = L2.derivatives(x, u, env); end
            tL = zeros(1, B); tM = tL; tL2 = tL;
            for b = 1:B
                if mod(b, 2)
                    t = tic; for i = 1:N, [~, ~] = L.derivatives(x, u, env); end; tL(b) = toc(t) / N;
                    t = tic; for i = 1:N, [~, ~] = m.derivatives(x, u, env); end; tM(b) = toc(t) / N;
                    t = tic; for i = 1:N, [~, ~] = L2.derivatives(x, u, env); end; tL2(b) = toc(t) / N;
                else
                    t = tic; for i = 1:N, [~, ~] = L2.derivatives(x, u, env); end; tL2(b) = toc(t) / N;
                    t = tic; for i = 1:N, [~, ~] = m.derivatives(x, u, env); end; tM(b) = toc(t) / N;
                    t = tic; for i = 1:N, [~, ~] = L.derivatives(x, u, env); end; tL(b) = toc(t) / N;
                end
            end
            ratio = median(tM) / median(tL);
            floorRatio = median(tL2) / median(tL);
            msg = sprintf(['per call: 0.9.1-CORE %.1f us, fromData %.1f us, ratio %.3f | noise floor (0.9.1-CORE vs its own ' ...
                'copy) %.3f | data() %.3f s, fromData %.3f s, model() %.3f s (reported)'], 1e6 * median(tL), 1e6 * median(tM), ...
                ratio, floorRatio, tData, tModel, tBuilder);
            tc.log(1, msg);
            fprintf('[tDataPerformance] %s\n', msg);
            tc.verifyWithin(ratio, 0, 1.05, 'REG', ['PLAN_DATA_LAYER 3.8: plant time per call within 1.05x; ' msg], ...
                'Quantity', 'fromData/0.9.1-CORE time ratio');
        end
    end
end
