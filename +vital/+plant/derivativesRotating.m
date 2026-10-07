function [xdot, y] = derivativesRotating(x, u, AC, env)
%DERIVATIVESROTATING  Vehicle state derivative over a rotating (or fixed) round
%   or WGS-84 Earth: the M5-C plant for the NESC check-cases.
%   [xdot, y] = vital.plant.derivativesRotating(x, u, AC, env)
%   Same signature as vital.plant.derivatives, so it runs through vital.sim.run
%   ('Plant', @vital.plant.derivativesRotating), trim and linearization.
%
%   STATE (13; proposed ADR N1, reports/fragments/nesc/DECISIONS.md)
%     x(1:3)    r_e   CM position, ECEF (m)
%     x(4:6)    v_e   CM velocity relative to the Earth, ECEF axes (m/s)
%     x(7:10)   q_be  scalar-first quaternion ECEF -> body
%     x(11:13)  w_bi  body rate relative to INERTIAL space, body axes (rad/s)
%   Build it with vital.eom.rotatingState; ECI (coincident with ECEF at t = 0)
%   with vital.eom.rotatingToInertial.
%
%   u    controls, passed unchanged to AC.loadsFcn (F-16: [de da dr throttle];
%        [] for the unpowered NESC sphere and brick)
%   AC   vehicle: mass (kg), J (kg m^2, about the CM, body axes), r_cg, r_mrc
%        (BFRP coordinates, m), b, cbar (m) and
%        [F_R, M_R, info] = AC.loadsFcn(ad, u, h, atm, AC): the M3 loads
%        signature (body axes, about the BFRP); e.g. vital.aircraft.f16.config
%        unchanged, or vital.nesc.vehicle('cannonball' | 'brick').
%        Optional AC.stageControl: u_applied = AC.stageControl(sig, u), a STATIC
%        control law evaluated at every plant evaluation (every RK4 stage, the
%        continuous-time form of a stateless feedback); u is then its command
%        vector and sig holds lat, lon, h, V, rho, alpha, beta, phi, theta, psi,
%        w_bn, w_be, w_bi. y.u_applied / y.u_command record both (vital.nesc.f16Controller).
%   env  (every field required; a missing one is vital:badInput)
%     earth           'wgs84' | 'sphere' | a constants struct (vital.geo.constants
%                     fields a, e2, mu, J2, omega)
%     rotation        true: the Earth rotates at K.omega; false: omega = 0
%     gravity         'J2' (zonal J2 gravitation) | 'central' (inverse square)
%     wind_n          wind at h = 0, local NED, Earth-fixed (m/s)
%     windGradient_n  d(wind)/dh (1/s): wind(h) = wind_n + windGradient_n h
%     deltaT          ISA temperature offset (K)
%
%   PIPELINE: ECEF -> geodetic (vital.geo.ecef2lla) -> US 1976 at the geometric
%   height -> air data with the airmass-relative velocity C_bn (v_n - wind) and
%   the Earth-relative body rate w_be = w_bi - C_be w_ie (the atmosphere turns
%   with the Earth; ADR N3) -> AC.loadsFcn -> sum at the CM (no gravity) ->
%   vital.eom.rotatingRigidBody with GRAVITATION (vital.geo.gravitation, J2 or
%   central); the rotating-frame terms supply centrifugal and Coriolis (ADR N2).
%   At zero airspeed alpha, beta and the non-dimensional rates are undefined
%   and set to NaN; loads models that must work there use ad.v_air, ad.V.
%
%   y (diagnostics; the fields vital.sim.run guards read are h, alpha, beta,
%   quatNorm, outOfEnvelope):
%     lat, lon (rad, geodetic), h (m above the ellipsoid/sphere), v_ned (m/s)
%     V (true airspeed), alpha, beta (rad), mach, qbar (Pa)
%     phi, theta, psi   3-2-1 Euler angles w.r.t. local geodetic NED (rad)
%     quatNorm          norm of the incoming quaternion (FC-601)
%     w_bi (= p, q, r)  body rates w.r.t. inertial space; w_be w.r.t. the Earth;
%                       w_bn w.r.t. local NED (rad/s)
%     localGravity      |gravitation| (m/s^2): NESC localGravity (CONVENTIONS 4)
%     rho, pressure, temperature, a   US 1976 (SI)
%     F_aero, M_aero_cg aero force (body, N) and aero moment about the CM (N m)
%     F_b, M_cg         total applied force and moment about the CM
%     specificForce_b   F_b / m (m/s^2); wind_n (m/s); outOfEnvelope
%   Errors: vital:badInput (state, env, zero quaternion), vital:plant:nonFinite
%   (loads or derivative not finite; FC-402), vital:env:altitudeOutOfRange
%   (FC-106), vital:badInput at the exact pole (NED undefined).
if ~(isnumeric(x) && numel(x) == 13)
    error('vital:badInput', 'rotating-plant state must have 13 elements [r_e v_e q_be w_bi], got %d.', numel(x));
end
vital.validate.finite(x, 'state');
if ~isempty(u), vital.validate.finite(u, 'controls'); end
[K, Kg, omega] = environment(env);
x = x(:);
r = x(1:3); v_e = x(4:6); q = x(7:10); w_bi = x(11:13);
nq = norm(q);
if nq == 0, error('vital:badInput', 'zero quaternion in the state.'); end
C_be = vital.frames.quat2dcm(q / nq);
[lat, lon, h] = vital.geo.ecef2lla(r, K);
C_ne = vital.geo.dcmEcefToNed(lat, lon);
C_bn = C_be * C_ne.';
v_ned = C_ne * v_e;
atm = vital.env.atmosphereUS76(h, 'DeltaT', env.deltaT);
wind = env.wind_n(:) + env.windGradient_n(:) * h;
w_be = w_bi - C_be * [0; 0; omega];
v_b = C_bn * v_ned;
ref = struct('b', AC.b, 'cbar', AC.cbar);
if norm(v_b - C_bn * wind) >= 1e-6
    ad = vital.airdata.airData(v_b, w_be, C_bn, wind, atm, ref);
else
    va = v_b - C_bn * wind;
    ad = struct('v_air', va, 'w_air', w_be, 'V', norm(va), 'alpha', NaN, 'beta', NaN, ...
        'qbar', 0.5 * atm.rho * (va.' * va), 'mach', norm(va) / atm.a, 'phat', NaN, 'qhat', NaN, 'rhat', NaN);
end
nav = vital.eom.navRates(lat, h, v_ned, K, omega);
e = vital.frames.dcm2eul(C_bn);
w_bn = w_bi - C_bn * nav.w_in_n;
if isfield(AC, 'stageControl')
    % static (stateless) control law evaluated at EVERY plant evaluation, i.e. at
    % every RK4 stage: the continuous-time form of an algebraic feedback law
    % (proposed ADR N6, superseded rate choice). u carries its commands.
    sig = struct('lat', lat, 'lon', lon, 'h', h, 'V', ad.V, 'rho', atm.rho, 'alpha', ad.alpha, ...
        'beta', ad.beta, 'phi', e(1), 'theta', e(2), 'psi', e(3), 'w_bn', w_bn, 'w_be', w_be, 'w_bi', w_bi);
    ucmd = u;
    u = AC.stageControl(sig, ucmd);
end
[F_R, M_R, info] = AC.loadsFcn(ad, u, h, atm, AC);
if any(~isfinite(F_R(:))) || any(~isfinite(M_R(:)))
    error('vital:plant:nonFinite', 'vehicle loads are not finite at this state.');
end
[F_b, M_cg] = vital.loads.sumLoadsAtCG(F_R, M_R, AC.r_cg, AC.mass, C_bn, [0; 0; 0]);
g_e = vital.geo.gravitation(r, Kg);
xdot = vital.eom.rotatingRigidBody(x, F_b, M_cg, AC.mass, AC.J, g_e, omega);
if any(~isfinite(xdot))
    error('vital:plant:nonFinite', 'state derivative is not finite.');
end
if nargout < 2, return; end
y.lat = lat; y.lon = lon; y.h = h; y.v_ned = v_ned;
y.V = ad.V; y.alpha = ad.alpha; y.beta = ad.beta; y.mach = ad.mach; y.qbar = ad.qbar;
y.phi = e(1); y.theta = e(2); y.psi = e(3);
y.quatNorm = nq;
y.w_bi = w_bi; y.p = w_bi(1); y.q = w_bi(2); y.r = w_bi(3);
y.w_be = w_be; y.w_bn = w_bn;
if isfield(AC, 'stageControl'), y.u_applied = u(:); y.u_command = ucmd(:); end
y.localGravity = norm(g_e);
y.rho = atm.rho; y.pressure = atm.p; y.temperature = atm.T; y.a = atm.a;
if isfield(info, 'F_aero') && isfield(info, 'M_aero')
    d = [0; 0; 0];
    if isfield(AC, 'r_mrc'), d = AC.r_mrc(:); end
    y.F_aero = info.F_aero;
    y.M_aero_cg = info.M_aero + cross(d - AC.r_cg(:), info.F_aero);
else
    y.F_aero = nan(3, 1); y.M_aero_cg = nan(3, 1);
end
y.F_b = F_b; y.M_cg = M_cg;
y.specificForce_b = F_b / AC.mass;
y.wind_n = wind;
y.outOfEnvelope = logical(info.outOfEnvelope);
end

function [K, Kg, omega] = environment(env)
need = {'earth', 'rotation', 'gravity', 'wind_n', 'windGradient_n', 'deltaT'};
if ~isstruct(env) || ~all(isfield(env, need))
    miss = need; if isstruct(env), miss = need(~isfield(env, need)); end
    error('vital:badInput', 'env for the rotating plant needs fields %s (missing: %s).', strjoin(need, ', '), strjoin(miss, ', '));
end
persistent cache
if ischar(env.earth) || (isstring(env.earth) && isscalar(env.earth))
    nm = char(env.earth);
    if ~any(strcmp(nm, {'wgs84', 'sphere'}))
        error('vital:badInput', 'env.earth must be ''wgs84'', ''sphere'' or a constants struct, not ''%s''.', nm);
    end
    if isempty(cache), cache = struct(); end
    if ~isfield(cache, nm), cache.(nm) = vital.geo.constants(nm); end
    K = cache.(nm);
elseif isstruct(env.earth) && all(isfield(env.earth, {'a', 'e2', 'mu', 'J2', 'omega'}))
    K = env.earth;
else
    error('vital:badInput', 'env.earth must be ''wgs84'', ''sphere'' or a struct with a, e2, mu, J2, omega.');
end
Kg = K;
switch char(env.gravity)
    case 'J2'
    case 'central'
        Kg.J2 = 0;
    otherwise
        error('vital:badInput', 'env.gravity must be ''J2'' or ''central''.');
end
if ~((islogical(env.rotation) || isnumeric(env.rotation)) && isscalar(env.rotation))
    error('vital:badInput', 'env.rotation must be a logical scalar.');
end
omega = double(logical(env.rotation)) * K.omega;
vital.validate.finite([env.wind_n(:); env.windGradient_n(:); env.deltaT], 'wind / deltaT');
if numel(env.wind_n) ~= 3 || numel(env.windGradient_n) ~= 3
    error('vital:badInput', 'env.wind_n and env.windGradient_n must be 3-vectors (NED).');
end
end
