function c = yawDamper(AC, env, tr, opts)
%YAWDAMPER  Static yaw damper (yaw-rate feedback to the rudder) with an optional
%   aileron-rudder interconnect, as a vital.sim.run controller (M7).
%   c = vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.5)
%   c = vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.5, 'Kari', 0.1, 'Rate', 100)
%
%   LAW (static; NO washout, so it also opposes the yaw rate of a steady turn):
%     dr = dr_ref + Kr (r - r0) + Kari (da_ref - da_trim)
%     de = de_ref, da = da_ref, throttle = throttle_ref
%   r is measured from the plant output y (y.r, ADR-026); r0 is y.r at the trim;
%   da_trim = tr.u(2). The interconnect acts on the reference aileron command
%   only (a feed-forward): it changes the closed-loop B, not A.
%   Units: Kr in rad of rudder per rad/s of yaw rate (s); Kari in rad/rad.
%
%   SIGN CONVENTION (CONVENTIONS 7, derived before any run): +dr is trailing edge
%   left and gives a nose-LEFT moment (Cn_dr < 0, N_dr < 0). A nose-right yaw
%   rate r > 0 is opposed by +dr, so Kr > 0 ADDS Dutch-roll (yaw) damping
%   (N_r,cl = N_r + N_dr Kr is more negative). Kr < 0 removes damping and can
%   destabilize the Dutch roll; the analysis reports it.
%   LIMITS: never clipped; flagged by the vital.sim.run control-limit monitor.
%
%   c fields: rate_hz, init ([]), static (true), step, info.
%   Errors: vital:ctrl:notTrimmed; vital:badInput.
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    opts.Kr (1,1) double = 0
    opts.Kari (1,1) double = 0
    opts.Rate (1,1) double = 100
end
y0 = vital.ctrl.refAtTrim(AC, env, tr, 'vital.ctrl.yawDamper');
Kr = gainValue(opts.Kr, 'Kr');
Kari = gainValue(opts.Kari, 'Kari');
if ~(isfinite(opts.Rate) && opts.Rate > 0)
    error('vital:badInput', 'vital.ctrl.yawDamper: Rate must be finite and > 0 (Hz).');
end
r0 = y0.r; da0 = tr.u(2);
c.rate_hz = opts.Rate;
c.init = [];
c.static = true;
c.step = @(t, x, y, uref, s) ydStep(y, uref, s, Kr, Kari, r0, da0);
c.info = struct('name', 'yawDamper', 'gains', struct('Kr', Kr, 'Kari', Kari), ...
    'units', struct('Kr', 'rad/(rad/s)', 'Kari', 'rad/rad'), 'r0', r0, 'da_trim', da0, ...
    'law', 'dr = dr_ref + Kr (r - r0) + Kari (da_ref - da_trim); other channels = u_ref (no washout)', ...
    'convention', 'CONVENTIONS 7: +dr gives a nose-left moment, so Kr > 0 adds yaw damping');
end

function [u, s] = ydStep(y, uref, s, Kr, Kari, r0, da0)
% the static law; never clipped (vital.sim.run monitors the limits)
u = uref(:);
u(3) = u(3) + Kr * (y.r - r0) + Kari * (u(2) - da0);
end

function v = gainValue(v, name)
if ~(isreal(v) && isfinite(v))
    error('vital:badInput', 'vital.ctrl.yawDamper: gain %s must be a finite real number.', name);
end
end
