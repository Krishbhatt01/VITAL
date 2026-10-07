classdef (TestTags = {'FIXTURE'}) fxVitalTol < vital.test.VitalTestCase
%FXVITALTOL  Synthetic uses of VitalTestCase checks with known outcomes.
%   Run as a nested suite by tVitalTestCase.

    methods (Test)
        function absPass(tc)
            tc.verifyTol(1 + 1e-10, 1, 1e-9, 'abs', 'ANALYTIC', 'fixture', ...
                'Quantity', 'x', 'Unit', 'm');
        end

        function absFail(tc)
            tc.verifyTol(1.1, 1, 1e-3, 'abs', 'ANALYTIC', 'fixture', 'Quantity', 'x');
        end

        function nanVsNan(tc)
            % verifyEqual(NaN,NaN) passes in MATLAB; verifyTol must not.
            tc.verifyTol(NaN, NaN, 1, 'abs', 'ANALYTIC', 'fixture', 'Quantity', 'nan');
        end

        function infActual(tc)
            tc.verifyTol(Inf, 1, 1, 'abs', 'ANALYTIC', 'fixture', 'Quantity', 'inf');
        end

        function badSource(tc)
            tc.verifyTol(1, 1, 0, 'abs', 'GUESS', 'fixture', 'Quantity', 'x');
        end

        function badMode(tc)
            tc.verifyTol(1, 1, 0, 'both', 'ANALYTIC', 'fixture', 'Quantity', 'x');
        end

        function absIgnoresRel(tc)
            % 2e-6 error on 1000: fails an absolute 1e-8, would pass a relative 1e-8.
            tc.verifyTol(1000 + 2e-6, 1000, 1e-8, 'abs', 'ANALYTIC', 'fixture', 'Quantity', 'x');
        end

        function relPass(tc)
            tc.verifyTol(1000 + 2e-6, 1000, 1e-8, 'rel', 'ANALYTIC', 'fixture', 'Quantity', 'x');
        end

        function relZeroExpected(tc)
            tc.verifyTol(0, 0, 1e-8, 'rel', 'ANALYTIC', 'fixture', 'Quantity', 'x');
        end

        function withinPass(tc)
            tc.verifyWithin(0.5, 0, 1, 'PUB', 'fixture', 'Quantity', 'w');
        end

        function withinFail(tc)
            tc.verifyWithin(1.5, 0, 1, 'PUB', 'fixture', 'Quantity', 'w');
        end

        function exactPass(tc)
            tc.verifyExact('OK', 'OK', 'ANALYTIC', 'fixture', 'Quantity', 'status');
        end

        function vectorOneBadElement(tc)
            tc.verifyTol([1 2 3], [1 2 3.5], 1e-9, 'abs', 'ANALYTIC', 'fixture', 'Quantity', 'v');
        end
    end
end
