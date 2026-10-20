# FRAMEWORK_GUIDE section draft (agent oop, 2026-10-19): 0.8.1-OOP

*Suggested place: a new chapter after "12. M7", before "13. The documents". Proposed title: "12a. The object layer and the MathWorks atmosphere (0.8.1-OOP)".*

## 12a. The object layer and the MathWorks atmosphere

### In plain words
Before 0.8.1, everything in VITAL was a function that took and returned plain structs. That design is fast, and it still is the engine. On top of it there is now a thin layer of MATLAB objects, so that a user can write

```matlab
ac  = vital.Aircraft('CG_PCT_MAC', 25);
fc  = vital.FlightCondition.fromFeet(565.6854, 10013);   % NESC README point
tr  = ac.trim(fc);                     % vital.TrimResult
lin = ac.linearize(tr);                % vital.LinearModel
m   = ac.modes(lin);                   % {ShortPeriod, Phugoid, DutchRoll, Roll, Spiral, ...}
C   = vital.fq.loadConditions(fullfile(vital.paths('rules'),'mil_f_8785c','conditions_f16.json'),'Grid','readme');
A   = ac.assess(C, 'Controller', vital.ctrl.PitchSasLaw('Kq', 0.2));
A.level('3.2.2.1.2-CatA')
[fw, st] = ac.toFixedWing(fc);        % Aero.FixedWing + Aero.FixedWing.State
```

Every object method calls the same function the struct user would call. `ac.toRuntime()` is exactly `vital.aircraft.f16.config(...)`, and `tr.toStruct()` is exactly the `vital.trim.solve` struct. The tests prove that the two routes give identical numbers.

### Why the engine stays functional
In the M8 uncertainty run the plant is called about 10^6 times. MATLAB method and property access cost more than struct access, so the hot loop (plant, loads, equations of motion, table lookups) stays on structs (ADR-005, still valid for the core). The objects are the outside: construction, validation, readable results, and the bridge to the Aerospace Toolbox objects (`Aero.FixedWing`, `Aero.FixedWing.State`, `aircraftEnvironment`).

### The classes
| Class | What it holds | Made by / delegates to |
|---|---|---|
| `vital.Aircraft` | the runtime struct of one aircraft | `vital.aircraft.f16.config` |
| `vital.FlightCondition` | V, h, gamma, psi, g, wind, atmosphere | builds `env` and the trim condition |
| `vital.TrimResult` | one trim | `vital.trim.solve` |
| `vital.LinearModel` | A, B | `vital.linear.linearize` |
| `vital.modes.Mode` + 5 subclasses | one mode | `vital.linear.modes` |
| `vital.rules.Rule` / `RuleSet` | MIL-F-8785C records | `vital.fq.loadRules`; `evaluate` = the engine's rule |
| `vital.fq.Assessment` | an assessment | `vital.fq.assess` |
| `vital.atmos.Atmosphere` / `IsaAtmosphere` | an atmosphere model | `vital.env.atmosphere` |
| `vital.ctrl.ControlLaw` + `PitchSasLaw`, `YawDamperLaw`, `NescLqrLaw`, `CombinedLaw` | gains of a law | the M7 law functions |
| `vital.uq.Study` | the options of an uncertainty run | `run_f16_uq` |

### The atmosphere is now MathWorks' atmosisa
- `vital.env.atmosphere(h)` calls the Aerospace Toolbox `atmosisa`. The wrapper adds the two things VITAL needs:
  - **Geopotential height.** atmosisa takes geopotential height, but VITAL's states hold geometric height, so the wrapper converts first.
  - **No silent clamp.** Outside -5 km to 84.852 km (geopotential), atmosisa holds the edge value and only warns. VITAL raises `vital:env:altitudeOutOfRange` instead, as it has since M1.
- The old name `vital.env.atmosphereUS76` still works; it now returns the same as `vital.env.atmosphere`.
- VITAL's own US 1976 code was kept, but only inside the tests (`tests/reference/us76Reference.m`), where it serves as an independent check.
- **How close the two are:**
  - Temperature and speed of sound match to better than one part in a million.
  - Pressure and density match to one part in a million below 10 km, and to 3 parts in a million at 32 km. The cause is that MathWorks derives the gas constant from sea-level values, which differ from US 1976's R*/M0 in the 7th digit.
  - NASA's published atmosphere check case still passes inside its pre-registered band.
- **Speed.** atmosisa checks its arguments on every call, which costs about 0.3 ms. The wrapper remembers the last altitude, so repeated calls at the same height (trim, linearization, flying qualities, uncertainty runs) cost almost nothing. A time simulation, where every step is a new altitude, is about 1.45 times slower than before.

### Why the frame functions were not swapped
MathWorks' `angle2dcm`, `quat2dcm`, `dcm2quat`, `lla2ecef`, `ecef2lla` and `dcmecef2ned` use the same conventions as VITAL; M1 proved it. They are, however, 6 to 64 times slower per call (ADR-037 table). The rule was to swap a function only if its speed is not materially worse, so VITAL keeps its own. The toolbox versions remain the independent check in the M1 tests.

### How it is verified
- **tests/M8/oop/** (tag `OOP`): 25 tests. They cover:
  - class contracts and validation errors;
  - `toRuntime` isequal to the config struct;
  - trim, linearize and modes equal to the functional chain to 1e-12;
  - `Rule.evaluate` equal to the M6 engine on all 118 records;
  - the atmosisa wrapper (range error, geopotential, agreement, NESC band);
  - the toolbox state (rho, qbar, Mach, C_bn);
  - the plant performance gate.
- **tests/M8/sabotages_oop.json:** 9 deliberate defects. Each must turn a test red.
