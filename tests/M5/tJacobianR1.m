classdef (TestTags = {'M5'}) tJacobianR1 < vital.test.VitalTestCase
%TJACOBIANR1  Review R1 finding B3 for vital.linear.jacobian: a round-off-
%   quantized plateau must not be accepted.
%
%   PRE-REGISTERED (before the fix):
%   B3  The criterion is round-off limited when, at the accepted step h,
%         eps * max|W f(z +/- h)| * ZScale / h > 0.01 * RelTol * ||W D||_inf + AbsTol.
%       That is, the derivative error caused by rounding the function VALUES
%       is above 1 % of the plateau tolerance.
%       f = 1e10 + sin(z), z0 = 0.3, h0 = 0.1: R1 found status OK with
%       J = 0.953674 against the true 0.955336 (differences of exactly 100, 10 and
%       1 ulp(1e10)). This must now be NOT_CONVERGED, with reason
%       'round-off limited', stepStudy status 'ROUNDOFF' and J NaN.
%       Guards (existing behaviour, must not change):
%         - f = 1e8 + z gives NO_PLATEAU
%         - the smooth function of tLinearJacobian (values O(1)) stays OK
%         - a zero column with large f values (f = [1e3; z2]) stays OK, because
%           the AbsTol term protects exact zeros

    methods (Test)
        function roundoffLimitedPlateauIsRefused(tc)
            [J, info] = vital.linear.jacobian(@(z) 1e10 + sin(z), 0.3, 0.1);
            tc.verifyEqual(info.status, 'NOT_CONVERGED');
            tc.verifySubstring(info.reason, 'round-off limited');
            tc.verifyEqual(info.stepStudy(1).status, 'ROUNDOFF');
            tc.verifyTrue(isnan(J), 'a round-off-limited derivative is not reported');
        end

        function conservativeCasesUnchanged(tc)
            [~, info] = vital.linear.jacobian(@(z) 1e8 + z, 0.3, 0.1);
            tc.verifyEqual(info.stepStudy(1).status, 'NO_PLATEAU');
            [J, info] = vital.linear.jacobian(@(z) [1e3; z(2)^2], [0.4; 1.5], [0.1; 0.1]);
            tc.verifyEqual(info.status, 'OK');
            tc.verifyExact(J(:, 1), [0; 0], 'ANALYTIC', 'f independent of z1: exact zero column', 'Quantity', 'zero column');
            tc.verifyTol(J(2, 2), 3, 1e-8, 'abs', 'ANALYTIC', 'd z^2/dz at 1.5', 'Quantity', 'J(2,2)');
            [~, info] = vital.linear.jacobian(@(z) [sin(z(1)) * exp(z(2)); z(1)^2 * z(2)], [0.7; -0.3], [0.1; 0.1]);
            tc.verifyEqual(info.status, 'OK');
        end
    end
end
