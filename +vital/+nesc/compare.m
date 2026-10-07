function cmp = compare(res, opts)
%COMPARE  Pre-registered envelope comparison of a VITAL run with the NESC simulations.
%   cmp = vital.nesc.compare(res)                  res from vital.nesc.runCase
%   cmp = vital.nesc.compare(res, 'Reference', ref) ref from vital.nesc.reference
%
%   For every band entry of the case in docs/NESC_CASE_MATRIX.json (ADR-009/015;
%   mechanics = proposed ADR N8):
%     - included sims = the case's sims minus the band's exclude_sims, that
%       record the signal (a sim without the column is skipped);
%     - VITAL is linearly interpolated onto each sim's own time stamps and the
%       residual ref_s - VITAL is formed; angle residuals (Euler angles,
%       longitude) are wrapped to (-180, 180] deg;
%     - vital.verify.envelopeCheck on tBase = the first included sim's times,
%       refScale = max |ref| over the included sims, with the band exactly as
%       registered (floor, rel_floor, k).
%   cmp(i): signal, unit, sims, status 'PASS' | 'FAIL' | 'NOT_ASSESSABLE', reason,
%           worst (envelope excess; <= 0 inside), tWorst, deltaAtWorst,
%           normWorst = worst/deltaAtWorst, tCompared, delta, refScale.
%   A VITAL run shorter than the case duration fails every signal. A NaN in
%   the VITAL series at a compared time fails the signal (reason given).
arguments
    res (1,1) struct
    opts.Reference struct = struct([])
end
cd = res.caseDef;
ref = opts.Reference;
if isempty(ref), ref = vital.nesc.reference(cd.id); end
ANGLES = {'eulerAngle_deg_Roll', 'eulerAngle_deg_Pitch', 'eulerAngle_deg_Yaw', 'longitude_deg'};
short = res.t(end) < cd.duration - 1e-9;
cmp = struct('signal', {}, 'unit', {}, 'sims', {}, 'status', {}, 'reason', {}, 'worst', {}, 'tWorst', {}, ...
    'deltaAtWorst', {}, 'normWorst', {}, 'tCompared', {}, 'delta', {}, 'refScale', {});
for b = cd.band(:).'
    c = struct('signal', b.signal, 'unit', b.unit, 'sims', [], 'status', '', 'reason', '', 'worst', NaN, ...
        'tWorst', NaN, 'deltaAtWorst', NaN, 'normWorst', NaN, 'tCompared', [], 'delta', [], 'refScale', NaN);
    incl = setdiff(cd.sims, b.exclude_sims, 'stable');
    T = {}; R = {}; scale = 0; used = [];
    bad = '';
    for s = incl
        j = find([ref.sim] == s, 1);
        if isempty(j) || ~any(strcmp(ref(j).columns, b.signal)), continue; end
        ts = ref(j).t(:); vs = ref(j).data.(b.signal)(:);
        ok = isfinite(ts) & isfinite(vs);
        ts = ts(ok); vs = vs(ok);
        % reference stamps a few ulps past the end (sim 6: 30.00000000001368 s) are
        % evaluated at VITAL's end point; anything further is a genuine gap (NaN)
        tq = ts; tq(tq > res.t(end) & tq <= res.t(end) + 1e-6) = res.t(end);
        vit = interp1(res.t(:), res.sig.(b.signal)(:), tq, 'linear');
        if any(~isfinite(vit))
            bad = sprintf('VITAL %s is not finite at a compared time of sim %d', b.signal, s);
            break
        end
        r = vs - vit;
        if any(strcmp(b.signal, ANGLES)), r = mod(r + 180, 360) - 180; end
        T{end+1} = ts; R{end+1} = r; %#ok<AGROW>
        scale = max(scale, max(abs(vs)));
        used(end+1) = s; %#ok<AGROW>
    end
    c.sims = used;
    if short
        c.status = 'FAIL'; c.reason = sprintf('VITAL run ended at %.4g s < duration %.4g s (%s)', res.t(end), cd.duration, res.stopReason);
    elseif ~isempty(bad)
        c.status = 'FAIL'; c.reason = bad;
    elseif isempty(used)
        c.status = 'NOT_ASSESSABLE';
        c.reason = sprintf('no included reference simulation (%s) records %s', mat2str(incl), b.signal);
    else
        e = vital.verify.envelopeCheck(T{1}, T, R, b, scale);
        [~, iw] = min(abs(e.tCompared - e.tWorst));
        c.worst = e.worst; c.tWorst = e.tWorst; c.deltaAtWorst = e.delta(iw);
        c.normWorst = e.worst / e.delta(iw);
        c.tCompared = e.tCompared; c.delta = e.delta; c.refScale = scale;
        if e.pass, c.status = 'PASS'; else, c.status = 'FAIL'; end
    end
    cmp(end+1) = c; %#ok<AGROW>
end
end
