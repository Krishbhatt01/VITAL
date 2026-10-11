function [D, p] = mahalanobis(theta, nominal, sigma, opts)
%MAHALANOBIS  Mahalanobis distance of parameter points under independent normal
%   multipliers N(nominal, sigma) (M8; review R3 M5).
%   [D, p] = vital.uq.mahalanobis(theta, nominal, sigma)
%   [D, p] = vital.uq.mahalanobis(theta, nominal, sigma, 'Dof', k)
%   theta    n x d points (one per row); nominal, sigma 1 x d (sigma > 0)
%   D        n x 1: sqrt(sum(((theta - nominal) ./ sigma).^2, 2))
%   p        n x 1: P(chi2_k >= D^2), the probability of a point at least as
%            far out; k = Dof (default d). Use Dof = the number of parameters
%            that were free (e.g. 2 for a longitudinal-only search).
%   A NaN theta gives NaN.
%   Errors: vital:badInput (size mismatch, sigma not finite > 0, Dof not a
%   positive integer).
arguments
    theta (:,:) double
    nominal (1,:) double
    sigma (1,:) double
    opts.Dof (1,1) double = NaN
end
d = numel(nominal);
if size(theta, 2) ~= d || numel(sigma) ~= d
    error('vital:badInput', 'theta (n x d), nominal and sigma (1 x d) must have the same d.');
end
if any(~isfinite(sigma)) || any(sigma <= 0)
    error('vital:badInput', 'sigma must be finite and > 0.');
end
k = opts.Dof;
if isnan(k), k = d; end
if ~(isfinite(k) && k >= 1 && k == round(k))
    error('vital:badInput', 'Dof must be a positive integer.');
end
D = sqrt(sum(((theta - nominal) ./ sigma).^2, 2));
p = chi2cdf(D.^2, k, 'upper');
end
