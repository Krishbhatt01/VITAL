function c = boxCoverage(B)
%BOXCOVERAGE  Probability content of the M8 box under the analysis' own normal
%   model (review R3 m2).
%   c = vital.uq.boxCoverage(B)      B from vital.uq.box
%   Per parameter the box half-width is k_g w sigma and the Monte Carlo sigma is
%   w sigma, so P(|theta_i - 1| <= h_i) = erf(k_g/sqrt2) whatever the width
%   scale w. Per group (d_g independent parameters): erf(k_g/sqrt2)^d_g (0.99
%   for d = 1, 0.9952 for d = 2 at coverage 0.99): the group box contains the
%   group's 99 % ellipsoid and holds a little more. Joint box: the product over
%   all parameters (0.9707 for the four groups of uq/f16_uncertainty.json).
%   c fields: joint, groups (name, d, kg, coverage), note.
arguments
    B (1,1) struct
end
pp = erf(B.kg / sqrt(2));                        % half-width / Monte Carlo sigma = k_g at every width
[gn, ~, ig] = unique(B.group, 'stable');
c.groups = struct('name', {}, 'd', {}, 'kg', {}, 'coverage', {});
for g = 1:numel(gn)
    in = ig(:).' == g;
    c.groups(g) = struct('name', gn{g}, 'd', sum(in), 'kg', B.kg(find(in, 1)), 'coverage', prod(pp(in)));
end
c.joint = prod(pp);
c.note = sprintf(['joint probability content of the box %.4f (product of the group boxes; the same at every width, ' ...
    'because the box and the Monte Carlo sigma scale together)'], c.joint);
end
