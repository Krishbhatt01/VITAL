classdef (TestTags = {'M5'}) tModes < vital.test.VitalTestCase
%TMODES  M5-A: flight-mode eigen-analysis and classification (vital.linear.modes)
%   on synthetic 8-state systems whose modes are known exactly (ANALYTIC).
%
%   Construction (state order u v w p q r phi theta):
%     each mode is a real Jordan block placed in a known state subspace,
%       short period  (w, q)      phugoid (u, theta)
%       Dutch roll    (v, r)      roll    p          spiral phi
%     and mixed inside its subspace by a non-orthogonal 2x2 T (so the eigenvector
%     is not a unit vector and the participation products are complex);
%     a lon -> lat coupling block C (lat rows, lon columns) makes A block
%     lower-triangular: the eigenvalues are unchanged, the lon modes' LEFT
%     eigenvectors vanish on the lat states, so their participation there is
%     exactly 0, although their RIGHT eigenvectors have large lat components;
%     finally a diagonal unit change D = diag(1,100,1,100,1,100,100,1)
%     (A = D A0 inv(D)) makes the lat components of the raw eigenvectors of the
%     lon modes dominate. A classifier deciding lon/lat on raw eigenvector
%     magnitude (the AAMF StabilityAnalysis.classify_aircraft_modes approach)
%     calls the short period lateral; participation factors are invariant under
%     diagonal scaling and must give the exact answer.
%
%   PRE-REGISTERED expectations (ANALYTIC; eigenvalue problems of an 8x8 matrix
%   with condition ~1e2: tolerances 1e-9 absolute on eigenvalues, wn, zeta,
%   times; 1e-10 on participation sums):
%     classic set  SP -2 +/- 3i, phugoid -0.01 +/- 0.08i, DR -0.3 +/- 2.5i,
%                  roll -3.5, spiral +0.02 (unstable): names exact, 5 entries
%                  (pairs once, eigenvalue with Im > 0), wn = |lambda|,
%                  zeta = -Re/|lambda|, period = 2 pi/Im, tHalf = ln2/(-Re) for
%                  stable, tDouble = ln2/Re for unstable (the other NaN),
%                  tau = -1/lambda for real modes; participation of a mode sums
%                  to 1 and lies entirely in its subspace.
%     unit change  participation identical with and without D (1e-10).
%     split SP     SP block with real roots -3 and +0.4: two entries named
%                  short_period with status NOT_OSCILLATORY (FC-507), wn, zeta
%                  and period NaN, tau 1/3 and -2.5, tHalf ln2/3, tDouble ln2/0.4.
%     unstable DR  +0.1 +/- 2i: zeta = -0.1/sqrt(4.01) < 0, tDouble = ln2/0.1.
%     roll-spiral  p, phi forming an oscillatory pair -1 +/- 0.5i: that pair is
%                  'other' with status UNCLASSIFIED; the Dutch roll is still named.
%     refusals     lin.status ~= 'OK' -> vital:linear:notConverged;
%                  non-finite A -> vital:badInput.

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

        function A = classic(opts)
            arguments
                opts.sp = tModes.rj(-2, 3)
                opts.dr = tModes.rj(-0.3, 2.5)
                opts.rollSpiral = []
                opts.scale (1,1) logical = true
            end
            A = zeros(8);
            A = tModes.place(A, [3 5], opts.sp, [1 0.4; -0.3 1]);          % short period (w, q)
            A = tModes.place(A, [1 8], tModes.rj(-0.01, 0.08), [1 -0.5; 0.2 1]);   % phugoid (u, theta)
            A = tModes.place(A, [2 6], opts.dr, [1 0.3; 0.6 1]);            % Dutch roll (v, r)
            if isempty(opts.rollSpiral)
                A(4, 4) = -3.5;                                             % roll (p)
                A(7, 7) = 0.02;                                             % spiral (phi), unstable
            else
                A = tModes.place(A, [4 7], opts.rollSpiral, [1 0.2; -0.4 1]);
            end
            A(tModes.LAT, tModes.LON) = 5 * [1 2 0.5 1; -1 1 2 0.5; 0.5 -2 1 1; 2 1 -1 0.5];
            if opts.scale
                D = diag([1 100 1 100 1 100 100 1]);
                A = D * A / D;
            end
        end

        function lin = asLin(A8)
            lin = struct('A', blkdiag(A8, zeros(4)), 'B', zeros(12, 4), 'status', 'OK', 'reason', '');
        end

        function e = byName(m, name)
            e = m(strcmp({m.name}, name));
        end
    end

    methods (Test)
        function classicModesNamedWithExactValues(tc)
            m = vital.linear.modes(tModes.asLin(tModes.classic()));
            tc.verifyExact(sort({m.name}), sort({'short_period','phugoid','dutch_roll','roll','spiral'}), ...
                'ANALYTIC', 'modes placed in known subspaces', 'Quantity', 'mode names');
            exp = {'short_period', -2 + 3i, [3 5];
                   'phugoid', -0.01 + 0.08i, [1 8];
                   'dutch_roll', -0.3 + 2.5i, [2 6]};
            for k = 1:size(exp, 1)
                e = tModes.byName(m, exp{k, 1}); lam = exp{k, 2};
                tc.assertNumElements(e, 1, exp{k, 1});
                tc.verifyEqual(e.status, 'OK');
                tc.verifyTrue(e.oscillatory, [exp{k, 1} ' is oscillatory']);
                c = sprintf('%s placed at %s', exp{k, 1}, num2str(lam));
                tc.verifyTol(real(e.eigenvalue), real(lam), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' Re']);
                tc.verifyTol(imag(e.eigenvalue), imag(lam), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' Im (> 0)']);
                tc.verifyTol(e.wn, abs(lam), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' wn'], 'Unit', 'rad/s');
                tc.verifyTol(e.zeta, -real(lam) / abs(lam), 1e-9, 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' zeta']);
                tc.verifyTol(e.period, 2 * pi / imag(lam), 1e-9 * 2 * pi / imag(lam), 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' period'], 'Unit', 's');
                tc.verifyTol(e.tHalf, log(2) / -real(lam), 1e-9 * log(2) / -real(lam), 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' tHalf'], 'Unit', 's');
                tc.verifyTrue(isnan(e.tDouble), 'a stable mode has no time to double');
                tc.verifyTol(sum(e.participation), 1, 1e-12, 'abs', 'ANALYTIC', 'participation normalized', 'Quantity', [exp{k,1} ' sum p']);
                tc.verifyTol(sum(e.participation(exp{k, 3})), 1, 1e-10, 'abs', 'ANALYTIC', c, 'Quantity', [exp{k,1} ' p in subspace']);
            end
            r = tModes.byName(m, 'roll');
            tc.assertNumElements(r, 1);
            tc.verifyTol(r.eigenvalue, -3.5, 1e-9, 'abs', 'ANALYTIC', 'roll at -3.5', 'Quantity', 'roll lambda');
            tc.verifyTol(r.tau, 1 / 3.5, 1e-9, 'abs', 'ANALYTIC', 'tau = -1/lambda', 'Quantity', 'roll tau', 'Unit', 's');
            tc.verifyTol(r.participation(4), 1, 1e-10, 'abs', 'ANALYTIC', 'roll in p', 'Quantity', 'roll p_p');
            tc.verifyFalse(r.oscillatory);
            tc.verifyTrue(isnan(r.wn) && isnan(r.zeta), 'a real mode has no wn/zeta');
            s = tModes.byName(m, 'spiral');
            tc.assertNumElements(s, 1);
            tc.verifyTol(s.eigenvalue, 0.02, 1e-9, 'abs', 'ANALYTIC', 'spiral at +0.02 (unstable)', 'Quantity', 'spiral lambda');
            tc.verifyTol(s.tDouble, log(2) / 0.02, 1e-7, 'abs', 'ANALYTIC', 'tDouble = ln2/lambda', 'Quantity', 'spiral tDouble', 'Unit', 's');
            tc.verifyTrue(isnan(s.tHalf), 'an unstable mode has no time to half');
            tc.verifyTol(s.tau, -50, 1e-7, 'abs', 'ANALYTIC', 'tau = -1/lambda (negative: unstable)', 'Quantity', 'spiral tau', 'Unit', 's');
            tc.verifyTol(s.participation(7), 1, 1e-10, 'abs', 'ANALYTIC', 'spiral in phi', 'Quantity', 'spiral p_phi');
            sp = tModes.byName(m, 'short_period');
            tc.verifyTol(sum(sp.participation(tModes.LAT)), 0, 1e-10, 'abs', 'ANALYTIC', ...
                'lon mode: left eigenvector vanishes on lat states', 'Quantity', 'SP lat participation');
        end

        function participationIsInvariantToUnits(tc)
            m1 = vital.linear.modes(tModes.asLin(tModes.classic('scale', false)));
            m2 = vital.linear.modes(tModes.asLin(tModes.classic('scale', true)));
            for n = {'short_period','phugoid','dutch_roll','roll','spiral'}
                a = tModes.byName(m1, n{1}); b = tModes.byName(m2, n{1});
                tc.assertNumElements(b, 1, n{1});
                tc.verifyTol(b.participation, a.participation, 1e-10, 'abs', 'ANALYTIC', ...
                    'participation factors are invariant under a diagonal change of units', 'Quantity', [n{1} ' participation']);
            end
            % fixture check: the raw right eigenvector of the short period is lat-dominated after D
            [V, L] = eig(tModes.classic('scale', true));
            [~, k] = min(abs(diag(L) - (-2 + 3i)));
            v = abs(V(:, k));
            tc.verifyGreaterThan(sum(v(tModes.LAT)), sum(v(tModes.LON)), ...
                'fixture: raw eigenvector magnitudes would call the short period lateral');
        end

        function shortPeriodSplitIsNotOscillatory(tc)
            m = vital.linear.modes(tModes.asLin(tModes.classic('sp', diag([-3 0.4]))));
            sp = tModes.byName(m, 'short_period');
            tc.assertNumElements(sp, 2, 'both real roots are reported');
            tc.verifyExact({sp.status}, {'NOT_OSCILLATORY', 'NOT_OSCILLATORY'}, 'ANALYTIC', ...
                'short period split into two real roots (FC-507)', 'Quantity', 'SP status');
            tc.verifyTrue(all(isnan([sp.wn])) && all(isnan([sp.zeta])) && all(isnan([sp.period])), ...
                'a split short period never produces a frequency, damping or period');
            tc.verifyFalse(any([sp.oscillatory]));
            lam = sort(real([sp.eigenvalue]));
            tc.verifyTol(lam, [-3 0.4], 1e-9, 'abs', 'ANALYTIC', 'placed real roots', 'Quantity', 'SP roots');
            st = sp(real([sp.eigenvalue]) < 0); un = sp(real([sp.eigenvalue]) > 0);
            tc.verifyTol(st.tau, 1/3, 1e-9, 'abs', 'ANALYTIC', 'tau = -1/lambda', 'Quantity', 'stable root tau', 'Unit', 's');
            tc.verifyTol(st.tHalf, log(2)/3, 1e-9, 'abs', 'ANALYTIC', 'ln2/3', 'Quantity', 'stable root tHalf', 'Unit', 's');
            tc.verifyTol(un.tau, -2.5, 1e-9, 'abs', 'ANALYTIC', 'tau = -1/lambda', 'Quantity', 'unstable root tau', 'Unit', 's');
            tc.verifyTol(un.tDouble, log(2)/0.4, 1e-9, 'abs', 'ANALYTIC', 'ln2/0.4', 'Quantity', 'unstable root tDouble', 'Unit', 's');
            ph = tModes.byName(m, 'phugoid');
            tc.assertNumElements(ph, 1);
            tc.verifyEqual(ph.status, 'OK');
        end

        function unstableOscillatoryMode(tc)
            m = vital.linear.modes(tModes.asLin(tModes.classic('dr', tModes.rj(0.1, 2))));
            d = tModes.byName(m, 'dutch_roll');
            tc.assertNumElements(d, 1);
            tc.verifyEqual(d.status, 'OK');
            tc.verifyTol(d.zeta, -0.1 / sqrt(4.01), 1e-9, 'abs', 'ANALYTIC', 'negative damping', 'Quantity', 'DR zeta');
            tc.verifyTol(d.tDouble, log(2) / 0.1, 1e-8, 'abs', 'ANALYTIC', 'ln2/0.1', 'Quantity', 'DR tDouble', 'Unit', 's');
            tc.verifyTrue(isnan(d.tHalf), 'an unstable mode has no time to half');
        end

        function rollSpiralCoupledIsUnclassified(tc)
            m = vital.linear.modes(tModes.asLin(tModes.classic('rollSpiral', tModes.rj(-1, 0.5))));
            o = tModes.byName(m, 'other');
            tc.assertNumElements(o, 1);
            tc.verifyEqual(o.status, 'UNCLASSIFIED');
            tc.verifyTol([real(o.eigenvalue) imag(o.eigenvalue)], [-1 0.5], 1e-9, 'abs', 'ANALYTIC', 'placed p-phi pair', ...
                'Quantity', 'lambda [Re Im]');
            tc.verifyNumElements(tModes.byName(m, 'dutch_roll'), 1);
            tc.verifyEmpty(tModes.byName(m, 'roll'));
            tc.verifyEmpty(tModes.byName(m, 'spiral'));
        end

        function refusesBadLinearization(tc)
            lin = tModes.asLin(tModes.classic());
            lin.status = 'NOT_CONVERGED';
            tc.verifyError(@() vital.linear.modes(lin), 'vital:linear:notConverged');
            lin = tModes.asLin(tModes.classic());
            lin.A(3, 5) = NaN;
            tc.verifyError(@() vital.linear.modes(lin), 'vital:badInput');
        end
    end
end
