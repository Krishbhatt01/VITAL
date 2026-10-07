function [x, t] = rk4(f, x0, dt, N)
%RK4  Generic fixed-step classical RK4 integration (CONVENTIONS 10).
%   [x, t] = vital.sim.rk4(f, x0, dt, N)
%
%   f    xdot = f(t, x), continuous and smooth (for 4th order)
%   x0   initial state (column vector, any length)
%   dt   step (s, finite, > 0);  N  number of steps (positive integer)
%   x    states, numel(x0) x (N+1), column k+1 at t(k+1) = k*dt (no
%        accumulated time drift);  t  1 x (N+1)
%
%   The step itself is vital.sim.rk4Step, the same core vital.sim.run uses,
%   so the order tests (tests/M5/tSimCore) exercise the simulation's
%   integrator. Errors: vital:sim:badStep (bad dt or N; FC-301),
%   vital:badInput (bad x0 or f), vital:sim:nanState (non-finite stage; FC-302).
if ~(isnumeric(dt) && isscalar(dt) && isreal(dt) && isfinite(dt) && dt > 0)
    error('vital:sim:badStep', 'dt must be a finite positive scalar.');
end
if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N >= 1 && N == round(N))
    error('vital:sim:badStep', 'N must be a positive integer number of steps.');
end
if ~isnumeric(x0) || isempty(x0) || ~isvector(x0)
    error('vital:badInput', 'x0 must be a non-empty numeric vector.');
end
vital.validate.finite(x0, 'x0');
if ~isa(f, 'function_handle')
    error('vital:badInput', 'f must be a function handle xdot = f(t, x).');
end
x = zeros(numel(x0), N + 1);
x(:, 1) = x0(:);
t = (0:N) * dt;
for k = 1:N
    x(:, k+1) = vital.sim.rk4Step(f, t(k), x(:, k), dt);
end
end
