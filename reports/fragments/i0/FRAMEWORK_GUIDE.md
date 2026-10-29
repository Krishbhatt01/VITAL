# FRAMEWORK_GUIDE fragment (agent i0, 2026-10-27): addition to chapter 12c

### 12c.x Known-answer aircraft (increment I0)

**Why.** A test that compares VITAL with VITAL proves plumbing, not physics. Before I0 the 1,100-state equivalence test compared the compiled model with `vital.plant.derivatives`, and both call `vital.aircraft.f16.loads`; every core test used unrotated axes. Three real errors (the compiled path using Cᵀ, the weight using the transposed DCM, the compiled path dropping the rotation) passed every core test. A known-answer aircraft is one whose right answer comes from outside VITAL: a hand derivation or a published check case.

**The three kinds in the suite** (`tests/M9/i0/`, fixtures in `tests/reference/`):

| Fixture | Answer comes from | What it catches |
|---|---|---|
| P1-P4 hand cases (`tI0CoreKnownAnswers`): a twin with tilted, toed-in engines, one chained on a dihedral wing axis, propeller torque, a rotated CG axis; `combine` with rotated self-inertia; `about()` a rotated and a chained axis; weight with a rotated, chained CG axis | the force and moment sums and the 6-DOF equations written out by hand | any frame error in the compiled or object path (SC-9, SC-10, SC-11) |
| the analytic **linear-derivative aircraft** (`linearDerivativeAircraft`, `LinearDerivativeComponent`): constant dimensional derivatives, controls `de da dr throttle` | closed forms: the reference steady state, the body-axis small-disturbance matrices, the roots of the characteristic quartics (Etkin & Reid 1996 sec. 4.9) | errors in the bridge, trim, linearization and mode analysis on a non-F-16 aircraft (SC-13) |
| the **NESC sphere and brick as AircraftModels** (`nescAircraftModel`, `nescModelRun`): zero controls, rotated CG axis, aero data on a rotated, offset axis | NASA/TM-2015-218675 check cases 1, 2, 3, 9, 10 and their registered bands | the rotation and transfer paths against published data (SC-9, SC-11, SC-14) |

**Build your own.** A known-answer aircraft is an ordinary `vital.AircraftModel`. Put the test-only component class in `tests/reference/`, never in `+vital`:
```matlab
[m, P] = linearDerivativeAircraft();          % compiled model + its parameters
AC  = m.toRuntime();                           % the struct the pre-I1 consumers take
tr  = vital.trim.solve(AC, env, struct('type', 'level', 'V', P.Ve, 'h', P.h_e));
lin = vital.linear.linearize(AC, env, tr);
md  = vital.linear.modes(lin);                 % compare with the closed-form roots
```
Rules that kept these tests honest:
- **Make every axis non-trivial.** At least one rotation and one offset per path you want to cover. An identity DCM hides a transpose.
- **Write the expected value without the class under test.** Use `vital.frames.dcm321`, `cross` and algebra; never `Axis`, `Loads` or `MassProperties` on the expected side.
- **Derive the tolerance.** Use round-off for sums, `||J⁻¹|| · tol` for a solver result, and the central-difference truncation g·h²/6 for a finite-difference Jacobian. Never pick a tolerance to make a test pass.
- **Prove the test can fail.** Register a sabotage that it must detect (`tests/M9/sabotages_core.json`).

**Limits until I1.** The consumers (plant, trim, linearize) still need exactly the four controls `de da dr throttle` and F-16-named limits (`de_deg`, `da_deg`, `dr_deg`, `throttle`, `alpha_deg`). A component must read the air data from `fl.Air`, not the state from `fl.X`, because the `toRuntime` bridge gives it no state. The full list is in `reports/fragments/i0/FINDINGS_FOR_I1.md`.
