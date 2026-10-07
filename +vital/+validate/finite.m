function finite(x, name)
%FINITE  Reject non-numeric, NaN or Inf input with vital:badInput (FC-101).
%   vital.validate.finite(x, 'name') is called at the top of every public
%   VITAL function, so a NaN never propagates silently into the physics.
if ~(isnumeric(x) || islogical(x)) || ~isreal(x) || any(~isfinite(x(:)))
    error('vital:badInput', '%s must be finite real numeric input.', name);
end
end
