# Plan: object-oriented layer + MATLAB built-in classes + atmosisa (DRAFT, awaiting user approval)

Status: APPROVED by the user 2026-10-19. Gated red-green like every milestone.
User decisions: (1) classes outside, fast numeric core; (2) do it NOW, M8 paused (its full run is done afterwards on the new code); (3) atmosisa everywhere, including the NESC cases, with a test proving agreement with US76 within the NESC bands. Section 6 below is superseded by (2).

## 1. What exists today (measured)
- 161 `.m` files in `+vital`; 3 are classes (`VitalTestCase`, `DavemlCase`, `uq.F16Evaluator`). Everything else is pure functions on flat numeric structs. That was a deliberate decision (ADR-005) for code generation and speed.
- Aerospace Toolbox is used today only as an **independent check** in the tests (`angle2dcm`, `quat2dcm`, `lla2ecef`, `gravitywgs84`, `atmoscoesa`, `correctairspeed`, `dcmecef2ned`).
- The atmosphere is VITAL's own US76 (`vital.env.atmosphereUS76`), called from 17 files.

## 2. Research findings (probed on this R2025b install)
| MATLAB resource | Useful? | Finding |
|---|---|---|
| `Aero.FixedWing.State` (`fixedWingState`) | **Yes, as the state/condition object** | Holds mass, inertia, CG, alpha, beta, V, Euler angles, rates, environment, and gives the derived quantities: dynamic pressure, Mach, flight-path angle, and the body/wind/stability/inertial DCMs |
| `Aero.Aircraft.Environment` (`aircraftEnvironment(ac,'ISA',h)`) | **Yes** | ISA or COESA density, temperature, pressure, speed of sound, gravity, wind |
| `Aero.FixedWing` (`fixedWingAircraft`) | **Partly** | Reference S, b, c̄, surfaces, thrust. Its coefficient model is a sum of terms that are linear in the states (optionally with lookup tables). It **cannot reproduce NASA's F-16 equations exactly** (e.g. CZ0(α)·(1−β²), β-α tables for Cl and Cn), so it cannot replace VITAL's verified aero without failing NASA's check data |
| `staticStability` | **Yes, as an extra check** | Runs here; gives a Stable/Unstable table of the static derivatives |
| `linearize`, `analyzeFlyingQualities`, `Aero.FixedWing.Specification` | **Not on this install** | Both call `ss`, which needs the Control System Toolbox (not installed: "Undefined function 'ss'"). The Specification class is also generic: min/max damping, frequency and time to half. It has no MIL-F-8785C Levels, Categories or CAP, and no citations. VITAL's rule records do more |
| `atmosisa` | **Yes** | Matches VITAL and `atmoscoesa` below 32 km (ρ differs by ~1e-7 at 10 km). Note: its input is **geopotential** height, and outside −5 km…84.852 km it **holds the value and only warns**, which is the silent clamp that VITAL deliberately fixed in M1 |
| `angle2dcm`, `dcm2quat`, `quat2dcm`, `quat2angle`, `dcmbody2wind`, `dcm2alphabeta`, `dcmecef2ned`, `lla2ecef`, `ecef2lla`, `lla2flat`, `gravitywgs84` | **Yes** | Same conventions as VITAL (scalar-first N→B quaternion, 3-2-1 Euler) |
| `airspeed`, `machnumber`, `dpressure`, `correctairspeed`, `convvel`/`convlength`/`convmass`/`convforce`/`convang`… | **Yes** | Air data and unit conversion |
| `Aero.Body`, `Aero.FlightGearAnimation` | Later (M9 visualisation) | 3-D animation |
| `jsbsimToFixedWing`, `datcomToFixedWing` | Later (X-57) | Import aircraft from JSBSim XML / DATCOM |

## 3. Proposed design: object-oriented outside, fast numeric core inside
A fully object-oriented hot loop (plant called ~10^6 times in the uncertainty run) would make the 11–14 h run slower, since MATLAB object method and property access costs more than struct access. So:

**Classes (the user-facing and architectural layer):**
- `vital.Aircraft` (value class): geometry, mass, CG, limits, aeroScale, models. Builds from `vital.aircraft.f16.config`. Methods `trim`, `linearize`, `modes`, `assess`, `toFixedWing` (→ `Aero.FixedWing` for S/b/c̄/mass display and `staticStability`), `toRuntime` (→ the existing numeric struct for the core).
- `vital.FlightCondition`: type, V, h, γ, turn rate... Wraps/produces an `Aero.FixedWing.State` with an `aircraftEnvironment('ISA', h)`.
- `vital.TrimResult`, `vital.LinearModel` (A, B, eigenvalues), `vital.Mode` subclasses (`ShortPeriod`, `Phugoid`, `DutchRoll`, `Roll`, `Spiral`, mirroring MATLAB's mode classes).
- `vital.rules.Rule` / `vital.rules.RuleSet` (MIL-F-8785C records as objects; `evaluate(mode)` → Level, margin) and `vital.fq.Assessment`.
- `vital.uq.Study`, `vital.ctrl.ControlLaw` (base) with the M7 laws as subclasses.
- `vital.Atmosphere` (abstract) → `IsaAtmosphere` (atmosisa, the default) and `US76Atmosphere` (kept for the NESC reproduction, which specifies US76).
- Later: `vital.Mission`, `vital.Segment`, `vital.Component` (mission feasibility, fuel/CG).

**Numeric core (stays functional, called by the class methods):** `plant.derivatives`, `loads`, `eom`, `frames`, the table lookups. The existing tests keep protecting it.

**Built-in functions used directly in the core:** frames (`angle2dcm`, `dcm2quat`, `quat2dcm`, `quat2angle`), geodesy (`lla2ecef`, `ecef2lla`, `dcmecef2ned`, `gravitywgs84`), and air data where the conventions match. VITAL's own versions are then kept only inside the tests as the independent check, so the tests don't compare MATLAB with itself.

## 4. atmosisa
- Default atmosphere becomes `atmosisa`, wrapped so that (a) geometric → geopotential altitude is converted first, and (b) out-of-range altitude is still an error (`vital:env:altitudeOutOfRange`), not a held value.
- The NESC check cases specify US76: they keep US76 explicitly (`atmoscoesa` or VITAL's own), or show they agree within the NESC band.
- Fact for the record: ISA (ICAO) is not newer physics than US76; the two are identical up to 32 km. The change is about using the maintained MathWorks implementation.

## 5. Gates (red-green, as always)
1. **Tests first:** class contracts (construction, validation, `toRuntime` gives the identical struct, `trim` equals the functional trim to 1e-12), atmosisa wrapper (range error, geopotential input, agreement with US76 ≤ 1e-6 relative below 32 km), built-in frame functions (round trips, conventions), `toFixedWing` (S, b, c̄, mass, inertia match).
2. **Equivalence gate:** every existing test (663) still green; the M7 Levels and the M8 smoke headline unchanged.
3. **Performance gate:** plant time per call within 10 % of today's 0.73 ms.
4. **Sabotages:** wrong atmosphere input (geometric fed as geopotential), clamp instead of error, `toRuntime` dropping a field, wrong DCM convention.
5. FRAMEWORK_GUIDE chapter on the class layer.

## 6. Order
Recommended: finish and close M8 first (restart the full uncertainty run), then this as its own milestone, since it touches the plant that M8's results are measured on.
