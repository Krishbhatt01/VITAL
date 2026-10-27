classdef (TestTags = {'M9', 'CORE'}) tCoreMass < vital.test.VitalTestCase
%TCOREMASS  0.9.1-CORE: vital.InertiaTensor and vital.MassProperties
%   (PLAN_CORE_FRAMES 2.7, 2.8, 5; CONVENTIONS 2 and 6).
%   PRE-REGISTERED (written before the classes existed):
%   1. PARALLEL AXIS THROUGH THE CG ONLY. Two point masses m = 3 kg at y = +/-2 m
%      about a CG axis with zero self-inertia: about(cg) = 0 (exact);
%      about(an axis at [1 0 0] from the CG) = analytic 2m (d'd I - d d') with
%      d = the CG position seen from that axis (ANALYTIC, 1e-12 abs);
%      combine of two masses placed OFF the reference origin (CG not at the origin)
%      gives the analytic CG-centred inertia, NOT the origin-centred one
%      (discriminating: the two differ by 2.7e3 kg m^2).
%   2. combine reproduces the M1 1,000-sub-box test (tests/M1/tMass.m
%      #boxWithSelfInertiaIsExact): mass 1e-12 rel, CG 1e-12 abs, diag J =
%      M/12 (b^2+c^2, a^2+c^2, a^2+b^2) at 1e-12 rel (ANALYTIC), here with the box
%      centred at [2 -1 0.5] m (off the origin) and given in a rotated reference
%      axis; and it equals vital.mass.massProps on the same items (INDEP, 1e-12 rel).
%   3. F-16 (vital.aircraft.f16.model): m = 637.1595 slug, Ixx 9496, Iyy 55814,
%      Izz 63100, Ixz 982 slug ft^2 (tensor entry J13 = -982 slug ft^2), CG
%      DXCG = 0.01 cbar (35 - 25) ft = 1.132 ft forward of the MRC
%      (PUB: F16_inertia.dml; 1e-12 rel/abs).
%   4. Ixy/Iyz SIGN FLIP: an inertia tensor given in the station axis
%      (Axis.station) expressed in the BFRP has Ixy and Iyz of opposite sign and
%      Ixz of the same sign, equal to vital.frames.inertiaStationToBody (INDEP,
%      1e-12 abs).
%   5. weightLoads(C_bn, g) equals today's gravity term of vital.loads.sumLoadsAtCG
%      (m C_bn [0 0 g]) with zero moment about the CG (INDEP, 1e-12 rel).
%   6. dAlembertLoads(a, w, wdot) = (-m a, -(J wdot + w x J w)) about the CG
%      (ANALYTIC, 1e-12); it is a check helper only (the model guard is in
%      tCoreModel#dAlembertNeverInTotal).
%   7. Errors: negative mass vital:mass:negativeMass; non-physical tensor
%      vital:mass:nonPhysicalInertia; non-symmetric tensor vital:badInput;
%      combine with an empty list vital:mass:negativeMass.

    methods (Test)
        function parallelAxisThroughCgOnly(tc)
            bfrp = vital.Axis.root('bfrp');
            cg = vital.Axis([0 0 0], eye(3), bfrp, 'Name', 'cg');
            m = 3; L = 2;
            p1 = vital.MassProperties(m, vital.Axis([0 L 0], eye(3), bfrp, 'Name', 'p1'), zeros(3));
            p2 = vital.MassProperties(m, vital.Axis([0 -L 0], eye(3), bfrp, 'Name', 'p2'), zeros(3));
            mp = vital.MassProperties.combine([p1 p2], bfrp);
            tc.verifyTol(mp.about(cg), diag([2*m*L^2, 0, 2*m*L^2]), 1e-12, 'abs', 'ANALYTIC', 'I = 2 m L^2 about x and z', ...
                'Quantity', 'J about CG', 'Unit', 'kg m2');
            q = vital.Axis([1 0 0], eye(3), bfrp, 'Name', 'q');
            d = [-1; 0; 0];                        % CG seen from q
            Jq = diag([2*m*L^2, 0, 2*m*L^2]) + 2 * m * ((d.' * d) * eye(3) - d * d.');
            tc.verifyTol(mp.about(q), Jq, 1e-12, 'abs', 'ANALYTIC', 'parallel axis from the CG to q', 'Quantity', 'J about q', 'Unit', 'kg m2');
            % masses OFF the reference origin: CG at [5 0 0]; the inertia about the CG
            % must not depend on where the reference origin is
            o1 = vital.MassProperties(m, vital.Axis([5 L 0], eye(3), bfrp, 'Name', 'o1'), zeros(3));
            o2 = vital.MassProperties(m, vital.Axis([5 -L 0], eye(3), bfrp, 'Name', 'o2'), zeros(3));
            mo = vital.MassProperties.combine([o1 o2], bfrp);
            tc.verifyTol(mo.CgAxis.originIn(bfrp), [5; 0; 0], 1e-14, 'abs', 'ANALYTIC', 'composite CG', 'Quantity', 'CG', 'Unit', 'm');
            tc.verifyTol(mo.Inertia.J, diag([2*m*L^2, 0, 2*m*L^2]), 1e-12, 'abs', 'ANALYTIC', ...
                'composite inertia is about the composite CG (origin-centred would add 2m 25 = 150 to Jyy, Jzz)', ...
                'Quantity', 'J about composite CG', 'Unit', 'kg m2');
        end

        function combineReproducesBox(tc)
            n = 10; dims = [4, 2, 1]; Mt = 50; centre = [2; -1; 0.5];
            d = dims / n; mi = Mt / n^3;
            Jself = mi/12 * diag([d(2)^2 + d(3)^2, d(1)^2 + d(3)^2, d(1)^2 + d(2)^2]);
            bfrp = vital.Axis.root('bfrp');
            ref = vital.Axis([0.3 -0.2 0.1], [0.2 -0.1 0.4], bfrp, 'Name', 'ref');   % rotated, offset reference
            Cref = bfrp.dcmTo(ref);                   % box edges along the BFRP axes
            c = @(k, Lk) -Lk/2 + (k - 0.5) * Lk / n;
            parts = repmat(vital.MassProperties(1, bfrp, zeros(3)), 1, n^3);
            items = repmat(struct('m', mi, 'r', zeros(3, 1), 'J', Jself), 1, n^3);
            idx = 0;
            for i = 1:n
                for j = 1:n
                    for k = 1:n
                        idx = idx + 1;
                        r = centre + [c(i, dims(1)); c(j, dims(2)); c(k, dims(3))];
                        ax = vital.Axis(r, eye(3), bfrp, 'Name', sprintf('b%d', idx));
                        parts(idx) = vital.MassProperties(mi, ax, vital.InertiaTensor(Jself, ax));
                        items(idx).r = r;
                    end
                end
            end
            mp = vital.MassProperties.combine(parts, ref);
            body = vital.Axis(mp.CgAxis.originIn(bfrp), eye(3), bfrp, 'Name', 'cgbody');
            Jbody = mp.about(body);
            a = dims(1); b = dims(2); cc = dims(3);
            tc.verifyTol(mp.Mass, Mt, 1e-12, 'rel', 'ANALYTIC', 'sum of sub-box masses (tests/M1/tMass)', 'Quantity', 'm');
            tc.verifyTol(mp.CgAxis.originIn(bfrp), centre, 1e-12, 'abs', 'ANALYTIC', 'box centre', 'Quantity', 'r_cg', 'Unit', 'm');
            tc.verifyTol(diag(Jbody), Mt/12*[b^2+cc^2; a^2+cc^2; a^2+b^2], 1e-12, 'rel', 'ANALYTIC', ...
                'uniform box: J = M/12 (b^2+c^2, a^2+c^2, a^2+b^2) (tests/M1/tMass)', 'Quantity', 'diag J (body axes)');
            [M0, r0, J0] = vital.mass.massProps(items);
            tc.verifyTol([mp.Mass; mp.CgAxis.originIn(bfrp); Jbody(:)], [M0; r0; J0(:)], 1e-12 * Mt * a^2, 'abs', 'INDEP', ...
                'vital.mass.massProps on the same items', 'Quantity', 'combine vs massProps');
            tc.verifyTol(mp.Inertia.J, Cref * J0 * Cref.', 1e-12 * Mt * a^2, 'abs', 'ANALYTIC', ...
                'combined tensor is given in the reference axis orientation: C J C transposed', 'Quantity', 'J in ref axes');
        end

        function f16MatchesNasa(tc)
            k = vital.units.constants();
            f16 = vital.aircraft.f16.model();
            mp = f16.MassProps;
            body = vital.Axis(mp.CgAxis.originIn(f16.axis('bfrp')), eye(3), f16.axis('bfrp'), 'Name', 'cgbody');
            J = mp.about(body) / k.slugft2;
            tc.verifyTol(mp.Mass / k.slug, 637.1595, 1e-12, 'rel', 'PUB', 'F16_inertia.dml XMASS (slug)', 'Quantity', 'mass', 'Unit', 'slug');
            tc.verifyTol([J(1,1) J(2,2) J(3,3)], [9496 55814 63100], 1e-12, 'rel', 'PUB', 'F16_inertia.dml XIXX XIYY XIZZ', ...
                'Quantity', 'Ixx Iyy Izz', 'Unit', 'slug ft2');
            tc.verifyTol(J(1,3), -982, 1e-12, 'rel', 'PUB', 'F16_inertia.dml XIZX = 982, tensor entry -Ixz (CONVENTIONS 6)', ...
                'Quantity', 'J13', 'Unit', 'slug ft2');
            tc.verifyTol([J(1,2) J(2,3)], [0 0], 1e-12, 'abs', 'PUB', 'F16_inertia.dml XIXY = XIYZ = 0', 'Quantity', 'J12 J23');
            r = mp.CgAxis.originIn(f16.axis('mrc')) / k.ft;
            tc.verifyTol(r, [0.01 * 11.32 * (35 - 25); 0; 0], 1e-12, 'abs', 'PUB', ...
                'F16_inertia.dml DXCG = 0.01 CBAR (35 - CG_PCT_MAC) ft forward of the MRC', 'Quantity', 'CG from MRC', 'Unit', 'ft');
        end

        function stationProductsFlipSign(tc)
            bfrp = vital.Axis.root('bfrp');
            st = vital.Axis.station([5; 0; 1], bfrp, 'Name', 'station');
            Ixy = 120; Ixz = 340; Iyz = -75;
            JS = vital.mass.inertiaTensor(1000, 3000, 3500, Ixy, Ixz, Iyz);
            T = vital.InertiaTensor(JS, st);
            JR = T.expressIn(bfrp).J;
            tc.verifyTol(JR, vital.frames.inertiaStationToBody(JS), 1e-12, 'abs', 'INDEP', ...
                'vital.frames.inertiaStationToBody (CONVENTIONS 2)', 'Quantity', 'J station -> BFRP');
            tc.verifyTol([-JR(1,2) -JR(1,3) -JR(2,3)], [-Ixy Ixz -Iyz], 1e-12, 'abs', 'ANALYTIC', ...
                'CONVENTIONS 2: Ixy and Iyz flip, Ixz keeps its sign', 'Quantity', 'products in BFRP');
        end

        function weightLoadsEqualGravityTerm(tc)
            bfrp = vital.Axis.root('bfrp');
            cg = vital.Axis([0.345; 0; 0], eye(3), bfrp, 'Name', 'cg');
            m = 9295.44; g = 9.80665;
            mp = vital.MassProperties(m, cg, vital.mass.inertiaTensor(12875, 75674, 85552, 0, 1331, 0));
            C = vital.frames.dcm321(0.3, 0.1, 1.2);
            W = mp.weightLoads(C, g);
            [Fb, Mcg] = vital.loads.sumLoadsAtCG(zeros(3, 0), zeros(3, 0), cg.originIn(bfrp), m, C, [0; 0; g]);
            tc.verifyTol(W.F, Fb, 1e-12 * m * g, 'abs', 'INDEP', 'gravity term of vital.loads.sumLoadsAtCG', 'Quantity', 'weight force', 'Unit', 'N');
            tc.verifyTol(W.M, Mcg, 0, 'abs', 'INDEP', 'weight acts at the CG (CONVENTIONS 6)', 'Quantity', 'weight moment about CG', 'Unit', 'N m');
            tc.verifyTrue(W.RefAxis.isSame(cg), 'weight is referred to the CG axis');
        end

        function dAlembertFormula(tc)
            bfrp = vital.Axis.root('bfrp');
            cg = vital.Axis([0.2; 0; 0.1], eye(3), bfrp, 'Name', 'cg');
            J = vital.mass.inertiaTensor(100, 200, 250, 5, 10, -3);
            mp = vital.MassProperties(7, cg, J);
            a = [1; -2; 3]; w = [0.3; -0.4; 0.5]; wd = [0.1; 0.2; -0.3];
            D = mp.dAlembertLoads(a, w, wd);
            tc.verifyTol([D.F; D.M], [-7 * a; -(J * wd + cross(w, J * w))], 1e-12, 'abs', 'ANALYTIC', ...
                'd''Alembert: -m a, -(J wdot + w x J w) about the CG', 'Quantity', 'dAlembert loads');
        end

        function errors(tc)
            bfrp = vital.Axis.root('bfrp');
            tc.verifyError(@() vital.MassProperties(-1, bfrp, eye(3)), 'vital:mass:negativeMass');
            tc.verifyError(@() vital.InertiaTensor(diag([1 1 5]), bfrp), 'vital:mass:nonPhysicalInertia');
            tc.verifyError(@() vital.InertiaTensor([1 0.2 0; 0 1 0; 0 0 1], bfrp), 'vital:badInput');
            tc.verifyError(@() vital.MassProperties.combine(vital.MassProperties.empty, bfrp), 'vital:mass:negativeMass');
        end
    end
end
