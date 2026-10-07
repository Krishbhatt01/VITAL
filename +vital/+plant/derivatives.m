function [xdot, y] = derivatives(x, u, AC, env)
%DERIVATIVES  The single physics entry point: state derivative of the aircraft.
%   [xdot, y] = vital.plant.derivatives(x, u, AC, env)
%     x    [v_b (3) m/s; w_b (3) rad/s; q (4) scalar-first N->B; p_n (3) m NED]
%     u    controls [de; da; dr; throttle] (rad, rad, rad, 0..1)
%     AC   aircraft configuration (e.g. vital.aircraft.f16.config) with loadsFcn
%     env  struct: g (m/s^2, flat-earth gravity), wind_n (3x1 NED m/s), deltaT (K)
%   Pipeline (docs/CONVENTIONS.md):
%     atmosphere (US 1976 at h = -p_n(3)) -> air data -> AC.loadsFcn (loads about
%     the BFRP) -> sum at the CG with gravity -> rigid-body equations.
%   y   diagnostics: V, alpha, beta, mach, qbar, h, loads, F_b, M_cg, outOfEnvelope
%       Added in M5-B for time simulation (vital.sim.run guards and logs):
%       quatNorm  norm of the INCOMING quaternion x(7:10) (before the plant
%                 normalises it for the DCM); guard FC-601
%       phi, theta, psi  3-2-1 Euler angles (rad) of C_bn from the normalised
%                 quaternion (vital.frames.dcm2eul; output only, never integrated)
%       p, q, r   body rates x(4:6) (rad/s)
%       specificForce_b  (aero + propulsive force)/m in body axes (m/s^2): the
%                 non-gravitational acceleration an accelerometer at the CG reads
%       nz        body-axis normal load factor = -specificForce_b(3) / env.g,
%                 positive UP (along -z_b), gravity excluded. In unaccelerated
%                 level flight nz = cos(theta) (the body z component of the
%                 lift + thrust that balances the weight). NaN when env.g <= 0
%                 (a load factor needs a reference gravity).
%   The same function serves trim, linearization and time simulation.
%   Errors: vital:badInput (bad x/u), vital:plant:nonFinite (a component or the
%   derivative is not finite; FC-402).
vital.validate.finite(x, 'state');
vital.validate.finite(u, 'controls');
if numel(x) ~= 13
    error('vital:badInput', 'state must have 13 elements, got %d.', numel(x));
end
if numel(u) ~= 4
    error('vital:badInput', 'controls must be [de da dr throttle], got %d elements.', numel(u));
end
x = x(:); u = u(:);
v = x(1:3); w = x(4:6); q = x(7:10);
nq = norm(q);
if nq == 0, error('vital:badInput', 'zero quaternion in the state.'); end
C = vital.frames.quat2dcm(q / nq);
h = -x(13);
atm = vital.env.atmosphereUS76(h, 'DeltaT', env.deltaT);
ad = vital.airdata.airData(v, w, C, env.wind_n, atm, struct('b', AC.b, 'cbar', AC.cbar));
[F_R, M_R, info] = AC.loadsFcn(ad, u, h, atm, AC);
if any(~isfinite(F_R(:))) || any(~isfinite(M_R(:)))
    error('vital:plant:nonFinite', 'aircraft loads are not finite at this state.');
end
[F_b, M_cg] = vital.loads.sumLoadsAtCG(F_R, M_R, AC.r_cg, AC.mass, C, [0; 0; env.g]);
xdot = vital.eom.rigidBodyDerivs(v, w, q, F_b, M_cg, AC.mass, AC.J);
if any(~isfinite(xdot))
    error('vital:plant:nonFinite', 'state derivative is not finite.');
end
y.V = ad.V; y.alpha = ad.alpha; y.beta = ad.beta; y.mach = ad.mach; y.qbar = ad.qbar; y.h = h;
y.F_b = F_b; y.M_cg = M_cg;
y.outOfEnvelope = info.outOfEnvelope;
for f = {'F_aero', 'M_aero', 'F_prop', 'M_prop', 'coeff', 'thrust_lbf'}
    if isfield(info, f{1}), y.(f{1}) = info.(f{1}); end
end
% M5-B diagnostics (additive; no existing field or behaviour changes).
y.quatNorm = nq;
e = vital.frames.dcm2eul(C);
y.phi = e(1); y.theta = e(2); y.psi = e(3);
y.p = w(1); y.q = w(2); y.r = w(3);
y.specificForce_b = sum(F_R, 2) / AC.mass;
if env.g > 0
    y.nz = -y.specificForce_b(3) / env.g;
else
    y.nz = NaN;
end
end
