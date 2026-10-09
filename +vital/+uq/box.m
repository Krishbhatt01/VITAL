function B = box(spec, opts)
%BOX  The joint-coverage box of an uncertainty specification (M8).
%   B = vital.uq.box(spec)                       judgment widths (x1)
%   B = vital.uq.box(spec, 'WidthScale', 1.5)    every sigma times 1.5
%
%   Per group g with d_g parameters: half-width h_i = w k_g sigma_i,
%   k_g = sqrt(chi2inv(coverage, d_g)), so the box |theta_i - 1| <= h_i contains
%   the group's joint ellipsoid sum((theta_i - 1)^2 / (w sigma_i)^2) <= k_g^2
%   (its extent along each axis is exactly k_g w sigma_i). The full box is the
%   product of the group boxes. Nominal: every multiplier 1.
%   B fields: names, aeroScale, term, group (per parameter), sigma (the spec's),
%     sigmaEff (w sigma), kg, halfWidth, lo, hi, nominal (ones), widthScale,
%     coverage, label ('JUDGMENT').
%   Errors: vital:badInput (WidthScale not finite > 0);
%   vital:uq:negativeMultiplier (a lower bound below 0: an AeroScale multiplier
%   must be >= 0).
arguments
    spec (1,1) struct
    opts.WidthScale (1,1) double = 1
end
w = opts.WidthScale;
if ~(isfinite(w) && w > 0)
    error('vital:badInput', 'WidthScale must be a finite number > 0.');
end
P = spec.parameters;
B.names = {P.name};
B.aeroScale = {P.aeroScale};
B.term = {P.term};
B.group = {P.group};
B.sigma = [P.sigma];
B.sigmaEff = w * B.sigma;
B.kg = [P.kg];
B.halfWidth = w * B.kg .* B.sigma;
B.lo = 1 - B.halfWidth;
B.hi = 1 + B.halfWidth;
B.nominal = ones(1, numel(P));
B.widthScale = w;
B.coverage = spec.coverage;
B.label = spec.label;
if any(B.lo < 0)
    k = find(B.lo < 0, 1);
    error('vital:uq:negativeMultiplier', ['WidthScale %g: the lower bound of %s is %g < 0 (an AeroScale ' ...
        'multiplier must be >= 0).'], w, B.names{k}, B.lo(k));
end
end
