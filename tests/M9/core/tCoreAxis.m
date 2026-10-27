classdef (TestTags = {'M9', 'CORE'}) tCoreAxis < vital.test.VitalTestCase
%TCOREAXIS  0.9.1-CORE: vital.Axis (docs/PLAN_CORE_FRAMES.md sections 2.3-2.6, 5).
%   CONVENTION (CONVENTIONS 3, passive): an Axis holds Origin (its origin in the
%   PARENT's coordinates, m) and C = C_this_parent (maps parent components to this
%   axis' components). a.dcmTo(b) = C_ba, a.originIn(b) = origin of a in b coords.
%
%   TOOLBOX CONVENTIONS, verified by probe (reports/work/core/probe_conventions.m,
%   probe_tt.m; R2025b, 2026-10-26) BEFORE these tests were written:
%     angle2dcm(psi, theta, phi, 'ZYX')          = C_bn (passive), as vital.frames.dcm321
%     quaternion(q.')  with VITAL's q (N->B):    rotmat(Q, 'frame') = C (passive),
%                                                rotmat(Q, 'point') = C' (active)
%     rotateframe(Q, v') = (C v)',  rotatepoint(Q, v') = (C' v)'
%     so3(Q) / so3(R):  ACTIVE; rotm(so3(Q)) = C'.  So an so3 orientation input
%                       means C = rotm(R)'.
%     se3(R, t): transform(T, p_child) = R p_child + t, i.e. the child's POSE in
%                the parent: R = C', t = child origin in parent coords.
%     transformTree: updateTransform(tt, parent, child, [C' t; 0 0 0 1], 0);
%                getTransform(tt, target, source, 0) maps POINTS source -> target.
%     dcmbody2wind(alpha, beta) = C_wb (passive, Etkin).
%   PRE-REGISTERED (written before the class existed):
%   1. Constructor: a non-orthonormal DCM, a left-handed DCM (det -1), Euler of the
%      wrong length, NaN anywhere, a 4-vector orientation, a non-Axis parent, an
%      unknown unit, a translation that is not a 3-vector: vital:badInput.
%   2. DCM, Euler [phi theta psi] (rad and 'deg'), quaternion and so3 inputs of the
%      same rotation give the same C (1e-14 abs, ANALYTIC/INDEP). 'ft' converts the
%      translation by 0.3048 exactly.
%   3. Random chains of depth 1..5: a.dcmTo(root) equals the product of the
%      passive DCMs (ANALYTIC, 1e-13); A->B->A is the identity (1e-13); point
%      composition equals se3 composition (INDEP, 1e-12 abs on positions <= 10 m)
%      and transformTree on a random tree with two branches (INDEP, 1e-12).
%   4. Axes of two different roots: vital:axis:noCommonRoot.
%   5. Axis(r, [0 pi 0], parent) equals diag(-1, 1, -1) (1e-15, ANALYTIC);
%      Axis.station gives it exactly and maps station points as
%      vital.frames.stationToBody (1e-13, INDEP).
%   6. Axis.wind = dcmbody2wind (INDEP, 1e-15); Axis.stability = analytic C_sb
%      (1e-15); Axis.bodyInNed(x) = angle2dcm(psi, theta, phi, 'ZYX') with origin
%      p_n (INDEP, 1e-14).
%   7. toSe3 / toQuaternion round-trip the toolbox objects (INDEP, 1e-14/1e-15).

    methods (Test)
        function badInputs(tc)
            r = vital.Axis.root('bfrp');
            tc.verifyError(@() vital.Axis([0 0 0], [1 0 0; 0 1 0; 0 0 1.1], r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], diag([1 1 -1]), r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], [0.1 0.2], r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 NaN 0], eye(3), r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], [NaN 0 0], r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], [1 0 0 0], r, 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], eye(3), struct('C', eye(3)), 'Name', 'a'), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0 0], eye(3), r, 'Name', 'a', 'Units', "furlong"), 'vital:badInput');
            tc.verifyError(@() vital.Axis([0 0], eye(3), r, 'Name', 'a'), 'vital:badInput');
        end

        function orientationInputsAgree(tc)
            r = vital.Axis.root('n');
            e = [0.3 -0.2 1.1];
            C = vital.frames.dcm321(e(1), e(2), e(3));
            q = vital.frames.eul2quat(e(1), e(2), e(3));
            Ctbx = angle2dcm(e(3), e(2), e(1), 'ZYX');
            aD = vital.Axis([0 0 0], C, r, 'Name', 'd');
            aE = vital.Axis([0 0 0], e, r, 'Name', 'e');
            aG = vital.Axis([0 0 0], rad2deg(e), r, 'Name', 'g', 'Units', "deg");
            aQ = vital.Axis([0 0 0], quaternion(q.'), r, 'Name', 'q');
            aS = vital.Axis([0 0 0], so3(quaternion(q.')), r, 'Name', 's');
            tc.verifyTol(aD.C, C, 0, 'abs', 'ANALYTIC', 'DCM stored as given', 'Quantity', 'C (DCM input)');
            tc.verifyTol(aE.C, C, 1e-14, 'abs', 'ANALYTIC', 'CONVENTIONS 3: C_bn = R1(phi) R2(theta) R3(psi)', 'Quantity', 'C (Euler rad)');
            tc.verifyTol(aG.C, C, 1e-14, 'abs', 'ANALYTIC', 'Units deg converted once', 'Quantity', 'C (Euler deg)');
            tc.verifyTol(aQ.C, Ctbx, 1e-14, 'abs', 'INDEP', ...
                'probe: rotmat(quaternion(q), frame) = C (passive)', 'Quantity', 'C (quaternion)');
            tc.verifyTol(aS.C, Ctbx, 1e-14, 'abs', 'INDEP', ...
                'probe: so3 is active, rotm(so3) = C transposed', 'Quantity', 'C (so3)');
            aF = vital.Axis([1 2 3], eye(3), r, 'Name', 'f', 'Units', "ft");
            tc.verifyTol(aF.Origin, [1; 2; 3] * 0.3048, 0, 'abs', 'ANALYTIC', 'CONVENTIONS 1: ft = 0.3048 m exact, one multiplication', ...
                'Quantity', 'origin (ft input)', 'Unit', 'm');
            aFD = vital.Axis([1 2 3], rad2deg(e), r, 'Name', 'fd', 'Units', ["ft" "deg"]);
            tc.verifyTol([aFD.Origin(:); aFD.C(:)], [aF.Origin(:); C(:)], 1e-14, 'abs', 'ANALYTIC', 'two units at once', ...
                'Quantity', 'ft + deg');
        end

        function chainsResolveBothWays(tc)
            rng(9101);
            for depth = 1:5
                root = vital.Axis.root('root');
                a = root; Cprod = eye(3); o = zeros(3, 1);
                for k = 1:depth
                    e = (rand(1, 3) - 0.5) * 2 * pi; t = (rand(3, 1) - 0.5) * 4;
                    a = vital.Axis(t, e, a, 'Name', sprintf('a%d', k));
                    Ck = vital.frames.dcm321(e(1), e(2), e(3));
                    o = o + Cprod.' * t;          % origin of a_k in root coordinates
                    Cprod = Ck * Cprod;           % C_{a_k, root}
                end
                tc.verifyTol(a.dcmTo(root), Cprod.', 1e-13, 'abs', 'ANALYTIC', 'transpose of the product of passive DCMs down the chain (dcmTo(root) = C_root_a)', ...
                    'Quantity', sprintf('C_root_a depth %d', depth));
                tc.verifyTol(root.dcmTo(a), Cprod, 1e-13, 'abs', 'ANALYTIC', 'product of passive DCMs down the chain (dcmTo(a) = C_a_root)', ...
                    'Quantity', sprintf('C_a_root depth %d', depth));
                tc.verifyTol(a.originIn(root), o, 1e-13, 'abs', 'ANALYTIC', 'origin summed down the chain', ...
                    'Quantity', sprintf('origin depth %d', depth), 'Unit', 'm');
                tc.verifyTol(root.originIn(a), -Cprod * o, 1e-13, 'abs', 'ANALYTIC', 'root origin in a = -C_a_root o', ...
                    'Quantity', sprintf('root in a, depth %d', depth), 'Unit', 'm');
                P = vital.Point(rand(3, 4), a);
                back = P.expressIn(root).expressIn(a);
                tc.verifyTol(back.R, P.R, 1e-13, 'abs', 'ANALYTIC', 'A -> B -> A is the identity', ...
                    'Quantity', sprintf('round trip depth %d', depth), 'Unit', 'm');
                tc.verifyTol(a.dcmTo(root) * root.dcmTo(a), eye(3), 1e-13, 'abs', 'ANALYTIC', 'A -> B -> A is the identity', ...
                    'Quantity', 'C round trip');
                tc.verifyEqual(numel(a.chain()), depth + 1);
            end
        end

        function compositionMatchesSe3(tc)
            rng(9102);
            root = vital.Axis.root('root');
            a = root; T = se3();
            for k = 1:5
                e = (rand(1, 3) - 0.5) * 2 * pi; t = (rand(1, 3) - 0.5) * 4;
                a = vital.Axis(t, e, a, 'Name', sprintf('a%d', k));
                T = T * se3(vital.frames.dcm321(e(1), e(2), e(3)).', t);   % child pose in parent
            end
            p = rand(3, 6) * 2;
            expected = transform(T, p.').';
            act = vital.Point(p, a).expressIn(root).R;
            tc.verifyTol(act, expected, 1e-12, 'abs', 'INDEP', 'se3 composition (probe: se3(C transposed, origin) is the child pose)', ...
                'Quantity', 'point in root via 5-deep chain', 'Unit', 'm');
            tc.verifyTol(a.dcmTo(root), rotm(T), 1e-13, 'abs', 'INDEP', 'rotm(se3 pose) = C_a_root transposed = C_root_a = a.dcmTo(root)', 'Quantity', 'C chain vs se3');
            Ta = a.toSe3();
            tc.verifyTol(tform(Ta), [a.C.' a.Origin; 0 0 0 1], 1e-15, 'abs', 'INDEP', 'toSe3 = pose in parent', 'Quantity', 'toSe3');
            Q = a.toQuaternion();
            tc.verifyTol(rotmat(Q, 'frame'), a.C, 1e-14, 'abs', 'INDEP', 'rotmat(quaternion, frame) = C', 'Quantity', 'toQuaternion');
        end

        function compositionMatchesTransformTree(tc)
            rng(9103);
            tt = transformTree("root", 20, 2);
            ax = {vital.Axis.root('root')};
            names = {'root'};
            parents = [0 1 2 3 1 5 6 2 8];     % two branches from the root, one off f2
            for k = 2:numel(parents)
                e = (rand(1, 3) - 0.5) * 2 * pi; t = (rand(3, 1) - 0.5) * 4;
                ax{k} = vital.Axis(t, e, ax{parents(k)}, 'Name', sprintf('f%d', k)); %#ok<AGROW>
                names{k} = sprintf('f%d', k); %#ok<AGROW>
                C = vital.frames.dcm321(e(1), e(2), e(3));
                updateTransform(tt, names{parents(k)}, names{k}, [C.' t; 0 0 0 1], 0);
            end
            pairs = [4 7; 7 4; 9 6; 3 9; 1 7; 7 1];
            for i = 1:size(pairs, 1)
                s = pairs(i, 1); g = pairs(i, 2);
                p = rand(3, 3);
                H = getTransform(tt, names{g}, names{s}, 0);
                expected = H(1:3, 1:3) * p + H(1:3, 4);
                act = vital.Point(p, ax{s}).expressIn(ax{g}).R;
                tc.verifyTol(act, expected, 1e-12, 'abs', 'INDEP', ...
                    'UAV Toolbox transformTree getTransform(target, source) (probe: maps points source -> target)', ...
                    'Quantity', sprintf('%s -> %s', names{s}, names{g}), 'Unit', 'm');
            end
        end

        function noCommonRootIsError(tc)
            a = vital.Axis([1 0 0], eye(3), vital.Axis.root('bfrp'), 'Name', 'a');
            b = vital.Axis([0 1 0], eye(3), vital.Axis.root('ned'), 'Name', 'b');
            tc.verifyError(@() a.dcmTo(b), 'vital:axis:noCommonRoot');
            tc.verifyError(@() vital.Point([1; 2; 3], a).expressIn(b), 'vital:axis:noCommonRoot');
        end

        function stationFrameIsBodyRotatedAboutY(tc)
            bfrp = vital.Axis.root('bfrp');
            s1 = vital.Axis([2 0 0.5], [0 pi 0], bfrp, 'Name', 'nose');
            tc.verifyTol(s1.C, diag([-1 1 -1]), 1e-15, 'abs', 'ANALYTIC', ...
                'CONVENTIONS 2: station (x aft, y right, z up) = body rotated 180 deg about y', 'Quantity', 'C_station_bfrp');
            datum = [3.1; 0.2; -0.4];                 % station coordinates of the BFRP
            st = vital.Axis.station(datum, bfrp, 'Name', 'station');
            tc.verifyExact(st.C, diag([-1 1 -1]), 'ANALYTIC', 'Axis.station uses the exact matrix', 'Quantity', 'C station factory');
            rS = [10 0.5 -1; 4 -2 0.3; 7 1 1].';
            act = vital.Point(rS, st).expressIn(bfrp).R;
            expected = zeros(3, 3);
            for k = 1:3, expected(:, k) = vital.frames.stationToBody(rS(:, k), datum); end
            tc.verifyTol(act, expected, 1e-13, 'abs', 'INDEP', 'vital.frames.stationToBody (CONVENTIONS 2)', ...
                'Quantity', 'station -> BFRP points', 'Unit', 'm');
        end

        function windStabilityAndNed(tc)
            rng(9104);
            body = vital.Axis.root('body');
            for k = 1:5
                al = (rand - 0.5) * pi / 2; be = (rand - 0.5) * pi / 3;
                w = vital.Axis.wind(al, be, body);
                tc.verifyTol(w.C, dcmbody2wind(al, be), 1e-15, 'abs', 'INDEP', 'Aerospace Toolbox dcmbody2wind', 'Quantity', 'C_wb');
                tc.verifyTol(w.Origin, zeros(3, 1), 0, 'abs', 'ANALYTIC', 'wind axes at the body origin', 'Quantity', 'wind origin');
                s = vital.Axis.stability(al, body);
                ca = cos(al); sa = sin(al);
                tc.verifyTol(s.C, [ca 0 sa; 0 1 0; -sa 0 ca], 1e-15, 'abs', 'ANALYTIC', 'C_sb = R2(alpha) passive', 'Quantity', 'C_sb');
            end
            ned = vital.Axis.root('ned');
            e = [0.4 -0.3 2.0];
            q = vital.frames.eul2quat(e(1), e(2), e(3));
            x = [200; 3; -5; 0.1; 0.2; 0.3; q; 1000; -200; -3000];
            b = vital.Axis.bodyInNed(x, ned);
            Ctbx = angle2dcm(e(3), e(2), e(1), 'ZYX');
            tc.verifyTol(b.C, Ctbx, 1e-14, 'abs', 'INDEP', 'angle2dcm ZYX = C_bn', 'Quantity', 'C_bn bodyInNed');
            tc.verifyTol(b.Origin, x(11:13), 0, 'abs', 'ANALYTIC', 'body origin at p_n', 'Quantity', 'body origin in NED', 'Unit', 'm');
            v = vital.Vector(x(1:3), b, 'Quantity', "velocity").expressIn(ned);
            tc.verifyTol(v.V, Ctbx.' * x(1:3), 1e-12, 'abs', 'INDEP', 'p_dot_n = C_bn transposed v_b', 'Quantity', 'v_n', 'Unit', 'm/s');
        end
    end
end
