classdef (TestTags = {'M5'}) tModesR1 < vital.test.VitalTestCase
%TMODESR1  Review R1 findings for vital.linear.modes and run_f16_modes:
%   M3, M5, M11 and MINOR 5.
%
%   PRE-REGISTERED (before the fixes). Synthetic systems are built as in tModes:
%   real Jordan blocks in known state subspaces, mixed inside the subspace.
%   M3  (a) SP -2 +/- 3i in (w, q), phugoid real roots -0.05 and +0.01 in (u, theta):
%           short_period OK; two phugoid entries NOT_OSCILLATORY with wn, zeta NaN
%       (b) Dutch roll diag(-0.8, -0.2) in (v, r), roll -3.5, spiral +0.02: two
%           dutch_roll entries NOT_OSCILLATORY; roll and spiral OK
%       (c) four real longitudinal roots, SP diag(-3, -1.5), phugoid
%           diag(-0.05, 0.01): all four NOT_OSCILLATORY (fastest two
%           short_period, slowest two phugoid)
%       (d) Jordan block [-1 1; 0 -1] in (w, q) (defective): every mode
%           UNCLASSIFIED, reason 'ill-conditioned'
%       These branches already exist, so the tests guard them; R1-L5..L8 must
%       now be detected.
%   MINOR 5  A split short period next to a longitudinal pair with p_w + p_q > 0.2
%       (R1: the coupled 'third oscillatory mode', wn 0.15-0.21 at aft CG).
%       The pair keeps the name phugoid and status OK, but its reason must say
%       'third oscillatory'. Fixtures, chosen on the pre-fix code:
%         - fixture 2: pair w+q = 0.415, note expected
%         - fixture 3: pair w+q = 0.000, no note
%   M11 At the README trim, REG approximation checks:
%       roll    tau_R * (-L_p') = 1 within 5 %, with L_p' = A(p,p). R1: 0.329 vs 0.338 s.
%       spiral  tau_S = a1/a0 of the lateral characteristic polynomial
%               (4x4 lat partition, s^4 + a3 s^3 + a2 s^2 + a1 s + a0), within 2 %.
%               R1: 99.3 vs 98.8 s.
%       REG lock of the README mode table: Re and Im of every eigenvalue within
%       1e-6 relative of the values of the 2026-09-29 GREEN code:
%         short_period  -1.13128582323 + 2.23324129327i
%         phugoid       -0.00710729354625 + 0.0744668906634i   (8 states)
%         dutch_roll    -0.388746143721 + 3.29552399195i
%         roll          -2.95636525857
%         spiral        -0.0101167381913
%   M5  The default modes stay 8-state (contract), but run_f16_modes also
%       reports the phugoid with altitude coupling:
%         - r.modesHeight = modes(lin, 'IncludeHeight', true) when column 12 is OK
%         - the printout contains 'phugoid (with h)' and 'height'
%       At 20,000 ft (h column on a table breakpoint, M1): r.status NOT_CONVERGED,
%       the 8-state modes present, r.modesHeight empty, and the printout says so.

    properties (Constant)
        LON = [1 3 5 8]
        LAT = [2 4 6 7]
    end

    methods (Static, Access = private)
        function A = place(A, idx, M, T)
            A(idx, idx) = T * M / T;
        end

        function M = rj(s, w)
            M = [s w; -w s];
        end

        function A = build(sp, ph, dr)
            A = zeros(8);
            A = tModesR1.place(A, [3 5], sp, [1 0.4; -0.3 1]);
            A = tModesR1.place(A, [1 8], ph, [1 -0.5; 0.2 1]);
            A = tModesR1.place(A, [2 6], dr, [1 0.3; 0.6 1]);
            A(4, 4) = -3.5; A(7, 7) = 0.02;
        end

        function A = thirdOscFixture(S)
            L = blkdiag([-0.1 0.2; -0.2 -0.1], -2.5, 0.3);
            A = zeros(8); A(tModesR1.LON, tModesR1.LON) = S * L / S;
            A([2 6], [2 6]) = [1 0.3; 0.6 1] * [-0.3 2.5; -2.5 -0.3] / [1 0.3; 0.6 1];
            A(4, 4) = -3.5; A(7, 7) = 0.02;
        end

        function m = modesOf(A8)
            m = vital.linear.modes(struct('A', blkdiag(A8, zeros(4)), 'status', 'OK'));
        end

        function e = byName(m, name)
            e = m(strcmp({m.name}, name));
        end
    end

    methods (Test)
        function splitPhugoidIsNotOscillatory(tc)
            m = tModesR1.modesOf(tModesR1.build(tModesR1.rj(-2, 3), diag([-0.05 0.01]), tModesR1.rj(-0.3, 2.5)));
            sp = tModesR1.byName(m, 'short_period'); ph = tModesR1.byName(m, 'phugoid');
            tc.assertNumElements(sp, 1); tc.assertNumElements(ph, 2);
            tc.verifyEqual(sp.status, 'OK');
            tc.verifyExact({ph.status}, {'NOT_OSCILLATORY', 'NOT_OSCILLATORY'}, 'ANALYTIC', 'split phugoid (M3a)', 'Quantity', 'phugoid status');
            tc.verifyTrue(all(isnan([ph.wn])) && all(isnan([ph.zeta])), 'no frequency or damping for real roots');
            tc.verifyTol(sort(real([ph.eigenvalue])), [-0.05 0.01], 1e-9, 'abs', 'ANALYTIC', 'placed roots', 'Quantity', 'phugoid roots');
        end

        function splitDutchRollIsNotOscillatory(tc)
            m = tModesR1.modesOf(tModesR1.build(tModesR1.rj(-2, 3), tModesR1.rj(-0.01, 0.08), diag([-0.8 -0.2])));
            dr = tModesR1.byName(m, 'dutch_roll');
            tc.assertNumElements(dr, 2);
            tc.verifyExact({dr.status}, {'NOT_OSCILLATORY', 'NOT_OSCILLATORY'}, 'ANALYTIC', 'split Dutch roll (M3b)', 'Quantity', 'DR status');
            tc.verifyTol(sort(real([dr.eigenvalue])), [-0.8 -0.2], 1e-9, 'abs', 'ANALYTIC', 'placed roots', 'Quantity', 'DR roots');
            r = tModesR1.byName(m, 'roll'); s = tModesR1.byName(m, 'spiral');
            tc.assertNumElements(r, 1); tc.assertNumElements(s, 1);
            tc.verifyEqual({r.status, s.status}, {'OK', 'OK'});
            tc.verifyTol([r.eigenvalue s.eigenvalue], [-3.5 0.02], 1e-9, 'abs', 'ANALYTIC', 'placed roots', 'Quantity', 'roll, spiral');
        end

        function fourRealLongitudinalRoots(tc)
            m = tModesR1.modesOf(tModesR1.build(diag([-3 -1.5]), diag([-0.05 0.01]), tModesR1.rj(-0.3, 2.5)));
            sp = tModesR1.byName(m, 'short_period'); ph = tModesR1.byName(m, 'phugoid');
            tc.assertNumElements(sp, 2); tc.assertNumElements(ph, 2);
            tc.verifyExact(unique([{sp.status}, {ph.status}]), {'NOT_OSCILLATORY'}, 'ANALYTIC', ...
                'all longitudinal roots real (M3c)', 'Quantity', 'lon statuses');
            tc.verifyTol(sort(real([sp.eigenvalue])), [-3 -1.5], 1e-9, 'abs', 'ANALYTIC', 'fastest two', 'Quantity', 'SP roots');
            tc.verifyTol(sort(real([ph.eigenvalue])), [-0.05 0.01], 1e-9, 'abs', 'ANALYTIC', 'slowest two', 'Quantity', 'phugoid roots');
        end

        function defectiveEigenvectorsAreUnclassified(tc)
            A = tModesR1.build(tModesR1.rj(-2, 3), tModesR1.rj(-0.01, 0.08), tModesR1.rj(-0.3, 2.5));
            A([3 5], [3 5]) = [-1 1; 0 -1];
            m = tModesR1.modesOf(A);
            tc.verifyExact(unique({m.status}), {'UNCLASSIFIED'}, 'ANALYTIC', 'defective matrix (M3d)', 'Quantity', 'statuses');
            tc.verifySubstring(m(1).reason, 'ill-conditioned');
        end

        function thirdOscillatoryModeIsNoted(tc)
            S2 = [1 0 0.3 0.3; 2 1 1 0.2; 1 2 0.2 1; 0.3 1 0.1 0.1];
            S3 = [1 0 0 0; 1 1 1 0.3; 1 1 0.3 1; 0.5 1 0 0];
            m = tModesR1.modesOf(tModesR1.thirdOscFixture(S2));
            ph = tModesR1.byName(m, 'phugoid'); sp = tModesR1.byName(m, 'short_period');
            tc.assertNumElements(ph, 1); tc.assertNumElements(sp, 2);
            tc.verifyGreaterThan(ph.participation(3) + ph.participation(5), 0.2, 'fixture 2: pair w+q > 0.2');
            tc.verifyEqual(ph.status, 'OK');
            tc.verifySubstring(ph.reason, 'third oscillatory');
            m = tModesR1.modesOf(tModesR1.thirdOscFixture(S3));
            ph = tModesR1.byName(m, 'phugoid');
            tc.assertNumElements(ph, 1);
            tc.verifyTrue(~contains(ph.reason, 'third oscillatory'), 'fixture 3: pure (u, theta) pair, no note');
        end

        function rollAndSpiralMatchClassicalApproximations(tc)
            r = run_f16_modes();
            tc.assertEqual(r.status, 'OK');
            ro = tModesR1.byName(r.modes, 'roll'); sp = tModesR1.byName(r.modes, 'spiral');
            tc.verifyWithin(ro.tau * (-r.lin.A(4, 4)) - 1, -0.05, 0.05, 'REG', ...
                'roll tau ~ -1/L_p'' (M11; R1 0.329 vs 0.338 s)', 'Quantity', 'roll tau / (-1/Lp'') - 1');
            a = poly(r.lin.lat.A);                       % [1 a3 a2 a1 a0]
            tc.verifyWithin(sp.tau / (a(4) / a(5)) - 1, -0.02, 0.02, 'REG', ...
                'spiral tau ~ a1/a0 of the lateral characteristic polynomial (M11; R1 99.3 vs 98.8 s)', ...
                'Quantity', 'spiral tau / (a1/a0) - 1');
        end

        function readmeModeTableLock(tc)
            r = run_f16_modes();
            lock = {'short_period', -1.13128582323, 2.23324129327;
                    'phugoid', -0.00710729354625, 0.0744668906634;
                    'dutch_roll', -0.388746143721, 3.29552399195;
                    'roll', -2.95636525857, 0;
                    'spiral', -0.0101167381913, 0};
            for k = 1:size(lock, 1)
                e = tModesR1.byName(r.modes, lock{k, 1});
                tc.assertNumElements(e, 1);
                c = 'REG lock of the 2026-09-29 GREEN mode table (M11)';
                tc.verifyTol(real(e.eigenvalue), lock{k, 2}, 1e-6, 'rel', 'REG', c, 'Quantity', [lock{k, 1} ' Re']);
                if lock{k, 3} ~= 0
                    tc.verifyTol(imag(e.eigenvalue), lock{k, 3}, 1e-6, 'rel', 'REG', c, 'Quantity', [lock{k, 1} ' Im']);
                end
            end
        end

        function entryPointReportsPhugoidWithHeight(tc)
            r = run_f16_modes();
            tc.assertTrue(isfield(r, 'modesHeight'), 'R1 M5: run_f16_modes returns modesHeight');
            tc.assertNotEmpty(r.modesHeight);
            ref = vital.linear.modes(r.lin, 'IncludeHeight', true);
            p1 = tModesR1.byName(r.modesHeight, 'phugoid'); p2 = tModesR1.byName(ref, 'phugoid');
            tc.assertNumElements(p1, 1);
            tc.verifyExact([real(p1.eigenvalue) imag(p1.eigenvalue)], [real(p2.eigenvalue) imag(p2.eigenvalue)], 'ANALYTIC', 'r.modesHeight = modes(lin, IncludeHeight)', ...
                'Quantity', 'phugoid with h');
            tc.verifyNumElements(tModesR1.byName(r.modesHeight, 'height'), 1);
            txt = evalc('run_f16_modes');
            tc.verifySubstring(txt, 'phugoid (with h)');
            tc.verifySubstring(txt, 'height');
        end

        function entryPointAtBreakpointAltitude(tc)
            r = run_f16_modes(565.6854, 20000);
            tc.assertTrue(isfield(r, 'modesHeight'), 'R1 M5: run_f16_modes returns modesHeight');
            tc.verifyEqual(r.status, 'NOT_CONVERGED');
            tc.verifyExact(sort({r.modes.name}), sort({'short_period','phugoid','dutch_roll','roll','spiral'}), ...
                'ANALYTIC', 'the 8-state modes do not use column 12 (M1)', 'Quantity', 'modes at 20,000 ft');
            tc.verifyEmpty(r.modesHeight, 'no height modes without column 12');
            txt = evalc('run_f16_modes(565.6854, 20000)');
            tc.verifySubstring(txt, 'column 12 (h)');
            tc.verifySubstring(txt, 'not available');
        end
    end
end
