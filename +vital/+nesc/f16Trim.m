function tr = f16Trim(cd, AC)
%F16TRIM  Trim the NESC F-16 for straight and level flight over the rotating Earth.
%   tr = vital.nesc.f16Trim(cd, AC)
%     cd  case definition (vital.nesc.caseDef; uses cd.ic.lat, lon, h, v_ned,
%         psi and cd.env)
%     AC  vital.aircraft.f16.config('CG_PCT_MAC', 25)
%   Procedure (proposed ADR N5, reports/fragments/nesc/DECISIONS.md):
%   1. vital.trim.solve (unknowns alpha, de, throttle; wings level, beta = 0)
%      with env.g = vital.geo.levelFlightGravity at the IC (the flat-earth trim
%      that reproduces NESC case 11's pitch attitude, tF16Trim).
%   2. Rotating state: IC position and NED velocity, Euler (0, theta, psi),
%      body rates w_bi = C_bn (w_ie + w_en) (ADR N4, SIM 5's definition).
%   3. Newton polish of z = (theta, de, throttle) on vital.plant.derivativesRotating
%      until r(z) = [a_x/g0; a_z/g0; wdot_y] = 0, where a = C_bn dv_n/dt and
%      dv_n/dt = C_ne vdot_e - w_en x v_n is the acceleration seen in the local
%      NED frame (steady level flight: v_n constant). Aileron and rudder 0.
%   tr fields: status 'OK' | 'OUT_OF_DATA_ENVELOPE' | 'NOT_CONVERGED' | the flat
%   trim's status when it failed; reason; x0, u0 (rotating state, [de da dr thr]);
%   theta, alpha, de, throttle (rad, rad, rad, 0..1); keas (kt, vital.nesc.
%   equivalentAirspeed); h_ft; residual (3, scaled); residualLateral
%   ([a_y/g0 pdot rdot]); iterations; flat (the vital.trim.solve result).
%   Only OK is a trim; OUT_OF_DATA_ENVELOPE is accepted by vital.nesc.runCase
%   for case 12 alone (ADR-014: the model is run as published on clamped tables).
k = vital.units.constants();
env = cd.env;
K = vital.geo.constants(env.earth);
omega = double(env.rotation) * K.omega;
lat = cd.ic.lat; lon = cd.ic.lon; h = cd.ic.h; v_ned = cd.ic.v_ned(:); psi = cd.ic.psi;
g = vital.geo.levelFlightGravity(lat, lon, h, v_ned, K);
cond = struct('type', 'level', 'V', norm(v_ned), 'h', h, 'gamma', 0, 'psi', psi);
flat = vital.trim.solve(AC, struct('g', g, 'wind_n', [0; 0; 0], 'deltaT', 0), cond);
tr = struct('status', flat.status, 'reason', flat.reason, 'x0', [], 'u0', [], 'theta', NaN, 'alpha', NaN, ...
    'de', NaN, 'throttle', NaN, 'keas', NaN, 'h_ft', NaN, 'residual', nan(3, 1), 'residualLateral', nan(3, 1), ...
    'iterations', 0, 'flat', flat);
if ~any(strcmp(flat.status, {'OK', 'OUT_OF_DATA_ENVELOPE'}))
    tr.reason = ['flat-earth trim failed: ' flat.reason];
    return
end
nav = vital.eom.navRates(lat, h, v_ned, K, omega);
C_ne = vital.geo.dcmEcefToNed(lat, lon);
plant = @vital.plant.derivativesRotating;
z = [flat.theta; flat.u(1); flat.u(4)];
[r, y] = resid(z);
tol = 1e-10;
it = 0;
while max(abs(r)) >= 1e-13 && it < 30
    it = it + 1;
    Jm = zeros(3);
    hstep = [1e-7; 1e-7; 1e-7];
    for j = 1:3
        e = zeros(3, 1); e(j) = hstep(j);
        Jm(:, j) = (resid(z + e) - resid(z - e)) / (2 * hstep(j));
    end
    z = z - Jm \ r;
    [r, y] = resid(z);
end
[x, u] = build(z);
[xd, y] = plant(x, u, AC, env);
C_bn = vital.frames.dcm321(0, z(1), psi);
a = C_bn * (C_ne * xd(4:6) - cross(nav.w_en_n, v_ned));
tr.x0 = x; tr.u0 = u;
tr.theta = z(1); tr.alpha = y.alpha; tr.de = z(2); tr.throttle = z(3);
tr.keas = vital.nesc.equivalentAirspeed(y.V, y.rho) / k.kt;
tr.h_ft = y.h / k.ft;
tr.residual = r;
tr.residualLateral = [a(2) / k.g0; xd(11); xd(13)];
tr.iterations = it;
if max(abs(r)) >= tol
    tr.status = 'NOT_CONVERGED';
    tr.reason = sprintf('rotating-plant polish: residual %.3g after %d iterations', max(abs(r)), it);
elseif y.outOfEnvelope || flat.outOfEnvelope
    tr.status = 'OUT_OF_DATA_ENVELOPE';
    tr.reason = 'converged, but a table input is clamped (outside the published data)';
else
    tr.status = 'OK'; tr.reason = '';
end

    function [x, u] = build(zz)
        Cb = vital.frames.dcm321(0, zz(1), psi);
        x = vital.eom.rotatingState(lat, lon, h, v_ned, [0; zz(1); psi], Cb * nav.w_in_n, K);
        u = [zz(2); 0; 0; zz(3)];
    end

    function [rr, yy] = resid(zz)
        [xx, uu] = build(zz);
        [xdd, yy] = plant(xx, uu, AC, env);
        Cb = vital.frames.dcm321(0, zz(1), psi);
        aa = Cb * (C_ne * xdd(4:6) - cross(nav.w_en_n, v_ned));
        rr = [aa(1) / k.g0; aa(3) / k.g0; xdd(12)];
    end
end
