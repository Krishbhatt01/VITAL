classdef (TestTags = {'M5'}) tLinearVsNonlinear < vital.test.VitalTestCase
%TLINEARVSNONLINEAR  M5-X: the linear F-16 model against the nonlinear plant
%   (INDEP: two independent code paths).
%   - Nonlinear: vital.sim.run (RK4, M5-B) of vital.plant.derivatives.
%   - Linear: dx(t) = expm(A t) dx0 (vital.linear.response) with the step-study
%     A of vital.linear.linearize.
%
%   Trim: NESC README condition (565.6854 ft/s, 10,013 ft, CG 25 % MAC, g = 32.174
%   ft/s^2, heading 0). Initial states: vital.linear.toPlantState(lin, dx0).
%   Nonlinear states are mapped back with vital.linear.fromPlantState.
%
%   Cases (perturbation of x_lin, window, step):
%     SP   dw = -1.5 m/s (d alpha = -0.50 deg), 6 s, dt 0.01; half amplitude -0.75 m/s
%     PH   du = +1.0 m/s, 90 s, dt 0.05 (about one period); half amplitude 0.5 m/s.
%          du > 0 keeps h >= h0: linear phugoid h = h0 + (V du/g)(1 - cos wt).
%          The NESC thrust tables have an altitude breakpoint at 10,000 ft, 3.96 m
%          BELOW the trim; a crossing would add a first-order (kink) error.
%     LAT  dv = +1.5 m/s (d beta = 0.50 deg), dp = +2 deg/s, 10 s, dt 0.01; half amplitude
%   Cost measured first: 1 ms per plant call, 4 calls per RK4 step, 6 runs,
%   about 27 s in total.
%
%   PRE-REGISTERED criteria (written before any nonlinear run was made):
%   1. Relative discrepancy rel_i = max_t |dx_nl,i - dx_lin,i| / max_t |dx_lin,i|
%      at the base amplitude:
%        SP channels w q theta, PH channels u theta h: rel < 2e-2
%        LAT channels v p r phi: rel < 1e-2
%   2. Amplitude scaling (the stronger test). For a correct linearization the
%      discrepancy is the Taylor remainder, and the step-study, RK4 (dt^4) and
%      expm floors are < 1e-5 of the response.
%        LON (SP, PH): the remainder is O(a^2), so the RELATIVE discrepancy halves
%          when the amplitude halves: rel(a) / rel(a/2) in [1.6, 2.4].
%        LAT: the NESC model is mirror-symmetric (CY, Cl, Cn odd in beta, p, r, da,
%          dr; CX, CZ, Cm even; Ixy = Iyz = 0). The lateral derivatives therefore
%          have no terms quadratic in the lateral states and none in the
%          longitudinal states alone. The lat-lon cross terms are
%          O(a * a^2), so the relative lateral discrepancy is O(a^2):
%          rel(a) / rel(a/2) in [3.2, 4.8].
%      A wrong A entry of relative size e gives a floor ~e that does not scale,
%      and the ratio falls towards 1.
%   3. Symmetry: in the SP case, v, p, r, phi of the nonlinear run stay 0
%      (|.| <= 1e-12; ANALYTIC, symmetric aircraft, symmetric perturbation).
%   4. Dominant mode of the NONLINEAR signal vs vital.linear.modes. The estimator
%      is a matrix pencil (sum-of-exponentials fit, SVD order 6), independent of
%      the linear model. The fitted complex root with the largest amplitude is
%      taken, from: q for SP, u for PH, v for DR.
%      Why not zero crossings or log decrement of raw q: the linear model shows
%      phugoid content of 3 % in q at t = 0, which is 5-15 % of the SP amplitude
%      by the 2nd extremum. The pencil separates the modes instead.
%        SP, DR: wd within 1 %, sigma within 2 % of modes(lin) (8 states)
%        PH:     wd within 1 %, sigma within 5 % of modes(lin, 'IncludeHeight', true)
%      Height coupling (measured on the LINEAR model before this file was
%      written): the 8-state model has no altitude. Density and thrust vary with
%      h, and including h moves the phugoid from -0.0071 +/- 0.0745i to
%      -0.0062 +/- 0.0801i and adds a height mode at -0.0016 1/s. REG expectation:
%      the 8-state modes(lin) phugoid wd differs from the nonlinear estimate by
%      5 to 10 %.
%      Secondary check: DR wd from the mean zero-crossing spacing of v on
%      [1, 6] s is within 3 %.
%   5. Mapping (ANALYTIC): fromPlantState(toPlantState(dx)) = dx to 1e-12;
%      toPlantState puts h into p_n(3) = -(h0 + dh); response(lin, dx0, t) equals
%      expm(A t) dx0 (1e-9 relative).

    properties
        AC
        env
        tr
        lin
        Ft = 0.3048
    end

    methods (TestClassSetup)
        function trimAndLinearize(tc)
            tc.AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
            tc.env = struct('g', 32.174 * tc.Ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
            cond = struct('type', 'level', 'V', 565.6854 * tc.Ft, 'h', 10013 * tc.Ft, 'gamma', 0, 'psi', 0);
            tc.tr = vital.trim.solve(tc.AC, tc.env, cond);
            tc.assertEqual(tc.tr.status, 'OK');
            tc.lin = vital.linear.linearize(tc.AC, tc.env, tc.tr);
            tc.assertEqual(tc.lin.status, 'OK');
        end
    end

    methods (Access = private)
        function [dn, dl, t, X] = pair(tc, dx0, dt, T)
            x0 = vital.linear.toPlantState(tc.lin, dx0);
            out = vital.sim.run(tc.AC, tc.env, x0, tc.tr.u, 'dt', dt, 'tFinal', T);
            tc.assertEqual(out.status, 'COMPLETED', out.stopReason);
            t = out.t; X = out.x;
            dn = vital.linear.fromPlantState(tc.lin, X);
            dl = vital.linear.response(tc.lin, dx0, t);
        end

        function [dn1, t] = checkCase(tc, label, dx0, dt, T, ch, relMax, ratioBand)
            [dn1, dl1, t, X] = tc.pair(dx0, dt, T);
            [dn2, dl2] = tc.pair(dx0 / 2, dt, T);
            tc.assertGreaterThan(min(-X(13, :)), 10000 * tc.Ft + 0.5, ...
                'precondition: the run stays above the 10,000 ft thrust-table breakpoint');
            names = tc.lin.stateNames;
            for i = ch
                r1 = max(abs(dn1(i, :) - dl1(i, :))) / max(abs(dl1(i, :)));
                r2 = max(abs(dn2(i, :) - dl2(i, :))) / max(abs(dl2(i, :)));
                tc.verifyWithin(r1, 0, relMax, 'INDEP', ...
                    sprintf('%s: nonlinear sim vs expm(A t) (criterion 1)', label), ...
                    'Quantity', sprintf('%s rel discrepancy %s', label, names{i}));
                tc.verifyWithin(r1 / r2, ratioBand(1), ratioBand(2), 'INDEP', ...
                    sprintf('%s: discrepancy is the Taylor remainder (criterion 2)', label), ...
                    'Quantity', sprintf('%s amplitude ratio %s', label, names{i}));
            end
        end

        function checkMode(tc, lam, ref, wTol, sTol, label, src, cite)
            tc.verifyTol(imag(lam), imag(ref), wTol, 'rel', src, cite, 'Quantity', [label ' damped frequency'], 'Unit', 'rad/s');
            tc.verifyTol(real(lam), real(ref), sTol, 'rel', src, cite, 'Quantity', [label ' sigma'], 'Unit', '1/s');
        end
    end

    methods (Static, Access = private)
        function lam = pencil(y, dt, M)
            % matrix-pencil estimate: complex root (Im > 0) of largest amplitude
            y = y(:); N = numel(y); L = floor(N / 2);
            Y = hankel(y(1:N-L), y(N-L:N));
            [~, ~, Vv] = svd(Y, 'econ');
            Vm = Vv(:, 1:M);
            z = eig(pinv(Vm(1:end-1, :)) * Vm(2:end, :));
            Z = (z.') .^ ((0:N-1).');
            c = Z \ y;
            k = find(imag(z) > 0);
            [~, j] = max(abs(c(k)));
            lam = log(z(k(j))) / dt;
        end

        function tz = zeroCrossings(t, y)
            s = sign(y);
            k = find(s(1:end-1) .* s(2:end) < 0);
            tz = t(k) - y(k) .* (t(k+1) - t(k)) ./ (y(k+1) - y(k));
        end

        function e = byName(m, name)
            e = m(strcmp({m.name}, name));
        end
    end

    methods (Test)
        function mappingAndLinearResponse(tc)
            dx = [0.3 -0.2 0.5 0.01 -0.02 0.03 0.04 -0.01 0.05 12 -7 9].';
            x = vital.linear.toPlantState(tc.lin, dx);
            tc.verifyTol(x(13), -(tc.lin.x0(12) + 9), 1e-9, 'abs', 'ANALYTIC', 'p_n(3) = -h', 'Quantity', 'down position', 'Unit', 'm');
            tc.verifyTol(norm(x(7:10)), 1, 1e-14, 'abs', 'ANALYTIC', 'unit quaternion', 'Quantity', '|q|');
            tc.verifyTol(vital.linear.fromPlantState(tc.lin, x), dx, 1e-12, 'abs', 'ANALYTIC', ...
                'fromPlantState inverts toPlantState', 'Quantity', 'round trip');
            t = 0:0.05:3;
            DX = vital.linear.response(tc.lin, dx, t);
            for k = [1 21 61]
                e = expm(tc.lin.A * t(k)) * dx;
                tc.verifyTol(DX(:, k), e, 1e-9 * max(abs(e)), 'abs', 'ANALYTIC', 'dx(t) = expm(A t) dx0', ...
                    'Quantity', sprintf('response at t = %g s', t(k)));
            end
        end

        function shortPeriodCase(tc)
            dx0 = zeros(12, 1); dx0(3) = -1.5;
            [dn, t] = tc.checkCase('SP', dx0, 0.01, 6, [3 5 8], 2e-2, [1.6 2.4]);
            tc.verifyTol(max(max(abs(dn([2 4 6 7], :)))), 0, 1e-12, 'abs', 'ANALYTIC', ...
                'symmetric aircraft, symmetric perturbation: no lateral motion', 'Quantity', 'SP lateral states');
            lam = tLinearVsNonlinear.pencil(dn(5, :), t(2) - t(1), 6);
            sp = tLinearVsNonlinear.byName(vital.linear.modes(tc.lin), 'short_period');
            tc.checkMode(lam, sp.eigenvalue, 0.01, 0.02, 'SP', 'INDEP', ...
                'matrix pencil of nonlinear q(t) vs vital.linear.modes short period (criterion 4)');
        end

        function phugoidCase(tc)
            dx0 = zeros(12, 1); dx0(1) = 1.0;
            [dn, t] = tc.checkCase('PH', dx0, 0.05, 90, [1 8 12], 2e-2, [1.6 2.4]);
            lam = tLinearVsNonlinear.pencil(dn(1, 1:2:end), 2 * (t(2) - t(1)), 6);
            ph9 = tLinearVsNonlinear.byName(vital.linear.modes(tc.lin, 'IncludeHeight', true), 'phugoid');
            tc.assertNumElements(ph9, 1);
            tc.checkMode(lam, ph9.eigenvalue, 0.01, 0.05, 'PH', 'INDEP', ...
                'matrix pencil of nonlinear u(t) vs modes(lin, IncludeHeight) phugoid (criterion 4)');
            ph8 = tLinearVsNonlinear.byName(vital.linear.modes(tc.lin), 'phugoid');
            tc.verifyWithin(abs(imag(ph8.eigenvalue) / imag(lam) - 1), 0.05, 0.10, 'REG', ...
                '8-state phugoid lacks the height coupling (criterion 4, measured on the linear model)', ...
                'Quantity', '8-state phugoid wd bias');
        end

        function lateralCase(tc)
            dx0 = zeros(12, 1); dx0(2) = 1.5; dx0(4) = deg2rad(2);
            [dn, t] = tc.checkCase('LAT', dx0, 0.01, 10, [2 4 6 7], 1e-2, [3.2 4.8]);
            lam = tLinearVsNonlinear.pencil(dn(2, 1:2:end), 2 * (t(2) - t(1)), 6);
            dr = tLinearVsNonlinear.byName(vital.linear.modes(tc.lin), 'dutch_roll');
            tc.checkMode(lam, dr.eigenvalue, 0.01, 0.02, 'DR', 'INDEP', ...
                'matrix pencil of nonlinear v(t) vs vital.linear.modes Dutch roll (criterion 4)');
            w = t >= 1 & t <= 6;
            tz = tLinearVsNonlinear.zeroCrossings(t(w), dn(2, w));
            tc.verifyTol(pi / mean(diff(tz)), imag(dr.eigenvalue), 0.03, 'rel', 'INDEP', ...
                'zero-crossing spacing of nonlinear v(t) on [1, 6] s (criterion 4, secondary)', ...
                'Quantity', 'DR wd from zero crossings', 'Unit', 'rad/s');
        end
    end
end
