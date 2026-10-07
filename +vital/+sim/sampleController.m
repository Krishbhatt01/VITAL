function [u, state, stop] = sampleController(ctrl, t, x, y, uref, state, nu)
%SAMPLECONTROLLER  One sample of a discrete controller, as vital.sim.run takes it (ADR-026).
%   [u, state, stop] = vital.sim.sampleController(ctrl, t, x, y, uref, state, nu)
%
%   ctrl   controller struct {rate_hz, init, step}; step is called as
%          [u, state] = ctrl.step(t, x, y, uref, state)
%   y      the plant output the controller measures. Under ADR-026 the caller
%          evaluates it at (x_k, u_applied), u_applied being the command held
%          over the step that ends at t_k (u_ref(0) = u0 + du(0) at k = 0).
%   nu     number of controls the output must have
%
%   Returns the new command u (nu x 1), the new controller state, and stop:
%     []                                   a valid sample
%     struct(reason, identifier, message)  the sample must stop the run:
%       reason 'vital:sim:controllerError'  step raised an error (its identifier
%                                           and message are kept)
%       reason 'vital:sim:nanState'         the output is not finite (FC-302)
%   Errors: vital:badInput when the output is not nu real numbers (a wiring
%   error of the controller, not a flight condition).
%   Shared by vital.sim.run and by tests that re-state its semantics.
stop = [];
try
    [uc, state] = ctrl.step(t, x, y, uref, state);
catch err
    u = nan(nu, 1);
    stop = struct('reason', 'vital:sim:controllerError', 'identifier', err.identifier, ...
        'message', err.message);
    return
end
if ~(isnumeric(uc) && numel(uc) == nu && isreal(uc))
    error('vital:badInput', 'controller returned %d values; expected %d real numbers.', numel(uc), nu);
end
u = double(uc(:));
if any(~isfinite(u))
    stop = struct('reason', 'vital:sim:nanState', 'identifier', 'vital:sim:nanState', ...
        'message', sprintf('controller output is not finite at t = %.6g s', t));
end
end
