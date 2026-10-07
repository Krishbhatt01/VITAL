classdef (TestTags = {'M1'}) tEnvelopeCheck < vital.test.VitalTestCase
%TENVELOPECHECK  M1: the pre-registered NESC comparison criterion (ADR-009).
%   Residuals r_s(t) = ref_s(t) - VITAL(t), one per reference simulation,
%   are put on a common time base. VITAL passes at time t when 0 lies in
%   [min_s r_s - delta, max_s r_s + delta], i.e. VITAL is inside the
%   envelope of the NASA simulations widened by
%   delta(t) = max(floor, rel_floor * refScale, k * (max_s r_s - min_s r_s)).

    properties
        Spec = struct('floor', 0.1, 'rel_floor', 0, 'k', 0.5)
    end

    methods (Test)
        function insideEnvelopePasses(tc)
            t = (0:0.1:1).';
            r = vital.verify.envelopeCheck(t, {t, t}, {0.5 + 0*t, -0.5 + 0*t}, tc.Spec, 1);
            tc.verifyTrue(r.pass);
            tc.verifyTol(r.worst, -0.5 - 0.5, 1e-12, 'abs', 'ANALYTIC', ...
                'worst = max over t of the distance from 0 to the widened envelope (negative inside)', 'Quantity', 'worst margin');
        end

        function outsideEnvelopeFailsAtTheRightTime(tc)
            t = (0:0.1:1).';
            r1 = 1 + 0*t; r1(8) = 3;               % both sims above VITAL; worst at t = 0.7
            r = vital.verify.envelopeCheck(t, {t, t}, {r1, 1 + 0*t}, tc.Spec, 1);
            tc.verifyFalse(r.pass);
            tc.verifyTol(r.tWorst, 0.0, 1e-12, 'abs', 'ANALYTIC', ...
                'at t = 0 the envelope is [1, 1], delta = max(0.1, 0.5*0) = 0.1, so 0 is 0.9 outside', 'Quantity', 'tWorst', 'Unit', 's');
            tc.verifyTol(r.worst, 0.9, 1e-12, 'abs', 'ANALYTIC', 'distance outside the widened envelope', 'Quantity', 'worst');
        end

        function spreadTermWidensTheBand(tc)
            % Envelope [1, 3] with k = 0.5 gives delta = 1, so 0 is exactly on the lower edge.
            t = (0:0.1:1).';
            r = vital.verify.envelopeCheck(t, {t, t}, {1 + 0*t, 3 + 0*t}, tc.Spec, 1);
            tc.verifyTol(r.worst, 0, 1e-12, 'abs', 'ANALYTIC', 'delta = k * spread = 0.5 * 2', 'Quantity', 'worst');
            tc.verifyTrue(r.pass, 'a point exactly on the edge passes');
        end

        function relativeFloorUsesReferenceScale(tc)
            t = (0:0.1:1).';
            spec = struct('floor', 0, 'rel_floor', 1e-3, 'k', 0);
            r = vital.verify.envelopeCheck(t, {t}, {0.9 + 0*t}, spec, 1000);   % delta = 1e-3 * 1000 = 1
            tc.verifyTrue(r.pass);
            r2 = vital.verify.envelopeCheck(t, {t}, {1.1 + 0*t}, spec, 1000);
            tc.verifyFalse(r2.pass);
        end

        function differentTimeBasesAreInterpolated(tc)
            tBase = (0:0.1:1).';
            tFine = (0:0.01:1).';
            r = vital.verify.envelopeCheck(tBase, {tBase, tFine}, {0.5 + 0*tBase, -0.5 + tFine}, tc.Spec, 1);
            % at t = 1 the fine sim's residual is +0.5, so the envelope is [0.5, 0.5]; delta = 0.1 -> 0 is 0.4 outside
            tc.verifyFalse(r.pass);
            tc.verifyTol(r.tWorst, 1.0, 1e-12, 'abs', 'ANALYTIC', 'linear interpolation onto the base', 'Quantity', 'tWorst', 'Unit', 's');
        end

        function onlyOverlappingTimesAreCompared(tc)
            tBase = (0:0.1:2).';
            tShort = (0:0.1:1).';
            r = vital.verify.envelopeCheck(tBase, {tBase, tShort}, {0*tBase, 0*tShort}, tc.Spec, 1);
            tc.verifyTol(r.tCompared(end), 1.0, 1e-12, 'abs', 'ANALYTIC', 'comparison stops where any reference ends', 'Quantity', 'last compared time', 'Unit', 's');
        end

        function singleSampleReferencesAreCompared(tc)
            % A trim is one instant (t = 0): references with one sample each must work
            % (found while writing the M4 NESC trim test).
            r = vital.verify.envelopeCheck(0, {0, 0}, {0.02, -0.01}, tc.Spec, 1);
            tc.verifyTrue(r.pass);
            r2 = vital.verify.envelopeCheck(0, {0, 0}, {0.5, 0.4}, tc.Spec, 1);
            tc.verifyFalse(r2.pass);
            tc.verifyTol(r2.worst, 0.4 - max(0.1, 0.5*0.1), 1e-12, 'abs', 'ANALYTIC', 'envelope [0.4, 0.5], delta 0.1', 'Quantity', 'worst');
        end

        function noReferenceIsAnError(tc)
            tc.verifyError(@() vital.verify.envelopeCheck((0:1).', {}, {}, tc.Spec, 1), 'vital:verify:noReference');
        end

        function nonFiniteResidualIsAnError(tc)
            t = (0:0.1:1).'; bad = 0*t; bad(3) = NaN;
            tc.verifyError(@() vital.verify.envelopeCheck(t, {t}, {bad}, tc.Spec, 1), 'vital:badInput');
        end
    end
end
