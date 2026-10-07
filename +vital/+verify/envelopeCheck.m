function r = envelopeCheck(tBase, tSims, resSims, spec, refScale)
%ENVELOPECHECK  Pre-registered comparison against multiple reference simulations (ADR-009).
%   r = vital.verify.envelopeCheck(tBase, tSims, resSims, spec, refScale)
%     tBase    common time base (column), usually the first included sim's times
%     tSims    cell array: time vector of each reference simulation
%     resSims  cell array: residual ref_s(t) - VITAL(t) for each simulation
%     spec     struct with floor, rel_floor, k (from NESC_CASE_MATRIX.json)
%     refScale max |reference| over the run (sets the relative floor)
%   Each residual is interpolated linearly onto tBase; only times covered
%   by every simulation are compared. At each time t
%     lo = min_s r_s - delta,  hi = max_s r_s + delta,
%     delta = max(floor, rel_floor*refScale, k*(max_s r_s - min_s r_s)),
%   and VITAL passes where 0 is in [lo, hi], i.e. VITAL lies inside the
%   NASA simulations' envelope widened by delta.
%   r.pass, r.worst (max over t of max(lo, -hi); <= 0 passes), r.tWorst,
%   r.tCompared, r.lo, r.hi, r.delta.
%   Errors: vital:verify:noReference (no simulations), vital:badInput.
if isempty(tSims) || isempty(resSims) || numel(tSims) ~= numel(resSims)
    error('vital:verify:noReference', 'no reference simulations to compare against.');
end
vital.validate.finite(tBase, 'time base');
vital.validate.finite([spec.floor spec.rel_floor spec.k refScale], 'band specification');
tBase = tBase(:);
tLo = -Inf; tHi = Inf;
for s = 1:numel(tSims)
    vital.validate.finite(tSims{s}, sprintf('time of reference %d', s));
    vital.validate.finite(resSims{s}, sprintf('residual of reference %d', s));
    tLo = max(tLo, min(tSims{s})); tHi = min(tHi, max(tSims{s}));
end
keep = tBase >= tLo - 1e-9 & tBase <= tHi + 1e-9;
tc = tBase(keep);
Rm = zeros(numel(tc), numel(tSims));
for s = 1:numel(tSims)
    [tu, iu] = unique(tSims{s}(:));
    rs = resSims{s}(:);
    if isscalar(tu)
        Rm(:, s) = rs(iu);          % single-instant reference (e.g. a trim at t = 0)
    else
        Rm(:, s) = interp1(tu, rs(iu), min(max(tc, tu(1)), tu(end)), 'linear');
    end
end
mn = min(Rm, [], 2); mx = max(Rm, [], 2);
delta = max(max(spec.floor, spec.rel_floor * refScale), spec.k * (mx - mn));
lo = mn - delta; hi = mx + delta;
excess = max(lo, -hi);
[worst, iw] = max(excess);
r.pass = worst <= 0;
r.worst = worst;
r.tWorst = tc(iw);
r.tCompared = tc;
r.lo = lo; r.hi = hi; r.delta = delta;
end
