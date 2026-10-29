# Plan D1: aircraft data as objects (DRAFT, queued after I0)

Status: requested by the user on 2026-10-27 ("the data from the NASA files ... in the OOP format ... for all the aircraft data, proper for later use"). Gated red-green like every increment. It starts after I0 is verified, because only one agent runs at a time.

## 1. Today (measured)
- `vital.daveml.read(file)` already parses each NASA DAVE-ML file into a struct with variables (name, units, min/max), breakpoints, tables (`functions`: inputs, breakpoints, data, extrapolation), MathML build-up equations and check cases.
- That struct is used **only** to generate code: `+vital/+models/+f16/{aero,prop,inertia,control,gnc}.m`. In the generated code the tables are anonymous `K.f1_data ... K.f18_data` with no names, units or source.
- `vital.aircraft.f16.config` then hand-copies geometry, mass and limits into the flat `AC` struct, with the sources in comments.
- `vital.aircraft.f16.model()` (0.9.1-CORE) builds the axes, components and mass from `config`.
- So the NASA data can't be inspected or called by name, and there is no file format another aircraft (X-57) could be written in.

## 2. Design: one data object per aircraft, built straight from the source files
Package `+vital/+data` (classes):

| Class | Holds | Main calls |
|---|---|---|
| `Parameter` | value, units, description, source (file, line, SHA-256, DAVE-ML varID) | `.value`, `.si()`, `disp` shows units and source |
| `Breakpoint` | name (the input variable, e.g. `alpha`), units, values | — |
| `Table` | name / varID (e.g. `CXT`), output units, breakpoints (ordered), data, extrapolation flags, limits, source | `.at('alpha', 5, 'el', 0)` (by name, any order), `.at([el alpha])`, `.grid()`, `.toGriddedInterpolant()` (MATLAB built-in, used as the INDEP check), `.plot()` |
| `AeroDatabase` | reference geometry (`Parameter`s S, b, cbar), moment reference axis, the tables, the build-up equations per output coefficient, the data axes (body / stability / wind), the inputs | `.table(name)`, `.list()`, `.coefficients(inputs)` (evaluates the build-up), `.checkCases` |
| `PropulsionData` | thrust tables, power-level schedule, engine axis, (later) torque / h_rot / prop data | `.table(name)`, `.thrust(inputs)` |
| `MassData` | mass, inertia, CG location as `Parameter`s, plus the `MassProperties` object | `.massProperties(cgAxis)` |
| `ControlData` | the NASA control-law gains and limits (`F16_control.dml`, `F16_gnc.dml`) as `Parameter`s and `Table`s | `.parameter(name)` |
| `AircraftData` | name, `geometry`, `axes` (the axis tree), `aero`, `propulsion`, `mass`, `controls` (names, limits, roles), `checkCases`, `provenance` (every source file with its SHA-256) | `.save(file)` / `AircraftData.load(file)` (JSON, lossless), `.summary()`, `.validate()` |

**How it is called** (the same naming style as the core):
```matlab
f16_data  = vital.aircraft.f16.data();            % read from data/nesc/... (read-only), checked against MANIFEST.json
f16_data.geometry.S                               % Parameter: 300 ft^2 (27.871 m^2), F16_aero.dml line ..., SHA ...
table_cxt = f16_data.aero.table('CXT');           % Table: breakpoints el [deg], alpha [deg]
cx        = table_cxt.at('alpha', 5, 'el', 0);    % lookup by name
table_tmil = f16_data.propulsion.table('T_MIL');  % thrust vs Mach, altitude
mass_f16  = f16_data.mass.massProperties(f16_data.axes.cg);
f16       = vital.AircraftModel.fromData(f16_data);   % the model is built from the data object
f16_data.save('f16.vital.json');                  % aircraft-agnostic file
x57_data  = vital.data.AircraftData.load('x57.vital.json');   % later aircraft, same format
```
The same loader builds the NESC brick and cannonball (`vital.aircraft.nesc.brick.data()` and so on), so the format is checked on three aircraft, not one.

**Speed is unchanged.** The data object is the definition. The runtime still uses the generated code (or a compiled form of the data object), and a test proves the two are equal bit for bit. Nothing in the hot loop calls a `Table` method.

**What changes in existing code:** `vital.aircraft.f16.model()` is built from `f16_data` instead of `config`. `config()` stays and is checked to give identical numbers to the data object, so trim, FQ, UQ and Simulink are untouched.

## 3. Success criteria (written before any code)
1. Every table, breakpoint vector and constant in the five F-16 `.dml` files, and in the brick and cannonball files, is present in the data object with exactly the file's values (PUB, exact), its units and its source line. A test lists any `.dml` entry that is missing.
2. `Table.at` equals the generated-code lookup **bitwise** at every breakpoint and at 10,000 random points, including outside the range (clamped exactly as the generated code clamps). `toGriddedInterpolant` agrees to 1e-12 inside the range (INDEP).
3. `aero.coefficients` reproduces every NASA `checkData` case to its stated tolerance (PUB).
4. `AircraftModel.fromData(f16_data)` is bitwise equal to today's `vital.aircraft.f16.model()` over the 1,100-state set and passes the I0 known-answer tests. `f16_data` gives the same S, b, c̄, mass, J, r_cg, r_mrc and limits as `config()` (exact).
5. `save` → `load` round trip is bitwise for every number, with no `num2str` loss, and keeps units and provenance.
6. Every `Parameter` and `Table` has units and a source. `validate()` rejects any object without them (`vital:data:noProvenance`, `vital:data:noUnits`).
7. `data/` is unchanged (MANIFEST hashes). A file whose hash differs is refused (`vital:data:hashMismatch`).
8. Full suite green; F-16 anchors unchanged (README trim, M7 Levels, M8 smoke, Simulink E = 0); plant time per call within 1.05x.

## 4. Sabotages (each must be detected)
- A table stored with its breakpoint order swapped (a transposed `CXT`).
- A breakpoint name mapped to the wrong input (`alpha` ↔ `el`).
- A unit not converted (ft² kept as m²).
- Provenance stripped from one table.
- JSON written with `num2str` (precision loss).
- `fromData` taking the CG from the wrong axis.

## 5. Documents
ADR-042, FC rows, VERIFICATION_MATRIX rows, a FRAMEWORK_GUIDE chapter "Aircraft data objects" (with how to write a new aircraft's `.vital.json`), CHANGELOG, version 0.9.3-DATA.

## 6. Out of scope (later increments)
- Uncertainty multipliers attached to `Table`s (that is I5).
- X-57 data entry (I8).
- Writing DAVE-ML back out.
