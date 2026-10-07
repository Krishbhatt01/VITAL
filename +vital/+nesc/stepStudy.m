function st = stepStudy(resA, resB)
%STEPSTUDY  Step-size study of a NESC case relative to its pre-registered bands.
%   st = vital.nesc.stepStudy(resA, resB)
%     resA  the run at the working dt (vital.nesc.runCase)
%     resB  the same case at the study dt (possibly shorter: 'tFinal')
%   For every assessable band signal, on the reference times of the
%   comparison of resA (vital.nesc.compare) inside the common window:
%     ratio = max_t |VITAL_A(t) - VITAL_B(t)| / delta(t)
%   (angle differences wrapped to +/-180 deg). The registered criterion
%   (proposed ADR N11) is ratio <= 0.1.
%   st(i): signal, ratio, maxDiff, tWorst, window.
cmp = vital.nesc.compare(resA);
ANGLES = {'eulerAngle_deg_Roll', 'eulerAngle_deg_Pitch', 'eulerAngle_deg_Yaw', 'longitude_deg'};
win = min(resA.t(end), resB.t(end));
st = struct('signal', {}, 'ratio', {}, 'maxDiff', {}, 'tWorst', {}, 'window', {});
for c = cmp(:).'
    if ~any(strcmp(c.status, {'PASS', 'FAIL'})) || isempty(c.tCompared), continue; end
    k = c.tCompared <= win + 1e-9;
    t = min(c.tCompared(k), win); dl = c.delta(k);
    a = interp1(resA.t(:), resA.sig.(c.signal)(:), t);
    b = interp1(resB.t(:), resB.sig.(c.signal)(:), t);
    d = a - b;
    if any(strcmp(c.signal, ANGLES)), d = mod(d + 180, 360) - 180; end
    [ratio, iw] = max(abs(d) ./ dl);
    st(end+1) = struct('signal', c.signal, 'ratio', ratio, 'maxDiff', max(abs(d)), 'tWorst', t(iw), 'window', win); %#ok<AGROW>
end
end
