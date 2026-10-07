function ad = airData(v_b, w_b, C_bn, wind_n, atm, ref)
%AIRDATA  Air-relative flow quantities at the CG (CONVENTIONS.md section 5).
%   v_b    body-axis velocity of the CG relative to the Earth (m/s)
%   w_b    body angular rate (rad/s)
%   C_bn   NED -> body DCM
%   wind_n steady wind, NED, Earth-fixed (m/s)
%   atm    struct with rho and a (vital.env.atmosphereUS76)
%   ref    struct with b (span) and cbar (mean chord), m
%   ad fields: v_air, w_air, V, alpha, beta, qbar, mach, phat, qhat, rhat
%   V = 0 raises vital:airdata:zeroAirspeed (FC-107); alpha and beta are
%   undefined there, and components that must work in hover use local
%   velocities instead.
vital.validate.finite(v_b, 'body velocity');
vital.validate.finite(w_b, 'body rate');
vital.validate.finite(C_bn, 'DCM');
vital.validate.finite(wind_n, 'wind');
vital.validate.finite([atm.rho atm.a], 'atmosphere');
v_air = v_b(:) - C_bn * wind_n(:);
V = norm(v_air);
if V < 1e-6
    error('vital:airdata:zeroAirspeed', 'airspeed %.3g m/s: alpha and beta are undefined.', V);
end
ad.v_air = v_air;
ad.w_air = w_b(:);
ad.V = V;
ad.alpha = atan2(v_air(3), v_air(1));
ad.beta = asin(max(-1, min(1, v_air(2) / V)));
ad.qbar = 0.5 * atm.rho * V^2;
ad.mach = V / atm.a;
ad.phat = w_b(1) * ref.b / (2 * V);
ad.qhat = w_b(2) * ref.cbar / (2 * V);
ad.rhat = w_b(3) * ref.b / (2 * V);
end
