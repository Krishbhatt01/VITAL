function [y, clamped] = lookup(bps, data, x, extrapolate, lo, hi)
%LOOKUP  Multilinear interpolation in a DAVE-ML gridded table.
%   [y, clamped] = vital.daveml.lookup(bps, data, x, extrapolate, lo, hi)
%     bps          cell array of breakpoint vectors, one per dimension
%     data         table with size(data, k) == numel(bps{k})
%     x            query point, one value per dimension
%     extrapolate  cellstr per dimension: 'neither' | 'min' | 'max' | 'both'
%     lo, hi       independentVarRef min/max per dimension
%   A dimension whose side does not allow extrapolation is CLAMPED to
%   [lo, hi] (and to the breakpoint range); clamped is then true, which the
%   caller reports as OUT_OF_DATA_ENVELOPE (FC-401). Where extrapolation is
%   allowed, the end interval is extended linearly.
%   At a breakpoint the stored datum is returned exactly (weights 1 and 0).
d = numel(bps);
clamped = false;
idx = zeros(1, d); t = zeros(1, d);
for k = 1:d
    bp = bps{k};
    xk = x(k);
    allowLo = any(strcmp(extrapolate{k}, {'min', 'both'}));
    allowHi = any(strcmp(extrapolate{k}, {'max', 'both'}));
    if ~allowLo
        floorK = max(lo(k), bp(1));
        if xk < floorK, xk = floorK; clamped = true; end
    end
    if ~allowHi
        ceilK = min(hi(k), bp(end));
        if xk > ceilK, xk = ceilK; clamped = true; end
    end
    nb = numel(bp);
    if nb == 1
        idx(k) = 1; t(k) = 0;
        continue
    end
    i = find(bp <= xk, 1, 'last');
    if isempty(i), i = 1; end
    if i >= nb, i = nb - 1; end
    idx(k) = i;
    t(k) = (xk - bp(i)) / (bp(i+1) - bp(i));
end
sz = size(data);
if d == 1
    sz = numel(data);
end
y = 0;
for c = 0:(2^d - 1)
    w = 1;
    sub = idx;
    for k = 1:d
        if bitget(c, k)
            w = w * t(k);
            if numel(bps{k}) > 1, sub(k) = idx(k) + 1; end
        else
            w = w * (1 - t(k));
        end
    end
    if w == 0, continue; end
    if d == 1
        lin = sub(1);
    else
        lin = sub(1);
        stride = 1;
        for k = 2:d
            stride = stride * sz(k-1);
            lin = lin + (sub(k) - 1) * stride;
        end
    end
    y = y + w * data(lin);
end
end
