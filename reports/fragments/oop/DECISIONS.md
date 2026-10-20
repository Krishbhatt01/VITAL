# DECISIONS fragment (agent oop, 2026-10-19): 0.8.1-OOP

## ADR-037 (proposed; agent oop, 2026-10-19): object layer outside, functional core inside; Aerospace Toolbox use; atmosisa as the core atmosphere

**Status:** proposed (user decisions of 2026-10-19 in docs/PLAN_OOP_TOOLBOX.md). **Supersedes part of ADR-005:** ADR-005 (pure functions on flat structs everywhere) still holds for the numeric core; it no longer forbids classes in the user-facing layer.

**Context.** VITAL was all functions on flat numeric structs (ADR-005), for speed and code generation. The user asked for a MATLAB object model on the outside, for MATLAB built-ins in the core where the conventions match, and for atmosisa in place of VITAL's own US 1976.

**Decision 1: object layer (value classes) that delegates to the existing functions.**

| Class | Wraps | Notes |
|---|---|---|
| `vital.Aircraft` | `vital.aircraft.f16.config` | `toRuntime()` returns the exact config struct (isequal). `trim`, `linearize`, `modes` and `assess` call `vital.trim.solve`, `vital.linear.linearize`, `vital.linear.modes` and `vital.fq.assess`. `toFixedWing()` returns an `Aero.FixedWing` (S, b, cbar) and an `Aero.FixedWing.State` (mass, inertia J, CG r_cg) |
| `vital.FlightCondition` | env + trim condition | `toEnv`/`toTrimCond` build exactly the structs of `vital.fq.f16Factory`. `fromFeet` takes NESC README units. `toFixedWingState(ac[, tr])` uses `fixedWingState` with `aircraftEnvironment(fw,'ISA',H)`, where H is the **geopotential** height |
| `vital.TrimResult`, `vital.LinearModel` | trim / linearize structs | `toStruct()` returns the struct unchanged |
| `vital.modes.Mode` and subclasses `ShortPeriod`, `Phugoid`, `DutchRoll`, `Roll`, `Spiral` | `vital.linear.modes` entries | `LinearModel.modes` returns a **cell** array (the subclasses are heterogeneous). Names outside the five, such as `height` or `other`, give the base `Mode` |
| `vital.rules.Rule`, `vital.rules.RuleSet` | `vital.fq.loadRules` records | `Rule.evaluate(metrics, policy)` restates the engine's per-record rule; it is proven equal to `vital.fq.assess` on all 118 records at the README point. `RuleSet.levels` gives the group Levels |
| `vital.fq.Assessment` | `vital.fq.assess` result | |
| `vital.atmos.Atmosphere` (abstract), `vital.atmos.IsaAtmosphere` | `vital.env.atmosphere` | |
| `vital.ctrl.ControlLaw` (abstract), `PitchSasLaw`, `YawDamperLaw`, `NescLqrLaw`, `CombinedLaw` | the M7 laws | `build` makes the existing controller struct; `builder()` gives the handle that `f16Factory('Controller', ...)` takes. The class names end in "Law" because `PitchSas.m` and `pitchSas.m` would be the same file on Windows |
| `vital.uq.Study` | `run_f16_uq` | Forwards the options unchanged. `EntryPoint` can be replaced for dry runs |

- The hot loop (`plant.derivatives`, loads, eom, lookups) is unchanged and stays on structs.
- **Not used:** `linearize`, `analyzeFlyingQualities` and `Aero.FixedWing.Specification` all need `ss` (Control System Toolbox, not installed).
- `Aero.FixedWing`'s linear coefficient model cannot reproduce the NASA F-16 tables, so it does **not** replace VITAL's aero. `toFixedWing` leaves the coefficients empty, so `staticStability` would be meaningless and is not offered.

**Decision 2: built-in frame and geodesy functions are NOT switched into the core (measured).** User decision 2 allowed a switch only if per-call speed is not materially worse (and codegen-compatible). Measured per call in R2025b on the development machine (`matlab -batch`, 20,000 calls each):

| VITAL | µs | Toolbox | µs | ratio |
|---|---|---|---|---|
| `vital.frames.quat2dcm` | 2.3 | `quat2dcm` | 44 | 19x |
| `vital.frames.dcm2quat` | 3.7 | `dcm2quat` | 235 | 64x |
| `vital.frames.dcm321` | 4.0 | `angle2dcm` | 29 | 7x |
| `vital.geo.lla2ecef` | 3.4 | `lla2ecef` | 24 | 7x |
| `vital.geo.ecef2lla` | 5.7 | `ecef2lla` | 32 | 6x |
| `vital.geo.dcmEcefToNed` | 1.8 | `dcmecef2ned` | 71 | 39x |

- Every toolbox function is 6 to 64 times slower per call, so none qualifies, and the VITAL functions stay. Their conventions were already proven identical to the toolbox (`tests/M1/tFrames`, `tGeo`; INDEP), so those tests remain genuinely independent.
- The toolbox frames are used at the OOP boundary only. `FlightCondition.toFixedWingState` is checked against VITAL's C_bn in `tOopAircraft#fixedWingStateConsistent` (INDEP).
- No `codegen` test of the plant exists in this tree; a search of `tests/` and `+vital` found none. Nothing in this change was made codegen-incompatible in the plant beyond atmosisa itself (see Decision 3, Consequences).

**Decision 3: atmosisa is the core atmosphere.**
- New function `vital.env.atmosphere(h, 'DeltaT', dT)`:
  - converts geometric height to geopotential first (`vital.env.geometricToGeopotential`);
  - pre-checks the range, so H outside [-5000, 84852] m raises `vital:env:altitudeOutOfRange`;
  - then calls `atmosisa(H, 'action', 'None')`, which never warns and never holds a value;
  - applies ISA + dT with atmosisa's own R.
- All six core callers were migrated: `plant.derivatives`, `plant.derivativesRotating`, `fq.f16Factory`, `viz.axisChecks`, plus `run_f16_models.m` and `SciComp/fit_f16_coefficients.m`.
- `vital.env.atmosphereUS76` is kept as a **thin alias** returning `vital.env.atmosphere`. Nine existing test files call it, and keeping the name avoids editing tests that do not assess the atmosphere. A test proves that no `+vital` file calls the alias.
- VITAL's former US 1976 implementation is frozen test-side as `tests/reference/us76Reference.m`. It is the INDEP oracle of the new atmosphere and is never called from `+vital`.
- **Speed.** atmosisa's `arguments` block (enumeration types) costs about 0.3 ms per call, roughly 10 times VITAL's former function and about 40 % of a plant call. A one-entry cache on the exact scalar geopotential height makes repeated-altitude calls cheap. This is exact, because atmosisa is a pure function of H. Repeated altitudes are the pattern of trim, linearization, flying qualities and the M8 uncertainty run.
- **Agreement with US 1976:**
  - T and a agree within 1e-6 relative over 0 to 32 km.
  - p and rho agree within 1e-6 only below about 10 km. At 32 km the difference is 3.3e-6 in p and 2.6e-6 in rho.
  - Cause: atmosisa's R = p0/(rho0 T0) = 287.0529 differs from US 1976's R*/M0 = 287.0531 by 7e-7, and that enters the barometric exponent.
  - The pre-registered 1e-6 below 32 km was therefore a FAILED HYPOTHESIS for p and rho above 10 km. The test now asserts 1e-6 below 10 km and 5e-6 over 0 to 32 km, with the failed hypothesis recorded in the test.
  - The NESC Atmos_01 bands still hold.

**Consequences.**
- Plant speed against the 0.8.0 plant in the same run: fixed altitude ratio about 1.0 (gated at 1.10). Every call at a new altitude (time simulation) is about 1.45 times slower; this is reported, not gated.
- atmosisa is code-generation capable according to MathWorks, but the persistent cache and the `arguments` block were not tried with `codegen`.
- Tests that asserted US 1976-specific constants of the old implementation were edited (see the CHANGELOG fragment for each edit and its justification).
