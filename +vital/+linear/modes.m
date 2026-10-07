function m = modes(lin, opts)
%MODES  Eigen-analysis and classification of the flight modes of a linear model.
%   m = vital.linear.modes(lin)
%   m = vital.linear.modes(lin, 'IncludeHeight', true)
%
%   lin  a vital.linear.linearize result. By default only lin.A(1:8, 1:8), the
%        dynamic states [u v w p q r phi theta], is used (psi, pN, pE are
%        kinematic integrals; h is excluded, per the contract).
%        Status: lin.status 'OK', OR lin.status NOT_CONVERGED with
%        lin.columnStatus 'OK' for every column used (1-8, plus 12 with
%        IncludeHeight; review R1 M1). A failed column elsewhere, e.g. the h column
%        at a thrust-table altitude breakpoint, does not affect the result.
%        Otherwise vital:linear:notConverged.
%   DEFAULT PHUGOID (review R1 M5): the default is the 8-state model of the
%        contract. Its phugoid omits the altitude coupling and is optimistic in
%        damping (README: zeta 0.095 vs 0.078 with h). Phugoid requirements
%        (M6) use IncludeHeight = true; run_f16_modes prints both, labelled.
%   'IncludeHeight'  true: use [u v w p q r phi theta h] (x_lin 1:8 and 12). The
%        density and thrust gradients with altitude couple h into the phugoid:
%        at the NESC README trim the phugoid moves from -0.0071 +/- 0.0745i
%        (8 states) to -0.0062 +/- 0.0801i, which is what the nonlinear plant
%        shows (tests/M5/tLinearVsNonlinear.m). The extra real root is named
%        'height' (the lon real root in which h has the largest participation);
%        participation then has 9 entries (h last) and h counts as longitudinal.
%
%   Longitudinal vs lateral, and the name of a mode, are decided by PARTICIPATION
%   FACTORS p_k = |v_k w_k| (right eigenvector v, left eigenvector w = row of
%   inv(V)), normalized to sum 1 per mode. They are invariant under a change of
%   units of the states (a diagonal similarity), unlike raw eigenvector
%   magnitudes, which the AAMF classifier (StabilityAnalysis.m:448-696) used.
%   lonFraction = sum of p over {u w q theta}; a mode is longitudinal if > 0.5.
%
%   Naming (roots counted with multiplicity, pairs reported once with Im > 0):
%     longitudinal, 2 pairs     faster |lambda| = short_period, slower = phugoid
%     longitudinal, 1 pair + 2 real roots
%                               the pair is short_period if p_w + p_q > p_u + p_theta,
%                               else phugoid; the two real roots take the other
%                               name with status NOT_OSCILLATORY (FC-507: e.g. a
%                               short period split into real roots)
%     longitudinal, 4 real      fastest two short_period, slowest two phugoid, all
%                               NOT_OSCILLATORY
%     lateral, pairs            the pair with the largest p_v + p_r = dutch_roll;
%                               any other pair (e.g. a roll-spiral oscillation) is
%                               'other', UNCLASSIFIED
%     lateral, real roots       with a Dutch-roll pair: faster = roll, slower =
%                               spiral; with none (split Dutch roll, 4 real roots):
%                               fastest = roll, slowest = spiral, the middle two
%                               dutch_roll NOT_OSCILLATORY
%     A phugoid pair next to a split short period whose p_w + p_q > 0.2 keeps
%     its name and status, with a reason noting that it may be the coupled
%     "third oscillatory" mode (aft CG; review R1 MINOR 5).
%     Each name is checked against its participation signature (short period
%     p_w + p_q > p_u + p_theta, phugoid the reverse, Dutch roll p_v + p_r >
%     p_p + p_phi, roll p_p largest, spiral p_phi or p_r largest). A mode failing
%     its signature, or any other root pattern, is 'other' with status UNCLASSIFIED.
%
%   m (struct array, order short_period, phugoid, dutch_roll, roll, spiral, other)
%     name, eigenvalue (Im >= 0), oscillatory
%     wn = |lambda|, zeta = -Re/|lambda| (negative when unstable), period = 2 pi/Im
%       (oscillatory only; NaN otherwise, never a value for a NOT_OSCILLATORY mode)
%     tHalf = ln2/(-Re) if stable, tDouble = ln2/Re if unstable (the other NaN)
%     tau = -1/lambda for real roots (negative = unstable; NaN for pairs)
%     participation (8 x 1, order u v w p q r phi theta, sums to 1; 9 x 1 with h)
%     dominant (states in descending participation until 80 % is covered)
%     lonFraction, status (OK | NOT_OSCILLATORY | UNCLASSIFIED), reason
%   Design constants (not published values; ADR-023): lonFraction threshold 0.5,
%   "dominant" = 80 % cumulative participation, oscillatory if |Im| > 1e-9
%   |lambda|, cond(V) > 1e10 means UNCLASSIFIED, third-oscillatory note at
%   p_w + p_q > 0.2.
%   Errors: vital:linear:notConverged (a used column not converged, or no
%   status); vital:badInput (missing or non-finite A).
arguments
    lin (1,1) struct
    opts.IncludeHeight (1,1) logical = false
end
if opts.IncludeHeight, used = [1:8 12]; else, used = 1:8; end
if ~isfield(lin, 'status') || ~strcmp(lin.status, 'OK')
    st = '(none)'; if isfield(lin, 'status'), st = char(lin.status); end
    usable = isfield(lin, 'columnStatus') && numel(lin.columnStatus) >= 12 && ...
        all(strcmp(lin.columnStatus(used), 'OK'));
    if ~usable
        bad = '';
        if isfield(lin, 'columnStatus') && numel(lin.columnStatus) >= 12
            k = used(~strcmp(lin.columnStatus(used), 'OK'));
            bad = sprintf(' (failed columns used here: %s)', strjoin(arrayfun(@num2str, k, 'UniformOutput', false), ', '));
        end
        error('vital:linear:notConverged', 'linear model status is %s, not OK%s: no modal analysis.', st, bad);
    end
end
if ~isfield(lin, 'A') || size(lin.A, 1) < 8 || size(lin.A, 2) < 8
    error('vital:badInput', 'lin.A must be at least 8 x 8.');
end
if opts.IncludeHeight
    if size(lin.A, 1) < 12 || size(lin.A, 2) < 12
        error('vital:badInput', 'IncludeHeight needs the 12-state lin.A.');
    end
    sel = [1:8 12];
else
    sel = 1:8;
end
A = lin.A(sel, sel);
vital.validate.finite(A, 'A (dynamic states)');
names8 = {'u','v','w','p','q','r','phi','theta','h'};
names8 = names8(1:numel(sel));
LON = [1 3 5 8 9];
LON = LON(LON <= numel(sel));
ih = 9;
[iu, iv, iw, ip, iq, ir, iphi, ith] = deal(1, 2, 3, 4, 5, 6, 7, 8);

[V, D] = eig(A);
lam = diag(D);
Wl = inv(V);
P = abs(V .* Wl.');                        % P(k, i): state k in mode i
P = P ./ sum(P, 1);
condV = cond(V);

% ---- one entry per real root / conjugate pair ------------------------------------
tolIm = 1e-9;
keep = find(imag(lam) > tolIm * abs(lam) | abs(imag(lam)) <= tolIm * abs(lam));
tmpl = struct('name', 'other', 'eigenvalue', 0, 'oscillatory', false, 'wn', NaN, 'zeta', NaN, ...
    'period', NaN, 'tHalf', NaN, 'tDouble', NaN, 'tau', NaN, 'participation', zeros(numel(sel), 1), ...
    'dominant', {{}}, 'lonFraction', NaN, 'status', 'UNCLASSIFIED', 'reason', '');
m = repmat(tmpl, 1, numel(keep));
for k = 1:numel(keep)
    i = keep(k); l = lam(i);
    e = tmpl;
    e.oscillatory = abs(imag(l)) > tolIm * abs(l);
    if e.oscillatory
        e.eigenvalue = l;
    else
        e.eigenvalue = real(l);
    end
    s = real(l);
    if s < 0, e.tHalf = log(2) / -s; elseif s > 0, e.tDouble = log(2) / s; end
    if e.oscillatory
        e.wn = abs(l); e.zeta = -s / abs(l); e.period = 2 * pi / abs(imag(l));
    elseif s ~= 0
        e.tau = -1 / s;
    else
        e.tau = Inf;
    end
    e.participation = P(:, i);
    e.lonFraction = sum(P(LON, i));
    [ps, order] = sort(P(:, i), 'descend');
    nd = find(cumsum(ps) >= 0.8 - 1e-12, 1);
    e.dominant = names8(order(1:nd));
    m(k) = e;
end

if condV > 1e10
    [m.status] = deal('UNCLASSIFIED');
    [m.reason] = deal(sprintf('eigenvector matrix is ill-conditioned (cond %.3g): repeated or defective eigenvalues', condV));
    m = sortModes(m);
    return
end

isLon = [m.lonFraction] > 0.5;
osc = [m.oscillatory];
spScore = @(e) e.participation(iw) + e.participation(iq);
phScore = @(e) e.participation(iu) + e.participation(ith);

% ---- longitudinal ------------------------------------------------------------------
L = find(isLon);
if opts.IncludeHeight
    Lr0 = L(~osc(L));
    if ~isempty(Lr0)
        [~, kh] = max(arrayfun(@(k) m(k).participation(ih), Lr0));
        kh = Lr0(kh);
        [~, top] = max(m(kh).participation);
        if top == ih
            m(kh).name = 'height'; m(kh).status = 'OK';
            m(kh).reason = 'height mode (altitude-density/thrust coupling)';
            L = L(L ~= kh);
        end
    end
end
Lp = L(osc(L)); Lr = L(~osc(L));
if numel(Lp) == 2 && isempty(Lr)
    [~, o] = sort(arrayfun(@(k) abs(m(k).eigenvalue), Lp), 'descend');
    m = name(m, Lp(o(1)), 'short_period', 'OK');
    m = name(m, Lp(o(2)), 'phugoid', 'OK');
elseif numel(Lp) == 1 && numel(Lr) == 2
    if spScore(m(Lp)) > phScore(m(Lp)), pn = 'short_period'; rn = 'phugoid';
    else, pn = 'phugoid'; rn = 'short_period'; end
    m = name(m, Lp, pn, 'OK');
    if strcmp(pn, 'phugoid') && spScore(m(Lp)) > 0.2
        m(Lp).reason = sprintf(['the short period is split and this pair has p_w + p_q = %.2f: it may be ' ...
            'the coupled "third oscillatory" mode rather than a classical phugoid'], spScore(m(Lp)));
    end
    for k = Lr, m = name(m, k, rn, 'NOT_OSCILLATORY'); end
elseif isempty(Lp) && numel(Lr) == 4
    [~, o] = sort(abs([m(Lr).eigenvalue]), 'descend');
    for k = Lr(o(1:2)), m = name(m, k, 'short_period', 'NOT_OSCILLATORY'); end
    for k = Lr(o(3:4)), m = name(m, k, 'phugoid', 'NOT_OSCILLATORY'); end
else
    for k = L
        m(k).reason = sprintf('unexpected longitudinal root pattern (%d pairs, %d real)', numel(Lp), numel(Lr));
    end
end
% signature checks (group-wise, so a split pair is judged by both roots together)
for nm = {'short_period', 'phugoid'}
    ks = find(strcmp({m.name}, nm{1}));
    if isempty(ks), continue; end
    a = sum(arrayfun(@(k) spScore(m(k)), ks)); b = sum(arrayfun(@(k) phScore(m(k)), ks));
    ok = (strcmp(nm{1}, 'short_period') && a > b) || (strcmp(nm{1}, 'phugoid') && b > a);
    if ~ok
        for k = ks
            m = unclassify(m, k, sprintf('named %s by time scale but its participation (w+q %.2f, u+theta %.2f) does not match', nm{1}, a, b));
        end
    end
end

% ---- lateral -----------------------------------------------------------------------
T = find(~isLon); Tp = T(osc(T)); Tr = T(~osc(T));
drScore = @(k) m(k).participation(iv) + m(k).participation(ir);
if ~isempty(Tp)
    [~, kd] = max(arrayfun(drScore, Tp));
    kdr = Tp(kd);
    m = name(m, kdr, 'dutch_roll', 'OK');
    for k = Tp(Tp ~= kdr)
        m = unclassify(m, k, 'second lateral oscillatory pair (e.g. roll-spiral coupled oscillation)');
    end
    if numel(Tr) == 2
        [~, o] = sort(abs([m(Tr).eigenvalue]), 'descend');
        m = name(m, Tr(o(1)), 'roll', 'OK');
        m = name(m, Tr(o(2)), 'spiral', 'OK');
    else
        for k = Tr, m = unclassify(m, k, sprintf('unexpected lateral root pattern (%d pairs, %d real)', numel(Tp), numel(Tr))); end
    end
elseif numel(Tr) == 4
    [~, o] = sort(abs([m(Tr).eigenvalue]), 'descend');
    m = name(m, Tr(o(1)), 'roll', 'OK');
    for k = Tr(o(2:3)), m = name(m, k, 'dutch_roll', 'NOT_OSCILLATORY'); end
    m = name(m, Tr(o(4)), 'spiral', 'OK');
else
    for k = Tr, m = unclassify(m, k, sprintf('unexpected lateral root pattern (%d pairs, %d real)', numel(Tp), numel(Tr))); end
end
% signature checks
ks = find(strcmp({m.name}, 'dutch_roll'));
if ~isempty(ks)
    a = sum(arrayfun(drScore, ks));
    b = sum(arrayfun(@(k) m(k).participation(ip) + m(k).participation(iphi), ks));
    if ~(a > b)
        for k = ks, m = unclassify(m, k, sprintf('Dutch roll signature failed (v+r %.2f <= p+phi %.2f)', a, b)); end
    end
end
for k = find(strcmp({m.name}, 'roll'))
    [~, top] = max(m(k).participation);
    if top ~= ip, m = unclassify(m, k, sprintf('roll signature failed (largest participation %s)', names8{top})); end
end
for k = find(strcmp({m.name}, 'spiral'))
    [~, top] = max(m(k).participation);
    if ~any(top == [iphi ir]), m = unclassify(m, k, sprintf('spiral signature failed (largest participation %s)', names8{top})); end
end
m = sortModes(m);
end

function m = name(m, k, nm, status)
m(k).name = nm;
m(k).status = status;
switch status
    case 'NOT_OSCILLATORY'
        m(k).reason = sprintf('%s is not oscillatory: real root %.6g 1/s (no frequency or damping)', nm, real(m(k).eigenvalue));
        m(k).wn = NaN; m(k).zeta = NaN; m(k).period = NaN;
    otherwise
        m(k).reason = '';
end
end

function m = unclassify(m, k, why)
m(k).name = 'other';
m(k).status = 'UNCLASSIFIED';
m(k).reason = why;
end

function m = sortModes(m)
ORDER = {'short_period', 'phugoid', 'height', 'dutch_roll', 'roll', 'spiral', 'other'};
[~, r] = ismember({m.name}, ORDER);
[~, o] = sortrows([r(:), -abs([m.eigenvalue]).']);
m = m(o);
end
