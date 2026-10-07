classdef (TestTags = {'M1'}) tMass < vital.test.VitalTestCase
%TMASS  M1: mass-property build-up (CONVENTIONS.md section 6).

    methods (Test)
        function twoPointMassesAnalytic(tc)
            m = 3; L = 2;
            items = [struct('m', m, 'r', [0; L; 0], 'J', zeros(3)), struct('m', m, 'r', [0; -L; 0], 'J', zeros(3))];
            [M, rcg, J] = vital.mass.massProps(items);
            tc.verifyTol(M, 2*m, 0, 'abs', 'ANALYTIC', 'sum of masses', 'Quantity', 'm', 'Unit', 'kg');
            tc.verifyTol(rcg, [0;0;0], 1e-15, 'abs', 'ANALYTIC', 'symmetric pair', 'Quantity', 'r_cg', 'Unit', 'm');
            tc.verifyTol(J, diag([2*m*L^2, 0, 2*m*L^2]), 1e-12, 'abs', 'ANALYTIC', 'I = 2 m L^2 about x and z', 'Quantity', 'J', 'Unit', 'kg m2');
        end

        function boxWithSelfInertiaIsExact(tc)
            % Uniform box a x b x c of mass Mt split into n^3 sub-boxes, each carrying its own
            % self-inertia. The parallel-axis sum is then exact: Jxx = Mt/12 (b^2 + c^2), etc.
            [items, dims, Mt] = boxItems(10, true);
            [M, rcg, J] = vital.mass.massProps(items);
            a = dims(1); b = dims(2); c = dims(3);
            tc.verifyTol(M, Mt, 1e-12, 'rel', 'ANALYTIC', 'sum of sub-box masses', 'Quantity', 'm');
            tc.verifyTol(rcg, [0;0;0], 1e-12, 'abs', 'ANALYTIC', 'box centred on the origin', 'Quantity', 'r_cg');
            tc.verifyTol(diag(J), Mt/12*[b^2+c^2; a^2+c^2; a^2+b^2], 1e-12, 'rel', 'ANALYTIC', ...
                'uniform box: J = M/12 (b^2+c^2, a^2+c^2, a^2+b^2)', 'Quantity', 'diag J');
        end

        function midpointMassesAreOnePercentShort(tc)
            % Correction E7: point masses at the cell centres give Jxx = M/12 (b^2+c^2)(1 - 1/n^2),
            % i.e. exactly 1 % short for n = 10, so the old 0.1 % check with point masses was wrong.
            [items, dims, Mt] = boxItems(10, false);
            [~, ~, J] = vital.mass.massProps(items);
            b = dims(2); c = dims(3);
            tc.verifyTol(J(1,1), Mt/12*(b^2+c^2)*(1 - 1/100), 1e-12, 'rel', 'ANALYTIC', ...
                'discrete midpoint sum: factor (1 - 1/n^2)', 'Quantity', 'Jxx point masses');
        end

        function productOfInertiaSign(tc)
            items = struct('m', 2, 'r', [3; 0; 4], 'J', zeros(3));
            items(2) = struct('m', 2, 'r', [-3; 0; -4], 'J', zeros(3));
            [~, ~, J] = vital.mass.massProps(items);
            tc.verifyTol(J(1,3), -(2*3*4 + 2*3*4), 1e-12, 'abs', 'ANALYTIC', ...
                'CONVENTIONS 6: tensor entry J13 = -Ixz = -sum m x z', 'Quantity', 'J13');
        end

        function inertiaTensorFromPublishedProducts(tc)
            % F-16 style: Ixz = 982 slug ft^2 published positive -> tensor entry -982.
            J = vital.mass.inertiaTensor(9496, 55814, 63100, 0, 982, 0);
            tc.verifyTol(J(1,3), -982, 0, 'abs', 'ANALYTIC', 'CONVENTIONS 6 tensor sign', 'Quantity', 'J13');
            tc.verifyTol(J, J.', 0, 'abs', 'ANALYTIC', 'tensor is symmetric', 'Quantity', 'J - J''');
        end

        function cgShiftsWithFuelBurn(tc)
            % Burning fuel from a tank aft of the CG moves the CG forward (x forward).
            base = struct('m', 1000, 'r', [0;0;0], 'J', zeros(3));
            full = [base, struct('m', 200, 'r', [-2;0;0], 'J', zeros(3))];
            half = [base, struct('m', 100, 'r', [-2;0;0], 'J', zeros(3))];
            [~, r1] = vital.mass.massProps(full);
            [~, r2] = vital.mass.massProps(half);
            tc.verifyTol(r2(1) - r1(1), 2*200/1200 - 2*100/1100, 1e-12, 'abs', 'ANALYTIC', ...
                'x_cg = sum m x / sum m', 'Quantity', 'forward CG shift', 'Unit', 'm');
            tc.verifyGreaterThan(r2(1), r1(1));
        end
    end
end

function [items, dims, Mt] = boxItems(n, withSelf)
dims = [4, 2, 1]; Mt = 50;
d = dims / n; mi = Mt / n^3;
Jself = mi/12 * diag([d(2)^2 + d(3)^2, d(1)^2 + d(3)^2, d(1)^2 + d(2)^2]);
if ~withSelf, Jself = zeros(3); end
c = @(k, L) -L/2 + (k - 0.5) * L / n;
items = repmat(struct('m', mi, 'r', zeros(3,1), 'J', Jself), 1, n^3);
idx = 0;
for i = 1:n
    for j = 1:n
        for k = 1:n
            idx = idx + 1;
            items(idx).r = [c(i, dims(1)); c(j, dims(2)); c(k, dims(3))];
        end
    end
end
end
