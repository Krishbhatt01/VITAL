classdef (TestTags = {'M6'}) tFqMetrics < vital.test.VitalTestCase
%TFQMETRICS  M6: MIL-F-8785C metric extractors vital.fq.metrics(lin, modes).
%
%   Definitions (MIL-F-8785C 6.2 as transcribed in docs/MIL8785C_EXTRACT.md
%   section 4; the names equal the record 'metric' fields):
%     zeta_sp, omega_nsp_rad_s       short-period damping / frequency (6.2.5): the
%                                    bare-airframe short-period mode is the
%                                    equivalent classical system (3.1.12)
%     n_alpha_g_per_rad              "steady-state normal acceleration change per
%                                    unit change in angle of attack for an
%                                    incremental pitch control deflection at
%                                    constant speed" (p.77): from the [alpha q]
%                                    rows of the air-axis model with dV = 0,
%                                    0 = A_sp [a; q] + B_sp de,  n/alpha = (V/g) q/a.
%                                    Closed form (derived here, ANALYTIC):
%                                    q/a = (Ma Zd - Za Md) / ((1+Zq) Md - Mq Zd),
%                                    Za = dalphadot/dalpha, 1+Zq = dalphadot/dq,
%                                    Zd = dalphadot/dde, Ma, Mq, Md likewise for qdot.
%                                    With Zd = 0 and Zq = 0 it reduces to
%                                    -(V/g) Za, the M5-A lin.n_alpha at gamma0 = 0.
%                                    Level trim only (|gamma0| <= 1e-6 rad), else
%                                    status NOT_LEVEL.
%     CAP                            omega_nsp^2 / (n/alpha) (3.2.2.1.1)
%     zeta_p                         phugoid damping ratio
%     T2_phugoid_s                   time to double, 6.2.1: T2 = -ln2/(zeta wn) for
%                                    oscillations (printed -.693/zeta omega_n); Inf
%                                    when the phugoid does not diverge
%     T2_speed_divergence_s          aperiodic speed divergence (3.2.1.1): ln2/lambda
%                                    of the largest positive real longitudinal root
%                                    whose participation is speed/attitude dominated
%                                    (p_u + p_theta > p_w + p_q); Inf if none
%     zeta_d, omega_nd_rad_s, zeta_d_omega_nd_rad_s
%                                    Dutch roll (p.77)
%     phi_beta_d, omega_nd2_phi_beta_d
%                                    |phi/beta|_d = |V v_phi / v_v| of the Dutch-roll
%                                    right eigenvector (beta = v/V at beta0 = 0) and
%                                    omega_nd^2 |phi/beta|_d (Table VI increment)
%     tau_R_s                        roll-mode time constant, positive for a stable
%                                    mode (6.2.6): -1/lambda; an unstable roll root
%                                    has no convergence time constant -> Inf (worse
%                                    than every Level)
%     spiral_T2_s                    ln2/lambda of an unstable spiral root, Inf if
%                                    stable ("time for the bank angle to double")
%     coupled_roll_spiral_present    1 if the lateral modes contain an oscillatory
%                                    pair other than the Dutch roll whose
%                                    participation is roll dominated (p_p + p_phi >
%                                    p_v + p_r); 0 if roll and spiral are both
%                                    classified real roots
%     zeta_RS_omega_nRS_rad_s        -Re(lambda) of that pair; NOT_APPLICABLE when
%                                    there is no coupled roll-spiral mode
%   ln 2 is used for the printed .693 (ln 2 = 0.6931 to four figures).
%
%   A mode whose status is not OK gives the metric that mode's status
%   (NOT_OSCILLATORY, UNCLASSIFIED) or MODE_MISSING, with value NaN: never a
%   number (FC-703).
%
%   PRE-REGISTERED (ANALYTIC, synthetic models built in the test):
%   1. SP/phugoid/DR/roll/spiral metrics equal their closed forms to 1e-12 rel.
%   2. n/alpha equals the closed form above to 1e-12 rel, and -(V/g) Za when
%      Zd = Zq = 0.
%   3. |phi/beta|_d of a constructed eigenvector (v_v = 1, v_phi = 0.02 e^(i0.7))
%      at V = 150 m/s equals 3.0 to 1e-9 rel.
%   4. Failure modes: NOT_OSCILLATORY short period -> zeta_sp, omega_nsp_rad_s and
%      CAP carry status NOT_OSCILLATORY with NaN values; a missing Dutch roll ->
%      MODE_MISSING; a non-OK linear model -> vital:linear:notConverged; a
%      non-level trim -> n_alpha and CAP status NOT_LEVEL.

    properties
        V = 150
        G = 9.80665
    end

    methods (Access = private)
        function [lin, m] = synthetic(tc, opts)
            % A block-diagonal 8-state model with prescribed eigen-structure, plus a
            % modes struct in vital.linear.modes format.
            arguments
                tc
                opts.Sp = -1.2 + 2.4i
                opts.Ph = -0.01 + 0.07i
                opts.Dr = -0.4 + 3.1i
                opts.Roll = -3
                opts.Spiral = -0.01
                opts.Gamma0 = 0
                opts.SpStatus = 'OK'
                opts.WithDutchRoll = true
                opts.CoupledRS = []           % if given: a lateral 'other' pair with this eigenvalue
            end
            % longitudinal air-axis [V alpha q theta] model (only the alpha, q rows are used)
            Za = -0.9; Zq = 0.02; Zd = -0.12; Ma = -5.0; Mq = -1.3; Md = -9.0;
            Alon = [-0.02 3 0 -9.8; 0 Za 1 + Zq 0; 0 Ma Mq 0; 0 0 1 0];
            Blon = [0.5 0 0 2; Zd 0 0 0; Md 0 0 0; 0 0 0 0];
            lin.status = 'OK'; lin.V0 = tc.V; lin.g = tc.G; lin.gamma0 = opts.Gamma0;
            lin.lon.air = struct('A', Alon, 'B', Blon, 'stateNames', {{'V','alpha','q','theta'}});
            % 8-state A with a constructed Dutch-roll eigenvector in [u v w p q r phi theta]
            lam = [opts.Sp; conj(opts.Sp); opts.Ph; conj(opts.Ph); opts.Dr; conj(opts.Dr); opts.Roll; opts.Spiral];
            vdr = [0; 1; 0; 0.3i; 0; -0.5; (3 / tc.V) * exp(0.7i); 0];   % |V v_phi / v_v| = 3
            Vm = eye(8); Vm(:, 5) = vdr; Vm(:, 6) = conj(vdr);
            Vm(:, 1) = [0; 0; 1; 0; 1i; 0; 0; 0]; Vm(:, 2) = conj(Vm(:, 1));
            Vm(:, 3) = [1; 0; 0; 0; 0; 0; 0; 1i]; Vm(:, 4) = conj(Vm(:, 3));
            Vm(:, 7) = [0; 0; 0; 1; 0; 0; 0.1; 0]; Vm(:, 8) = [0; 0.01; 0; 0; 0; 0.05; 1; 0];
            lin.A = real(Vm * diag(lam) / Vm);
            lin.A(9:12, 9:12) = 0;
            t = struct('name', 'other', 'eigenvalue', 0, 'oscillatory', false, 'wn', NaN, 'zeta', NaN, ...
                'period', NaN, 'tHalf', NaN, 'tDouble', NaN, 'tau', NaN, 'participation', zeros(8, 1), ...
                'dominant', {{}}, 'lonFraction', NaN, 'status', 'OK', 'reason', '');
            pair = @(t, nm, l, P) setfield(setfield(setfield(setfield(setfield(setfield(t, 'name', nm), ...
                'eigenvalue', l), 'oscillatory', true), 'wn', abs(l)), 'zeta', -real(l) / abs(l)), 'participation', P); %#ok<SFLD>
            real1 = @(t, nm, l, P) setfield(setfield(setfield(setfield(t, 'name', nm), 'eigenvalue', l), 'tau', -1 / l), 'participation', P); %#ok<SFLD>
            P = @(varargin) tFqMetrics.part(varargin{:});
            m = [pair(t, 'short_period', opts.Sp, P('w', 0.5, 'q', 0.5)), pair(t, 'phugoid', opts.Ph, P('u', 0.5, 'theta', 0.5))];
            if strcmp(opts.SpStatus, 'NOT_OSCILLATORY')
                m(1) = setfield(setfield(setfield(setfield(m(1), 'status', 'NOT_OSCILLATORY'), 'wn', NaN), 'zeta', NaN), 'oscillatory', false); %#ok<SFLD>
            end
            if opts.WithDutchRoll
                m(end+1) = pair(t, 'dutch_roll', opts.Dr, P('v', 0.4, 'r', 0.4, 'p', 0.1, 'phi', 0.1));
            end
            if isempty(opts.CoupledRS)
                m(end+1) = real1(t, 'roll', opts.Roll, P('p', 0.9, 'phi', 0.1));
                m(end+1) = real1(t, 'spiral', opts.Spiral, P('phi', 0.8, 'r', 0.2));
            else
                o = pair(t, 'other', opts.CoupledRS, P('p', 0.45, 'phi', 0.45, 'r', 0.1));
                o.status = 'UNCLASSIFIED'; o.lonFraction = 0;
                o.reason = 'second lateral oscillatory pair (e.g. roll-spiral coupled oscillation)';
                m(end+1) = o;
            end
            for k = 1:numel(m)
                m(k).lonFraction = sum(m(k).participation([1 3 5 8]));
                l = m(k).eigenvalue;
                if real(l) < 0, m(k).tHalf = log(2) / -real(l); elseif real(l) > 0, m(k).tDouble = log(2) / real(l); end
            end
        end
    end

    methods (Static, Access = private)
        function p = part(varargin)
            names = {'u','v','w','p','q','r','phi','theta'};
            p = zeros(8, 1);
            for k = 1:2:numel(varargin), p(strcmp(names, varargin{k})) = varargin{k+1}; end
        end
    end

    methods (Test)
        function shortPeriodAndCapClosedForm(tc)
            [lin, m] = tc.synthetic();
            M = vital.fq.metrics(lin, m);
            sp = -1.2 + 2.4i;
            c = 'ANALYTIC: 6.2.5 definitions on a constructed model (class header)';
            tc.verifyTol(M.omega_nsp_rad_s.value, abs(sp), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'omega_nsp', 'Unit', 'rad/s');
            tc.verifyTol(M.zeta_sp.value, 1.2 / abs(sp), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'zeta_sp');
            Za = -0.9; Zq = 0.02; Zd = -0.12; Ma = -5.0; Mq = -1.3; Md = -9.0;
            na = (tc.V / tc.G) * (Ma * Zd - Za * Md) / ((1 + Zq) * Md - Mq * Zd);
            tc.verifyTol(M.n_alpha_g_per_rad.value, na, 1e-12, 'rel', 'ANALYTIC', ...
                'MIL-F-8785C p.77 n/alpha, closed form of the constant-speed [alpha q] steady state (header)', ...
                'Quantity', 'n/alpha', 'Unit', 'g/rad');
            tc.verifyTol(M.CAP.value, abs(sp)^2 / na, 1e-12, 'rel', 'ANALYTIC', 'CAP = omega_nsp^2/(n/alpha) (3.2.2.1.1)', ...
                'Quantity', 'CAP', 'Unit', '1/(g s^2)');
            for f = {'omega_nsp_rad_s', 'zeta_sp', 'n_alpha_g_per_rad', 'CAP'}
                tc.verifyEqual(M.(f{1}).status, 'OK', f{1});
            end
        end

        function nAlphaReducesToAlphaOnlyWithoutElevatorLift(tc)
            [lin, m] = tc.synthetic();
            lin.lon.air.A(2, 3) = 1;          % Zq = 0
            lin.lon.air.B(2, 1) = 0;          % Zd = 0
            M = vital.fq.metrics(lin, m);
            tc.verifyTol(M.n_alpha_g_per_rad.value, -(tc.V / tc.G) * lin.lon.air.A(2, 2), 1e-12, 'rel', 'ANALYTIC', ...
                'n/alpha = -(V/g) Z_alpha when Z_de = Z_q = 0 (M5-A lin.n_alpha at gamma0 = 0)', 'Quantity', 'n/alpha', 'Unit', 'g/rad');
        end

        function timeToDoubleAndTimeConstants(tc)
            c = 'ANALYTIC: 6.2.1 T2 = -ln2/(zeta wn) (printed .693), 6.2.6 tau_R = -1/lambda_R';
            [lin, m] = tc.synthetic('Ph', 0.02 + 0.07i, 'Spiral', 0.05, 'Roll', -2.5);
            M = vital.fq.metrics(lin, m);
            tc.verifyTol(M.T2_phugoid_s.value, log(2) / 0.02, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'T2 phugoid', 'Unit', 's');
            tc.verifyTol(M.zeta_p.value, -0.02 / abs(0.02 + 0.07i), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'zeta_p');
            tc.verifyTol(M.spiral_T2_s.value, log(2) / 0.05, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'spiral T2', 'Unit', 's');
            tc.verifyTol(M.tau_R_s.value, 1 / 2.5, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'tau_R', 'Unit', 's');
            [lin, m] = tc.synthetic();
            M = vital.fq.metrics(lin, m);
            tc.verifyExact([M.T2_phugoid_s.value M.spiral_T2_s.value M.T2_speed_divergence_s.value], [Inf Inf Inf], ...
                'ANALYTIC', 'no divergence: the time to double is infinite', 'Quantity', 'T2 of stable modes');
            [lin, m] = tc.synthetic('Roll', 0.3);
            M = vital.fq.metrics(lin, m);
            tc.verifyExact(M.tau_R_s.value, Inf, 'ANALYTIC', 'unstable roll root: no convergence time constant', 'Quantity', 'tau_R unstable');
            tc.verifyEqual(M.tau_R_s.status, 'OK');
        end

        function speedDivergenceFromRealPhugoidRoots(tc)
            [lin, m] = tc.synthetic();
            % phugoid split into two real roots, one unstable (speed dominated)
            ph = m(strcmp({m.name}, 'phugoid'));
            a = ph; a.eigenvalue = 0.04; a.oscillatory = false; a.status = 'NOT_OSCILLATORY'; a.wn = NaN; a.zeta = NaN; a.tau = -1 / 0.04;
            b = a; b.eigenvalue = -0.1; b.tau = 10;
            m = [m(~strcmp({m.name}, 'phugoid')), a, b];
            M = vital.fq.metrics(lin, m);
            tc.verifyTol(M.T2_speed_divergence_s.value, log(2) / 0.04, 1e-12, 'rel', 'ANALYTIC', ...
                '3.2.1.1 / 6.2.1: T2 = .693 tau of a first-order divergence (extract 6.1 item 5: ln2/|lambda|)', ...
                'Quantity', 'T2 speed divergence', 'Unit', 's');
            % SUPERSEDED 2026-10-05 (review R2 B1/B2, coordinator decision "a split ...
            % with an unstable root is a failure, not an exclusion"): first registered
            % as status NOT_OSCILLATORY; a split phugoid with an unstable root (here
            % +0.04) is now DIVERGENT (fails every Level). Still never a number.
            tc.verifyEqual(M.zeta_p.status, 'DIVERGENT', 'zeta_p of a divergent split phugoid fails, it is not a number');
            tc.verifyTrue(isnan(M.zeta_p.value));
        end

        function dutchRollMetrics(tc)
            [lin, m] = tc.synthetic();
            M = vital.fq.metrics(lin, m);
            dr = -0.4 + 3.1i;
            c = 'ANALYTIC: constructed Dutch-roll eigenvalue and eigenvector (class header)';
            tc.verifyTol(M.omega_nd_rad_s.value, abs(dr), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'omega_nd', 'Unit', 'rad/s');
            tc.verifyTol(M.zeta_d.value, 0.4 / abs(dr), 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'zeta_d');
            tc.verifyTol(M.zeta_d_omega_nd_rad_s.value, 0.4, 1e-12, 'rel', 'ANALYTIC', c, 'Quantity', 'zeta_d omega_nd', 'Unit', 'rad/s');
            tc.verifyTol(M.phi_beta_d.value, 3.0, 1e-9, 'rel', 'ANALYTIC', 'pre-registration 3', 'Quantity', '|phi/beta|_d');
            tc.verifyTol(M.omega_nd2_phi_beta_d.value, 3.0 * abs(dr)^2, 1e-9, 'rel', 'ANALYTIC', c, ...
                'Quantity', 'omega_nd^2 |phi/beta|_d', 'Unit', '(rad/s)^2');
            tc.verifyExact(M.coupled_roll_spiral_present.value, 0, 'ANALYTIC', 'classic roll and spiral roots', ...
                'Quantity', 'coupled roll-spiral present');
            tc.verifyEqual(M.zeta_RS_omega_nRS_rad_s.status, 'NOT_APPLICABLE');
        end

        function coupledRollSpiralDetected(tc)
            rs = -0.35 + 0.6i;
            [lin, m] = tc.synthetic('CoupledRS', rs);
            M = vital.fq.metrics(lin, m);
            tc.verifyExact(M.coupled_roll_spiral_present.value, 1, 'ANALYTIC', 'lateral roll-dominated pair besides the Dutch roll', ...
                'Quantity', 'coupled roll-spiral present');
            tc.verifyTol(M.zeta_RS_omega_nRS_rad_s.value, 0.35, 1e-12, 'rel', 'ANALYTIC', 'zeta_RS omega_nRS = -Re(lambda_RS)', ...
                'Quantity', 'zeta_RS omega_nRS', 'Unit', 'rad/s');
            tc.verifyNotEqual(M.tau_R_s.status, 'OK', 'no roll root: tau_R is a status');
            tc.verifyTrue(isnan(M.tau_R_s.value));
        end

        function nonOscillatoryModeGivesStatusNotNumber(tc)
            [lin, m] = tc.synthetic('SpStatus', 'NOT_OSCILLATORY', 'WithDutchRoll', false);
            M = vital.fq.metrics(lin, m);
            for f = {'zeta_sp', 'omega_nsp_rad_s', 'CAP'}
                tc.verifyEqual(M.(f{1}).status, 'NOT_OSCILLATORY', [f{1} ' (FC-703)']);
                tc.verifyTrue(isnan(M.(f{1}).value), [f{1} ' has no value']);
            end
            for f = {'zeta_d', 'omega_nd_rad_s', 'zeta_d_omega_nd_rad_s', 'phi_beta_d', 'omega_nd2_phi_beta_d'}
                tc.verifyEqual(M.(f{1}).status, 'MODE_MISSING', f{1});
                tc.verifyTrue(isnan(M.(f{1}).value), [f{1} ' has no value']);
            end
            tc.verifyEqual(M.zeta_p.status, 'OK', 'the phugoid is unaffected');
        end

        function metricNamesAreComplete(tc)
            [lin, m] = tc.synthetic();
            M = vital.fq.metrics(lin, m);
            [names, units] = vital.fq.metricNames();
            tc.verifyEqual(numel(units), numel(names));
            tc.verifyEqual(sort(fieldnames(M)), sort(names(:)), 'metrics returns exactly metricNames');
            for f = names(:)'
                tc.verifyTrue(all(isfield(M.(f{1}), {'value', 'status', 'reason', 'unit'})), f{1});
            end
        end

        function badInputsRejected(tc)
            [lin, m] = tc.synthetic();
            bad = lin; bad.status = 'NOT_CONVERGED';
            tc.verifyError(@() vital.fq.metrics(bad, m), 'vital:linear:notConverged');
            [lin, m] = tc.synthetic('Gamma0', 0.05);
            M = vital.fq.metrics(lin, m);
            tc.verifyEqual(M.n_alpha_g_per_rad.status, 'NOT_LEVEL');
            tc.verifyEqual(M.CAP.status, 'NOT_LEVEL');
            tc.verifyTrue(isnan(M.CAP.value));
        end
    end
end
