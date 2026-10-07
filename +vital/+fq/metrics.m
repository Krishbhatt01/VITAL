function M = metrics(lin, modes, opts)
%METRICS  MIL-F-8785C metric extractors from a linear model and its modes.
%   M = vital.fq.metrics(lin, modes)
%   M = vital.fq.metrics(lin, modes, 'PhugoidModes', modesH, 'PhugoidUnavailable', why, 'GammaTol', 1e-6)
%
%   lin    vital.linear.linearize result. Accepted when lin.status is 'OK', or
%          when lin.columnStatus is 'OK' for every column used here (1-8, the
%          dynamic states, and 13, the elevator, for n/alpha; linear ADR-028).
%          Otherwise vital:linear:notConverged.
%   modes  vital.linear.modes(lin) (8 dynamic states): short period, Dutch roll,
%          roll, spiral, coupled roll-spiral.
%   'PhugoidModes'  vital.linear.modes(lin, 'IncludeHeight', true): used, when
%          given, for zeta_p, T2_phugoid_s, the speed divergence and (with the
%          8-state roots) the longitudinal divergence rate. The 9-state phugoid is
%          what the nonlinear F-16 flies (tests/M5/tLinearVsNonlinear.m).
%   'PhugoidUnavailable'  reason text when the 9-state modes could not be
%          formed (the h column of the linear model is not OK, e.g. at a
%          thrust-table altitude breakpoint): the phugoid and speed-divergence
%          metrics then have status NOT_CONVERGED with that reason.
%
%   M.(name) = struct(value, status, reason, unit) for every name of
%   vital.fq.metricNames. Status:
%     OK              value is the metric
%     DIVERGENT       the requirement cannot be met at this point (an unstable
%                     real root where an oscillation is required): the engine
%                     FAILS the point at every Level (review R2 B1)
%     NOT_APPLICABLE  the requirement does not apply (e.g. no coupled
%                     roll-spiral mode, or tau_R / spiral when a coupled mode
%                     replaces them)
%     anything else   (NOT_OSCILLATORY, UNCLASSIFIED, MODE_MISSING, NOT_LEVEL,
%                     NOT_CONVERGED, ...): no value (NaN); the engine excludes
%                     and counts the point (FC-703)
%
%   Definitions (MIL-F-8785C 6.2, docs/MIL8785C_EXTRACT.md section 4):
%     zeta_sp, omega_nsp_rad_s  short-period zeta and wn (6.2.5). A short period
%                     split into real roots: DIVERGENT if a root is unstable,
%                     NOT_OSCILLATORY otherwise.
%     n_alpha_g_per_rad  6.2 (p.77) steady state at constant speed per elevator
%                     increment: 0 = A_sp [alpha; q] + b_de de, n/alpha = (V/g) q/alpha
%                     (= lin.n_alpha_ss); level trims only (NOT_LEVEL otherwise).
%     CAP             omega_nsp^2/(n/alpha)
%     zeta_p          phugoid damping ratio; DIVERGENT for a split phugoid with an
%                     unstable root
%     T2_phugoid_s    6.2.1: -ln2/(zeta wn) for an unstable oscillation, ln2/lambda
%                     for a split phugoid with an unstable root (.693 tau), Inf if
%                     it does not diverge
%     lon_divergence_rate_1_s  the largest eigenvalue among the REAL longitudinal
%                     roots (lonFraction > 0.5) of the 8-state modes and of the
%                     9-state modes (the 'height' root included); -Inf when there
%                     is none. > 0 = aperiodic divergence (3.2.2.2, p.13)
%     T2_aperiodic_divergence_s  ln2 / lon_divergence_rate if > 0, else Inf
%     speed_divergence_rate_1_s  the same over the real longitudinal roots with
%                     p_u + p_theta > p_w + p_q, 9-state modes when given (height
%                     root included); 3.2.1.1 "no tendency for airspeed to diverge
%                     aperiodically" (p.11)
%     T2_speed_divergence_s  ln2 / speed_divergence_rate if > 0, else Inf
%     zeta_d, omega_nd_rad_s, zeta_d_omega_nd_rad_s  Dutch roll
%     phi_beta_d, omega_nd2_phi_beta_d  |V0 v_phi / v_v| of the Dutch-roll
%                     eigenvector and omega_nd^2 |phi/beta|_d
%     tau_R_s         -1/lambda of the roll root (Inf if it is unstable). The roll
%                     root is the classifier's 'roll'; when the classifier gives
%                     none, the fastest lateral real root that is not a Dutch roll
%                     root ("fallback", review R2 B2 b; the classifier's body-axis
%                     signature is not a MIL definition). NOT_APPLICABLE when a
%                     coupled roll-spiral mode exists.
%     spiral_T2_s     ln2/lambda of an unstable spiral root, Inf if stable; the
%                     spiral is the slowest lateral real root in the fallback.
%                     NOT_APPLICABLE with a coupled roll-spiral mode.
%     coupled_roll_spiral_present  1 if a lateral oscillatory pair other than the
%                     Dutch roll is roll dominated (p_p + p_phi > p_v + p_r); 0 if
%                     roll and spiral are separate real roots
%     zeta_RS_omega_nRS_rad_s  -Re(lambda) of the least-damped such pair;
%                     NOT_APPLICABLE when there is none
%   ln 2 is used for the printed .693.
%   Errors: vital:linear:notConverged; vital:fq:badInput (missing fields).
arguments
    lin (1,1) struct
    modes struct
    opts.PhugoidModes struct = struct('name', {})
    opts.PhugoidUnavailable (1,:) char = ''
    opts.GammaTol (1,1) double = 1e-6
end
if ~isfield(lin, 'status')
    error('vital:linear:notConverged', 'linear model has no status: no flying-qualities metrics.');
end
if ~strcmp(lin.status, 'OK')
    used = [1:8 13];
    ok = isfield(lin, 'columnStatus') && numel(lin.columnStatus) >= 13 && all(strcmp(lin.columnStatus(used), 'OK'));
    if ~ok
        error('vital:linear:notConverged', ['linear model status is %s and a column used by the metrics ' ...
            '(1-8, 13) is not OK: no flying-qualities metrics.'], char(lin.status));
    end
end
for f = {'A', 'lon', 'V0', 'g', 'gamma0'}
    if ~isfield(lin, f{1}), error('vital:fq:badInput', 'lin has no field "%s".', f{1}); end
end
if ~isfield(lin.lon, 'air') || ~all(isfield(lin.lon.air, {'A', 'B'}))
    error('vital:fq:badInput', 'lin.lon.air must have A and B ([V alpha q theta] form).');
end
modes = checkModes(modes);
noPh = ~isempty(opts.PhugoidUnavailable);
if isempty(opts.PhugoidModes)
    pmodes = modes; phSrc = '8-state modes';
else
    pmodes = checkModes(opts.PhugoidModes); phSrc = 'modes with height (IncludeHeight)';
end
[names, units] = vital.fq.metricNames();
M = struct();
for k = 1:numel(names)
    M.(names{k}) = struct('value', NaN, 'status', 'MODE_MISSING', 'reason', '', 'unit', units{k});
end
iu = 1; iv = 2; iw = 3; ip = 4; iq = 5; ir = 6; iphi = 7; ith = 8;

% ---- short period, n/alpha, CAP ------------------------------------------------------
[sp, sst, srs] = pick(modes, 'short_period');
if isempty(sp) && strcmp(sst, 'NOT_OSCILLATORY')
    ks = strcmp({modes.name}, 'short_period');
    lam = real([modes(ks).eigenvalue]);
    if any(lam > 0)
        sst = 'DIVERGENT';
        srs = sprintf('short period split into real roots with an unstable root %.4g 1/s: aperiodic AoA divergence', max(lam));
    end
end
if isempty(sp)
    M = put(M, {'zeta_sp', 'omega_nsp_rad_s'}, NaN, sst, srs);
else
    M = put(M, 'zeta_sp', sp.zeta, 'OK', '');
    M = put(M, 'omega_nsp_rad_s', sp.wn, 'OK', '');
end
if abs(lin.gamma0) > opts.GammaTol
    M = put(M, 'n_alpha_g_per_rad', NaN, 'NOT_LEVEL', ...
        sprintf('gamma0 = %.3g rad: the constant-speed steady state is defined here for level trims only', lin.gamma0));
else
    Asp = lin.lon.air.A(2:3, 2:3);
    bde = lin.lon.air.B(2:3, 1);
    K = [Asp(:, 2), bde];                           % unknowns [q; de] per unit alpha
    if rcond(K) < 1e-12
        M = put(M, 'n_alpha_g_per_rad', NaN, 'SINGULAR', 'the [alpha q] steady state per elevator is singular');
    else
        z = K \ (-Asp(:, 1));
        M = put(M, 'n_alpha_g_per_rad', (lin.V0 / lin.g) * z(1), 'OK', '');
    end
end
na = M.n_alpha_g_per_rad;
if isempty(sp)
    M = put(M, 'CAP', NaN, sst, srs);
elseif ~strcmp(na.status, 'OK')
    M = put(M, 'CAP', NaN, na.status, na.reason);
elseif na.value <= 0
    M = put(M, 'CAP', NaN, 'NONPOSITIVE_N_ALPHA', sprintf('n/alpha = %.4g g/rad', na.value));
else
    M = put(M, 'CAP', sp.wn^2 / na.value, 'OK', '');
end

% ---- phugoid ------------------------------------------------------------------------
if noPh
    M = put(M, {'zeta_p', 'T2_phugoid_s'}, NaN, 'NOT_CONVERGED', opts.PhugoidUnavailable);
else
    [ph, pst, prs] = pick(pmodes, 'phugoid');
    if isempty(ph)
        lamP = [];
        if strcmp(pst, 'NOT_OSCILLATORY')
            lamP = real([pmodes(strcmp({pmodes.name}, 'phugoid')).eigenvalue]);
        end
        if any(lamP > 0)
            M = put(M, 'zeta_p', NaN, 'DIVERGENT', sprintf('phugoid split into real roots with an unstable root %.4g 1/s', max(lamP)));
            M = put(M, 'T2_phugoid_s', log(2) / max(lamP), 'OK', ['first-order divergence, T2 = .693 tau (' phSrc ')']);
        else
            M = put(M, {'zeta_p', 'T2_phugoid_s'}, NaN, pst, prs);
        end
    else
        M = put(M, 'zeta_p', ph.zeta, 'OK', phSrc);
        if ph.zeta < 0
            M = put(M, 'T2_phugoid_s', -log(2) / (ph.zeta * ph.wn), 'OK', phSrc);
        else
            M = put(M, 'T2_phugoid_s', Inf, 'OK', ['phugoid does not diverge: time to double is infinite (' phSrc ')']);
        end
    end
end

% ---- aperiodic divergences (3.2.1.1 speed, 3.2.2.2 pitch attitude / AoA) ---------------
lonReal = @(mm) mm([mm.lonFraction] > 0.5 & ~[mm.oscillatory]);
if noPh
    cand = lonReal(modes);
    srcL = '8-state modes only (the modes with height are unavailable)';
else
    cand = [lonReal(modes), lonReal(pmodes)];
    srcL = '8-state modes and modes with height';
end
if isempty(modes) && isempty(pmodes)
    M = put(M, {'lon_divergence_rate_1_s', 'T2_aperiodic_divergence_s'}, NaN, 'MODE_MISSING', 'no modes');
else
    rate = -Inf;
    if ~isempty(cand), rate = max(real([cand.eigenvalue])); end
    M = put(M, 'lon_divergence_rate_1_s', rate, 'OK', ['largest real longitudinal root, ' srcL]);
    if rate > 0
        M = put(M, 'T2_aperiodic_divergence_s', log(2) / rate, 'OK', 'aperiodic longitudinal divergence');
    else
        M = put(M, 'T2_aperiodic_divergence_s', Inf, 'OK', 'no aperiodic longitudinal divergence');
    end
end
if noPh
    M = put(M, {'speed_divergence_rate_1_s', 'T2_speed_divergence_s'}, NaN, 'NOT_CONVERGED', opts.PhugoidUnavailable);
elseif isempty(pmodes)
    M = put(M, {'speed_divergence_rate_1_s', 'T2_speed_divergence_s'}, NaN, 'MODE_MISSING', 'no modes');
else
    rate = -Inf;
    for e = lonReal(pmodes)
        Pp = e.participation;
        if Pp(iu) + Pp(ith) > Pp(iw) + Pp(iq)
            rate = max(rate, real(e.eigenvalue));
        end
    end
    M = put(M, 'speed_divergence_rate_1_s', rate, 'OK', ['largest speed/attitude-dominated real longitudinal root (' phSrc ')']);
    if rate > 0   % speed divergence only when the root is unstable
        M = put(M, 'T2_speed_divergence_s', log(2) / rate, 'OK', ['aperiodic speed divergence (' phSrc ')']);
    else
        M = put(M, 'T2_speed_divergence_s', Inf, 'OK', ['no aperiodic speed divergence (' phSrc ')']);
    end
end

% ---- Dutch roll ---------------------------------------------------------------------
drNames = {'zeta_d', 'omega_nd_rad_s', 'zeta_d_omega_nd_rad_s', 'phi_beta_d', 'omega_nd2_phi_beta_d'};
[dr, dst, drs] = pick(modes, 'dutch_roll');
if isempty(dr)
    M = put(M, drNames, NaN, dst, drs);
else
    M = put(M, 'zeta_d', dr.zeta, 'OK', '');
    M = put(M, 'omega_nd_rad_s', dr.wn, 'OK', '');
    M = put(M, 'zeta_d_omega_nd_rad_s', dr.zeta * dr.wn, 'OK', '');
    [Vm, D] = eig(lin.A(1:8, 1:8));
    [dl, i] = min(abs(diag(D) - dr.eigenvalue));
    v = Vm(:, i);
    if dl > 1e-6 * abs(dr.eigenvalue) || abs(v(iv)) == 0
        M = put(M, {'phi_beta_d', 'omega_nd2_phi_beta_d'}, NaN, 'EIGENVECTOR_MISMATCH', ...
            'no eigenvector of lin.A matches the Dutch-roll eigenvalue');
    else
        pb = abs(lin.V0 * v(iphi) / v(iv));
        M = put(M, 'phi_beta_d', pb, 'OK', '');
        M = put(M, 'omega_nd2_phi_beta_d', dr.wn^2 * pb, 'OK', '');
    end
end

% ---- roll, spiral, coupled roll-spiral (3.3.1.2-3.3.1.4) ---------------------------------
lat = modes([modes.lonFraction] <= 0.5);
sig = [];
for e = lat
    Pp = e.participation;
    if e.oscillatory && ~strcmp(e.name, 'dutch_roll') && Pp(ip) + Pp(iphi) > Pp(iv) + Pp(ir)
        sig(end+1) = -real(e.eigenvalue); %#ok<AGROW>
    end
end
[ro, ~, rrs] = pick(modes, 'roll');
[sg, ~, grs] = pick(modes, 'spiral');
note = '';
if ~isempty(sig)
    why = 'a coupled roll-spiral oscillation replaces the roll and spiral modes (3.3.1.4 governs)';
    M = put(M, {'tau_R_s', 'spiral_T2_s'}, NaN, 'NOT_APPLICABLE', why);
    M = put(M, 'coupled_roll_spiral_present', 1, 'OK', 'roll-dominated lateral oscillatory pair');
    M = put(M, 'zeta_RS_omega_nRS_rad_s', min(sig), 'OK', '');
else
    if isempty(ro) || isempty(sg)
        realLat = lat(~[lat.oscillatory] & ~strcmp({lat.name}, 'dutch_roll'));
        if numel(realLat) >= 2
            [~, o] = sort(abs([realLat.eigenvalue]), 'descend');
            ro = realLat(o(1)); sg = realLat(o(end));
            note = sprintf(['fallback: roll = fastest lateral real root %.4g 1/s, spiral = slowest %.4g 1/s; the ' ...
                'classifier named them %s / %s (%s)'], real(ro.eigenvalue), real(sg.eigenvalue), ro.name, sg.name, ...
                strjoin(unique({ro.reason, sg.reason, rrs, grs}), '; '));
        end
    end
    if isempty(ro)
        M = put(M, 'tau_R_s', NaN, 'MODE_MISSING', rrs);
    elseif real(ro.eigenvalue) < 0
        M = put(M, 'tau_R_s', -1 / real(ro.eigenvalue), 'OK', note);
    else
        M = put(M, 'tau_R_s', Inf, 'OK', strtrim(sprintf('unstable roll root %.4g 1/s: no convergence time constant %s', ...
            real(ro.eigenvalue), note)));
    end
    if isempty(sg)
        M = put(M, 'spiral_T2_s', NaN, 'MODE_MISSING', grs);
    elseif real(sg.eigenvalue) > 0
        M = put(M, 'spiral_T2_s', log(2) / real(sg.eigenvalue), 'OK', strtrim(['divergent spiral ' note]));
    else
        M = put(M, 'spiral_T2_s', Inf, 'OK', strtrim(['spiral does not diverge: time to double is infinite ' note]));
    end
    if ~isempty(ro) && ~isempty(sg)
        M = put(M, 'coupled_roll_spiral_present', 0, 'OK', 'roll and spiral are separate real roots');
        M = put(M, 'zeta_RS_omega_nRS_rad_s', NaN, 'NOT_APPLICABLE', 'no coupled roll-spiral mode');
    else
        M = put(M, {'coupled_roll_spiral_present', 'zeta_RS_omega_nRS_rad_s'}, NaN, 'MODE_UNCLASSIFIED', ...
            'lateral modes are neither two separate real roots nor a coupled roll-spiral pair');
    end
end
end

function modes = checkModes(modes)
if isempty(modes)
    modes = struct('name', {}, 'eigenvalue', {}, 'status', {}, 'reason', {}, 'participation', {}, ...
        'lonFraction', {}, 'oscillatory', {}, 'wn', {}, 'zeta', {}, 'tau', {});
elseif ~all(isfield(modes, {'name', 'eigenvalue', 'status', 'reason', 'participation', 'lonFraction', 'oscillatory'}))
    error('vital:fq:badInput', 'modes must be a vital.linear.modes result.');
end
modes = reshape(modes, 1, []);
end

function [e, st, rs] = pick(modes, name)
% the single mode of that name with status OK, else [] with a status
e = []; st = 'MODE_MISSING'; rs = sprintf('no %s mode', name);
if isempty(modes), return; end
ks = find(strcmp({modes.name}, name));
if isempty(ks), return; end
bad = ks(~strcmp({modes(ks).status}, 'OK'));
if ~isempty(bad)
    st = modes(bad(1)).status; rs = modes(bad(1)).reason;
    if isempty(rs), rs = sprintf('%s mode status %s', name, st); end
    return
end
if numel(ks) > 1
    st = 'MODE_AMBIGUOUS'; rs = sprintf('%d modes named %s', numel(ks), name);
    return
end
e = modes(ks); st = 'OK'; rs = '';
end

function M = put(M, names, value, status, reason)
if ischar(names), names = {names}; end
for k = 1:numel(names)
    M.(names{k}).value = value;
    M.(names{k}).status = status;
    M.(names{k}).reason = reason;
end
end
