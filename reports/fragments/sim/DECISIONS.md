# Proposed ADR (agent `sim`, M5-B)

## ADR-0xx: Time-simulation semantics of vital.sim.run (proposed 2026-09-29)

**Context.** CONVENTIONS 10 requires fixed-step RK4 on a continuous plant, with discrete elements zero-order held. M5-C (rotating plant), M6 (time-domain metrics) and M7 (controllers) all build on `vital.sim.run`. They need a precise definition of what is sampled when, what a stop means, and which time a stop is reported at.

**Decision.**
1. **Integrator.** Classical RK4 (Butcher tableau in `+vital/+sim/rk4Step.m`) is shared by `vital.sim.rk4` (the order tests) and `vital.sim.run`. Times are `t_k = k*dt`, never accumulated. `tFinal/dt` must be within 1e-6 of a positive integer, otherwise `vital:sim:badStep` (FC-301).
2. **Inputs.**
   - A function handle `du = f(t)` is treated as smooth and evaluated at the stage times.
   - A piecewise specification (`vital.sim.doublet`, `vital.sim.stepInput`, or any struct with `channel`, `fcn`, `breakpoints`) must have every breakpoint on a step boundary (a multiple of dt within 1e-6 dt), otherwise `vital:sim:badStep`. It is evaluated at the step's interior point `t_k + dt/2`, and that value is used for all four stages. Stage 1 therefore sees the right limit at t_k and stage 4 the left limit at t_k+dt, so no stage straddles a switch.
3. **Controller.**
   - `{rate_hz, init, step}` is sampled at `t_k` with `mod(k, nHold) == 0`, where `nHold = 1/(rate_hz*dt)` must be a positive integer (within 1e-9), otherwise `vital:sim:badStep`. Nothing runs faster than the base step (correction E4).
   - The controller receives `u_ref = u0 + du(t_k)` and the plant output `y` at `(x_k, u_ref)`. This avoids an algebraic loop: u-dependent outputs such as nz reflect the reference command.
   - Its output is held across every stage until the next sample. With a controller present, inputs reach the plant only through `u_ref` at the samples.
4. **Log.**
   - Sample k logs `x_k`, the command applied at stage 1 of the step from t_k, and `y` from that same stage-1 evaluation, so logging costs no extra plant call.
   - The final sample logs the stage-4 command of the last step (left limit).
   - By default the log holds every real numeric or logical `y` field.
5. **Guards and stops.**
   - Guards are checked on every logged sample, including t = 0. A guard firing at t_k stops the run with `stopTime = t_k = t(end)`.
   - A step whose stage state or derivative is non-finite, or whose plant call raises, is rejected. Its `stopTime` is `t_k`, the last accepted finite state.
   - `vital:plant:nonFinite` raised by the plant is reported as `vital:sim:nanState`. Any other plant error is reported as `vital:sim:plantError`, with the identifier and message kept in `out.stopDetail`.
   - A guard whose `y` field is absent is disabled and listed as such in `out.guards`. A NaN guard value trips its guard.
   - Clamped tables (`y.outOfEnvelope`) are recorded (first time) and stop the run only with `Guards.stopOnOutOfEnvelope`, which gives `vital:sim:outOfEnvelope`.
   - Only an evaluation of the plant that rejects x0/u0 before any successful plant call is an exception (`vital:badInput`).
6. **Diagnostics added to `vital.plant.derivatives` y** (additive):
   - `quatNorm`: norm of the incoming quaternion
   - `phi`, `theta`, `psi`
   - `p`, `q`, `r`
   - `specificForce_b`: (aero + propulsion)/m in body axes
   - `nz = -specificForce_b(3)/env.g`: the body-axis normal load factor, positive up, gravity excluded. It equals cos(theta) in level unaccelerated flight, and is NaN when env.g <= 0.

**Consequences.**
- M5-C needs only to provide `y.quatNorm`, `y.h`, `y.alpha`/`y.beta` and `y.outOfEnvelope` to get the same guards.
- M7 controllers see a well-defined sampled system, and closed-loop linearization must use the same `u_ref`/`y` definition.
- Evidence: `tests/M5/tSimCore.m`, `tests/M5/tSimGuards.m`, `tests/M5/tF16Sim.m`.

---

# Amendment to ADR-021 after review R1 (agent `sim`, 2026-09-30; implements ADR-026)

Proposed replacement text for the ADR-021 items below. Everything else in ADR-021 stands.

**2. Inputs** (added sentence). A piecewise specification must also be *constant inside every step*. `vital.sim.run` samples each step's fcn at t_k + dt/4, dt/2 and 3dt/4 before the run and refuses any variation with `vital:sim:inputNotPiecewiseConstant` (R1 MINOR 4). A smooth input must be passed as a function handle.

**3. Controller** (replaces the second and third bullets).
- At sample k the controller receives `u_ref = u0 + du(t_k)` and y(x_k, u_applied). u_applied is the command held over the step that ends at t_k; at k = 0 it is u_ref(0) = u0 + du(0) (ADR-026).
- The per-sample logic is the public function `vital.sim.sampleController(ctrl, t, x, y, uref, state, nu)`. `vital.linear.linearize` can call it so that both use the same semantics.
- A controller that raises is a STOP `vital:sim:controllerError`, with its identifier and message kept in `out.stopDetail`.
- A non-finite output is a STOP `vital:sim:nanState`, with `stopDetail.stage` = 'controller sample'.
- A wrong-sized output is an exception `vital:badInput`, because it is a wiring error.
- A controller stop is at t_k. It logs x_k, the command applied up to t_k, and the y the controller saw.

**5. Guards and stops** (added bullet). Command limits (R1 M6):
- Every stage command is compared with `vital.sim.controlLimits(AC, n)`: `AC.limits.<name>_deg` in rad, or `AC.limits.<name>` in SI, matched by `AC.controlNames`.
- When the plant reports `y.u_applied` (a plant that maps a command vector to surfaces, e.g. NESC stage mode), that vector is checked instead.
- The first violation is recorded in `out.controlLimit` (`ever`, `firstTime`, `channel`, `value`, `limit`). The command is never clipped.
- `Guards.stopOnControlLimit` stops the run with `vital:sim:controlLimit`. `Guards.controlLimits` overrides the limits, and `struct()` disables them.
