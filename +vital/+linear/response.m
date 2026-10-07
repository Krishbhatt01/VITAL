function DX = response(lin, dx0, t)
%RESPONSE  Free response of the linear model, dx(t) = expm(A t) dx0.
%   DX = vital.linear.response(lin, dx0, t)
%     lin  a linear model with field A (n x n), e.g. vital.linear.linearize
%          (open or closed loop)
%     dx0  initial deviation (n x 1)
%     t    times (s), increasing, starting at 0 or later
%     DX   n x numel(t)
%   Uniformly spaced t (to 1e-9 relative) uses the exact one-step transition
%   Phi = expm(A dt), so DX(:,k+1) = Phi DX(:,k) and DX(:,1) = expm(A t1) dx0.
%   Otherwise expm(A t_k) is evaluated for every sample.
%   Errors: vital:badInput (non-finite A, size mismatch, t not increasing).
arguments
    lin (1,1) struct
    dx0 double
    t double
end
if ~isfield(lin, 'A'), error('vital:badInput', 'lin must have a field A.'); end
A = lin.A; n = size(A, 1);
vital.validate.finite(A, 'A');
vital.validate.finite(dx0, 'dx0');
vital.validate.finite(t, 't');
if size(A, 2) ~= n || numel(dx0) ~= n
    error('vital:badInput', 'A must be square and dx0 must have %d elements.', n);
end
t = t(:).';
if isempty(t) || any(diff(t) <= 0)
    error('vital:badInput', 't must be non-empty and strictly increasing.');
end
DX = zeros(n, numel(t));
DX(:, 1) = expm(A * t(1)) * dx0(:);
if numel(t) == 1, return; end
d = diff(t);
if max(abs(d - d(1))) <= 1e-9 * d(1)
    Phi = expm(A * d(1));
    for k = 2:numel(t)
        DX(:, k) = Phi * DX(:, k-1);
    end
else
    for k = 2:numel(t)
        DX(:, k) = expm(A * t(k)) * dx0(:);
    end
end
end
