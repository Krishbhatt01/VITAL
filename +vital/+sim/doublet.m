function in = doublet(t0, width, amp, channel)
%DOUBLET  Doublet input for vital.sim.run: +amp for width s, then -amp for width s.
%   in = vital.sim.doublet(t0, width, amp, channel)
%
%   t0       start time (s, >= 0)       width  duration of each half (s, > 0)
%   amp      amplitude in the control's own SI unit (rad for surfaces,
%            fraction 0..1 for the throttle); may be negative
%   channel  control index (1..numel(u0)) or name: an entry of AC.controlNames
%            or an alias 'elevator' -> 'de', 'aileron' -> 'da', 'rudder' -> 'dr'
%
%   du(t) = +amp on [t0, t0+width), -amp on [t0+width, t0+2 width), 0 otherwise,
%   added to u0 on that channel. The result is an input SPECIFICATION (struct):
%     kind 'vital.sim.input', name 'doublet', channel, fcn (@(t) scalar value),
%     breakpoints [t0, t0+width, t0+2 width], and the parameters.
%   vital.sim.run requires every breakpoint to lie on a step boundary (a
%   multiple of dt within 1e-6 dt; vital:sim:badStep otherwise) and evaluates
%   the piece that contains each step, so no RK4 stage straddles a switch.
%   Errors: vital:badInput (non-finite or out-of-range arguments).
chk(t0, 't0'); chk(width, 'width'); chk(amp, 'amp');
if t0 < 0, error('vital:badInput', 'doublet start t0 = %g s must be >= 0.', t0); end
if width <= 0, error('vital:badInput', 'doublet width = %g s must be > 0.', width); end
channel = vital.sim.stepInput(0, 0, channel).channel;       % same channel validation
t1 = t0 + width; t2 = t0 + 2*width;
in = struct('kind', 'vital.sim.input', 'name', 'doublet', 'channel', channel, ...
    'fcn', @(t) amp * ((t >= t0 & t < t1) - (t >= t1 & t < t2)), ...
    'breakpoints', [t0 t1 t2], 't0', t0, 'width', width, 'amp', amp);
end

function chk(v, name)
if ~(isnumeric(v) && isscalar(v))
    error('vital:badInput', '%s must be a numeric scalar.', name);
end
vital.validate.finite(v, name);
end
