function xNew = rk4Step(f, t, x, dt, k1)
%RK4STEP  One classical fourth-order Runge-Kutta step (CONVENTIONS 10).
%   xNew = vital.sim.rk4Step(f, t, x, dt)
%   xNew = vital.sim.rk4Step(f, t, x, dt, k1)   reuse k1 = f(t, x) already computed
%
%   f    xdot = f(tau, xs): continuous right-hand side at stage time tau and
%        stage state xs (column vectors of any length)
%   Butcher tableau (c | A ; b):
%        0   |
%        1/2 | 1/2
%        1/2 | 0    1/2
%        1   | 0    0    1
%        ----+-------------------
%            | 1/6  1/3  1/3  1/6
%   Stage times are t, t + dt/2, t + dt/2, t + dt. Anything discrete (inputs
%   with switches, controllers) must be constant across the four stages; that
%   is the caller's job (vital.sim.run).
%
%   Errors: vital:sim:nanState when a stage state or a stage derivative is not
%   finite (FC-302); the message names the stage. Errors raised by f propagate
%   unchanged (vital.sim.run classifies them).
if nargin < 5 || isempty(k1)
    k1 = f(t, x);
end
check(k1, 1, t, 'derivative');
x2 = x + dt/2 * k1;   check(x2, 2, t, 'state');
k2 = f(t + dt/2, x2); check(k2, 2, t, 'derivative');
x3 = x + dt/2 * k2;   check(x3, 3, t, 'state');
k3 = f(t + dt/2, x3); check(k3, 3, t, 'derivative');
x4 = x + dt * k3;     check(x4, 4, t, 'state');
k4 = f(t + dt, x4);   check(k4, 4, t, 'derivative');
xNew = x + dt/6 * (k1 + 2*k2 + 2*k3 + k4);
end

function check(v, stage, t, what)
if any(~isfinite(v(:)))
    error('vital:sim:nanState', 'RK4 stage %d %s is not finite (step from t = %.6g s).', stage, what, t);
end
end
