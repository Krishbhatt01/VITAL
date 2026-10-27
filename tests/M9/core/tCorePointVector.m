classdef (TestTags = {'M9', 'CORE'}) tCorePointVector < vital.test.VitalTestCase
%TCOREPOINTVECTOR  0.9.1-CORE: vital.Point and vital.Vector (PLAN_CORE_FRAMES 2.1, 2.11, 5).
%   PRE-REGISTERED (written before the classes existed):
%   1. A Point changes axis by rotation AND translation, r_b = o_ab + C_ba r_a;
%      a Vector by rotation only, v_b = C_ba v_a (ANALYTIC, 1e-13 abs).
%      Discriminating case: two axes with the same orientation and a 5 m offset:
%      the Point moves by exactly the offset, the Vector does not move at all.
%   2. A Vector's length is invariant under any change of axis (ANALYTIC, 1e-12
%      relative); the distance between two Points is invariant (1e-12 rel).
%   3. plus/minus of Vectors in different axes: vital:axis:mismatch; of different
%      quantities (force + moment): vital:vector:quantityMismatch. Point - Point in
%      different axes: vital:axis:mismatch. Point - Point gives a Vector of
%      quantity 'position'.
%   4. 3xN batches: expressIn of a 3x50 batch equals column-by-column (1e-15 abs);
%      a 2xN or 4xN input is vital:badInput; NaN is vital:badInput; an unknown
%      quantity is vital:badInput.
%   5. cross(position, force) has quantity 'moment' and equals the numeric cross
%      (ANALYTIC, 0 abs); dot and norm equal the numeric ones.

    methods (Test)
        function pointTranslatesVectorDoesNot(tc)
            root = vital.Axis.root('root');
            a = vital.Axis([5 0 0], eye(3), root, 'Name', 'a');
            p = vital.Point([1; 2; 3], a).expressIn(root);
            v = vital.Vector([1; 2; 3], a).expressIn(root);
            tc.verifyTol(p.R, [6; 2; 3], 0, 'abs', 'ANALYTIC', 'pure translation 5 m along x', 'Quantity', 'Point in root', 'Unit', 'm');
            tc.verifyTol(v.V, [1; 2; 3], 0, 'abs', 'ANALYTIC', 'a free vector ignores translation', 'Quantity', 'Vector in root');
            rng(9201);
            e = (rand(1, 3) - 0.5) * 2 * pi; t = (rand(3, 1) - 0.5) * 6;
            b = vital.Axis(t, e, root, 'Name', 'b');
            C = vital.frames.dcm321(e(1), e(2), e(3));
            r = rand(3, 1);
            tc.verifyTol(vital.Point(r, b).expressIn(root).R, t + C.' * r, 1e-13, 'abs', 'ANALYTIC', ...
                'r_root = o + C_rb r_b', 'Quantity', 'Point rotated + translated', 'Unit', 'm');
            tc.verifyTol(vital.Vector(r, b).expressIn(root).V, C.' * r, 1e-13, 'abs', 'ANALYTIC', ...
                'v_root = C_rb v_b', 'Quantity', 'Vector rotated only');
            tc.verifyTol(vital.Point(r, root).expressIn(b).R, C * (r - t), 1e-13, 'abs', 'ANALYTIC', ...
                'r_b = C_br (r_root - o)', 'Quantity', 'Point into child', 'Unit', 'm');
        end

        function lengthsAreInvariant(tc)
            rng(9202);
            root = vital.Axis.root('root');
            a = vital.Axis(rand(3, 1) * 3, (rand(1, 3) - 0.5) * 6, root, 'Name', 'a');
            b = vital.Axis(rand(3, 1) * 3, (rand(1, 3) - 0.5) * 6, a, 'Name', 'b');
            V = vital.Vector(rand(3, 20) - 0.5, b, 'Quantity', "force");
            tc.verifyTol(V.expressIn(root).norm(), V.norm(), 1e-12, 'rel', 'ANALYTIC', 'a rotation keeps length', 'Quantity', 'norm(v)');
            P1 = vital.Point(rand(3, 1), b); P2 = vital.Point(rand(3, 1), b);
            d0 = norm(P1.R - P2.R);
            d1 = norm(P1.expressIn(root).R - P2.expressIn(root).R);
            tc.verifyTol(d1, d0, 1e-12, 'rel', 'ANALYTIC', 'a rigid change of axis keeps distances', 'Quantity', 'point distance', 'Unit', 'm');
        end

        function mixingIsAnError(tc)
            root = vital.Axis.root('root');
            a = vital.Axis([1 0 0], eye(3), root, 'Name', 'a');
            F1 = vital.Vector([1; 0; 0], root, 'Quantity', "force");
            F2 = vital.Vector([1; 0; 0], a, 'Quantity', "force");
            M1 = vital.Vector([1; 0; 0], root, 'Quantity', "moment");
            tc.verifyError(@() F1 + F2, 'vital:axis:mismatch');
            tc.verifyError(@() F1 - F2, 'vital:axis:mismatch');
            tc.verifyError(@() F1 + M1, 'vital:vector:quantityMismatch');
            P1 = vital.Point([1; 0; 0], root); P2 = vital.Point([1; 0; 0], a);
            tc.verifyError(@() P1 - P2, 'vital:axis:mismatch');
            d = vital.Point([3; 2; 1], root) - P1;
            tc.verifyClass(d, 'vital.Vector');
            tc.verifyExact(char(d.Quantity), 'position', 'ANALYTIC', 'Point - Point is a position vector', 'Quantity', 'quantity');
            tc.verifyTol(d.V, [2; 2; 1], 0, 'abs', 'ANALYTIC', 'difference', 'Quantity', 'P - P', 'Unit', 'm');
            s = F1 + vital.Vector([0; 2; 0], root, 'Quantity', "force");
            tc.verifyTol(s.V, [1; 2; 0], 0, 'abs', 'ANALYTIC', 'same axis and quantity add', 'Quantity', 'F + F');
        end

        function batchesAndValidation(tc)
            rng(9203);
            root = vital.Axis.root('root');
            a = vital.Axis(rand(3, 1), (rand(1, 3) - 0.5) * 6, root, 'Name', 'a');
            R = rand(3, 50);
            Pb = vital.Point(R, a).expressIn(root).R;
            Vb = vital.Vector(R, a).expressIn(root).V;
            Pc = zeros(3, 50); Vc = zeros(3, 50);
            for k = 1:50
                Pc(:, k) = vital.Point(R(:, k), a).expressIn(root).R;
                Vc(:, k) = vital.Vector(R(:, k), a).expressIn(root).V;
            end
            tc.verifyTol(Pb, Pc, 1e-15, 'abs', 'ANALYTIC', 'batch = column by column', 'Quantity', 'Point batch', 'Unit', 'm');
            tc.verifyTol(Vb, Vc, 1e-15, 'abs', 'ANALYTIC', 'batch = column by column', 'Quantity', 'Vector batch');
            tc.verifyError(@() vital.Point(rand(2, 4), a), 'vital:badInput');
            tc.verifyError(@() vital.Vector(rand(4, 4), a), 'vital:badInput');
            tc.verifyError(@() vital.Vector([1; NaN; 0], a), 'vital:badInput');
            tc.verifyError(@() vital.Vector([1; 0; 0], a, 'Quantity', "torque-ish"), 'vital:badInput');
            tc.verifyError(@() vital.Point([1; 0; 0], 'a'), 'vital:badInput');
        end

        function crossDotNorm(tc)
            root = vital.Axis.root('root');
            r = vital.Vector([1; 2; 3], root, 'Quantity', "position");
            F = vital.Vector([4; -5; 6], root, 'Quantity', "force");
            M = cross(r, F);
            tc.verifyExact(char(M.Quantity), 'moment', 'ANALYTIC', 'r x F is a moment', 'Quantity', 'quantity of r x F');
            tc.verifyTol(M.V, cross([1; 2; 3], [4; -5; 6]), 0, 'abs', 'ANALYTIC', 'numeric cross', 'Quantity', 'r x F');
            tc.verifyTol(dot(r, F), dot([1; 2; 3], [4; -5; 6]), 0, 'abs', 'ANALYTIC', 'numeric dot', 'Quantity', 'r . F');
            tc.verifyTol(F.norm(), norm([4; -5; 6]), 1e-15, 'rel', 'ANALYTIC', 'numeric norm (sqrt of the sum of squares vs BLAS norm: 1 ulp)', 'Quantity', 'norm F');
        end
    end
end
