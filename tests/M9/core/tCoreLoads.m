classdef (TestTags = {'M9', 'CORE'}) tCoreLoads < vital.test.VitalTestCase
%TCORELOADS  0.9.1-CORE: vital.Loads, force + moment about the origin of a
%   reference axis (PLAN_CORE_FRAMES 2.1, 2.2, 5; CONVENTIONS 6).
%   PRE-REGISTERED (written before the class existed):
%   1. L.transform(b) equals vital.loads.transferLoad(F, M, b.originIn(a),
%      a.dcmTo(b)) (INDEP: the M1-verified functional core; 1e-12 relative to the
%      load scale) on 20 random axis pairs, including chains through siblings.
%   2. Loads.aggregate(list, cg) of five component loads, each in its own rotated
%      and offset axis, equals vital.loads.sumLoadsAtCG of the same loads moved to
%      the BFRP by transferLoad, with gravity zero (INDEP, 1e-12 of the load scale).
%   3. POWER INVARIANCE (ANALYTIC, an independent physical check): for a rigid
%      body moving with v_O, omega, the power F . v_P + M_P . omega of a load is
%      the same about every point P (all quantities in the axis of P);
%      relative 1e-12 over 10 random axes.
%   4. A pure couple (F = 0) only rotates: M_b = C_ba M_a (1e-13).
%   5. plus of Loads with different reference axes: vital:loads:refMismatch;
%      Loads(F, M) with F and M in different axes: vital:axis:mismatch; a moment
%      vector given as the force: vital:badInput. Same-reference plus adds.
%   6. Batches: 3xN loads transform column by column (1e-15 abs).

    methods (Test)
        function transformEqualsTransferLoad(tc)
            rng(9301);
            root = vital.Axis.root('bfrp');
            ax = {root};
            for k = 2:8
                ax{k} = vital.Axis((rand(3, 1) - 0.5) * 8, (rand(1, 3) - 0.5) * 2 * pi, ax{randi(k - 1)}, ...
                    'Name', sprintf('a%d', k)); %#ok<AGROW>
            end
            for i = 1:20
                ia = randi(8); ib = randi(8);
                a = ax{ia}; b = ax{ib};
                F = (rand(3, 1) - 0.5) * 2e4; M = (rand(3, 1) - 0.5) * 5e4;
                L = vital.Loads(vital.Vector(F, a, 'Quantity', "force"), vital.Vector(M, a, 'Quantity', "moment"));
                Lb = L.transform(b);
                [Fe, Me] = vital.loads.transferLoad(F, M, b.originIn(a), a.dcmTo(b));
                s = max(norm(F), norm(M));
                tc.verifyTol([Lb.F; Lb.M], [Fe; Me], 1e-12 * s, 'abs', 'INDEP', ...
                    'vital.loads.transferLoad (CONVENTIONS 6; tests/M1/tLoads)', 'Quantity', sprintf('%s -> %s', a.Name, b.Name));
                tc.verifyTrue(Lb.RefAxis.isSame(b), 'reference axis after transform');
            end
        end

        function aggregateEqualsSumLoadsAtCG(tc)
            rng(9302);
            bfrp = vital.Axis.root('bfrp');
            cg = vital.Axis([0.35; 0.01; -0.05], eye(3), bfrp, 'Name', 'cg');
            list = vital.Loads.empty;
            FR = zeros(3, 5); MR = zeros(3, 5);
            for k = 1:5
                a = vital.Axis((rand(3, 1) - 0.5) * 6, (rand(1, 3) - 0.5) * 2 * pi, bfrp, 'Name', sprintf('c%d', k));
                F = (rand(3, 1) - 0.5) * 2e4; M = (rand(3, 1) - 0.5) * 5e4;
                list(k) = vital.Loads(F, M, a);
                [FR(:, k), MR(:, k)] = vital.loads.transferLoad(F, M, bfrp.originIn(a), a.dcmTo(bfrp));
            end
            L = vital.Loads.aggregate(list, cg);
            [Fb, Mcg] = vital.loads.sumLoadsAtCG(FR, MR, cg.originIn(bfrp), 1000, eye(3), [0; 0; 0]);
            s = max(abs([FR(:); MR(:)]));
            tc.verifyTol([L.F; L.M], [Fb; Mcg], 1e-12 * s, 'abs', 'INDEP', ...
                'vital.loads.sumLoadsAtCG without gravity (CONVENTIONS 6)', 'Quantity', 'aggregate at the CG');
            Lc = vital.Loads.aggregate(num2cell(list), cg);
            tc.verifyTol([Lc.F; Lc.M], [L.F; L.M], 0, 'abs', 'ANALYTIC', 'cell list = array list', 'Quantity', 'aggregate (cell)');
        end

        function powerIsInvariant(tc)
            rng(9303);
            O = vital.Axis.root('O');
            vO = [50; -3; 2]; w = [0.4; -0.2; 0.7];           % rigid-body velocity of O and rate, O axes
            a = vital.Axis([1; 2; -1], [0.2 0.1 -0.4], O, 'Name', 'a');
            L = vital.Loads([1200; -300; 4500], [800; 2500; -600], a);
            P0 = powerAbout(L, O, vO, w);
            for k = 1:10
                b = vital.Axis((rand(3, 1) - 0.5) * 10, (rand(1, 3) - 0.5) * 2 * pi, O, 'Name', sprintf('b%d', k));
                Pk = powerAbout(L.transform(b), O, vO, w);
                tc.verifyTol(Pk, P0, 1e-12, 'rel', 'ANALYTIC', 'power F.v_P + M_P.omega is point-independent', ...
                    'Quantity', sprintf('power about b%d', k), 'Unit', 'W');
            end
        end

        function pureCoupleOnlyRotates(tc)
            root = vital.Axis.root('root');
            b = vital.Axis([3; -4; 5], [0.3 0.2 0.1], root, 'Name', 'b');
            M = [100; -200; 300];
            Lb = vital.Loads([0; 0; 0], M, root).transform(b);
            tc.verifyTol(Lb.M, root.dcmTo(b) * M, 1e-13, 'abs', 'ANALYTIC', 'a couple has no lever arm', 'Quantity', 'couple');
            tc.verifyTol(Lb.F, [0; 0; 0], 0, 'abs', 'ANALYTIC', 'no force appears', 'Quantity', 'couple force');
        end

        function mismatchesAreErrors(tc)
            root = vital.Axis.root('root');
            a = vital.Axis([1 0 0], eye(3), root, 'Name', 'a');
            L1 = vital.Loads([1; 0; 0], [0; 1; 0], root);
            L2 = vital.Loads([1; 0; 0], [0; 1; 0], a);
            tc.verifyError(@() L1 + L2, 'vital:loads:refMismatch');
            tc.verifyError(@() vital.Loads(vital.Vector([1; 0; 0], root, 'Quantity', "force"), ...
                vital.Vector([1; 0; 0], a, 'Quantity', "moment")), 'vital:axis:mismatch');
            tc.verifyError(@() vital.Loads(vital.Vector([1; 0; 0], root, 'Quantity', "moment"), ...
                vital.Vector([1; 0; 0], root, 'Quantity', "moment")), 'vital:badInput');
            S = L1 + vital.Loads([0; 2; 0], [3; 0; 0], root);
            tc.verifyTol([S.F; S.M], [1; 2; 0; 3; 1; 0], 0, 'abs', 'ANALYTIC', 'same reference adds', 'Quantity', 'L + L');
        end

        function batchesTransform(tc)
            rng(9304);
            root = vital.Axis.root('root');
            b = vital.Axis(rand(3, 1), (rand(1, 3) - 0.5) * 6, root, 'Name', 'b');
            F = rand(3, 30); M = rand(3, 30);
            Lb = vital.Loads(F, M, root).transform(b);
            Fc = zeros(3, 30); Mc = zeros(3, 30);
            for k = 1:30
                Lk = vital.Loads(F(:, k), M(:, k), root).transform(b);
                Fc(:, k) = Lk.F; Mc(:, k) = Lk.M;
            end
            tc.verifyTol([Lb.F; Lb.M], [Fc; Mc], 1e-15, 'abs', 'ANALYTIC', 'batch = column by column', 'Quantity', 'Loads batch');
        end
    end
end

function P = powerAbout(L, O, vO, w)
% power of a load L (about the origin of L.RefAxis, in its components) for a rigid
% body whose point O moves with vO and rotates with w (both in O components)
b = L.RefAxis;
rP = b.originIn(O);
vP = vO + cross(w, rP);
C = O.dcmTo(b);
P = dot(L.F, C * vP) + dot(L.M, C * w);
end
