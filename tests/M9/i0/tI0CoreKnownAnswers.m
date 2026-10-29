classdef (TestTags = {'M9', 'I0'}) tI0CoreKnownAnswers < vital.test.VitalTestCase
%TI0COREKNOWNANSWERS  Increment I0 (test hardening, no behaviour change; ADR-041):
%   hand-derived known answers for the object core with ROTATED axes everywhere,
%   so that the rotation path of the compiled model, the rotation of the weight
%   into a rotated CG axis and the rotation of self-inertia are checked against
%   numbers that do not come from VITAL (reports/review/CORE_AUDIT.md, finding M2;
%   sabotages SC-9, SC-10, SC-11).
%
%   Conventions (docs/CONVENTIONS.md 2, 3, 6): C_ab maps b components to a
%   components (passive); dcm321(phi, theta, psi) = R1(phi) R2(theta) R3(psi) = C_a_parent
%   for an axis with 3-2-1 Euler angles relative to its parent; the BFRP root is
%   body-parallel; the inertia tensor J = [Ixx -Ixy -Ixz; ...].
%   Every hand answer below is built from dcm321, cross, inv and elementary
%   algebra only; no vital.Axis/Loads/MassProperties call enters an expected value.
%
%   PRE-REGISTERED (written before the run; tolerances: every answer is a sum of
%   at most ~20 double-precision products of O(1e4) numbers, so the round-off is
%   below 1e-14 of the scale; the gate 1e-12 of the scale (max abs of the expected
%   vector) leaves a 100x margin, while each sabotage moves a result by 1e-3 or more
%   of its scale):
%
%   P1 TWIN WITH TILTED, TOED-IN, OFFSET ENGINES ON A CHAINED WING AXIS (ANALYTIC)
%      bfrp root. CG axis at r_cg = [0.5 0 0.1] m, ROTATED, Euler [0.05 -0.1 0.2] rad
%      (C_cg_b); inertia given in the CG axis, J_cg = C_cg_b J_b C_cg_b' with
%      J_b = [8000 0 -300; 0 20000 0; -300 0 26000] kg m^2; m = 5000 kg.
%      Wing axis 'wingL' at [0 0 0.5], 5 deg dihedral: C_w_b = R1(-5 deg).
%      Left engine axis CHAINED on the wing: origin r_L_w = C_w_b (r_L - o_w), orientation
%      C_eL_w = C_eL_b C_w_b', with r_L = [-2 -3 0.5] m and C_eL_b = dcm321(0, 3 deg, +5 deg)
%      (tilt 3 deg up, toe 5 deg). Right engine on the bfrp: r_R = [-2 3 0.5],
%      C_eR_b = dcm321(0, 3 deg, -5 deg).
%      Thrust T th_k along the engine +x, torque +Q th_L (left), -Q th_R (right),
%      T = 10 kN, Q = 500 N m, th = [0.8 0.6].
%      Hand: thrust direction in body d_k = C_ek_b' [1 0 0]'; F_k = T th_k d_k;
%      moment about the engine origin, body components, Q_k d_k; at the BFRP
%      M_k = r_k x F_k + Q_k d_k. Weight W_b = m C_bn [0 0 g]', at the CG.
%      State: phi, theta, psi = 0.1, 0.05, 0.3 rad; v_b = [60 2 3] m/s;
%      w = [0.1 -0.2 0.15] rad/s; p_n = [0 0 -1000] m; g = 9.80665.
%      (a) p1PerComponentLoadsAtBfrp: each component's Loads transformed to the bfrp
%          (object path) and the compiled y.F_R, y.M_R columns = (F_k, M_k).
%      (b) p1TotalsAtCgAndBfrp: loadsTotal(x, u, env, 'cg') (components in the ROTATED
%          CG axis) = C_cg_b [SF + W_b ; SM_k - r_cg x SF]; loadsTotal at the bfrp =
%          [SF + W_b ; SM_k + r_cg x W_b].
%      (c) p1DerivativesAgainstHandXdot: the compiled derivatives and derivativesObject
%          both equal the hand xdot (all 13 entries):
%            vdot = (SF + W_b)/m - w x v
%            wdot = J_b \ (M_cg - w x J_b w),  M_cg = SM_k - r_cg x SF
%            qdot = 0.5 Omega(w) q   (scalar-first, N -> B; |q| = 1)
%            pdot = C_bn' v
%          (Stevens & Lewis, Aircraft Control and Simulation, flat-Earth 6-DOF
%          equations; the gate 1e-12 of max|xdot|.)
%   P2 COMBINE WITH ROTATED SELF-INERTIA (ANALYTIC)
%      m1 = 100 kg at [1 0 0] with J = diag(10, 20, 30) in an axis yawed 90 deg (so
%      diag(20, 10, 30) in body axes); m2 = 300 kg at [-1 2 0] with J = 5 I.
%      Composite: m = 400, CG = [-0.5 1.5 0]; parallel axis through the composite CG
%      (d1 = [1.5 -1.5 0], d2 = [-0.5 0.5 0]): J = [325 300 0; 300 315 0; 0 0 635]
%      (J12 = +300 is Ixy = -300). Combined about a ROTATED, OFFSET reference axis
%      (origin [0.3 -0.2 0.1], Euler [0.1 0.2 -0.3]): CG coordinates C_r_b (cg - o_r),
%      tensor C_r_b J C_r_b'.
%   P3 about() A ROTATED, OFFSET AXIS AND A CHAINED ONE (ANALYTIC)
%      MassProperties built directly: m = 400, CG axis at [-0.5 1.5 0] ROTATED (Euler
%      [0.3 0.1 -0.2]), tensor in it J_cg = C J C' with J of P2. b at [2 0 1], Euler
%      [0.2 -0.1 0.4]; b2 a child of b at [0.5 -0.3 0.2] (b coordinates), Euler
%      [-0.3 0.2 0.1] relative to b, so C_b2_b = C_b2_b_rel C_b_bfrp and
%      o_b2 = o_b + C_b' t. Hand: about(a) = C_a (J + m (d'd I - d d')) C_a', d = cg - o_a
%      (body components). Also about(cg axis) = J_cg exactly (no transfer).
%   P4 WEIGHT WITH A ROTATED, CHAINED CG AXIS AT A NON-ZERO ATTITUDE (ANALYTIC)
%      m = 750 kg; 'fus' axis at [1 0 0], Euler [0.1 0 0.2]; CG axis a child of 'fus'
%      at [0.2 -0.1 0.3] (fus coordinates), Euler [0 0.3 0]; attitude Euler
%      [0.2 0.1 0.6] rad. Hand: W_b = m C_bn [0 0 g]'; in the CG axis F = C_cg_b W_b,
%      M = 0; at the bfrp F = W_b, M = r_cg x W_b; in NED C_bn' W_b = [0 0 m g]'.

    properties (Constant)
        G = 9.80665
    end

    methods (Test)
        function p1PerComponentLoadsAtBfrp(tc)
            [m, h] = p1Twin();
            fl = m.flight(h.x, h.u, h.env);
            bfrp = m.axis('bfrp');
            [~, y] = m.derivatives(h.x, h.u, h.env);
            names = {'engL', 'engR'};
            for k = 1:2
                L = m.component(names{k}).loads(fl).transform(bfrp);
                sc = max(abs([h.F(:, k); h.M(:, k)]));
                tc.verifyTol(L.F, h.F(:, k), 1e-12 * sc, 'abs', 'ANALYTIC', 'F_k = T th_k C_ek_b'' e1 (class header P1a)', ...
                    'Quantity', [names{k} ' force at bfrp (object)'], 'Unit', 'N');
                tc.verifyTol(L.M, h.M(:, k), 1e-12 * sc, 'abs', 'ANALYTIC', 'M_k = r_k x F_k + Q_k d_k (class header P1a)', ...
                    'Quantity', [names{k} ' moment about bfrp (object)'], 'Unit', 'N m');
                j = find(strcmp(y.componentNames, names{k}));
                tc.verifyTol(y.F_R(:, j), h.F(:, k), 1e-12 * sc, 'abs', 'ANALYTIC', 'compiled F_R = C F (class header P1a)', ...
                    'Quantity', [names{k} ' force at bfrp (compiled)'], 'Unit', 'N');
                tc.verifyTol(y.M_R(:, j), h.M(:, k), 1e-12 * sc, 'abs', 'ANALYTIC', 'compiled M_R = C M + r x C F (class header P1a)', ...
                    'Quantity', [names{k} ' moment about bfrp (compiled)'], 'Unit', 'N m');
            end
        end

        function p1TotalsAtCgAndBfrp(tc)
            [m, h] = p1Twin();
            SF = sum(h.F, 2); SM = sum(h.M, 2);
            Fexp = h.Ccg * (SF + h.Wb);
            Mexp = h.Ccg * (SM - cross(h.rcg, SF));
            L = m.loadsTotal(h.x, h.u, h.env, 'cg');
            sc = max(abs([Fexp; Mexp]));
            tc.verifyTol(L.F, Fexp, 1e-12 * sc, 'abs', 'ANALYTIC', 'C_cg_b (SF + W_b) (class header P1b)', ...
                'Quantity', 'total force, rotated CG axis', 'Unit', 'N');
            tc.verifyTol(L.M, Mexp, 1e-12 * sc, 'abs', 'ANALYTIC', 'C_cg_b (SM - r_cg x SF) (class header P1b)', ...
                'Quantity', 'total moment about the CG, rotated CG axis', 'Unit', 'N m');
            L = m.loadsTotal(h.x, h.u, h.env, 'bfrp');
            Fexp = SF + h.Wb; Mexp = SM + cross(h.rcg, h.Wb);
            sc = max(abs([Fexp; Mexp]));
            tc.verifyTol(L.F, Fexp, 1e-12 * sc, 'abs', 'ANALYTIC', 'SF + W_b (class header P1b)', ...
                'Quantity', 'total force at bfrp', 'Unit', 'N');
            tc.verifyTol(L.M, Mexp, 1e-12 * sc, 'abs', 'ANALYTIC', 'SM + r_cg x W_b (class header P1b)', ...
                'Quantity', 'total moment about bfrp', 'Unit', 'N m');
        end

        function p1DerivativesAgainstHandXdot(tc)
            [m, h] = p1Twin();
            tc.assertTrue(m.isCompiled(), 'the fixture must exercise the compiled path');
            tc.assertFalse(any(m.Compiled.identity), 'every engine axis must be rotated (else the rotation path is not exercised)');
            SF = sum(h.F, 2); SM = sum(h.M, 2);
            x = h.x; v = x(1:3); w = x(4:6); q = x(7:10);
            Mcg = SM - cross(h.rcg, SF);
            vdot = (SF + h.Wb) / h.mass - cross(w, v);
            wdot = h.Jb \ (Mcg - cross(w, h.Jb * w));
            Om = [0 -w(1) -w(2) -w(3); w(1) 0 w(3) -w(2); w(2) -w(3) 0 w(1); w(3) w(2) -w(1) 0];
            qdot = 0.5 * Om * q;
            pdot = h.Cbn.' * v;
            xd = [vdot; wdot; qdot; pdot];
            sc = max(abs(xd));
            xc = m.derivatives(x, h.u, h.env);
            tc.verifyTol(xc, xd, 1e-12 * sc, 'abs', 'ANALYTIC', 'flat-Earth 6-DOF equations, hand loads (class header P1c)', ...
                'Quantity', 'xdot compiled vs hand', 'Unit', 'SI');
            xo = m.derivativesObject(x, h.u, h.env);
            tc.verifyTol(xo, xd, 1e-12 * sc, 'abs', 'ANALYTIC', 'flat-Earth 6-DOF equations, hand loads (class header P1c)', ...
                'Quantity', 'xdot object path vs hand', 'Unit', 'SI');
        end

        function p2CombineRotatedSelfInertia(tc)
            bfrp = vital.Axis.root('bfrp');
            a1 = vital.Axis([1 0 0], [0 0 pi/2], bfrp, 'Name', 'm1');
            a2 = vital.Axis([-1 2 0], eye(3), bfrp, 'Name', 'm2');
            mp1 = vital.MassProperties(100, a1, diag([10 20 30]));
            mp2 = vital.MassProperties(300, a2, 5 * eye(3));
            Jh = [325 300 0; 300 315 0; 0 0 635];
            cgh = [-0.5; 1.5; 0];
            mc = vital.MassProperties.combine([mp1 mp2], bfrp);
            tc.verifyTol(mc.Mass, 400, 1e-12 * 400, 'abs', 'ANALYTIC', '100 + 300 kg (class header P2)', 'Quantity', 'combined mass', 'Unit', 'kg');
            tc.verifyTol(mc.CgAxis.originIn(bfrp), cgh, 1e-12 * 2, 'abs', 'ANALYTIC', '(100 [1 0 0] + 300 [-1 2 0]) / 400 (class header P2)', ...
                'Quantity', 'composite CG', 'Unit', 'm');
            C = mc.Inertia.Axis.dcmTo(bfrp);
            tc.verifyTol(C * mc.Inertia.J * C.', Jh, 1e-12 * 635, 'abs', 'ANALYTIC', 'rotated self-inertia + parallel axis via composite CG (class header P2)', ...
                'Quantity', 'composite J about the CG, body components', 'Unit', 'kg m^2');
            ref = vital.Axis([0.3 -0.2 0.1], [0.1 0.2 -0.3], bfrp, 'Name', 'refRot');
            Cr = vital.frames.dcm321(0.1, 0.2, -0.3);
            mr = vital.MassProperties.combine([mp1 mp2], ref);
            tc.verifyTol(mr.CgAxis.originIn(ref), Cr * (cgh - [0.3; -0.2; 0.1]), 1e-12 * 2, 'abs', 'ANALYTIC', ...
                'C_r_b (cg - o_r) (class header P2)', 'Quantity', 'composite CG in the rotated reference', 'Unit', 'm');
            C = mr.Inertia.Axis.dcmTo(ref);
            tc.verifyTol(C * mr.Inertia.J * C.', Cr * Jh * Cr.', 1e-12 * 635, 'abs', 'ANALYTIC', 'C_r_b J C_r_b'' (class header P2)', ...
                'Quantity', 'composite J in the rotated reference', 'Unit', 'kg m^2');
        end

        function p3AboutRotatedOffsetAxis(tc)
            bfrp = vital.Axis.root('bfrp');
            Jh = [325 300 0; 300 315 0; 0 0 635]; mass = 400; cgb = [-0.5; 1.5; 0];
            Ccg = vital.frames.dcm321(0.3, 0.1, -0.2);
            cg = vital.Axis(cgb, Ccg, bfrp, 'Name', 'cg');
            mp = vital.MassProperties(mass, cg, vital.InertiaTensor(Ccg * Jh * Ccg.', cg));
            ob = [2; 0; 1]; Cb = vital.frames.dcm321(0.2, -0.1, 0.4);
            b = vital.Axis(ob, [0.2 -0.1 0.4], bfrp, 'Name', 'b');
            t2 = [0.5; -0.3; 0.2]; Crel = vital.frames.dcm321(-0.3, 0.2, 0.1);
            b2 = vital.Axis(t2, [-0.3 0.2 0.1], b, 'Name', 'b2');
            Cb2 = Crel * Cb; ob2 = ob + Cb.' * t2;
            hand = @(C, o) C * (Jh + mass * (((cgb - o).' * (cgb - o)) * eye(3) - (cgb - o) * (cgb - o).')) * C.';
            sc = 400 * 10 + 635;
            tc.verifyTol(mp.about(b), hand(Cb, ob), 1e-12 * sc, 'abs', 'ANALYTIC', 'C_b (J + m(d''d I - d d'')) C_b'' (class header P3)', ...
                'Quantity', 'J about a rotated, offset axis', 'Unit', 'kg m^2');
            tc.verifyTol(mp.about(b2), hand(Cb2, ob2), 1e-12 * sc, 'abs', 'ANALYTIC', 'chained axis: C_b2_b = C_rel C_b, o_b2 = o_b + C_b'' t (class header P3)', ...
                'Quantity', 'J about a chained rotated axis', 'Unit', 'kg m^2');
            tc.verifyTol(mp.about(cg), Ccg * Jh * Ccg.', 1e-12 * 635, 'abs', 'ANALYTIC', 'no transfer about the CG itself (class header P3)', ...
                'Quantity', 'J about the rotated CG axis', 'Unit', 'kg m^2');
        end

        function p4WeightRotatedChainedCgAxis(tc)
            g = tc.G; mass = 750;
            bfrp = vital.Axis.root('bfrp');
            fus = vital.Axis([1 0 0], [0.1 0 0.2], bfrp, 'Name', 'fus');
            cg = vital.Axis([0.2 -0.1 0.3], [0 0.3 0], fus, 'Name', 'cg');
            Cf = vital.frames.dcm321(0.1, 0, 0.2);
            Ccg = vital.frames.dcm321(0, 0.3, 0) * Cf;
            rcg = [1; 0; 0] + Cf.' * [0.2; -0.1; 0.3];
            Cbn = vital.frames.dcm321(0.2, 0.1, 0.6);
            Wb = mass * Cbn * [0; 0; g];
            mp = vital.MassProperties(mass, cg, eye(3));
            W = mp.weightLoads(Cbn, g);
            sc = mass * g;
            tc.verifyTol(W.F, Ccg * Wb, 1e-12 * sc, 'abs', 'ANALYTIC', 'C_cg_b m C_bn [0 0 g]'' (class header P4)', ...
                'Quantity', 'weight in the rotated, chained CG axis', 'Unit', 'N');
            tc.verifyTol(W.M, zeros(3, 1), 1e-12 * sc, 'abs', 'ANALYTIC', 'the weight acts at the CG (class header P4)', ...
                'Quantity', 'weight moment about the CG', 'Unit', 'N m');
            Wr = W.transform(bfrp);
            tc.verifyTol(Wr.F, Wb, 1e-12 * sc, 'abs', 'ANALYTIC', 'm C_bn [0 0 g]'' (class header P4)', ...
                'Quantity', 'weight at the bfrp', 'Unit', 'N');
            tc.verifyTol(Wr.M, cross(rcg, Wb), 1e-12 * sc * norm(rcg), 'abs', 'ANALYTIC', 'r_cg x W_b (class header P4)', ...
                'Quantity', 'weight moment about the bfrp', 'Unit', 'N m');
            tc.verifyTol(Cbn.' * Wr.F, [0; 0; mass * g], 1e-12 * sc, 'abs', 'ANALYTIC', 'weight is straight down in NED (class header P4)', ...
                'Quantity', 'weight in NED', 'Unit', 'N');
        end
    end
end

function [m, h] = p1Twin()
% the P1 model (compiled) and the hand quantities of the class header
g = 9.80665;
bfrp = vital.Axis.root('bfrp');
h.rcg = [0.5; 0; 0.1];
h.Ccg = vital.frames.dcm321(0.05, -0.1, 0.2);
cg = vital.Axis(h.rcg, h.Ccg, bfrp, 'Name', 'cg');
th = deg2rad(3); ps = deg2rad(5);
rL = [-2; -3; 0.5]; rR = [-2; 3; 0.5]; ow = [0; 0; 0.5];
Cw = vital.frames.dcm321(deg2rad(-5), 0, 0);
wing = vital.Axis(ow, [deg2rad(-5) 0 0], bfrp, 'Name', 'wingL');
CeL = vital.frames.dcm321(0, th, ps);
CeR = vital.frames.dcm321(0, th, -ps);
engL = vital.Axis(Cw * (rL - ow), CeL * Cw.', wing, 'Name', 'engL');
engR = vital.Axis(rR, [0 th -ps], bfrp, 'Name', 'engR');
T = 10000; Q = 500;
fL = @(fl, t) deal(T * t, Q * t, struct('outOfEnvelope', false));
fR = @(fl, t) deal(T * t, -Q * t, struct('outOfEnvelope', false));
pL = vital.PropulsorComponent('engL', engL, fL, 'thL');
pR = vital.PropulsorComponent('engR', engR, fR, 'thR');
h.mass = 5000;
h.Jb = [8000 0 -300; 0 20000 0; -300 0 26000];
mp = vital.MassProperties(h.mass, cg, vital.InertiaTensor(h.Ccg * h.Jb * h.Ccg.', cg));
m = vital.AircraftModel('P1 twin (I0 test fixture)', [bfrp cg wing engL engR], {pL, pR}, mp, {'thL', 'thR'}, ...
    'Ref', struct('S', 20, 'b', 10, 'cbar', 2));
m = m.compile();
h.u = [0.8; 0.6];
eul = [0.1 0.05 0.3];
h.x = [60; 2; 3; 0.1; -0.2; 0.15; vital.frames.eul2quat(eul(1), eul(2), eul(3)); 0; 0; -1000];
h.env = struct('g', g, 'wind_n', [0; 0; 0], 'deltaT', 0);
h.Cbn = vital.frames.dcm321(eul(1), eul(2), eul(3));
dL = CeL.' * [1; 0; 0]; dR = CeR.' * [1; 0; 0];
h.F = [T * h.u(1) * dL, T * h.u(2) * dR];
h.M = [cross(rL, h.F(:, 1)) + Q * h.u(1) * dL, cross(rR, h.F(:, 2)) - Q * h.u(2) * dR];
h.Wb = h.mass * h.Cbn * [0; 0; g];
end
