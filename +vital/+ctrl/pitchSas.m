function c = pitchSas(AC, env, tr, opts)
%PITCHSAS  Static pitch stability augmentation (q and alpha feedback to the elevator)
%   as a vital.sim.run controller (M7).
%   c = vital.ctrl.pitchSas(AC, env, tr)                     zero gains
%   c = vital.ctrl.pitchSas(AC, env, tr, 'Kq', 0.2, 'Ka', 0.5, 'Rate', 100)
%
%   AC, env  the aircraft and environment the trim belongs to (flat-Earth plant
%            vital.plant.derivatives)
%   tr       an OK vital.trim.solve result (vital:ctrl:notTrimmed otherwise)
%
%   LAW (static: no washout, no filter, no internal state):
%     de = de_ref + Kq (q - q0) + Ka (alpha - alpha0)
%     da = da_ref, dr = dr_ref, throttle = throttle_ref
%   u_ref = [de_ref da_ref dr_ref throttle_ref] is the reference command that
%   vital.sim.run passes (u0 + du(t_k)). q and alpha are MEASURED from the plant
%   output y (y.q, y.alpha; ADR-026: y at the command actually applied). q0 and
%   alpha0 are the plant outputs at the trim (x_trim, u_trim), so the law returns
%   exactly u_trim at the trim: the closed-loop equilibrium is the open-loop trim.
%   Units: Kq in rad of elevator per rad/s of pitch rate (s); Ka in rad/rad.
%
%   SIGN CONVENTION (derived from CONVENTIONS 7 before any run): +de is trailing
%   edge down and gives a nose-DOWN moment (Cm_de < 0, M_de < 0). A nose-up rate
%   q > 0 is opposed by +de, so Kq > 0 ADDS short-period damping
%   (M_q,cl = M_q + M_de Kq is more negative). An alpha increase is opposed by +de,
%   so Ka > 0 ADDS pitch stiffness (M_alpha,cl = M_alpha + M_de Ka is more
%   negative) and raises the short-period frequency, and CAP at constant n/alpha.
%   Negative gains do the opposite and can destabilize. They are legal inputs;
%   the analysis (vital.ctrl.closedLoop, vital.fq.assess) reports the result and
%   never presents it as an improvement.
%
%   LIMITS: the law never clips. A command beyond AC.limits is flagged by the
%   vital.sim.run control-limit monitor (out.controlLimit, ADR-027), never
%   silently limited.
%
%   c fields: rate_hz, init ([]), static (true), step ([u, s] = step(t, x, y,
%   u_ref, s)), info (name, gains, units, references q0 and alpha0, law text,
%   convention).
%   Errors: vital:ctrl:notTrimmed (trim status not OK); vital:badInput (gains not
%   finite, Rate not finite and > 0, trim without x and u).
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    opts.Kq (1,1) double = 0
    opts.Ka (1,1) double = 0
    opts.Rate (1,1) double = 100
end
y0 = vital.ctrl.refAtTrim(AC, env, tr, 'vital.ctrl.pitchSas');
Kq = gainValue(opts.Kq, 'Kq');
Ka = gainValue(opts.Ka, 'Ka');
if ~(isfinite(opts.Rate) && opts.Rate > 0)
    error('vital:badInput', 'vital.ctrl.pitchSas: Rate must be finite and > 0 (Hz).');
end
q0 = y0.q; a0 = y0.alpha;
c.rate_hz = opts.Rate;
c.init = [];
c.static = true;
c.step = @(t, x, y, uref, s) sasStep(y, uref, s, Kq, Ka, q0, a0);
c.info = struct('name', 'pitchSas', 'gains', struct('Kq', Kq, 'Ka', Ka), ...
    'units', struct('Kq', 'rad/(rad/s)', 'Ka', 'rad/rad'), 'q0', q0, 'alpha0', a0, ...
    'law', 'de = de_ref + Kq (q - q0) + Ka (alpha - alpha0); other channels = u_ref', ...
    'convention', 'CONVENTIONS 7: +de gives a nose-down moment, so Kq > 0 adds damping and Ka > 0 adds stiffness');
end

function [u, s] = sasStep(y, uref, s, Kq, Ka, q0, a0)
% the static law; never clipped (vital.sim.run monitors the limits)
u = uref(:);
u(1) = u(1) + Kq * (y.q - q0) + Ka * (y.alpha - a0);
end

function v = gainValue(v, name)
if ~(isreal(v) && isfinite(v))
    error('vital:badInput', 'vital.ctrl.pitchSas: gain %s must be a finite real number.', name);
end
end
