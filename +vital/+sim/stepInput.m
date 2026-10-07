function in = stepInput(t0, amp, channel)
%STEPINPUT  Step input for vital.sim.run: +amp from t0 on.
%   in = vital.sim.stepInput(t0, amp, channel)
%
%   t0       switch time (s, >= 0)
%   amp      step size in the control's own SI unit (rad for surfaces,
%            fraction 0..1 for the throttle); may be negative
%   channel  control index (1..numel(u0)) or name: an entry of AC.controlNames
%            or an alias 'elevator' -> 'de', 'aileron' -> 'da', 'rudder' -> 'dr'
%
%   du(t) = amp for t >= t0, 0 before; added to u0 on that channel. Returns an
%   input SPECIFICATION (kind 'vital.sim.input', name 'step', channel, fcn,
%   breakpoints = t0, t0, amp). vital.sim.run requires t0 to be a multiple of
%   dt (within 1e-6 dt; vital:sim:badStep otherwise), so the step switches
%   exactly on a step boundary and no RK4 stage straddles it.
%   Errors: vital:badInput (non-finite t0/amp, t0 < 0, bad channel).
for a = {t0, 't0'; amp, 'amp'}.'
    if ~(isnumeric(a{1}) && isscalar(a{1}))
        error('vital:badInput', '%s must be a numeric scalar.', a{2});
    end
    vital.validate.finite(a{1}, a{2});
end
if t0 < 0, error('vital:badInput', 'step time t0 = %g s must be >= 0.', t0); end
if isstring(channel) && isscalar(channel), channel = char(channel); end
okName = ischar(channel) && ~isempty(channel) && isrow(channel);
okIndex = isnumeric(channel) && isscalar(channel) && isfinite(channel) && channel >= 1 && channel == round(channel);
if ~(okName || okIndex)
    error('vital:badInput', 'channel must be a control name or a positive integer index.');
end
in = struct('kind', 'vital.sim.input', 'name', 'step', 'channel', channel, ...
    'fcn', @(t) amp * (t >= t0), 'breakpoints', t0, 't0', t0, 'amp', amp);
end
