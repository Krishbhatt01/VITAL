# VITAL plan: M5 to M8 (F-16 baseline)

Authorized by the user on 2026-09-29: "plan and implement till M8. Use different agents to coordinate and ensure everything is working well and implemented correctly. Follow failure-test methods."

Every increment follows the same red-green discipline:
1. **Tests and stubs first.** Expectations and tolerances are pre-registered in each test file's header, before the implementation exists.
2. **RED run.** Every new test must be `RED_EXPECTED`, with 0 regressions. VACUOUS tests are only allowed when justified (e.g. guards on existing behaviour).
3. **Implement.**
4. **GREEN run** of everything up to and including the milestone.
5. **Sabotage run.** Every registered sabotage must be detected.
6. **Independent review** by a separate agent that did not write the code.

A tolerance is **never** loosened after a failing run. A failed pre-registered expectation is recorded as a failed hypothesis, as tF16Trim hypothesis 3 was, together with its corrected physics.

## Milestones and increments

| Increment | Scope | Owner (agent) | Depends on | Test tag / folder |
|---|---|---|---|---|
| M5-A | Linearization (step-study central differences) and flight modes (ported AAMF classifier + participation factors), `run_f16_modes`, aileron/rudder limits | `linear` | M4 | M5, `tests/M5` |
| M5-B | Fixed-step RK4 time simulation with discrete ZOH controller, inputs, guards, `run_f16_sim` | `sim` | M3 | M5 |
| M5-X | Linear-vs-nonlinear cross-check (perturbed-trim response) | `linear` (second task) | M5-A, M5-B | M5 |
| M5-C | Rotating WGS-84 EOM, NESC cases 1–10 (sphere, brick, cannonball), F-16 cases 11, 12, 13.1–13.4 (15, 16 per the case matrix) with the NESC control laws compiled from DAVE-ML | `nesc` | M5-B | M5 |
| M6 | MIL-F-8785C Class IV flying-qualities engine: curated rule records, metric extractors, status-aware condition search, Level + margin reports, pre-registered mutations | `fq` | M5-A (M5-B for time-domain metrics) | M6, `tests/M6` |
| M7 | Baseline pitch SAS + yaw damper (and the NESC LQR as a second controller); closed-loop linearization; design feedback confirmed by re-run | `ctrl` | M5-B, M6 | M7, `tests/M7` |
| M8 | Uncertainty: judgment-width groups, bound-worst margin over the joint-coverage box, Monte Carlo at the critical condition, Clopper–Pearson, Robust verdict | `uq` | M6, M7 | M8, `tests/M8` |

**Review agents** (read-only on implementation):
- R1 after M5-A/B
- R2 after M5-C and M6
- R3 after M7 and M8
- a final holistic review

Each one:
- re-runs the gates
- audits the tests for vacuity, weak tolerances and wrong physics
- proposes additional sabotages, which the coordinator registers and runs

## Parallel-work rules (enforced by infrastructure added before M5)
- `run_vital_tests('M5', 'Phase', 'red', 'Increment', {classes}, 'Baseline', {done}, 'Tag', 'A', 'ReportDir', ...)`. Other increments' unfinished tests are skipped, so they cannot break this gate. The full gate (no options) still runs everything.
- Sabotages go in `tests/M<k>/sabotages_<part>.json`, and `run_sabotage('M5', 'Parts', {'A'})` runs one part.
  - The tree-hash check assumes a quiet tree, so a hash mismatch during parallel work is not evidence of harm.
  - The coordinator runs the authoritative sabotage check with the tree quiet.
- **Shared documents are edited only by the coordinator:** CONVENTIONS, DECISIONS, FAILURE_CATALOGUE, VERIFICATION_MATRIX, CHANGELOG, `version.m`.
  - Agents write fragments to `reports/fragments/<agent>/`: `DECISIONS.md` (proposed ADRs), `FAILURE_CATALOGUE.md` (rows), `CHANGELOG.md`, `NOTES.md` (open issues).
- **Failure-catalogue rows for an open milestone** may stay `PLANNED` until the milestone closes. A closed milestone must have every row pointing at a real test (`docs/MILESTONES.json`).

## Interface contract (agents must not change these without the coordinator)

### Plant (existing, M3)
```
[xdot, y] = vital.plant.derivatives(x, u, AC, env)
```
- `x` has 13 elements: v_b, w_b, q (N→B), p_n.
- `u = [de da dr throttle]`.
- M5-B may **add** diagnostic fields to `y` (e.g. `quatNorm`, `nz`) but must not change existing ones.

### M5-A linear
```
lin = vital.linear.linearize(AC, env, tr, 'Name', value, ...)
```
- `tr` must have status OK, otherwise error `vital:linear:notTrimmed`.
- **State:** `x_lin = [u v w p q r phi theta psi pN pE h]` (12, SI, rad).
- **Output fields:**
  - `A` (12×12), `B` (12×4), `stateNames`, `inputNames`, `x0`, `u0`, `status` ('OK' | 'NOT_CONVERGED'), `reason`, `stepStudy`
  - `lon` (states u w q theta), `lat` (states v p r phi)
  - converters to `[V alpha q theta]` and `[beta p r phi]`
- Option `'Controller'` (M7) linearizes the closed loop.

```
J = vital.linear.jacobian(f, z0, h0, ...)
```
The generic step-study central difference, with FC-506 when no step plateau is found.

```
m = vital.linear.modes(lin)
```
Returns a struct array, one entry per mode, with fields:
- `name`: short_period | phugoid | dutch_roll | roll | spiral | other
- `eigenvalue`, `oscillatory`
- `wn`, `zeta`, `period`, `tHalf`, `tDouble`, `tau`
- `participation` (over the 8 states u v w p q r phi theta), `dominant`
- `status`: OK | NOT_OSCILLATORY (FC-507) | UNCLASSIFIED

Oscillatory pairs are reported once.

### M5-B sim
```
out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', T, 'Inputs', f, 'Controller', c, 'Plant', p, 'Guards', g)
```
- `Inputs`: `du = f(t)`, an additive control perturbation evaluated at the RK4 stage times, piecewise functions stepping exactly on step boundaries.
- `Controller`: a struct with fields `rate_hz`, `init` and `step`, where `[u, state] = step(t, x, y, u_ref, state)`. It is zero-order held across RK4 stages; `rate_hz` must divide 1/dt.
- `Plant`: a function handle with the plant signature (default `@vital.plant.derivatives`). The state is layout-agnostic; guards use `y` fields.
- **Output fields:** `t`, `x`, `u`, `y` (a struct of logged time series), `status` ('COMPLETED' | 'STOPPED'), `stopReason` (an identifier), `stopTime`.
- **Stop reasons:**
  - `vital:sim:nanState` (FC-302)
  - `vital:sim:quatNorm` (FC-601)
  - `vital:sim:envelope` (FC-602)
  - `vital:sim:ground`
  - `vital:sim:plantError`
- A bad `dt`/`tFinal` is an error `vital:sim:badStep` (FC-301).
- `vital.sim.rk4(f, x0, dt, N)` is the integrator core (used by the order tests).
- Input helpers: `vital.sim.doublet(t0, width, amp, channel)`, `vital.sim.stepInput(t0, amp, channel)`.

### M5-C rotating Earth
- `vital.plant.derivativesRotating(x, u, AC, env)`: WGS-84 or sphere, J2 or central gravitation per the TM, and its own state layout (documented).
- It runs through `vital.sim.run` via `'Plant'`.
- `vital.nesc.runCase(id)` returns time series in NESC signal names and units. The comparison uses `vital.verify.envelopeCheck` with the **pre-registered bands in `docs/NESC_CASE_MATRIX.json`**.

### M6 flying qualities
- Rules: `vital.fq.loadRules(folder)`, where each record passes `vital.io.validateRule`.
- `res = vital.fq.assess(rules, acFactory, conditions, ...)`:
  - per rule: Level, normalized margin, critical condition and status
  - non-OK points never improve a verdict (FC-702)
  - all points infeasible gives `NOT_ASSESSABLE` (FC-701)
- Metric extractors: `vital.fq.metrics(lin, modes, ...)`.

### M7 control
- Controllers follow the M5-B controller struct.
- `vital.ctrl.pitchSas`, `vital.ctrl.yawDamper`, `vital.ctrl.nescLqr`.
- Design feedback: `vital.ctrl.suggestGains(...)` must be confirmed by re-running `vital.fq.assess`.

### M8 uncertainty
- `vital.uq.boundWorst`, `vital.uq.monteCarlo`, `vital.uq.clopperPearson`, `vital.uq.verdict`.

## Exit criteria for "done to M8"
1. `run_vital_tests('M8')` is GREEN from a fresh MATLAB session (`restoredefaultpath`, no `startup_vital`), with 0 excluded.
2. `run_sabotage('M5')` … `('M8')` detect every sabotage, with the tree unchanged.
3. Every failure-catalogue row for M5–M8 names a real test, and M5–M8 are closed in `docs/MILESTONES.json`.
4. Review agents report no unresolved defect. Anything unresolved is listed in the final report as an open issue, never hidden.
5. User entry points work: `run_f16_modes`, `run_f16_sim`, `run_f16_fq`, and the M7/M8 demonstrations.
