classdef (TestTags = {'M5'}) tClosedLoopR1 < vital.test.VitalTestCase
%TCLOSEDLOOPR1  Review R1 findings M9 (C1, C3) and ADR-026 for the closed-loop
%   linearization (vital.linear.linearize(..., 'Controller', c)).
%
%   ADR-026 semantics (continuous limit): the controller measures the plant under
%   the command actually applied, u = step(0, x, y(x, u), u_ref, state0). For y
%   fields that depend on u (nz) this is an algebraic loop, solved by Newton's
%   method on r(u) = u - step(x, y(x, u)). A loop that does not converge
%   gives vital:linear:algebraicLoop.
%
%   PRE-REGISTERED (written before the implementation of ADR-026 and M9):
%   M9  (C1) Prefilter u = u0 + 2 (u_ref - u0): Kref = 2 I (1e-8), K = 0 exactly,
%           lin.B = 2 open.B within 4e-6 FScale/ZScale (twice the per-estimate
%           accuracy of tClosedLoopLinearize, because the input step is doubled),
%           lin.A = open.A (1e-12 of the entry scale).
%       (C3) A kink in the controller at the trim, u = u_ref + [0.01 |q - q0|; 0; 0; 0]:
%           lin.status NOT_CONVERGED, reason mentions 'controller',
%           columnStatus{5} (q) is not OK.
%   ADR-026 nz feedback de = de_ref + Knz (y.nz - nz0), Knz = 0.05 rad/g.
%       Let g_x = d nz/d x_lin and g_de = d nz/d de, computed by the TEST as central
%       differences of the plant's y.nz with steps 1e-6. Then:
%         K(de,:) = Knz g_x / (1 - Knz g_de),  Kref(de,de) = 1 / (1 - Knz g_de)
%       These hold within 1e-6 of max |K| (ANALYTIC; both sides are finite
%       differences of a locally smooth plant).
%       With y at u_ref (the pre-ADR-026 semantics) the denominator would be
%       missing. g_de ~ 1.8 g/rad, so that is a ~10 % difference.
%       A_cl = open.A + open.B K within 2e-6 FScale/ZScale.
%   Refusal  u = u_ref - [0.01 sign(y.nz - nz0); 0; 0; 0] has no fixed point near
%       the trim (the sign flips once the command acts):
%       vital:linear:algebraicLoop.

    properties
        AC
        env
        tr
        Ft = 0.3048
    end

    properties (Constant)
        ZSCALE = [10 10 10 1 1 1 1 1 1 1000 1000 1000 0.1 0.1 0.1 1]
    end

    methods (TestClassSetup)
        function trimOnce(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
        end
    end

    methods (Access = private)
        function fs = fscale(tc)
            V = tc.tr.y.V; g = tc.env.g;
            fs = [g g g 1 1 1 1 1 1 V V V].';
        end

        function n = nzAt(tc, xl, u)
            x = [xl(1:6); vital.frames.eul2quat(xl(7), xl(8), xl(9)); xl(10); xl(11); -xl(12)];
            [~, y] = vital.plant.derivatives(x, u, tc.AC, tc.env);
            n = y.nz;
        end

        function xl = x0lin(tc)
            x = tc.tr.x;
            xl = [x(1:6); vital.frames.dcm2eul(vital.frames.quat2dcm(x(7:10))); x(11); x(12); -x(13)];
        end
    end

    methods (Test)
        function prefilterReferencePath(tc)
            u0 = tc.tr.u;
            c = struct('rate_hz', 100, 'init', 0, 'static', true, 'step', @(t, x, y, uref, s) deal(u0 + 2 * (uref - u0), s));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            tc.verifyTol(lin.Kref, 2 * eye(4), 1e-8, 'abs', 'ANALYTIC', 'u = u0 + 2 (u_ref - u0)', 'Quantity', 'Kref');
            tc.verifyExact(lin.K, zeros(4, 12), 'ANALYTIC', 'no state feedback', 'Quantity', 'K');
            tol = 4e-6 * tc.fscale() ./ tc.ZSCALE(13:16);
            tc.verifyTol(max(abs(lin.B - 2 * lin.open.B) ./ tol, [], 'all'), 0, 1, 'abs', 'ANALYTIC', ...
                'B_cl = open.B Kref = 2 open.B (M9, R1-C1)', 'Quantity', 'B_cl error / tolerance');
            tc.verifyTol(lin.A, lin.open.A, 1e-12 * max(abs(lin.open.A(:))), 'abs', 'ANALYTIC', 'no state feedback', 'Quantity', 'A_cl - A');
        end

        function controllerKinkIsReported(tc)
            q0 = tc.tr.x(5);
            c = struct('rate_hz', 100, 'init', 0, 'static', true, ...
                'step', @(t, x, y, uref, s) deal(uref + [0.01 * abs(x(5) - q0); 0; 0; 0], s));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.assertTrue(isfield(lin, 'columnStatus'), 'R1 M1: lin.columnStatus exists');
            tc.verifyEqual(lin.status, 'NOT_CONVERGED');
            tc.verifySubstring(lin.reason, 'controller');
            tc.verifyNotEqual(lin.columnStatus{5}, 'OK');
        end

        function nzFeedbackSolvesTheAlgebraicLoop(tc)
            Knz = 0.05; xl0 = tc.x0lin(); u0 = tc.tr.u;
            nz0 = tc.nzAt(xl0, u0);
            c = struct('rate_hz', 100, 'init', 0, 'static', true, ...
                'step', @(t, x, y, uref, s) deal(uref + [Knz * (y.nz - nz0); 0; 0; 0], s));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            h = 1e-6; gx = zeros(1, 12);
            for j = 1:12
                d = zeros(12, 1); d(j) = h;
                gx(j) = (tc.nzAt(xl0 + d, u0) - tc.nzAt(xl0 - d, u0)) / (2 * h);
            end
            du = [h; 0; 0; 0];
            gde = (tc.nzAt(xl0, u0 + du) - tc.nzAt(xl0, u0 - du)) / (2 * h);
            Kexp = zeros(4, 12); Kexp(1, :) = Knz * gx / (1 - Knz * gde);
            tc.verifyTol(lin.K, Kexp, 1e-6 * max(abs(Kexp(:))), 'abs', 'ANALYTIC', ...
                'ADR-026: u = step(x, y(x, u)) -> K = Knz g_x / (1 - Knz g_de)', 'Quantity', 'K (nz feedback)');
            tc.verifyTol(lin.Kref(1, 1), 1 / (1 - Knz * gde), 1e-6, 'abs', 'ANALYTIC', ...
                'ADR-026: du/du_ref = 1 / (1 - Knz g_de)', 'Quantity', 'Kref(de,de)');
            tc.verifyGreaterThan(Knz * gde, 0.05, 'fixture: the loop term is large enough to tell the semantics apart');
            tol = 2e-6 * tc.fscale() ./ tc.ZSCALE(1:12);
            tc.verifyTol(max(abs(lin.A - (lin.open.A + lin.open.B * lin.K)) ./ tol, [], 'all'), 0, 1, 'abs', 'ANALYTIC', ...
                'A_cl = A + B K', 'Quantity', 'nz A_cl error / tolerance');
        end

        function unsolvableLoopIsRefused(tc)
            nz0 = tc.nzAt(tc.x0lin(), tc.tr.u);
            c = struct('rate_hz', 100, 'init', 0, 'static', true, ...
                'step', @(t, x, y, uref, s) deal(uref - [0.01 * sign(y.nz - nz0); 0; 0; 0], s));
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:linear:algebraicLoop');
        end
    end
end
