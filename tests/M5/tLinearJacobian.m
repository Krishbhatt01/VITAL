classdef (TestTags = {'M5'}) tLinearJacobian < vital.test.VitalTestCase
%TLINEARJACOBIAN  M5-A: the generic step-study central-difference Jacobian
%   (vital.linear.jacobian), on analytic functions whose answer is known.
%
%   PRE-REGISTERED acceptance criterion of the step study (written before the
%   implementation existed; it is the criterion vital.linear.jacobian must use):
%     steps      h_k = h0 / 10^(k-1), k = 1..7 (default)
%     estimate   central difference D_k = (f(z + h_k e_j) - f(z - h_k e_j)) / (2 h_k)
%     weights    rows by 1/FScale, the column by ZScale (both default 1), so an
%                entry is "fraction of a typical output per typical input"
%     agreement  a_k = ||W (D_k - D_(k-1))||_inf
%     plateau    two consecutive agreements a_k, a_(k+1) <= RelTol * ||W D||_inf + AbsTol
%                (three estimates in a row agree; one agreeing pair could be a
%                coincidence); the accepted estimate is the middle one, D_k.
%                RelTol = 1e-6, AbsTol = 1e-10.
%     rationale  central-difference truncation error falls 100x per decade of h,
%                round-off error rises 10x; in double precision the best attainable
%                relative accuracy is ~eps^(2/3) ~ 4e-11. The F-16 plant chains an
%                atmosphere, table look-ups and a quaternion DCM, with ~1e-15
%                relative noise on force terms of order g, so a 1e-6 plateau
%                leaves >= 3 decades of margin, and a 1e-6 relative error in a
%                stability derivative is far below any physical significance.
%     kink       one-sided asymmetry s_k = ||W (f(z+h) - 2 f(z) + f(z-h)) / h||_inf.
%                Smooth f: s_k = |f''| h_k, so s_k / s_(k-1) = 0.1. A kink (left and
%                right slopes differ, e.g. a table breakpoint exactly at z0): s_k
%                tends to the slope jump and does not decay. At the accepted step,
%                s_k > KinkTol * ||W D||_inf + AbsTol (KinkTol = 1e-6) together with
%                s_k >= 0.5 s_(k-1) means a kink. A central difference there would
%                return the AVERAGE of the one-sided slopes at every step (it
%                plateaus!), so the plateau alone cannot detect it.
%     failure    a column without a plateau, or with a kink, is NOT_CONVERGED
%                (FC-506); its Jacobian column is NaN (never a plausible number),
%                and the reason names the column and the cause.
%
%   Tests (ANALYTIC):
%     smooth function with a closed-form Jacobian: every entry within
%       1e-7 * max|J| (the accepted estimate's truncation error is about its
%       agreement / 99 <= RelTol / 99 ~ 1e-8 of the column; 10x margin)
%     observed order: a_2 / a_3 in [50, 200] (h^2 truncation gives 100 for a step
%       factor of 10; a first-order (forward) scheme would give 10)
%     an unused variable gives an exactly zero column and status OK
%     kink exactly at z0 (f = 3 z + 2 |z - 1| at z = 1, slopes 1 and 5): NOT_CONVERGED,
%       reason mentions 'kink', column NaN, one-sided slopes 1 and 5 (1e-9)
%     kink 1e-3 away from z0: resolved once h < 1e-3, J = 5 (1e-9), status OK
%     deterministic noise of 1e-7 on sin(z): no plateau, NOT_CONVERGED, 'plateau'
%     bad input (NaN z0, h0 <= 0, size mismatch, non-finite f(z0)): vital:badInput

    methods (Static, Access = private)
        function y = smoothF(z)
            y = [sin(z(1)) * exp(z(2));
                 z(1)^2 * z(3) + z(2)^3;
                 log(1 + z(3)^2) * z(1);
                 exp(-z(2)) * cos(z(3))];
        end

        function J = smoothJ(z)
            J = [cos(z(1)) * exp(z(2)), sin(z(1)) * exp(z(2)), 0, 0;
                 2 * z(1) * z(3), 3 * z(2)^2, z(1)^2, 0;
                 log(1 + z(3)^2), 0, 2 * z(3) * z(1) / (1 + z(3)^2), 0;
                 0, -exp(-z(2)) * cos(z(3)), -exp(-z(2)) * sin(z(3)), 0];
        end

        function y = noisyF(z)
            % sin(z) plus 1e-7 of deterministic pseudo-random noise
            n = mod(sin(z * 12.9898) * 43758.5453, 1) - 0.5;
            y = sin(z) + 1e-7 * n;
        end
    end

    methods (Test)
        function smoothFunctionKnownJacobian(tc)
            z0 = [0.7; -0.3; 1.2; 0.4];      % z(4) is not used by f
            [J, info] = vital.linear.jacobian(@tLinearJacobian.smoothF, z0, 0.1 * ones(4, 1));
            tc.verifyEqual(info.status, 'OK');
            Je = tLinearJacobian.smoothJ(z0);
            tc.verifyTol(J, Je, 1e-7 * max(abs(Je(:))), 'abs', 'ANALYTIC', ...
                'closed-form Jacobian; tolerance from the plateau criterion (class header)', 'Quantity', 'J');
            tc.verifyExact(J(:, 4), zeros(4, 1), 'ANALYTIC', 'f does not depend on z4: exactly zero column', ...
                'Quantity', 'unused column');
        end

        function centralDifferenceIsSecondOrder(tc)
            z0 = [0.7; -0.3; 1.2; 0.4];
            [~, info] = vital.linear.jacobian(@tLinearJacobian.smoothF, z0, 0.1 * ones(4, 1));
            for j = 1:3
                a = info.stepStudy(j).agreement;
                tc.verifyWithin(a(2) / a(3), 50, 200, 'ANALYTIC', ...
                    'central difference: truncation ~h^2, 100x per decade of step', ...
                    'Quantity', sprintf('agreement ratio, column %d', j));
            end
        end

        function kinkAtPointIsDetectedNotAveraged(tc)
            f = @(z) [3 * z(1) + 2 * abs(z(1) - 1) + z(2); z(2)^2];
            [J, info] = vital.linear.jacobian(f, [1; 2], [0.1; 0.1]);
            tc.verifyEqual(info.status, 'NOT_CONVERGED');
            tc.verifyExact(info.columns, 1, 'ANALYTIC', 'only column 1 has the kink', 'Quantity', 'failed columns');
            tc.verifySubstring(info.reason, 'kink');
            tc.verifyTrue(all(isnan(J(:, 1))), 'a kinked column is NaN, never the average of the slopes');
            tc.verifyTol(J(:, 2), [1; 4], 1e-9, 'abs', 'ANALYTIC', 'smooth column unaffected', 'Quantity', 'J(:,2)');
            s = info.stepStudy(1);
            tc.verifyEqual(s.status, 'KINK');
            tc.verifyTol(s.left(1), 1, 1e-9, 'abs', 'ANALYTIC', 'left slope of 3z + 2|z-1| at 1', 'Quantity', 'left slope');
            tc.verifyTol(s.right(1), 5, 1e-9, 'abs', 'ANALYTIC', 'right slope of 3z + 2|z-1| at 1', 'Quantity', 'right slope');
        end

        function kinkNearPointIsResolvedBySmallSteps(tc)
            f = @(z) 3 * z + 2 * abs(z - 1);
            [J, info] = vital.linear.jacobian(f, 1 + 1e-3, 0.1);
            tc.verifyEqual(info.status, 'OK');
            tc.verifyTol(J, 5, 1e-9, 'abs', 'ANALYTIC', 'right of the kink the slope is 5', 'Quantity', 'J');
        end

        function noisyFunctionHasNoPlateau(tc)
            [J, info] = vital.linear.jacobian(@tLinearJacobian.noisyF, 0.3, 0.1);
            tc.verifyEqual(info.status, 'NOT_CONVERGED');
            tc.verifySubstring(info.reason, 'plateau');
            tc.verifyTrue(isnan(J), 'no plateau: the derivative is not reported');
            tc.verifyEqual(info.stepStudy(1).status, 'NO_PLATEAU');
        end

        function badInputRejected(tc)
            f = @(z) z.^2;
            tc.verifyError(@() vital.linear.jacobian(f, [1; NaN], [0.1; 0.1]), 'vital:badInput');
            tc.verifyError(@() vital.linear.jacobian(f, [1; 2], [0.1; 0]), 'vital:badInput');
            tc.verifyError(@() vital.linear.jacobian(f, [1; 2], [0.1; 0.1; 0.1]), 'vital:badInput');
            tc.verifyError(@() vital.linear.jacobian(@(z) z / 0, 1, 0.1), 'vital:badInput');
        end
    end
end
