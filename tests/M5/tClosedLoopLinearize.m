classdef (TestTags = {'M5'}) tClosedLoopLinearize < vital.test.VitalTestCase
%TCLOSEDLOOPLINEARIZE  M5-X / M7-facing: closed-loop linearization with a static
%   controller (vital.linear.linearize(..., 'Controller', c)).
%
%   Controller: the M5-B struct {rate_hz, init, step}, with
%   [u, state] = step(t, x, y, u_ref, state). It follows the vital.sim.run
%   semantics:
%     - x is the 13-state plant state
%     - y is the plant output at (x, u_ref)
%     - u_ref = the trim controls u0
%     - t = 0 and state = init (or init(x0, u0) for a function handle)
%   The closed loop is f(x_lin, u_ref) = plant(x, u(x, u_ref)).
%   Only STATIC controllers are supported, and a controller must declare it with
%   c.static = true. Every call is also checked: the returned state must equal
%   the initial state (isequal). Otherwise vital:linear:dynamicController. A
%   dynamic controller is never linearized as static.
%   The controller output at the trim must equal u0 (1e-9), otherwise the trim
%   is not a closed-loop equilibrium: vital:linear:controllerNotAtTrim.
%   The ZOH sampling delay is not modelled (continuous approximation).
%
%   PRE-REGISTERED checks (written before the implementation existed):
%   1. Linear state feedback u = u_ref + K (x_lin - x0), with a fixed K acting on
%      q, theta, u, p, r, phi, beta-like v (ANALYTIC):
%        lin.K = K and lin.Kref = I (1e-8 abs; the controller is exactly linear)
%        lin.A = lin.open.A + lin.open.B K, and lin.B = lin.open.B, entrywise
%        within 2e-6 FScale(row)/ZScale(col). These are two independent
%        step-study estimates, each within 1e-6 in these units (tF16Linearize).
%   2. y path: de = de_ref + Ka (y.alpha - alpha0). The controller reads alpha
%      from y, and at zero wind alpha = atan2(w, u), so K(de, u) = -Ka w0/V^2
%      and K(de, w) = Ka u0/V^2, other entries 0. The K check is 1e-8 abs;
%      A = A_open + B_open K is checked as in 1.
%   3. A controller that returns u_ref, ignoring x and y: lin.K = 0 exactly,
%      lin.A = lin.open.A within 1e-12 of the entry scale.
%   4. Pitch damper. CONVENTIONS 7: +de (TED) gives a nose-down moment
%      (Cm_de < 0). Opposing a nose-up rate q > 0 needs +de, so de = de_ref + Kq q
%      with Kq > 0 adds damping. REG: zeta_sp(Kq = -0.2) < zeta_sp(0)
%      < zeta_sp(+0.2), with Kq in rad per rad/s; all three short periods
%      oscillatory with status OK.
%   5. Refusals:
%        no 'static' field, or static = true but the state changes (always, or only
%        away from the trim)  -> vital:linear:dynamicController
%        u(x0) ~= u0          -> vital:linear:controllerNotAtTrim
%        missing step/rate_hz, output of the wrong size -> vital:badInput

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

    methods (Static, Access = private)
        function xl = xlin(x)
            % the test's own 13-state -> x_lin map
            xl = [x(1:6); vital.frames.dcm2eul(vital.frames.quat2dcm(x(7:10))); x(11); x(12); -x(13)];
        end

        function c = feedback(K, x0)
            c = struct('rate_hz', 100, 'init', 0, 'static', true, ...
                'step', @(t, x, y, uref, s) deal(uref + K * (tClosedLoopLinearize.xlin(x) - x0), s));
        end
    end

    methods (Access = private)
        function x0 = x0lin(tc)
            x0 = tClosedLoopLinearize.xlin(tc.tr.x);
        end

        function verifyAcl(tc, lin, K, label)
            V = tc.tr.y.V; g = tc.env.g;
            fs = [g g g 1 1 1 1 1 1 V V V].';
            tol = 2e-6 * fs ./ tc.ZSCALE(1:12);
            E = lin.open.A + lin.open.B * K;
            tc.verifyTrue(all(abs(lin.A - E) <= tol, 'all'), ...
                sprintf('%s: A_cl = A + B K within 2e-6 FScale/ZScale (max weighted error %.3g)', label, ...
                max(abs(lin.A - E) ./ tol, [], 'all') * 2e-6));
            tc.verifyTol(max(abs(lin.A - E) ./ tol, [], 'all'), 0, 1, 'abs', 'ANALYTIC', ...
                'A_cl = A_open + B_open K (header check 1)', 'Quantity', [label ' A_cl error / tolerance']);
        end
    end

    methods (Test)
        function stateFeedbackGivesAPlusBK(tc)
            K = zeros(4, 12);
            K(1, [1 5 8]) = [0.002 0.3 -0.5];      % de on u, q, theta
            K(2, [2 4 7]) = [0.01 0.2 0.4];        % da on v, p, phi
            K(3, [2 6]) = [-0.01 0.5];             % dr on v, r
            K(4, [1 12]) = [-0.02 -1e-4];          % throttle on u, h
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', tClosedLoopLinearize.feedback(K, tc.x0lin()));
            tc.assertEqual(lin.status, 'OK', lin.reason);
            tc.verifyTol(lin.K, K, 1e-8, 'abs', 'ANALYTIC', 'controller input Jacobian of a linear law', 'Quantity', 'K');
            tc.verifyTol(lin.Kref, eye(4), 1e-8, 'abs', 'ANALYTIC', 'u = u_ref + ...: du/du_ref = I', 'Quantity', 'Kref');
            tc.verifyAcl(lin, K, 'state feedback');
            V = tc.tr.y.V; g = tc.env.g; fs = [g g g 1 1 1 1 1 1 V V V].';
            tc.verifyTol(max(abs(lin.B - lin.open.B) ./ (2e-6 * fs ./ tc.ZSCALE(13:16)), [], 'all'), 0, 1, 'abs', 'ANALYTIC', ...
                'B_cl = B_open Kref = B_open', 'Quantity', 'B_cl error / tolerance');
        end

        function controllerReadsYAtReferenceCommand(tc)
            Ka = 0.8; a0 = tc.tr.alpha; u0 = tc.tr.x(1); w0 = tc.tr.x(3); V = norm(tc.tr.x(1:3));
            c = struct('rate_hz', 50, 'init', [], 'static', true, ...
                'step', @(t, x, y, uref, s) deal(uref + [Ka * (y.alpha - a0); 0; 0; 0], s));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            K = zeros(4, 12); K(1, 1) = -Ka * w0 / V^2; K(1, 3) = Ka * u0 / V^2;
            tc.verifyTol(lin.K, K, 1e-8, 'abs', 'ANALYTIC', 'alpha = atan2(w, u) read from y (zero wind)', 'Quantity', 'K via y');
            tc.verifyAcl(lin, K, 'y feedback');
        end

        function inertControllerGivesOpenLoop(tc)
            c = struct('rate_hz', 100, 'init', 0, 'static', true, 'step', @(t, x, y, uref, s) deal(uref, s));
            lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c);
            tc.assertEqual(lin.status, 'OK', lin.reason);
            tc.verifyExact(lin.K, zeros(4, 12), 'ANALYTIC', 'output independent of x', 'Quantity', 'K');
            tc.verifyTol(lin.A, lin.open.A, 1e-12 * max(abs(lin.open.A(:))), 'abs', 'ANALYTIC', ...
                'no feedback: closed loop = open loop', 'Quantity', 'A_cl - A');
        end

        function pitchDamperAddsShortPeriodDamping(tc)
            z = zeros(1, 3); Kq = [-0.2 0 0.2];
            for k = 1:3
                K = zeros(4, 12); K(1, 5) = Kq(k);
                lin = vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', tClosedLoopLinearize.feedback(K, tc.x0lin()));
                tc.assertEqual(lin.status, 'OK', lin.reason);
                m = vital.linear.modes(lin);
                sp = m(strcmp({m.name}, 'short_period'));
                tc.assertNumElements(sp, 1, sprintf('Kq = %g', Kq(k)));
                tc.assertEqual(sp.status, 'OK');
                z(k) = sp.zeta;
            end
            tc.verifyWithin(z(2) - z(1), 0, Inf, 'REG', 'CONVENTIONS 7: de = +Kq q damps (header check 4)', 'Quantity', 'zeta(0) - zeta(-0.2)');
            tc.verifyWithin(z(3) - z(2), 0, Inf, 'REG', 'CONVENTIONS 7: de = +Kq q damps (header check 4)', 'Quantity', 'zeta(+0.2) - zeta(0)');
            % the registered ordering is STRICT (verifyWithin admits equality; added after
            % sabotage S5L-6 showed an ignored controller gave equal zetas and passed)
            tc.verifyGreaterThan(z(2), z(1), 'zeta(0) > zeta(-0.2) strictly (header check 4)');
            tc.verifyGreaterThan(z(3), z(2), 'zeta(+0.2) > zeta(0) strictly (header check 4)');
        end

        function dynamicControllerRefused(tc)
            base = struct('rate_hz', 100, 'init', 0, 'step', @(t, x, y, uref, s) deal(uref, s));
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', base), 'vital:linear:dynamicController');
            c = base; c.static = true; c.step = @(t, x, y, uref, s) deal(uref, s + 1);
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:linear:dynamicController');
            q0 = tc.tr.x(5);
            c.step = @(t, x, y, uref, s) deal(uref, s + (x(5) - q0));    % integrates q: unchanged at the trim only
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:linear:dynamicController');
        end

        function controllerNotAtTrimRefused(tc)
            c = struct('rate_hz', 100, 'init', 0, 'static', true, 'step', @(t, x, y, uref, s) deal(uref + [0.01; 0; 0; 0], s));
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:linear:controllerNotAtTrim');
        end

        function badControllerRefused(tc)
            c = struct('rate_hz', 100, 'init', 0, 'static', true);
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:badInput');
            c = struct('init', 0, 'static', true, 'step', @(t, x, y, uref, s) deal(uref, s));
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:badInput');
            c = struct('rate_hz', 100, 'init', 0, 'static', true, 'step', @(t, x, y, uref, s) deal(uref(1:3), s));
            tc.verifyError(@() vital.linear.linearize(tc.AC, tc.env, tc.tr, 'Controller', c), 'vital:badInput');
        end
    end
end
