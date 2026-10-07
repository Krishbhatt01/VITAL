classdef (TestTags = {'M6'}) tFqMetricsR2 < vital.test.VitalTestCase
%TFQMETRICSR2  M6, review R2 fixes to the metric extractors vital.fq.metrics
%   (synthetic linear models and mode tables; ANALYTIC expected values).
%
%   Findings covered (reports/work/review2/REVIEW.md): B1, B2 (b), M1, MINOR 6,
%   10, 11, and the escaped mutations R2-7, R2-13, R2-16.
%
%   New metric definitions, PRE-REGISTERED here (MIL-F-8785C pp.11, 13, 71, 77):
%   1. lon_divergence_rate_1_s: the largest real eigenvalue among the REAL
%      longitudinal roots (lonFraction > 0.5) of the 8-state modes and, when
%      given, of the 9-state (with height) modes, the root named 'height'
%      included; -Inf when there is no real longitudinal root. Positive = an
%      aperiodic divergence of pitch attitude / angle of attack / speed
%      (3.2.2.2 "no tendency ... to diverge aperiodically", p.13).
%      T2_aperiodic_divergence_s = ln2 / rate when the rate is > 0, else Inf.
%   2. speed_divergence_rate_1_s: as 1, restricted to roots with
%      p_u + p_theta > p_w + p_q, from the 9-state modes when given (3.2.1.1 "no
%      tendency for airspeed to diverge aperiodically", p.11). The 'height' root
%      is included (MINOR 10). T2_speed_divergence_s = ln2 / rate if > 0, else
%      Inf (unchanged definition, now also counting the height root).
%   3. A short period split into real roots with an UNSTABLE root: zeta_sp,
%      omega_nsp_rad_s and CAP have status DIVERGENT (the requirement cannot be
%      met), not NOT_OSCILLATORY. A split with both roots stable stays
%      NOT_OSCILLATORY (excluded). Likewise a split phugoid with an unstable root:
%      zeta_p DIVERGENT and T2_phugoid_s = ln2/lambda (6.2.1, first-order
%      divergence: T2 = .693 tau).
%   4. Roll mode fallback (B2 b): when no mode named 'roll' has status OK, the
%      roll mode is the fastest lateral real root that is not the Dutch roll; the
%      spiral is then the slowest lateral real root. Status OK, and the reason
%      records the classifier disagreement ("fallback").
%   5. With a coupled roll-spiral oscillation (a roll-dominated lateral pair),
%      tau_R_s and spiral_T2_s are NOT_APPLICABLE (MINOR 11); zeta_RS_omega_nRS
%      is that of the LEAST damped such pair (R2-16).
%   6. A descending trim (gamma0 < 0) is NOT_LEVEL as well (R2-13).
%   7. Column status (linear ADR-028): a linear model whose overall status is
%      NOT_CONVERGED is accepted when the columns used (1-8 and the elevator
%      column 13) are OK; otherwise vital:linear:notConverged.

    methods (Static, Access = private)
        function p = part(varargin)
            names = {'u','v','w','p','q','r','phi','theta'};
            p = zeros(8, 1);
            for k = 1:2:numel(varargin), p(strcmp(names, varargin{k})) = varargin{k+1}; end
        end

        function e = mode(name, l, P, status)
            if nargin < 4, status = 'OK'; end
            osc = imag(l) ~= 0;
            e = struct('name', name, 'eigenvalue', l, 'oscillatory', osc, 'wn', NaN, 'zeta', NaN, ...
                'period', NaN, 'tHalf', NaN, 'tDouble', NaN, 'tau', NaN, 'participation', P, ...
                'dominant', {{}}, 'lonFraction', sum(P([1 3 5 8])), 'status', status, 'reason', '');
            if osc && strcmp(status, 'OK') || osc && strcmp(status, 'UNCLASSIFIED')
                e.wn = abs(l); e.zeta = -real(l) / abs(l);
            elseif ~osc
                e.tau = -1 / l;
            end
            if strcmp(status, 'UNCLASSIFIED'), e.reason = 'classifier: signature failed'; end
        end

        function [lin, m] = base()
            % lin with an 8-state A whose Dutch-roll eigenvalue matches the mode table
            P = @tFqMetricsR2.part;
            lin.status = 'OK'; lin.V0 = 150; lin.g = 9.80665; lin.gamma0 = 0;
            lin.lon.air = struct('A', [-0.02 3 0 -9.8; 0 -0.9 1.02 0; 0 -5 -1.3 0; 0 0 1 0], ...
                'B', [0.5 0 0 2; -0.12 0 0 0; -9 0 0 0; 0 0 0 0]);
            dr = -0.4 + 3.1i;
            A = diag([-1 -2 -3 -4 -5 -6 -7 -8]);
            A(2, 2) = real(dr); A(2, 7) = imag(dr); A(7, 2) = -imag(dr); A(7, 7) = real(dr);
            lin.A = zeros(12); lin.A(1:8, 1:8) = A;
            lin.columnStatus = repmat({'OK'}, 1, 16);
            M = @tFqMetricsR2.mode;
            m = [M('short_period', -1.2 + 2.4i, P('w', 0.5, 'q', 0.5)), M('phugoid', -0.01 + 0.07i, P('u', 0.5, 'theta', 0.5)), ...
                 M('dutch_roll', dr, P('v', 0.4, 'r', 0.4, 'p', 0.1, 'phi', 0.1)), ...
                 M('roll', -3, P('p', 0.9, 'phi', 0.1)), M('spiral', -0.01, P('phi', 0.8, 'r', 0.2))];
        end

        function m = replace(m, names, new)
            m = [m(~ismember({m.name}, names)), new];
        end
    end

    methods (Access = private)
        function x = need(tc, M, name)
            tc.assertTrue(isfield(M, name), ['metric ' name ' exists']);
            x = M.(name);
        end
    end

    methods (Test)
        function aperiodicPitchDivergenceFails(tc)
            % pre-registrations 1 and 3 (B1): split short period, +0.2029 not u/theta dominated
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            m = tFqMetricsR2.replace(m, {'short_period'}, [Mo('short_period', -0.8921, P('w', 0.6, 'q', 0.39, 'u', 0.01), 'NOT_OSCILLATORY'), ...
                Mo('short_period', 0.2029, P('q', 0.30, 'w', 0.28, 'u', 0.26, 'theta', 0.16), 'NOT_OSCILLATORY')]);
            M = vital.fq.metrics(lin, m);
            c = 'ANALYTIC: pre-registrations 1 and 3 (class header); review R2 B1';
            tc.verifyTol(tc.need(M, 'lon_divergence_rate_1_s').value, 0.2029, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'lon divergence rate');
            tc.verifyTol(tc.need(M, 'T2_aperiodic_divergence_s').value, log(2) / 0.2029, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'T2 aperiodic');
            tc.verifyExact(tc.need(M, 'speed_divergence_rate_1_s').value, -Inf, 'ANALYTIC', c, 'Quantity', 'speed divergence rate (none u/theta dominated)');
            for f = {'zeta_sp', 'omega_nsp_rad_s', 'CAP'}
                tc.verifyEqual(M.(f{1}).status, 'DIVERGENT', [f{1} ': a divergent split short period fails']);
            end
        end

        function stableSplitShortPeriodStaysExcluded(tc)
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            m = tFqMetricsR2.replace(m, {'short_period'}, [Mo('short_period', -0.9, P('w', 0.6, 'q', 0.4), 'NOT_OSCILLATORY'), ...
                Mo('short_period', -0.3, P('w', 0.5, 'q', 0.5), 'NOT_OSCILLATORY')]);
            M = vital.fq.metrics(lin, m);
            tc.verifyEqual(M.zeta_sp.status, 'NOT_OSCILLATORY', 'pre-registration 3: a stable split stays excluded');
            tc.verifyTol(tc.need(M, 'lon_divergence_rate_1_s').value, -0.3, 1e-12, 'rel', 'ANALYTIC', ...
                'pre-registration 1: largest real longitudinal root', 'Quantity', 'lon rate (stable)');
            tc.verifyExact(M.T2_aperiodic_divergence_s.value, Inf, 'ANALYTIC', 'no divergence', 'Quantity', 'T2 aperiodic');
        end

        function stableSplitPhugoidNoSpeedDivergence(tc)
            % R2-7: both real phugoid roots stable
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            m = tFqMetricsR2.replace(m, {'phugoid'}, [Mo('phugoid', -0.04, P('u', 0.6, 'theta', 0.4), 'NOT_OSCILLATORY'), ...
                Mo('phugoid', -0.1, P('u', 0.5, 'theta', 0.5), 'NOT_OSCILLATORY')]);
            M = vital.fq.metrics(lin, m);
            c = 'ANALYTIC: pre-registration 2';
            tc.verifyExact(M.T2_speed_divergence_s.value, Inf, 'ANALYTIC', c, 'Quantity', 'T2 speed (stable split)');
            tc.verifyTol(tc.need(M, 'speed_divergence_rate_1_s').value, -0.04, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'speed rate');
            tc.verifyEqual(M.zeta_p.status, 'NOT_OSCILLATORY');
        end

        function unstableSplitPhugoidDiverges(tc)
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            m = tFqMetricsR2.replace(m, {'phugoid'}, [Mo('phugoid', 0.04, P('u', 0.6, 'theta', 0.4), 'NOT_OSCILLATORY'), ...
                Mo('phugoid', -0.1, P('u', 0.5, 'theta', 0.5), 'NOT_OSCILLATORY')]);
            M = vital.fq.metrics(lin, m);
            c = 'ANALYTIC: pre-registration 3 (6.2.1 T2 = .693 tau)';
            tc.verifyEqual(M.zeta_p.status, 'DIVERGENT');
            tc.verifyTol(M.T2_phugoid_s.value, log(2) / 0.04, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'T2 phugoid');
            tc.verifyTol(M.T2_speed_divergence_s.value, log(2) / 0.04, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'T2 speed');
        end

        function heightRootCountsForDivergence(tc)
            % MINOR 10: an unstable, u/theta-dominated 'height' root of the 9-state modes
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            h = Mo('height', 0.01, [P('u', 0.5, 'theta', 0.3); 0]); h.participation(9) = 0.2; h.lonFraction = 1;
            ph = Mo('phugoid', -0.01 + 0.08i, [P('u', 0.5, 'theta', 0.5); 0]);
            mh = [m(1), ph, h, m(3:end)];
            for k = 1:numel(mh), if numel(mh(k).participation) == 8, mh(k).participation(9) = 0; end, end
            M = vital.fq.metrics(lin, m, 'PhugoidModes', mh);
            c = 'ANALYTIC: pre-registrations 1-2 (height root included)';
            tc.verifyTol(M.T2_speed_divergence_s.value, log(2) / 0.01, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'T2 speed');
            tc.verifyTol(tc.need(M, 'lon_divergence_rate_1_s').value, 0.01, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'lon rate');
        end

        function rollFallbackFastestLateralRealRoot(tc)
            % B2 (b): 29,000 ft / M 0.30 / CG 20 pattern (review R2 E2)
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            m = tFqMetricsR2.replace(m, {'roll', 'spiral'}, [Mo('spiral', -0.0854, P('r', 0.72, 'phi', 0.17, 'p', 0.11)), ...
                Mo('other', -0.2187, P('phi', 0.68, 'p', 0.25, 'r', 0.07), 'UNCLASSIFIED')]);
            M = vital.fq.metrics(lin, m);
            c = 'ANALYTIC: pre-registration 4';
            tc.verifyEqual(M.tau_R_s.status, 'OK', 'roll fallback');
            tc.verifyTol(M.tau_R_s.value, 1 / 0.2187, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'tau_R (fallback)', 'Unit', 's');
            tc.verifySubstring(M.tau_R_s.reason, 'fallback');
            tc.verifyExact(M.spiral_T2_s.value, Inf, 'ANALYTIC', c, 'Quantity', 'spiral T2 (stable)');
            tc.verifyExact(M.coupled_roll_spiral_present.value, 0, 'ANALYTIC', c, 'Quantity', 'coupled roll-spiral present');
            tc.verifyEqual(M.zeta_RS_omega_nRS_rad_s.status, 'NOT_APPLICABLE');
        end

        function coupledModeLeastDampedAndNotApplicable(tc)
            % R2-16 and MINOR 11
            [lin, m] = tFqMetricsR2.base();
            P = @tFqMetricsR2.part; Mo = @tFqMetricsR2.mode;
            a = Mo('other', -0.35 + 0.6i, P('p', 0.45, 'phi', 0.45, 'r', 0.1), 'UNCLASSIFIED');
            b = Mo('other', -0.8 + 0.5i, P('p', 0.5, 'phi', 0.4, 'r', 0.1), 'UNCLASSIFIED');
            m = tFqMetricsR2.replace(m, {'roll', 'spiral'}, [b, a]);
            M = vital.fq.metrics(lin, m);
            c = 'ANALYTIC: pre-registration 5';
            tc.verifyTol(M.zeta_RS_omega_nRS_rad_s.value, 0.35, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'least-damped coupled pair');
            tc.verifyEqual(M.tau_R_s.status, 'NOT_APPLICABLE');
            tc.verifyEqual(M.spiral_T2_s.status, 'NOT_APPLICABLE');
        end

        function descendingTrimIsNotLevel(tc)
            [lin, m] = tFqMetricsR2.base();
            lin.gamma0 = -0.05;
            M = vital.fq.metrics(lin, m);
            tc.verifyEqual(M.n_alpha_g_per_rad.status, 'NOT_LEVEL', 'pre-registration 6 (R2-13)');
            tc.verifyEqual(M.CAP.status, 'NOT_LEVEL');
        end

        function columnStatusAccepted(tc)
            [lin, m] = tFqMetricsR2.base();
            lin.status = 'NOT_CONVERGED';
            lin.columnStatus{12} = 'KINK';
            try
                M = vital.fq.metrics(lin, m);
            catch err
                tc.assertFail(sprintf('metrics refused a model whose used columns are OK (%s)', err.identifier));
            end
            tc.verifyEqual(M.zeta_sp.status, 'OK', 'pre-registration 7: columns 1-8 and 13 OK');
            lin.columnStatus{5} = 'KINK';
            tc.verifyError(@() vital.fq.metrics(lin, m), 'vital:linear:notConverged');
            lin.columnStatus{5} = 'OK'; lin.columnStatus{13} = 'NO_PLATEAU';
            tc.verifyError(@() vital.fq.metrics(lin, m), 'vital:linear:notConverged');
        end
    end
end
