# PLAN M9-A: generated Simulink plant, equivalent to vital.sim.run

Written 2026-10-25 by agent m9a BEFORE any M9 code or test. Scope: the Simulink half of
the original plan's "M10: Simulink + Cesium + joystick" (now M9). Cesium and the joystick
are M9-B and are not in this plan. M8 stays open and paused; nothing here changes M8
behaviour. Proposed decision: ADR-039 (fragment in `reports/fragments/M9/`).

## 1. Contract

`vital.slx.simulate(AC, env, x0, u0, 'dt', dt, 'tFinal', T, 'Inputs', in, 'Controller', c)`
returns a struct with the same core fields as `vital.sim.run` (t, x, u, y, status,
stopReason, stopTime, stopDetail, controller, dt, tFinal, nSteps, wallTime_s) produced
by the generated Simulink model `VitalPlant` (one physics source,
`vital.plant.derivatives`). On the cases in section 7 it equals `vital.sim.run` within
the pre-registered tolerances.

## 2. Model architecture (`models/VitalPlant.slx`, generated)

```
 Digital Clock (Ts) --t--> [FCS: MATLAB Function, discrete, sample time Ts] --u--+--> Out2 "u"
                              ^ x                                                  |
                              |                                                    v
 Integrator "x" (13 states, IC x0) <--xdot-- [Plant: MATLAB Function, inherited/continuous]
        |                                         ^ x
        +-----------------------------------------+------------------------------> Out1 "x"
```

- **Plant** (MATLAB Function block, continuous): `xdot = vital.slx.kernel('plant', x, u)`
  which is `vital.plant.derivatives(x, u, AC, env)`.
- **Integrator** (one block, 13 states, initial condition variable `x0`): the only
  continuous state. Nothing else integrates.
- **FCS** (MATLAB Function block, discrete, sample time `Ts`): `u = vital.slx.kernel('fcs', t, x)`.
  - With a controller: `Ts = 1/rate_hz`; the kernel measures `y(x_k, u_held)` (ADR-026,
    `u_held` = the command held over the step that ends at t_k; `u_ref(0)` at k = 0),
    calls `vital.sim.sampleController` with `u_ref = u0 + du(t_k)` and holds the result.
  - Without a controller: `Ts = dt` and `u = u0 + du(t_k + dt/2)`, i.e. exactly the
    value `vital.sim.run` gives every stage of a piecewise-constant input.
  - The block output is held by Simulink between hits (zero-order hold), so all four
    ode4 stages see the same command, as in `vital.sim.run`.
- **Digital Clock** (sample time `Ts`): t_k for the FCS.
- **Outports** `x` (13) and `u` (4), saved as arrays at every major step (t_k = k dt).
- No algebraic loop: the Integrator has no direct feedthrough.

### Reaching the plant: `coder.extrinsic` (chosen)

Options: (a) `coder.extrinsic('vital.slx.kernel')` calling `vital.plant.derivatives` in
MATLAB; (b) a codegen-native kernel. Choice: **(a)**.
- One physics source: the Simulink path executes the very function the MATLAB path
  executes; no second implementation can drift.
- `AC` carries a function handle (`loadsFcn`) and the controller is a struct of
  function handles: neither can cross a codegen boundary as a signal or parameter.
  With (a) they stay in MATLAB, in a session store `vital.slx.context` set by
  `vital.slx.simulate` before `sim` and cleared after it.
- Cost: interpreted, normal mode only (no accelerator, no code generation of the
  model). Speed is not a goal of M9-A; exact equivalence is.
- The model therefore cannot run without `vital.slx.simulate` having set the context;
  a bare `sim('VitalPlant')` raises `vital:slx:noContext`.

### Solver

Fixed-step, `Solver = ode4`, `SolverType = Fixed-step`, `FixedStep = dt` (variable),
`StartTime = 0`, `StopTime = N dt` (N from the same check as `vital.sim.run`:
`vital:sim:badStep`). Simulink's ode4 has the same Butcher tableau (stage times t,
t+h/2, t+h/2, t+h; weights 1/6 1/3 1/3 1/6) as `vital.sim.rk4Step`.

### Quaternion handling

`vital.sim.run` does **not** renormalize the quaternion after a step. The plant
normalizes q only to build the DCM, and the derivative carries the constraint
stabilization term `k(1 - q'q) q` (CONVENTIONS 3). The Simulink path calls the same
plant, so the same mechanism applies with nothing added; no discrete-state RK4
workaround is needed. The |q| guard (FC-601, default 1e-6) is applied by
`vital.slx.simulate` to every logged sample; the log is truncated at the first
violating sample with status STOPPED, reason `vital:sim:quatNorm`. Because the system is
causal, a log truncated after the fact equals the log of a run that stopped there.

### Inputs and logging

- Inputs: `[]`, or piecewise-constant specifications (`vital.sim.doublet`,
  `vital.sim.stepInput`, or a cell array of them), with the same breakpoint and
  piecewise-constancy checks as `vital.sim.run`. Smooth function-handle inputs are not
  supported (`vital:slx:unsupportedInput`): a continuous source would be evaluated at
  the stage times by Simulink's own clock, which is not the contract under test.
- Log: t, x, u at every t_k. u at t_k is the command applied over [t_k, t_k+dt]
  (stage 1), as in `vital.sim.run`, for k < N. At t_N `vital.sim.run` logs the left
  limit; the Simulink output port shows the next hold value. Comparisons of u use
  samples 1..N (documented, not a defect).
- y (V, alpha, beta, h, phi, theta, psi, p, q, r, quatNorm, nz) is recomputed after the
  run with `vital.plant.derivatives(x_k, u_k)` for k < N and the left-limit u at N.

## 3. Guards, failure modes, error identifiers

| Situation | Behaviour | Identifier |
|---|---|---|
| bad dt / tFinal / controller rate / breakpoint | error before sim | `vital:sim:badStep` |
| non-finite or wrong-size x0/u0, bad option | error | `vital:badInput` |
| smooth (function-handle) input, or a `Plant` option | error | `vital:slx:unsupportedInput` |
| `models/VitalPlant.slx` missing | error | `vital:slx:modelMissing` |
| model simulated without `vital.slx.simulate` | Simulink error from the kernel | `vital:slx:noContext` |
| plant derivative not finite during the run | STOPPED | `vital:sim:nanState` |
| controller output not finite | STOPPED | `vital:sim:nanState` |
| controller raises | STOPPED | `vital:sim:controllerError` |
| |q| - 1 beyond quatNormTol on a logged sample | STOPPED, log truncated | `vital:sim:quatNorm` |
| any other Simulink error | STOPPED, message kept | `vital:slx:simulinkError` |

Only the |q| guard is implemented in the Simulink path (envelope, ground and control
limit guards stay in `vital.sim.run`); `Guards` accepts only `quatNormTol`.

## 4. Builder and the generated artifact

- `vital.slx.build('Folder', f)` creates the model from scratch (`new_system`), sets the
  solver, adds and wires the blocks, writes the MATLAB Function code, saves
  `f/VitalPlant.slx` and returns `vital.slx.structure(model)`.
- The artifact lives in `models/` (committed, generated; never hand-edited).
  `vital.slx.structure` lists every block (path, type, key parameters, MATLAB Function
  script), every line (source -> destination port) and the solver settings, and hashes
  the canonical text (SHA-256). A test regenerates the model in a temporary folder and
  requires the same hash as the committed `models/VitalPlant.slx`.
- `run_f16_simulink.m` (user entry point): trims at the NESC README point, builds the
  model if missing, runs the Simulink path and `vital.sim.run` with the M7 SAS and an
  elevator doublet, prints the maximum differences and plots both.

## 5. Package layout

`+vital/+slx/`: `build.m`, `structure.m`, `simulate.m`, `compare.m`, `kernel.m`,
`context.m`, `modelFile.m`. `models/VitalPlant.slx` (generated). Tests in `tests/M9/`.

## 6. Source tags

The equivalence checks are **INDEP**: Simulink's ode4 solver, its sample-time
scheduler and its zero-order hold are an independent (MathWorks) implementation of the
integration and scheduling that `vital.sim.run` implements by hand. The physics is
shared on purpose and is NOT what these tests verify (M3-M5 verify it). The trim-hold
bounds are **REG** (restated from tests/M5/tF16Sim.m). Attitude signs are **ANALYTIC**
(CONVENTIONS 7). Configuration and structure checks use `verifyEqual` / `verifyExact`.

## 7. Pre-registered expectations (written before any Simulink run)

Condition: NESC README trim (565.6854 ft/s, 10013 ft, CG 25 % MAC, g = 32.174 ft/s^2),
`vital.trim.solve` level condition as in tests/M7.

Metric: e_i = max_k |x_slx,i(t_k) - x_mat,i(t_k)| / max(1, max_k |x_mat,i(t_k)|) for each
of the 13 states; E = max_i e_i.

Reasoning for the 1e-9 bound: both paths evaluate the same plant at the same stage
states and stage commands. The only expected difference is floating-point operation
order in the two ode4 updates (Simulink's ode4 forms x + h/6 (f0 + 2f1 + 2f2 + f3), the
same order as `vital.sim.rk4Step`, so the difference may well be zero). A per-step
round-off of eps |x| ~ 2.2e-16 relative, accumulated over N <= 1000 steps and amplified
by at most e^(sigma T) with sigma T <= 6 (the slowest-growing F-16 mode at CG 25 % is
stable; 6 allows an unstable mode at 0.6 1/s for 10 s), gives 1000 x 2.2e-16 x 400 ~
1e-10. 1e-9 keeps a decade of margin. Any discrepancy at the size of a modelling or
scheduling error (a hold misaligned by one step, an ode1 solver, a sign) is >= 1e-4.

| # | Case | Expectation |
|---|---|---|
| E1 | open loop, bare aircraft, 1 deg elevator doublet t0 = 0.5 s width 0.5 s, dt 0.01, 2 s | E <= 1e-9; t equal to (0:N) dt within 1e-12 s; u(1..N) within 1e-12 |
| E2 | closed loop, M7 SAS (pitchSas Kq 0.02, Ka 0.14 + yawDamper Kr 0.82, combined), 100 Hz, dt 0.01, 10 s, elevator doublet (1 deg, 1 s, 0.5 s) + rudder doublet (1 deg, 4 s, 0.5 s) | E <= 1e-9; controller sample count equal |
| E3 | closed loop, M7 SAS at 50 Hz (nHold = 2), dt 0.01, 5 s, elevator doublet | E <= 1e-9 (multi-rate hold) |
| E4 | closed loop, NESC LQR (`vital.ctrl.nescLqr`), 200 Hz, dt 0.005, 3 s, initial dw = -0.3 m/s | E <= 1e-9 |
| E5 | trim hold, no input, dt 0.02, 10 s, Simulink path | tF16Sim bounds: |dV| <= 1e-6 m/s, |dalpha|, |dtheta| <= 1e-8 rad, |p|,|q|,|r| <= 1e-8 rad/s, |dh| <= 1e-4 m, |beta|,|phi|,|psi| <= 1e-8 rad (REG); and E <= 1e-9 against vital.sim.run |
| E6 | doublet response non-vacuous (E1) | max |q| >= 1e-3 rad/s, so E1 compares a real response |
| A1-A3 | attitude signs through Simulink, 0.1 s from trim | +1 deg elevator -> q < -1e-6 rad/s and theta(end) < theta0; +1 deg aileron step -> p < -1e-6 and phi(end) < 0; +1 deg rudder step -> r < -1e-6 and psi(end) < 0 (ANALYTIC, CONVENTIONS 7, as tests/M5/tF16Sim.m) |

If E <= 1e-9 is missed for a principled reason, the failure is recorded as a failed
hypothesis with the measured value; the tolerance is not loosened silently.

## 8. Tests (`tests/M9/`)

- `tSlxBuild`: build reproducible (two builds, same structure hash; block list as
  registered: Plant, FCS, Integrator x, Digital Clock, Out x, Out u); committed artifact
  equals a fresh build (not hand-edited); solver config (FixedStepDiscrete / Fixed-step,
  ode4, FixedStep `dt`, StopTime set per run).
- `tSlxEquivalence`: E1-E6.
- `tSlxAttitude`: A1-A3.
- `tSlxGuards`: error identifiers of section 3 (badStep, badInput, unsupportedInput,
  noContext, quatNorm STOPPED, nanState STOPPED from a NaN controller, controllerError).
- `tRunF16Simulink`: the entry point runs, returns the comparison and draws a figure.
Runtimes are recorded in the gate report.

## 9. Sabotages (`tests/M9/sabotages.json`)

| ID | Change | Must turn RED |
|---|---|---|
| S9-1 | builder sets ode1 instead of ode4 | E1, solver config |
| S9-2 | the |q| guard removed from `vital.slx.simulate` | quatNorm guard test |
| S9-3 | controller sample time forced to dt | E3 (50 Hz) |
| S9-4 | sign flip of the moment rows of xdot in the Plant block code | E1, attitude, structure |
| S9-5 | builder silently drops the u Outport | structure / committed-artifact test |
| S9-6 | FCS samples u_ref at t_k + dt (next piece) instead of the piece of the step | E1 |
