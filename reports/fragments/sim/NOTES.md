# Notes from agent `sim` (M5-B): open issues, doubts, unverified items

## 1. Failed pre-registered hypothesis: quaternion norm (tSimCore hypothesis 5)

**Registered:** | |q| - 1 | <= 1e-10 for the torque-free F-16 (w0 = [1 0.5 0.3] rad/s, dt = 0.01, 10 s).
**Result:** FAILED, with a maximum of 1.273e-10.

The derivation was wrong. It treated the norm error as that of a pure rotation, for which the RK4 amplification factor |R(i om h)| = 1 - O(h^6) with om = |w|/2 gives about 3e-16 per step. That misses two things:
- The RK4 stage states q + h/2 k1 are off the unit sphere by O((om h)^2).
- The constraint-stabilisation term k(1 - q'q)q of `vital.eom.rigidBodyDerivs` acts on those off-sphere stage states.

**Diagnostic runs** (seen before the corrected test was written):

| Case | |q| - 1 |
|---|---|
| dt = 0.02 | 2.05e-9 |
| dt = 0.01 | 1.27e-10 |
| dt = 0.005 | 7.9e-12 |
| constant w = [1 .5 .3], pure stabilised kinematics | 1.289e-10 |

The deviation scales as dt^4 and appears without any rigid-body dynamics, so it is a property of the integrator on the stabilised kinematics. It is not a driver bug.

**Corrected physics** (derived independently):
- For qdot = A q + k(1 - q'q) q, with A skew and A^2 = -om^2 I, one RK4 step from |q| = 1 gives
  |q|^2 - 1 = e = k om^2 h^5 (om^2 - 4k^2)/24 + O(h^6).
- The coefficients were obtained from a 60-digit `vpa` evaluation of one step at (k, om) = (1,1), (1,2), (2,1), (2,2):
  - e/h^5 = -0.12491, ~0, -1.24960, -3.99423
  - the only admissible h^5 monomials are k om^4, k^3 om^2 and k^5
  - the fitted coefficients are 1/24, -1/6 and 0; the (2,2) point checks the fit
  - the (1,2) point confirms the zero at om = 2k.
- The stabilisation restores |q|^2 by the factor (1 - 2kh) per step. The steady state is therefore
  |q| - 1 = -om^2 h^4 (4k^2 - om^2)/96.
- For the constant-w case this predicts -1.280e-10, against -1.289e-10 measured.

**Corrected test:** `tSimCore/quaternionNormFollowsStabilisedRk4Error` (header 9) passes:
- max | |q| - 1 | = 1.273e-10, against a bound of 1.40e-10
- final value -1.2507e-10, within 15 % of the prediction
- ratio per halving 16.06

Part (c), the h^4 ratio, restates an observation from the diagnostic run.

**Consequences:**
- At dt = 0.01 the steady norm error reaches the default `quatNormTol` of 1e-6 near |w| of about 20 rad/s. For F-16 roll rates (up to about 5 rad/s) it is about 1.5e-9.
- M5-C (rotating plant, same stabilisation) should expect the same law.
- A larger k does **not** reduce the error for om << 2k: the steady value is independent of k to leading order.

## 2. The 60 s trim hold is a floating-point fixed point

At the README trim (dt = 0.02 s, 60 s) the deviations are:
- **exactly 0** in V, alpha, theta, h, beta, phi, psi, p and r
- max |q| = 9.9e-17 rad/s

The trim residual is xdot = [0 0 3.1e-15 0 -1.4e-16 0 ...]. Each RK4 increment is about dt × 3e-15 = 6e-17 m/s, which is below half an ulp of w_b (~8 m/s, ulp 1.8e-15), so the state never changes.

The pre-registered bounds (1e-6 m/s, 1e-8 rad, 1e-4 m) therefore pass trivially. The test checks the driver (u0 applied, env passed, state not reordered, no spurious input) and **not** mode stability. Mode stability belongs to M5-A (eigenvalues) and M5-X (perturbed-trim cross-check). A reviewer may want a perturbed-hold test with an analytic linear prediction; that is M5-X's scope.

## 3. Definitions other agents depend on (see DECISIONS.md)

**nz:**
- body-axis, accelerometer-like, gravity excluded, positive up
- nz = cos(theta) in level flight (0.99893 at the README trim), **not** 1
- M6/M7 metrics that need the wind-axis load factor L/W must compute it separately

**Controller y:**
- evaluated at (x_k, u_ref), i.e. before the controller acts
- fields that depend on u (nz, loads) reflect the reference command
- M7's closed-loop linearization must use the same definition, or document its own

**Inputs with a controller:** they reach the plant only through u_ref at the controller samples, as through a digital FCS. Without a controller, smooth inputs are evaluated at the stage times.

**Stop times:**
- a guard stop is the first violating sample
- a failed step stops at the step's start, the last accepted finite state
- when the stage-1 evaluation at the stop sample itself failed (plant error or nonFinite loads at stage 1), that sample's y is NaN

## 4. Unverified or assumed

- **`vital:plant:nonFinite` is reported as `vital:sim:nanState`, not plantError.** It is the plant's own "non-finite derivative/loads" error, which is FC-302's failure mode.
- **Non-finite controller output** stops with `vital:sim:nanState`. A wrong-sized output is an exception (`vital:badInput`); no test covers either case yet.
- **Envelope limits:** the default is AC.limits alpha_deg/beta_deg (the table ranges [-10 45] deg and [-30 30] deg).
  - Near-stall flight inside 45 deg is allowed.
  - Beyond it, both the envelope stop and the clamped-table flag apply; the envelope stops first.
  - NESC case 12 will need `Guards.envelope = struct()` or wider limits to run the clamped tables.
- **Plant timing:**
  - 1000 calls of `vital.plant.derivatives` at the README trim: 1.007 s (1.0 ms/call)
  - zero-load plant: 0.27 ms/call
  - a 60 s run at dt = 0.02 takes about 12,000 calls, 16.7 s wall
- `LogFields` and multi-element y fields are logged as numel x n arrays. A plant whose y fields change size mid-run is stopped with `vital:sim:plantError` (untested).

## 5. Review R1 fixes (2026-09-30)

**Failed pre-registered hypothesis** (tSimR1 header 6):
- **Registered:** at a 24.5 deg elevator command, `outOfEnvelope` stays false, so that only the new command-limit monitor flags it.
- **Basis:** R1 M6 said "the de table clamps at 25 deg".
- **Result:** FAILED. The DE1 breakpoints end at +/-24 deg (F16_aero.dml:969; `independentVarRef el max="24.0" extrapolate="neither"`, :987). Direct model calls give oob = 0 at 24.0 and oob = 1 at 24.5, 25 and 27.7 deg.
- **Corrected (6b):** both flags fire at 24.5 deg.
- **Where the silent gap really is:** the aileron and rudder. They enter linearly (dail = ail/20, drdr = rdr/30, :253) and are never clamped: a 60 deg aileron command gives oob = 0. New check 5b pins this.
- The elevator case is still covered, because the monitor flags 24.5 deg and not 23.5 deg.

**ADR-026 is implemented in `vital.sim.run`:**
- The controller's y is evaluated at the command held over the step ending at t_k, and at u_ref(0) at k = 0.
- The per-sample semantics are in `vital.sim.sampleController`, which `linearize` may reuse.
- Pinned by `tSimR1/controllerSeesAppliedCommand` (nz feedback, K = -0.1 rad/g, +1 deg pilot step). It uses an independent loop, and has a power check that the ADR-021 choice changes the second command by >= 1e-6 rad.

**NESC (M5-C) impact:**
- Their sampled controller now sees y at the applied command. Their inputs (alt, KEAS, alpha, rates, attitudes) do not depend on u, so this should not change their results. **Their tests were not re-run by me.**
- In stage mode their plant reports `y.u_applied`, so the command-limit monitor checks the real surfaces, not their command vector.
- Monitoring only records by default; it never stops or clips unless asked.

**VACUOUS in the RED run** (8 tests), all guards on behaviour that was already correct (R1 escapes):
- guardFiresAtTimeZero, guardFiresAtFinalSample, nanQuatNormTrips, nanEnvelopeValueTrips
- defaultQuatNormTolerance, finalSampleLogsLeftLimitCommand
- runF16SimChannelMap
- tighterConservationLocks: REG locks registered from provenance values that R1 quoted

These tests exist to make R1-S1..S4, S6, S9 and S10 detectable. They were not meant to fail before the fix.

**Not done:**
- R1-C2 (the controller's y in `linearize.m`) is linear's code. It becomes detectable once linear's closed-loop-vs-sim test exists.
- The M12 tighter locks were added only for my tests: energy, |H| and dropped-mass z_n.
