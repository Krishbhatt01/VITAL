classdef (TestTags = {'M1'}) tLoads < vital.test.VitalTestCase
%TLOADS  M1: load transfer between points and summation at the CG with
%   gravity (docs/CONVENTIONS.md section 6).

    methods (Test)
        function transferKnownCase(tc)
            % F = [0 0 -10] N at A; B origin at [2 0 0] in A coordinates.
            % M_B = M_A + (r_A - r_B) x F = (-[2 0 0]) x [0 0 -10] = [0 -20 0].
            [F, M] = vital.loads.transferLoad([0;0;-10], [0;0;0], [2;0;0], eye(3));
            tc.verifyTol(F, [0;0;-10], 1e-15, 'abs', 'ANALYTIC', 'force unchanged by translation', 'Quantity', 'F_B', 'Unit', 'N');
            tc.verifyTol(M, [0;-20;0], 1e-12, 'abs', 'ANALYTIC', 'M_B = M_A + (r_A - r_B) x F', 'Quantity', 'M_B', 'Unit', 'N m');
        end

        function pureCoupleInvariant(tc)
            [~, M] = vital.loads.transferLoad([0;0;0], [1;2;3], [5;-7;11], eye(3));
            tc.verifyTol(M, [1;2;3], 1e-15, 'abs', 'ANALYTIC', 'a pure couple is independent of the reference point', 'Quantity', 'M_B');
        end

        function transferRoundTrip(tc)
            s = RandStream('mt19937ar', 'Seed', 3);
            F = randn(s,3,1)*100; M = randn(s,3,1)*100; r = randn(s,3,1)*5;
            C = vital.frames.dcm321(0.3, -0.2, 1.1);
            [F2, M2] = vital.loads.transferLoad(F, M, r, C);
            % back: origin of A expressed in B coordinates is -C*r; B->A DCM is C'
            [F3, M3] = vital.loads.transferLoad(F2, M2, -C*r, C.');
            tc.verifyTol([F3; M3], [F; M], 1e-11, 'abs', 'ANALYTIC', 'A -> B -> A returns the original load', 'Quantity', '[F;M] round trip');
        end

        function gravityLevel(tc)
            [F, M] = vital.loads.sumLoadsAtCG(zeros(3,0), zeros(3,0), [0;0;0], 2, eye(3), [0;0;9.80665]);
            tc.verifyTol(F, [0;0;19.6133], 1e-12, 'abs', 'ANALYTIC', 'F_g = m C_bn g_n, level', 'Quantity', 'F_b', 'Unit', 'N');
            tc.verifyTol(M, [0;0;0], 0, 'abs', 'ANALYTIC', 'gravity acts at the CG: zero moment', 'Quantity', 'M_cg');
        end

        function gravityNinetyBank(tc)
            C = vital.frames.dcm321(pi/2, 0, 0);
            F = vital.loads.sumLoadsAtCG(zeros(3,0), zeros(3,0), [0;0;0], 2, C, [0;0;9.80665]);
            tc.verifyTol(F, [0; 19.6133; 0], 1e-12, 'abs', 'ANALYTIC', 'phi = 90 deg: gravity along +y body', 'Quantity', 'F_b', 'Unit', 'N');
        end

        function gravityNinetyPitch(tc)
            C = vital.frames.dcm321(0, pi/2, 0);
            F = vital.loads.sumLoadsAtCG(zeros(3,0), zeros(3,0), [0;0;0], 2, C, [0;0;9.80665]);
            tc.verifyTol(F, [-19.6133; 0; 0], 1e-12, 'abs', 'ANALYTIC', 'theta = 90 deg: gravity along -x body', 'Quantity', 'F_b', 'Unit', 'N');
        end

        function componentMomentTransferredToCg(tc)
            % One component: F = [0 0 -100] N about the BFRP with M_R = 0; CG at [1 0 0] (BFRP coords).
            % M_cg = M_R - r_cg x F = -[1 0 0] x [0 0 -100] = [0 -100 0].
            [F, M] = vital.loads.sumLoadsAtCG([0;0;-100], [0;0;0], [1;0;0], 1, eye(3), [0;0;0]);
            tc.verifyTol(F, [0;0;-100], 1e-12, 'abs', 'ANALYTIC', 'sum of forces', 'Quantity', 'F_b');
            tc.verifyTol(M, [0;-100;0], 1e-12, 'abs', 'ANALYTIC', 'M_cg = sum M_R - r_cg x sum F_R', 'Quantity', 'M_cg');
        end

        function datumInvariantMomentAtCg(tc)
            % The same physical loads described about two different BFRP datums give the same M_cg.
            F = [10 -3; 2 5; -40 7]; Mloc = [1 0; 0 2; -1 1]; pos = [3 -1; 0.5 0; 0.2 -0.4]; cg = [0.7; 0.1; 0.05];
            for datum = {[0;0;0], [3;0.7;-1.2]}
                d = datum{1};
                MR = Mloc + cross(pos - d, F);                % each component's moment about the BFRP
                [~, M] = vital.loads.sumLoadsAtCG(F, MR, cg - d, 1, eye(3), [0;0;0]);
                if all(d == 0), M0 = M; end
            end
            tc.verifyTol(M, M0, 1e-12, 'abs', 'ANALYTIC', 'M_cg is independent of the BFRP datum', 'Quantity', 'M_cg datum shift');
        end
    end
end
