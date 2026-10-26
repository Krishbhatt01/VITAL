# FRAMEWORK_GUIDE fragment (agent m9a, 2026-10-25): chapter draft

## 12b. M9-A: the same aircraft in Simulink

**What it is.** A Simulink model, `models/VitalPlant.slx`, that flies the F-16 exactly as `vital.sim.run` does. Nobody draws it: `vital.slx.build()` writes it from a script, and a test checks that the file in the repository is still what the script produces. To change the model, change `+vital/+slx/build.m` and run `vital.slx.build()`.

**Inside the model.** Six blocks. The *Plant* block asks MATLAB for the state derivative (`vital.plant.derivatives`, the same function every other part of VITAL uses). The *Integrator* holds the 13 states and Simulink's ode4 solver steps them with the same Runge-Kutta formula as `vital.sim.rk4Step`. The *FCS* block runs at the controller rate and holds its command between samples (the zero-order hold); with no controller it plays the doublet or step input. A *Digital Clock* gives it the time; two outports log x and u.

**Why the blocks call back into MATLAB.** The aircraft description contains a function handle and the control laws are function handles; Simulink's generated code cannot carry them. So the blocks use `coder.extrinsic` and the physics stays in one place. The price: normal mode only, and slower than the MATLAB loop.

**How to use it.**
```matlab
run_f16_simulink                      % trim, SAS, doublet; Simulink vs MATLAB, plotted
out = vital.slx.simulate(AC, env, x0, u0, 'dt', 0.01, 'tFinal', 5, 'Controller', c, ...
      'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'));
```
`out` has the same fields as a `vital.sim.run` result (t, x, u, y, status, ...).

**How we know it is right.** Before any Simulink run, the plan registered that the two paths must agree to 1e-9 (scaled) on an open-loop doublet, the M7 SAS at 100 and 50 Hz, the NESC LQR and a trim hold. The measured difference is exactly zero: both integrate the same equations with the same arithmetic. Attitude signs, guards and error identifiers are tested too, and six sabotages (ode1, no |q| guard, wrong sample time, moment sign flip, a dropped block, a mistimed input) are each caught.

**Limits.** Only piecewise-constant inputs; only the |q| guard (envelope, ground and control-limit guards are in `vital.sim.run`); a NaN raised inside the plant stops the run but its stop sample may be one step off `vital.sim.run`.
