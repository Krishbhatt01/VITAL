function c = nescLqr(AC, env, tr, opts)
%NESCLQR  NASA's NESC F-16 stability augmentation (the LQR of F16_control.dml with
%   sasOn = 1, apOn = 0) as a static vital.sim.run controller on the flat-Earth
%   body-axis plant (vital.plant.derivatives).
%   c = vital.ctrl.nescLqr(AC, env, tr)
%   c = vital.ctrl.nescLqr(AC, env, tr, 'Rate', 50)
%
%   The law is NOT re-typed: every call evaluates the generated control law
%   vital.models.f16.control (F16_control.dml, compiled in M2; gains and law in
%   docs/nesc/NESC_EXTRACT_F16.md section C).
%   Signal mapping (as vital.nesc.f16Controller, proposed ADRs N6 and N6c, here
%   on the flat Earth):
%     alpha, beta, phi, theta, psi  y fields, rad -> deg
%     pb, qb, rb                    y.p, y.q, y.r (rad/s; body rates relative to
%                                   the flat, non-rotating Earth)
%     Vequiv (KEAS)                 vital.nesc.equivalentAirspeed(y.V, rho) / kt
%                                   with rho = 2 y.qbar / y.V^2
%     altMsl                        y.h in ft (used only by the autopilot, off)
%     LQR references replaced by the trim through exact input shifts:
%       alpha -> alpha - alpha_trim + trimmedAlpha, theta likewise,
%       Vequiv -> KEAS - KEAS_trim + trimmedKEAS
%     reference command u_ref -> the law's pilot and trim inputs, so that
%       u = u_ref when every LQR error is zero:
%       longStkTrim = -de_ref[deg]/25, throttleTrim = throttle_ref,
%       latStk = -da_ref[deg]/21.5, pedal = -(dr_ref[deg] - 0.008 da_ref[deg])/30,
%       longStk = 0, throttle (pilot) = 0
%     outputs u = [el; ail; rdr] deg -> rad, throttle = PWR/100 (NESC signs equal
%       VITAL's, CONVENTIONS 7)
%   The LQR gains are a point design for 10,000 ft / 287.8 KEAS; elsewhere NASA
%   calls them "sub-optimal or even unstable" (README.html:1353-1355).
%   LIMITS: NASA's law contains its own limiters (stick totals +/-1, throttle
%   [0, 1]); they are part of the published law and are kept. The law can command
%   el = +/-25 deg, beyond AC.limits.de_deg = +/-24, and rdr beyond +/-30 deg
%   through the 0.008 interconnect: vital.sim.run flags those and never clips.
%   c.lawState(y, u_ref) returns the law's output struct and the flags
%   saturated.longStk / latStk / pedal / throttle (a limiter of the law is
%   active), so the published limiter is visible, not silent.
%
%   c fields: rate_hz, init ([]), static (true), step, lawState, info (trim
%   references, dmlReference, mapping text).
%   Errors: vital:ctrl:notTrimmed; vital:badInput.
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    opts.Rate (1,1) double = 50
end
y0 = vital.ctrl.refAtTrim(AC, env, tr, 'vital.ctrl.nescLqr');
if ~(isfinite(opts.Rate) && opts.Rate > 0)
    error('vital:badInput', 'vital.ctrl.nescLqr: Rate must be finite and > 0 (Hz).');
end
k = vital.units.constants();
law = @vital.models.f16.control;
ref.alpha_deg = rad2deg(y0.alpha);
ref.theta_deg = rad2deg(y0.theta);
ref.keas = keasOf(y0, k);
ref.h_ft = y0.h / k.ft;
base = struct('throttle', 0, 'longStk', 0, 'latStk', 0, 'pedal', 0, 'sasOn', 1, 'apOn', 0, ...
    'keasCmd', ref.keas, 'altCmd', ref.h_ft, 'latOffset', 0, 'baseChiCmd', 0, 'altMsl', ref.h_ft, ...
    'Vequiv', ref.keas, 'alpha', 0, 'beta', 0, 'phi', 0, 'theta', 0, 'psi', 0, 'pb', 0, 'qb', 0, 'rb', 0, ...
    'throttleTrim', tr.u(4), 'longStkTrim', -rad2deg(tr.u(1)) / 25);
o0 = law(base);
dml = struct('alpha', o0.trimmedAlpha, 'theta', o0.trimmedTheta, 'keas', o0.trimmedKEAS);
c.rate_hz = opts.Rate;
c.init = [];
c.static = true;
c.step = @(t, x, y, uref, s) lqrStep(y, uref, s, base, ref, dml, k, law);
c.lawState = @(y, uref) lqrState(y, uref, base, ref, dml, k, law);
c.info = struct('name', 'nescLqr', 'law', 'vital.models.f16.control (F16_control.dml), sasOn 1, apOn 0', ...
    'reference', ref, 'dmlReference', dml, ...
    'mapping', ['alpha/theta/KEAS shifted by the trim to the DML references; u_ref -> longStkTrim, ' ...
    'throttleTrim, latStk, pedal; outputs el, ail, rdr (deg) and PWR/100'], ...
    'note', 'LQR gains are a point design for 10,000 ft / 287.8 KEAS (README.html:1353-1355)');
end

function v = keasOf(y, k)
% equivalent airspeed (kt) from the plant's dynamic pressure: rho = 2 qbar / V^2
v = vital.nesc.equivalentAirspeed(y.V, 2 * y.qbar / y.V^2) / k.kt;
end

function in = lawInput(y, uref, base, ref, dml, k)
uref = uref(:);
in = base;
in.altMsl = y.h / k.ft;
in.altCmd = in.altMsl;                                       % autopilot off: unused
in.Vequiv = keasOf(y, k) - ref.keas + dml.keas;
in.alpha = rad2deg(y.alpha) - ref.alpha_deg + dml.alpha;
in.theta = rad2deg(y.theta) - ref.theta_deg + dml.theta;
in.beta = rad2deg(y.beta);
in.phi = rad2deg(y.phi);
in.psi = rad2deg(y.psi);
in.pb = y.p; in.qb = y.q; in.rb = y.r;
in.longStkTrim = -rad2deg(uref(1)) / 25;
in.throttleTrim = uref(4);
in.latStk = -rad2deg(uref(2)) / 21.5;
in.pedal = -(rad2deg(uref(3)) - 0.008 * rad2deg(uref(2))) / 30;
end

function [u, s] = lqrStep(y, uref, s, base, ref, dml, k, law)
o = law(lawInput(y, uref, base, ref, dml, k));
u = [deg2rad(o.el); deg2rad(o.ail); deg2rad(o.rdr); o.PWR / 100];
end

function st = lqrState(y, uref, base, ref, dml, k, law)
in = lawInput(y, uref, base, ref, dml, k);
o = law(in);
st.out = o;
st.input = in;
st.saturated = struct( ...
    'longStk', abs(o.longStkTrim + o.longStkSw + o.longLQRsw) > 1, ...
    'latStk', abs(o.latStkSw + o.latLQRsw) > 1, ...
    'pedal', abs(o.pedalSw + o.dirLQRsw) > 1, ...
    'throttle', (o.throttleTrim + o.throttleSw + o.throttleLQRsw) < 0 || (o.throttleTrim + o.throttleSw + o.throttleLQRsw) > 1, ...
    'pilotInputs', abs(in.latStk) > 1 || abs(in.pedal) > 1);
end
