# DECISIONS fragment (agent m9a, 2026-10-25): 0.9.0-M9A

## ADR-039 (proposed; agent m9a, 2026-10-25): generated Simulink plant, one physics source through coder.extrinsic

(ADR-038 is reserved for the paused speed-up.)

**Context.** The original plan's Simulink milestone (now M9) asks for a script-generated Plant.slx (MATLAB Function block -> Integrator, ode4, the MATLAB path's quaternion handling, a discrete FCS) that equals `vital.sim.run`. The aircraft struct carries a function handle (`loadsFcn`) and controllers are structs of handles; neither can cross a code-generation boundary.

**Decision.**
1. `vital.slx.build` generates `models/VitalPlant.slx` from scratch: Plant (MATLAB Function, continuous), Integrator (13 states, IC `x0`), FCS (MATLAB Function, discrete, `SystemSampleTime = Ts`), Digital Clock (`Ts`), Outports x, u. Solver Fixed-step ode4, `FixedStep = dt`. The .slx is a generated artifact, committed, never hand-edited; `vital.slx.structure` hashes blocks, key parameters, MATLAB Function code, lines and solver settings, and a test requires the committed file to hash equal to a fresh build.
2. The MATLAB Function blocks reach the plant through `coder.extrinsic('vital.slx.kernel')`, which calls `vital.plant.derivatives` and `vital.sim.sampleController`. One physics source; normal mode only (no accelerator, no codegen of the model). AC, env, the controller and its state live in a session store `vital.slx.context`, set by `vital.slx.simulate` and cleared after the run; without it the kernel raises `vital:slx:noContext`.
3. The quaternion is handled exactly as in the MATLAB path: no post-step renormalization (the plant normalizes for the DCM and carries the `k(1 - q'q) q` stabilization term). The |q| guard is applied after the run to every logged sample with the log truncated at the first violation (causal, so identical to stopping).
4. The FCS block is the ZOH: with a controller `Ts = nHold dt` and ADR-026 measurement y(x_k, u_held); without one `Ts = dt` and `u = u0 + du(t_k + dt/2)`. Only piecewise-constant inputs are accepted (`vital:slx:unsupportedInput` for function handles).
5. Behaviour tests run on a FRESH build (temp folder), so builder defects show behaviourally; the default user path runs the committed model.

**Result.** Simulink ode4 uses the same Butcher tableau and the same operation order as `vital.sim.rk4Step`; on all registered cases the two paths are bitwise identical (E = 0 against the pre-registered 1e-9).

**Consequences.** Simulink runs are slower than `vital.sim.run` (extrinsic call per stage; about 4 s for 500 steps after a one-off ~15 s compile). Envelope, ground and control-limit guards stay in `vital.sim.run` only. A plant-side NaN during a Simulink run stops with `vital:sim:nanState` but its stop sample is not guaranteed to equal `vital.sim.run`'s (the plant block does not know the step index); controller-side stops are exact.
