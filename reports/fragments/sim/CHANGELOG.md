# M5-B (agent `sim`): fixed-step time simulation — gate evidence (2026-09-29)

## Added
- `+vital/+sim/run.m`: RK4 time simulation with:
  - inputs (smooth handles or piecewise specifications aligned to step boundaries)
  - a zero-order-held discrete controller `{rate_hz, init, step}`
  - a layout-agnostic `'Plant'`
  - logging of y fields
  - guards: nanState, quatNorm, envelope, ground, plantError, and optional outOfEnvelope
  - identified set-up errors (`vital:sim:badStep`, `vital:badInput`)
- `+vital/+sim/rk4Step.m` (the shared RK4 core) and `+vital/+sim/rk4.m` (generic integrator)
- `+vital/+sim/doublet.m`, `+vital/+sim/stepInput.m` (input specifications)
- `run_f16_sim.m`: the user entry point. It trims with `vital.aircraft.f16.trimLevel`, applies a doublet or step on elevator, aileron, rudder or throttle, simulates, and prints a summary (with an optional plot). A non-OK trim is reported and not simulated.
- `+vital/+plant/derivatives.m`, additive y fields only: `quatNorm`, `phi`, `theta`, `psi`, `p`, `q`, `r`, `specificForce_b`, `nz`. No existing field or behaviour changed; all M0–M4 tests pass.
- Tests (TestTags M5): `tests/M5/tSimCore.m` (9 tests), `tests/M5/tSimGuards.m` (13), `tests/M5/tF16Sim.m` (8)
- Sabotages: `tests/M5/sabotages_sim.json` (S5S-1 … S5S-5)

## Gate evidence
**RED:** `reports/work/sim/M5_red_sim.txt`
- 246 tests: PASS 217 (M0–M4), RED_EXPECTED 29, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 0, REGRESSION 0, EXCLUDED 0
- GATE OK

**GREEN:** `reports/work/sim/M5_green_sim.txt`
- 247 tests: PASS 247, EXCLUDED 0
- GATE OK (166 s)
- The extra test is the corrected `tSimCore/quaternionNormFollowsStabilisedRk4Error`. It was added after pre-registered hypothesis 5 failed, so it had **no RED run** (same pattern as tF16Trim hypothesis 3).

**Sabotage:** `reports/work/sim/M5_sabotage_sim.txt`
- S5S-1 … S5S-5 all DETECTED
- tree unchanged: 1

## Pre-registered results
| Hypothesis | Registered | Measured | Outcome |
|---|---|---|---|
| RK4 order, harmonic oscillator (dt 0.1/0.05/0.025) | ratio in [15.5, 16.5] | 15.9988, 15.9997 | pass |
| RK4 order, smooth input through run (dt 0.05/0.025/0.0125) | ratio in [14, 18] | 15.9914, 15.9958 | pass |
| ZOH controller forcing (dt 0.1/0.05/0.025) | ratio in [1.8, 2.2] | 1.9991, 1.9996 | pass |
| Dropped mass | exact to round-off | exact | pass |
| Torque-free F-16: energy and \|H\| | drift <= 1e-7 rel | 8.5e-12, 2.4e-12 | pass |
| Torque-free F-16: quaternion norm | \| \|q\| - 1 \| <= 1e-10 | 1.273e-10 | **FAILED**; superseded by hypothesis 9 (closed-form stabilised-RK4 norm error), which passes; see NOTES.md §1 |
| Controller ZOH | 10 calls, held values, acc = 0.018 | as registered | pass |
| Guards | analytic stop times | nanState 1.00 s, plant nonFinite 0.50 s, plantError 0.50 s, envelope 0.26 s, ground 1.43 s / 1.01 s, quatNorm 0.10 s, outOfEnvelope 0.31 s | all exact |
| Trim hold, 60 s | registered bounds | deviations exactly 0 (\|q\| <= 1e-16) | pass; see NOTES.md §2 (floating-point fixed point) |
| Control signs | q < 0 (+de), p < 0 (+da), r < 0 (+dr), udot > 0 (+throttle) | all as registered | pass |

# M5-B R1 fixes (agent `sim`, 2026-09-30)

## Changed
- `+vital/+sim/run.m`:
  - **ADR-026.** The controller's y is evaluated at (x_k, u_applied), with u_ref(0) at k = 0.
  - **Controller failures.** A controller error stops with `vital:sim:controllerError`; a NaN output stops with `vital:sim:nanState`. Both log the y the controller saw.
  - **Command limits.** A new `out.controlLimit` records violations, with `Guards.stopOnControlLimit` (giving `vital:sim:controlLimit`) and `Guards.controlLimits`. Commands are never clipped.
  - **Piecewise-constancy check** (`vital:sim:inputNotPiecewiseConstant`).
  - The header is updated.
- **New files:**
  - `+vital/+sim/sampleController.m`: the per-sample controller semantics.
  - `+vital/+sim/controlLimits.m`: the default limits from AC.limits.
- `run_f16_sim.m` prints a command-limit violation.
- **Tests:**
  - new `tests/M5/tSimR1.m` (15 tests)
  - `tSimGuards` envelopeDefaultsFromAircraftLimits: tag PUB -> ANALYTIC (R1 MINOR 3)
  - `tF16Sim` header: the trim hold is plumbing evidence (R1 MINOR 1)
- **Sabotages:** new `tests/M5/sabotages_simR1.json` (S5SR-1..17).

## Gate evidence
- **RED** (`reports/work/sim/M5_red_simR1.txt`), with Increment {tSimR1} and Baseline {tSimCore, tSimGuards, tF16Sim}:
  - 262 tests: PASS 247, RED_EXPECTED 7, VACUOUS 8 (justified in NOTES §5), RED_UNEXPECTED / RED_SUSPICIOUS / REGRESSION / EXCLUDED 0
  - GATE OK
- **GREEN** (`reports/work/sim/M5_green_simR1.txt`), with Increment {tSimCore, tSimGuards, tF16Sim, tSimR1}:
  - 262/262 PASS, all M0–M4 included, EXCLUDED 0
  - GATE OK (152.9 s)
- **One failed pre-registered sub-expectation:** tSimR1 header 6, the elevator table edge. See NOTES §5.
- **Sabotage** (`reports/work/sim/M5_sabotage_sim_simR1.txt`), Parts {sim, simR1}:
  - All 22 sabotages DETECTED: S5S-1..5 and S5SR-1..17.
  - "tree unchanged: 0" is caused by parallel agents editing the tree (expected per AGENT_BRIEF); the coordinator re-runs on a quiet tree.
