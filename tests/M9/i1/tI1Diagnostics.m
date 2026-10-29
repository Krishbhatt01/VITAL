classdef (TestTags = {'M9', 'I1'}) tI1Diagnostics < vital.test.VitalTestCase
%TI1DIAGNOSTICS  Increment I1 (ADR-043): the diagnostics of the model path are by
%   component KIND and never a silent wrong number (findings F-6, F-7, F-8).
%   Every vital.Component declares a Kind: 'aero' (AeroTableComponent),
%   'propulsion' (PropulsorComponent), 'other' (counted in neither), or
%   'unclassified' (the default; then y.F_aero, M_aero, F_prop, M_prop are NaN:
%   the force cannot be attributed). c.withKind(kind) re-declares it.
%
%   PRE-REGISTERED (written before the implementation):
%   1. linearAircraftThroughPlant (ANALYTIC, 1e-12 of max|xdot|): the analytic
%      linear-derivative aircraft (tests/reference/linearDerivativeAircraft.m)
%      through vital.plant.derivatives(x, u, model, env) and through its toRuntime
%      struct equals the closed form tests/reference/linearDerivativeXdot.m (the
%      I0 hand equations) at 3 states; y.F_R equals the closed-form component
%      force to 1e-12 of its scale.
%   2. unclassifiedIsNaN (F-7, REG): its single LinearDerivativeComponent is
%      unclassified (it lumps aero and thrust derivatives), so y.F_aero, y.M_aero,
%      y.F_prop and y.M_prop are all NaN, never 0 (before I1 F_aero read 0 while the
%      body force is ~1 kN).
%   3. declaredAeroIsExact (F-7, ANALYTIC 1e-12): the same model with the component
%      re-declared c.withKind('aero'): y.F_aero = the closed-form force F, y.M_aero
%      = the closed-form moment M (about the component origin), y.F_prop = y.M_prop
%      = 0 exactly (no propulsion component); 'other' gives F_aero = F_prop = 0.
%      An unknown kind is vital:badInput.
%   4. twinPropulsionSums (F-8, REG 1e-12 rel): through the plant, the twin's
%      y.F_prop is the sum of its two engines and equals the F-16 single engine's
%      F_prop (each engine half the thrust) and y.thrust_lbf the F-16's; the
%      compiled y and the object-path y carry the same F_aero/M_aero/F_prop/M_prop.
%   5. twoAeroPointsRotating (F-6, ANALYTIC 1e-12 of the moment scale): a model with
%      TWO AeroTableComponents of constant coefficients on axes at DIFFERENT points
%      (one rotated), zero controls, through derivativesRotating with its toRuntime
%      struct: y.F_aero = sum_k C_k' F_k and y.M_aero_cg = sum_k (C_k' M_k +
%      (r_k - r_cg) x C_k' F_k), F_k = qbar S [cx cy cz], M_k = qbar S [b cl; cbar
%      cm; b cn] with qbar = y.qbar (before I1 the moment used the FIRST component's
%      point for both).

    properties
        Env
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            tc.Env = struct('g', 9.80665, 'wind_n', [0; 0; 0], 'deltaT', 0);
        end
    end

    methods (Test)
        function linearAircraftThroughPlant(tc)
            [m, P] = linearDerivativeAircraft();
            R = m.toRuntime();
            for k = 1:3
                [x, u] = linState(k);
                [xd, F] = linearDerivativeXdot(P, x, u);
                sc = max(abs(xd));
                cite = 'closed-form 6-DOF with the LinearDerivativeComponent loads (tests/reference/linearDerivativeXdot.m)';
                [x1, y1] = vital.plant.derivatives(x, u, m, tc.Env);
                x2 = vital.plant.derivatives(x, u, R, tc.Env);
                tc.verifyTol(x1, xd, 1e-12 * sc, 'abs', 'ANALYTIC', cite, 'Quantity', sprintf('xdot plant(model) state %d', k), 'Unit', 'SI');
                tc.verifyTol(x2, xd, 1e-12 * sc, 'abs', 'ANALYTIC', cite, 'Quantity', sprintf('xdot plant(toRuntime) state %d', k), 'Unit', 'SI');
                tc.verifyTol(y1.F_R, F, 1e-12 * max(abs(F)), 'abs', 'ANALYTIC', cite, 'Quantity', sprintf('y.F_R state %d', k), 'Unit', 'N');
            end
        end

        function unclassifiedIsNaN(tc)
            m = linearDerivativeAircraft();
            [x, u] = linState(1);
            [~, y] = vital.plant.derivatives(x, u, m, tc.Env);
            for f = {'F_aero', 'M_aero', 'F_prop', 'M_prop'}
                tc.verifyTrue(isfield(y, f{1}) && isequal(size(y.(f{1})), [3 1]) && all(isnan(y.(f{1}))), ...
                    sprintf('y.%s must be NaN(3,1) for an unclassified component (F-7), not 0', f{1}));
            end
        end

        function declaredAeroIsExact(tc)
            [m0, P] = linearDerivativeAircraft();
            m = withKindModel(m0, 'aero');
            [x, u] = linState(2);
            [~, F, M] = linearDerivativeXdot(P, x, u);
            [~, y] = vital.plant.derivatives(x, u, m, tc.Env);
            cite = 'LinearDerivativeComponent loads written out (tests/reference/linearDerivativeXdot.m)';
            tc.verifyTol(y.F_aero, F, 1e-12 * max(abs(F)), 'abs', 'ANALYTIC', cite, 'Quantity', 'y.F_aero (kind aero)', 'Unit', 'N');
            tc.verifyTol(y.M_aero, M, 1e-12 * max(abs(M)), 'abs', 'ANALYTIC', cite, 'Quantity', 'y.M_aero (kind aero)', 'Unit', 'N m');
            tc.verifyExact([y.F_prop; y.M_prop], zeros(6, 1), 'ANALYTIC', 'no propulsion component', 'Quantity', 'y.F_prop, y.M_prop');
            mo = withKindModel(m0, 'other');
            [~, yo] = vital.plant.derivatives(x, u, mo, tc.Env);
            tc.verifyExact([yo.F_aero; yo.F_prop], zeros(6, 1), 'ANALYTIC', 'kind other: in neither sum', 'Quantity', 'y.F_aero, y.F_prop (other)');
            tc.verifyError(@() m0.Components{1}.withKind('wing'), 'vital:badInput');
        end

        function twinPropulsionSums(tc)
            twin = coreTwinFixture(1.5);
            f16 = vital.aircraft.f16.model();
            x = [150; 2; 8; 0.01; 0.02; -0.01; vital.frames.eul2quat(0.05, 0.06, 0.4); 0; 0; -3000];
            th = 0.6;
            [~, yt] = vital.plant.derivatives(x, [-0.03; 0.01; 0; th; th], twin, tc.Env);
            [~, yf] = vital.plant.derivatives(x, [-0.03; 0.01; 0; th], vital.aircraft.f16.config(), tc.Env);
            [~, yo] = twin.derivativesObject(x, [-0.03; 0.01; 0; th; th], tc.Env);
            cite = 'two engines of half the F-16 thrust each (coreTwinFixture)';
            tc.verifyTol(yt.F_prop, yf.F_prop, 1e-12 * norm(yf.F_prop), 'abs', 'REG', cite, 'Quantity', 'twin y.F_prop', 'Unit', 'N');
            tc.verifyTol(yt.thrust_lbf, yf.thrust_lbf, 1e-12 * yf.thrust_lbf, 'abs', 'REG', cite, 'Quantity', 'twin y.thrust_lbf', 'Unit', 'lbf');
            tc.verifyExact([yt.F_aero; yt.M_aero], [yf.F_aero; yf.M_aero], 'REG', 'same aero component as the F-16', 'Quantity', 'twin y.F_aero, M_aero');
            sc = max(abs([yt.F_aero; yt.M_aero; yt.F_prop]));
            tc.verifyTol([yo.F_aero; yo.M_aero; yo.F_prop; yo.M_prop], [yt.F_aero; yt.M_aero; yt.F_prop; yt.M_prop], 1e-12 * sc, ...
                'abs', 'REG', 'object path = compiled path', 'Quantity', 'twin kind sums, object vs compiled', 'Unit', 'SI');
        end

        function twoAeroPointsRotating(tc)
            root = vital.Axis.root('bfrp');
            cg = vital.Axis([0.3; 0; 0.1], eye(3), root, 'Name', 'cg');
            C2 = vital.frames.dcm321(0.2, -0.1, 0.3);
            a1 = vital.Axis([1.5; 0; -0.2], eye(3), root, 'Name', 'wing');
            a2 = vital.Axis([-4; 0.5; 0.8], C2, root, 'Name', 'tail');
            S = 2; b = 3; cbar = 0.7;
            c1 = [-0.03 0.01 -0.4 0.002 0.05 -0.001];
            c2 = [-0.01 -0.02 -0.08 0.004 -0.03 0.006];
            k1 = vital.AeroTableComponent('wing', a1, @(fl) constCoeff(c1), 'S', S, 'b', b, 'cbar', cbar, 'Channels', {});
            k2 = vital.AeroTableComponent('tail', a2, @(fl) constCoeff(c2), 'S', S, 'b', b, 'cbar', cbar, 'Channels', {});
            J = diag([400 900 1200]);
            mp = vital.MassProperties(300, cg, vital.InertiaTensor(J, cg));
            m = vital.AircraftModel('two aero points (I1 test fixture)', [root cg a1 a2], {k1, k2}, mp, {}, ...
                'Ref', struct('S', S, 'b', b, 'cbar', cbar));
            m = m.compile();
            K = vital.geo.constants('wgs84');
            env = struct('earth', 'wgs84', 'rotation', true, 'gravity', 'J2', 'wind_n', [0; 0; 0], ...
                'windGradient_n', [0; 0; 0], 'deltaT', 0);
            x = vital.eom.rotatingState(0.4, 0.2, 2000, [80; 5; -2], [0.05; 0.1; 0.4], [0.01; 0.02; 0.0], K);
            [~, y] = vital.plant.derivativesRotating(x, [], m.toRuntime(), env);
            qS = y.qbar * S;
            F1 = qS * c1(1:3).'; M1 = qS * [b * c1(4); cbar * c1(5); b * c1(6)];
            F2 = qS * c2(1:3).'; M2 = qS * [b * c2(4); cbar * c2(5); b * c2(6)];
            r1 = [1.5; 0; -0.2]; r2 = [-4; 0.5; 0.8]; rcg = [0.3; 0; 0.1];
            Fh = F1 + C2.' * F2;
            Mh = M1 + cross(r1 - rcg, F1) + C2.' * M2 + cross(r2 - rcg, C2.' * F2);
            cite = 'sum over components of C_k'' M_k + (r_k - r_cg) x C_k'' F_k (rigid-body moment transfer)';
            tc.verifyTol(y.F_aero, Fh, 1e-12 * norm(Fh), 'abs', 'ANALYTIC', cite, 'Quantity', 'y.F_aero, two aero components', 'Unit', 'N');
            tc.verifyTol(y.M_aero_cg, Mh, 1e-12 * max(norm(Mh), norm(Fh)), 'abs', 'ANALYTIC', cite, ...
                'Quantity', 'y.M_aero_cg, two aero components at different points (F-6)', 'Unit', 'N m');
        end
    end
end

function [c, info] = constCoeff(c)
info = struct('outOfEnvelope', false);
end

function m = withKindModel(m0, kind)
comps = m0.Components;
comps{1} = comps{1}.withKind(kind);
m = vital.AircraftModel(m0.Name, m0.Axes, comps, m0.MassProps, m0.Controls, 'Ref', m0.Ref, 'Limits', m0.Limits);
m = m.compile();
end

function [x, u] = linState(k)
eul = [0.15 0.12 -0.4; -0.2 0.05 1.1; 0.4 -0.1 2.5];
vb = [48 3 5; 55 -2 4; 42 6 1];
w = [0.2 -0.1 0.3; -0.05 0.1 0.02; 0.3 0.2 -0.25];
x = [vb(k, :).'; w(k, :).'; vital.frames.eul2quat(eul(k, 1), eul(k, 2), eul(k, 3)); 10; -20; -1500];
uu = [-0.06 0.03 -0.02 0.5; -0.02 -0.05 0.04 0.3; 0.01 0.0 0.1 0.8];
u = uu(k, :).';
end
