classdef (TestTags = {'M1'}) tFrames < vital.test.VitalTestCase
%TFRAMES  M1: DCM, Euler 3-2-1 and scalar-first quaternion conventions
%   (docs/CONVENTIONS.md section 3), checked analytically and against the
%   Aerospace Toolbox as an independent implementation.

    properties
        Att        % 100 seeded random attitudes [phi theta psi] (rad), |theta| < 89 deg
    end

    methods (TestClassSetup)
        function makeAttitudes(tc)
            s = RandStream('mt19937ar', 'Seed', 1);
            n = 100;
            tc.Att = [ (2*rand(s,n,1)-1)*pi, (2*rand(s,n,1)-1)*deg2rad(89), (2*rand(s,n,1)-1)*pi ];
        end
    end

    methods (Test)
        function dcmOrthonormalAndProper(tc)
            worstO = 0; worstD = 0;
            for k = 1:size(tc.Att,1)
                C = vital.frames.dcm321(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3));
                worstO = max(worstO, norm(C.'*C - eye(3), 'fro'));
                worstD = max(worstD, abs(det(C) - 1));
            end
            tc.verifyTol(worstO, 0, 1e-13, 'abs', 'ANALYTIC', 'C''C = I for a rotation', 'Quantity', 'max ||C''C - I||');
            tc.verifyTol(worstD, 0, 1e-13, 'abs', 'ANALYTIC', 'det C = +1 for a proper rotation', 'Quantity', 'max |det C - 1|');
        end

        function eulerDcmRoundTrip(tc)
            worst = 0;
            for k = 1:size(tc.Att,1)
                e = vital.frames.dcm2eul(vital.frames.dcm321(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3)));
                worst = max(worst, max(abs(angdiff(e(:), tc.Att(k,:).'))));
            end
            tc.verifyTol(worst, 0, 1e-12, 'abs', 'ANALYTIC', 'Euler -> DCM -> Euler identity', 'Quantity', 'max angle error', 'Unit', 'rad');
        end

        function eulerQuatDcmRoundTrip(tc)
            worst = 0;
            for k = 1:size(tc.Att,1)
                q = vital.frames.eul2quat(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3));
                C1 = vital.frames.quat2dcm(q);
                C2 = vital.frames.dcm321(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3));
                q2 = vital.frames.dcm2quat(C2);
                worst = max([worst, norm(C1 - C2, 'fro'), norm(vital.frames.quat2dcm(q2) - C2, 'fro')]);
            end
            tc.verifyTol(worst, 0, 1e-13, 'abs', 'ANALYTIC', 'Euler -> quat -> DCM equals Euler -> DCM; DCM -> quat -> DCM identity', ...
                'Quantity', 'max ||C_q - C_e||');
        end

        function roundTripNearGimbalLock(tc)
            for th = deg2rad([89.9, -89.9])
                a = [0.7, th, -2.1];
                e = vital.frames.dcm2eul(vital.frames.dcm321(a(1), a(2), a(3)));
                tc.verifyTol(max(abs(angdiff(e(:), a(:)))), 0, 1e-10, 'abs', 'ANALYTIC', ...
                    'round trip at |theta| = 89.9 deg', 'Quantity', sprintf('angle error at theta=%.1f deg', rad2deg(th)), 'Unit', 'rad');
            end
        end

        function gimbalConventionAtNinetyDegrees(tc)
            for th = [pi/2, -pi/2]
                C = vital.frames.dcm321(0.3, th, 0.5);
                e = vital.frames.dcm2eul(C);
                tc.verifyTol(e(1), 0, 1e-12, 'abs', 'ANALYTIC', 'CONVENTIONS 3: phi = 0 at |theta| = 90 deg', 'Quantity', 'phi');
                tc.verifyTol(e(2), th, 1e-7, 'abs', 'ANALYTIC', 'theta recovered', 'Quantity', 'theta');
                Crec = vital.frames.dcm321(e(1), e(2), e(3));
                tc.verifyTol(norm(Crec - C, 'fro'), 0, 1e-7, 'abs', 'ANALYTIC', ...
                    'the returned angles reproduce the DCM (psi carries the combined angle)', 'Quantity', '||C_rec - C||');
            end
        end

        function matchesAngle2dcm(tc)
            worst = 0;
            for k = 1:size(tc.Att,1)
                C = vital.frames.dcm321(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3));
                Ct = angle2dcm(tc.Att(k,3), tc.Att(k,2), tc.Att(k,1), 'ZYX');
                worst = max(worst, max(abs(C(:) - Ct(:))));
            end
            tc.verifyTol(worst, 0, 1e-14, 'abs', 'INDEP', 'Aerospace Toolbox angle2dcm(psi,theta,phi,''ZYX'')', 'Quantity', 'max |C - C_toolbox|');
        end

        function matchesToolboxQuaternions(tc)
            worstQ = 0; worstC = 0;
            for k = 1:size(tc.Att,1)
                q = vital.frames.eul2quat(tc.Att(k,1), tc.Att(k,2), tc.Att(k,3));
                qt = angle2quat(tc.Att(k,3), tc.Att(k,2), tc.Att(k,1), 'ZYX').';
                if qt(1) < 0, qt = -qt; end
                worstQ = max(worstQ, max(abs(q - qt)));
                Ct = quat2dcm(q.');
                worstC = max(worstC, max(max(abs(vital.frames.quat2dcm(q) - Ct))));
            end
            tc.verifyTol(worstQ, 0, 1e-14, 'abs', 'INDEP', 'Aerospace Toolbox angle2quat (scalar-first, sign fixed q0 >= 0)', 'Quantity', 'max |q - q_toolbox|');
            tc.verifyTol(worstC, 0, 1e-14, 'abs', 'INDEP', 'Aerospace Toolbox quat2dcm', 'Quantity', 'max |C(q) - C_toolbox(q)|');
        end

        function dcm2quatHasNonNegativeScalar(tc)
            q = vital.frames.dcm2quat(vital.frames.dcm321(0.1, 0.2, 3.1));
            tc.verifyWithin(q(1), 0, 1, 'ANALYTIC', 'CONVENTIONS 3: q0 >= 0 chosen for uniqueness', 'Quantity', 'q0');
            tc.verifyTol(norm(q), 1, 1e-15, 'abs', 'ANALYTIC', 'unit quaternion', 'Quantity', '|q|');
        end

        function stationToBodyPoint(tc)
            r = vital.frames.stationToBody([10; 2; 3], [4; 0; 1]);
            tc.verifyTol(r, [-6; 2; -2], 1e-15, 'abs', 'ANALYTIC', 'CONVENTIONS 2: r_R = diag(-1,1,-1)(r_S - r_S,BFRP)', 'Quantity', 'r_R', 'Unit', 'm');
        end

        function stationToBodyInertiaSigns(tc)
            IS = [100 -5 -7; -5 200 -9; -7 -9 300];
            IR = vital.frames.inertiaStationToBody(IS);
            tc.verifyTol(IR, [100 5 -7; 5 200 9; -7 9 300], 1e-12, 'abs', 'ANALYTIC', ...
                'CONVENTIONS 2: Ixz keeps sign, Ixy and Iyz flip under T = diag(-1,1,-1)', 'Quantity', 'I_R');
        end
    end
end

function d = angdiff(a, b)
d = atan2(sin(a - b), cos(a - b));
end
