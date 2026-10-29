classdef (TestTags = {'M9', 'I0'}) tI0LinearDerivativeAircraft < vital.test.VitalTestCase
%TI0LINEARDERIVATIVEAIRCRAFT  Increment I0 (ADR-041): a NON-F-16 aircraft whose
%   answers are known in closed form, run through the existing consumers
%   (vital.plant.derivatives via toRuntime, vital.trim.solve, vital.linear.linearize,
%   vital.linear.modes) without any production change.
%   Fixture: tests/reference/linearDerivativeAircraft.m (one
%   tests/reference/LinearDerivativeComponent.m at the CG, body-parallel; constant
%   dimensional derivatives; controls {de da dr throttle}; Ixz ~= 0; reference
%   state Ve = 50 m/s, alpha_e = theta_e = 0.08 rad, de_e = -0.04 rad, t_e = 0.45,
%   h = 1000 m, zero wind, g = 9.80665).
%   Notation: a.Xu = Xu/m etc. (forces per unit mass), a.Mu = Mu/Iyy, a.Lv = Lv/Ixx,
%   a.Nv = Nv/Izz (P.a of the fixture); Ue = Ve cos(alpha_e), We = Ve sin(alpha_e).
%
%   PRE-REGISTERED:
%   1. xdotExact (ANALYTIC, 1e-12 of max|xdot|): at a general state (attitude
%      [0.15 0.12 -0.4] rad, v_b = [48 3 5] m/s, w = [0.2 -0.1 0.3] rad/s, controls
%      [-0.06 0.03 -0.02 0.5]) the hand xdot = the 6-DOF equations of class
%      tI0CoreKnownAnswers P1c with the loads of LinearDerivativeComponent written out
%      in the test (component at the CG, so M_cg = [L M N]), for the compiled model,
%      the object path and vital.plant.derivatives(x, u, model.toRuntime(), env).
%      Round-off: ~20 products of O(1e4) numbers; 1e-12 leaves a 100x margin.
%   2. trimAtReferenceState (ANALYTIC): vital.trim.solve(model.toRuntime(), env,
%      level V = Ve, h_e) gives status OK and (alpha, de, throttle) = (alpha_e, de_e,
%      t_e). Closed form: the constant loads Xe = m g sin(theta_e), Ze = -m g
%      cos(theta_e), Me = 0 make the reference state an equilibrium exactly (Etkin &
%      Reid 1996, sec. 4.9, reference steady state). Tolerance: the solver accepts a
%      scaled residual r = [udot/g, wdot/g, qdot] below tr.tol (1e-9); to first order
%      |dz| <= ||Jr^-1||_inf tr.tol, Jr the hand Jacobian of r with respect to
%      (alpha, de, throttle) (written out below); that bound is the tolerance.
%   3. trimOffDesign (ANALYTIC): level trim at V = 60 m/s. With q = 0, beta = 0,
%      phi = 0, theta = alpha, the three residuals are linear in (dde, dt) for a given
%      alpha; X and M give dde(alpha), dt(alpha) by Cramer's rule and the Z equation
%      reduces to ONE scalar equation g(alpha) = 0, solved by fzero to round-off. Same
%      tolerance rule as 2.
%   4. linearModelClosedForm (ANALYTIC): vital.linear.linearize at the trim of 2.
%      Body-axis small-disturbance matrices (Etkin & Reid 1996 sec. 4.9 with W_e ~= 0
%      kept, i.e. body rather than stability axes; Stevens & Lewis 2003, small-
%      perturbation equations), x_lon = [u w q theta], x_lat = [v p r phi]:
%        A_lon = [a.Xu  a.Xw  a.Xq - We  -g cos(th_e);
%                 a.Zu  a.Zw  a.Zq + Ue  -g sin(th_e);
%                 a.Mu  a.Mw  a.Mq        0;
%                 0     0     1           0]
%        A_lat = [a.Yv  a.Yp + We  a.Yr - Ue  g cos(th_e);
%                 L'v   L'p        L'r        0;
%                 N'v   N'p        N'r        0;
%                 0     1          tan(th_e)  0]
%      primed (Ixz) derivatives: [L'; N'] = [Izz Ixz; Ixz Ixx] [L; N] / (Ixx Izz - Ixz^2)
%      (the inverse of the inertia block [Ixx -Ixz; -Ixz Izz]); the w x J w term
%      vanishes to first order at w = 0. B_lon/B_lat: the control derivatives per unit
%      mass/inertia (primed for L, N). Tolerances: B 1e-9 abs (the plant is EXACTLY
%      linear in the controls, so the central difference is exact to round-off);
%      A 1e-7 abs: the only non-linear columns are theta and phi (gravity), where the
%      accepted central-difference step of vital.linear.jacobian (1e-4 rad, its
%      plateau rule with the default H0) leaves a truncation g h^2/6 = 1.6e-8; 1e-7
%      is ~6x that bound.
%   5. eigenvaluesClosedForm (ANALYTIC, 1e-8 abs, the I0 criterion of CORE_AUDIT 6):
%      the exact roots of the characteristic quartics det(sI - A) = s^4 + c1 s^3 +
%      c2 s^2 + c3 s + c4 with the coefficients written out from the entries above
%      (sums of principal minors; Etkin & Reid's longitudinal and lateral quartics in
%      body axes):
%        lon (a b c d / e f g h / i j k 0 / 0 0 1 0):
%          c1 = -(a + f + k);  c2 = af - be + ak - ci + fk - gj
%          c3 = -(a(fk - gj) - b(ek - gi) + c(ej - fi) + d i + h j)
%          c4 = a h j - b h i - d(e j - f i)
%        lat (a b c d / e f g 0 / i j k 0 / 0 1 t 0):
%          c1 = -(a + f + k);  c2 = af - be + ak - ci + fk - gj
%          c3 = -(a(fk - gj) - b(ek - gi) + c(ej - fi) + d e + d i t)
%          c4 = -d(e(j t - k) - f i t + g i)
%      roots by `roots` (companion matrix, well separated roots, error ~1e-15). Compared
%      with eig(lin.lon.A), eig(lin.lat.A), eig(lin.A(1:8, 1:8)) and the eigenvalues of
%      vital.linear.modes(lin): short period = the faster lon pair, phugoid = the
%      slower, dutch_roll = the lat pair, roll = the fast lat real root, spiral = the
%      slow one. The first-order eigenvalue error from the 1.6e-8 A error is O(1e-10).

    properties
        Model
        P
        AC
        Env
        Trim
    end

    methods (TestClassSetup)
        function setup(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(vital.paths('tests'), 'reference')));
            [tc.Model, tc.P] = linearDerivativeAircraft();
            tc.AC = tc.Model.toRuntime();
            tc.Env = struct('g', tc.P.g, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', tc.P.Ve, 'h', tc.P.h_e, 'gamma', 0, 'psi', 0);
            tc.Trim = vital.trim.solve(tc.AC, tc.Env, cond);
        end
    end

    methods (Test)
        function xdotExact(tc)
            P = tc.P; a = P.a; g = P.g;
            eul = [0.15 0.12 -0.4];
            x = [48; 3; 5; 0.2; -0.1; 0.3; vital.frames.eul2quat(eul(1), eul(2), eul(3)); 10; -20; -1500];
            u = [-0.06; 0.03; -0.02; 0.5];
            du = x(1) - P.Ue; v = x(2); dw = x(3) - P.We; p = x(4); q = x(5); r = x(6);
            dde = u(1) - P.de_e; da = u(2); dr = u(3); dt = u(4) - P.t_e;
            m = P.m_kg;
            F = m * [P.Xe / m + a.Xu * du + a.Xw * dw + a.Xq * q + a.Xde * dde + a.Xt * dt;
                     a.Yv * v + a.Yp * p + a.Yr * r + a.Yda * da + a.Ydr * dr;
                     P.Ze / m + a.Zu * du + a.Zw * dw + a.Zq * q + a.Zde * dde + a.Zt * dt];
            M = [P.Ixx * (a.Lv * v + a.Lp * p + a.Lr * r + a.Lda * da + a.Ldr * dr);
                 P.Iyy * (a.Mu * du + a.Mw * dw + a.Mq * q + a.Mde * dde + a.Mt * dt);
                 P.Izz * (a.Nv * v + a.Np * p + a.Nr * r + a.Nda * da + a.Ndr * dr)];
            J = [P.Ixx 0 -P.Ixz; 0 P.Iyy 0; -P.Ixz 0 P.Izz];
            Cbn = vital.frames.dcm321(eul(1), eul(2), eul(3));
            w = x(4:6); vb = x(1:3); qq = x(7:10);
            Om = [0 -w(1) -w(2) -w(3); w(1) 0 w(3) -w(2); w(2) -w(3) 0 w(1); w(3) w(2) -w(1) 0];
            xd = [F / m + Cbn * [0; 0; g] - cross(w, vb); J \ (M - cross(w, J * w)); 0.5 * Om * qq; Cbn.' * vb];
            env = tc.Env;
            sc = max(abs(xd));
            cite = '6-DOF equations with the LinearDerivativeComponent loads written out (class header 1)';
            tc.verifyTol(tc.Model.derivatives(x, u, env), xd, 1e-12 * sc, 'abs', 'ANALYTIC', cite, 'Quantity', 'xdot compiled', 'Unit', 'SI');
            tc.verifyTol(tc.Model.derivativesObject(x, u, env), xd, 1e-12 * sc, 'abs', 'ANALYTIC', cite, 'Quantity', 'xdot object path', 'Unit', 'SI');
            tc.verifyTol(vital.plant.derivatives(x, u, tc.AC, env), xd, 1e-12 * sc, 'abs', 'ANALYTIC', cite, ...
                'Quantity', 'xdot vital.plant.derivatives(toRuntime)', 'Unit', 'SI');
        end

        function trimAtReferenceState(tc)
            P = tc.P; tr = tc.Trim;
            tc.assertEqual(tr.status, 'OK', tr.reason);
            zh = [P.alpha_e; P.de_e; P.t_e];
            tol = norm(inv(trimJacobian(P, P.Ve, P.alpha_e)), inf) * tr.tol;
            tc.verifyTol([tr.alpha; tr.u(1); tr.u(4)], zh, tol, 'abs', 'ANALYTIC', ...
                'reference steady state Xe = m g sin(th_e), Ze = -m g cos(th_e), Me = 0 (class header 2)', ...
                'Quantity', 'trim [alpha de throttle] at Ve', 'Unit', 'rad, rad, -');
            tc.verifyTol(tr.u([2 3]), [0; 0], 0, 'abs', 'ANALYTIC', 'wings-level trim (class header 2)', ...
                'Quantity', 'trim [da dr]', 'Unit', 'rad');
        end

        function trimOffDesign(tc)
            P = tc.P; V = 60;
            cond = struct('type', 'level', 'V', V, 'h', P.h_e, 'gamma', 0, 'psi', 0);
            tr = vital.trim.solve(tc.AC, tc.Env, cond);
            tc.assertEqual(tr.status, 'OK', tr.reason);
            al = fzero(@(al) offDesignResidual(P, V, al), P.alpha_e, optimset('TolX', 1e-17));
            [~, dde, dt] = offDesignResidual(P, V, al);
            zh = [al; P.de_e + dde; P.t_e + dt];
            tol = norm(inv(trimJacobian(P, V, al)), inf) * tr.tol + 1e-14;
            tc.verifyTol([tr.alpha; tr.u(1); tr.u(4)], zh, tol, 'abs', 'ANALYTIC', ...
                'X, M Cramer elimination + scalar Z equation solved by fzero (class header 3)', ...
                'Quantity', 'trim [alpha de throttle] at 60 m/s', 'Unit', 'rad, rad, -');
        end

        function linearModelClosedForm(tc)
            tc.assertEqual(tc.Trim.status, 'OK', tc.Trim.reason);
            lin = vital.linear.linearize(tc.AC, tc.Env, tc.Trim);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            [Alon, Alat, Blon, Blat] = handMatrices(tc.P);
            cite = 'body-axis small-disturbance matrices (class header 4)';
            tc.verifyTol(lin.lon.A, Alon, 1e-7, 'abs', 'ANALYTIC', cite, 'Quantity', 'A_lon', 'Unit', 'SI');
            tc.verifyTol(lin.lat.A, Alat, 1e-7, 'abs', 'ANALYTIC', cite, 'Quantity', 'A_lat', 'Unit', 'SI');
            tc.verifyTol(lin.lon.B, Blon, 1e-9, 'abs', 'ANALYTIC', cite, 'Quantity', 'B_lon', 'Unit', 'SI');
            tc.verifyTol(lin.lat.B, Blat, 1e-9, 'abs', 'ANALYTIC', cite, 'Quantity', 'B_lat', 'Unit', 'SI');
        end

        function eigenvaluesClosedForm(tc)
            tc.assertEqual(tc.Trim.status, 'OK', tc.Trim.reason);
            lin = vital.linear.linearize(tc.AC, tc.Env, tc.Trim);
            [clon, clat] = quartics(tc.P);
            rl = roots(clon); rt = roots(clat);
            cite = 'roots of the hand-written characteristic quartics (class header 5)';
            tc.verifyTol(matchRoots(eig(lin.lon.A), rl), zeros(4, 1), 1e-8, 'abs', 'ANALYTIC', cite, ...
                'Quantity', 'eig(A_lon) - closed form', 'Unit', '1/s');
            tc.verifyTol(matchRoots(eig(lin.lat.A), rt), zeros(4, 1), 1e-8, 'abs', 'ANALYTIC', cite, ...
                'Quantity', 'eig(A_lat) - closed form', 'Unit', '1/s');
            tc.verifyTol(matchRoots(eig(lin.A(1:8, 1:8)), [rl; rt]), zeros(8, 1), 1e-8, 'abs', 'ANALYTIC', cite, ...
                'Quantity', 'eig(A(1:8,1:8)) - closed form', 'Unit', '1/s');
            md = vital.linear.modes(lin);
            pl = rl(imag(rl) > 0); [~, i] = sort(abs(pl), 'descend'); pl = pl(i);
            rr = rt(abs(imag(rt)) < 1e-12); [~, i] = sort(abs(rr), 'descend'); rr = real(rr(i));
            want = struct('short_period', pl(1), 'phugoid', pl(2), 'dutch_roll', rt(imag(rt) > 0), ...
                'roll', rr(1), 'spiral', rr(2));
            for f = fieldnames(want).'
                k = find(strcmp({md.name}, f{1}));
                tc.assertNumElements(k, 1, sprintf('vital.linear.modes must name exactly one %s mode', f{1}));
                tc.verifyTol(abs(md(k).eigenvalue - want.(f{1})), 0, 1e-8, 'abs', 'ANALYTIC', cite, ...
                    'Quantity', [f{1} ' eigenvalue (vital.linear.modes) - closed form'], 'Unit', '1/s');
            end
        end
    end
end

function [Alon, Alat, Blon, Blat] = handMatrices(P)
a = P.a; g = P.g; th = P.theta_e; U = P.Ue; W = P.We;
Alon = [a.Xu, a.Xw, a.Xq - W, -g * cos(th);
        a.Zu, a.Zw, a.Zq + U, -g * sin(th);
        a.Mu, a.Mw, a.Mq,     0;
        0,    0,    1,        0];
D = P.Ixx * P.Izz - P.Ixz^2;
L = P.Ixx * [a.Lv a.Lp a.Lr a.Lda a.Ldr];
N = P.Izz * [a.Nv a.Np a.Nr a.Nda a.Ndr];
Lp = (P.Izz * L + P.Ixz * N) / D;           % primed derivatives
Np = (P.Ixz * L + P.Ixx * N) / D;
Alat = [a.Yv,  a.Yp + W, a.Yr - U, g * cos(th);
        Lp(1), Lp(2),    Lp(3),    0;
        Np(1), Np(2),    Np(3),    0;
        0,     1,        tan(th),  0];
% inputs [de da dr throttle]
Blon = [a.Xde 0 0 a.Xt; a.Zde 0 0 a.Zt; a.Mde 0 0 a.Mt; 0 0 0 0];
Blat = [0 a.Yda a.Ydr 0; 0 Lp(4) Lp(5) 0; 0 Np(4) Np(5) 0; 0 0 0 0];
end

function [clon, clat] = quartics(P)
% the characteristic quartics written out (class header 5), NOT poly()/det()
[Alon, Alat] = handMatrices(P);
a = Alon(1, 1); b = Alon(1, 2); c = Alon(1, 3); d = Alon(1, 4);
e = Alon(2, 1); f = Alon(2, 2); g = Alon(2, 3); h = Alon(2, 4);
i = Alon(3, 1); j = Alon(3, 2); k = Alon(3, 3);
clon = [1, -(a + f + k), a*f - b*e + a*k - c*i + f*k - g*j, ...
    -(a*(f*k - g*j) - b*(e*k - g*i) + c*(e*j - f*i) + d*i + h*j), a*h*j - b*h*i - d*(e*j - f*i)];
a = Alat(1, 1); b = Alat(1, 2); c = Alat(1, 3); d = Alat(1, 4);
e = Alat(2, 1); f = Alat(2, 2); g = Alat(2, 3);
i = Alat(3, 1); j = Alat(3, 2); k = Alat(3, 3); t = Alat(4, 3);
clat = [1, -(a + f + k), a*f - b*e + a*k - c*i + f*k - g*j, ...
    -(a*(f*k - g*j) - b*(e*k - g*i) + c*(e*j - f*i) + d*e + d*i*t), -d*(e*(j*t - k) - f*i*t + g*i)];
end

function e = matchRoots(a, b)
% |a_k - nearest unused b| for every a_k (greedy pairing of two root sets)
a = a(:); b = b(:); e = zeros(numel(a), 1);
for k = 1:numel(a)
    [e(k), j] = min(abs(b - a(k)));
    b(j) = [];
end
end

function [r, dde, dt] = offDesignResidual(P, V, al)
% level flight at V, q = 0, theta = alpha: X and M give (dde, dt) by Cramer's rule;
% r is the remaining Z residual (m/s^2), class header 3
a = P.a; g = P.g;
du = V * cos(al) - P.Ue; dw = V * sin(al) - P.We;
bx = -(P.Xe / P.m_kg + a.Xu * du + a.Xw * dw - g * sin(al));
bm = -(P.Me / P.Iyy + a.Mu * du + a.Mw * dw);
det2 = a.Xde * a.Mt - a.Xt * a.Mde;
dde = (bx * a.Mt - a.Xt * bm) / det2;
dt = (a.Xde * bm - bx * a.Mde) / det2;
r = P.Ze / P.m_kg + a.Zu * du + a.Zw * dw + a.Zde * dde + a.Zt * dt + g * cos(al);
end

function Jr = trimJacobian(P, V, al)
% d [udot/g; wdot/g; qdot] / d [alpha; de; throttle] in level flight, q = 0
a = P.a; g = P.g;
dudal = -V * sin(al); dwdal = V * cos(al);
Jr = [(a.Xu * dudal + a.Xw * dwdal - g * cos(al)) / g, a.Xde / g, a.Xt / g;
      (a.Zu * dudal + a.Zw * dwdal - g * sin(al)) / g, a.Zde / g, a.Zt / g;
      a.Mu * dudal + a.Mw * dwdal,                     a.Mde,     a.Mt];
end
