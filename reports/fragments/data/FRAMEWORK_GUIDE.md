# FRAMEWORK_GUIDE fragment (agent data, 2026-10-27): chapter draft (after 12c)

## 12d. Aircraft data objects

**Why.** NASA's F-16 comes as five DAVE-ML files: tables, breakpoints, constants, build-up equations and check cases, each with units. Before D1 VITAL turned them straight into generated code, where the tables became anonymous arrays (`K.f1_data`), and `config.m` copied the geometry and mass by hand. You could not ask "what is CX0 at 5 degrees, and where does that number come from?", and there was no format in which to write a second aircraft. Now every aircraft is one data object, read straight from its source files, in the same object style as the core (12c), and every number in it carries its units and its source: file, line, SHA-256 and DAVE-ML id.

**Calling the data by name.**
```matlab
f16_data  = vital.aircraft.f16.data();            % read from data/nesc/... (read-only, SHA-256 checked)
f16_data.geometry.S                               % S = 300 ft2 (27.8709 m2)  [F16_aero.dml:380 [sref], sha256 82796577...]
f16_data.geometry.S.si()                          % 27.870912 (m2)
table_cxt = f16_data.aero.table('CXT');           % Table cxt (CX0): el [deg] x alpha [deg], F16_aero.dml:976
cx        = table_cxt.at('alpha', 5, 'el', 0);    % by input name, any order; = table_cxt.at([0 5])
table_tmil = f16_data.propulsion.table('T_MIL');  % thrust vs RMACH [nd], ALT [ft]
mass_f16  = f16_data.mass.massProperties(f16_data.axes.cg);
f16_data.controlLaw('control').parameter('longLQR11')   % a NASA control-law gain, with units and line
f16_data.aero.list()                              % every variable: varID, name, kind, units, line
f16_data.aero.equation('cx')                      % the build-up of CX, as compiled from the MathML
rep = f16_data.aero.runChecks();                  % NASA's 16 check cases, through the data object
f16       = vital.AircraftModel.fromData(f16_data);   % the model is built from the data
f16_data.save('f16.vital.json');                  % aircraft-agnostic file, lossless
x57_data  = vital.data.AircraftData.load('x57.vital.json');   % later aircraft, same format
```
`run_data_example` runs all of this and prints a summary; the brick and the cannonball are read by the same loader (`vital.aircraft.nesc.brick.data()`, `vital.aircraft.nesc.cannonball.data()`).

**The classes (package `vital.data`).**

| Class | What it holds | Main calls |
|---|---|---|
| `Source` | file (relative to the data root), line, SHA-256, varID, element, note | `isValid()`, `char` |
| `Parameter` | value in the published units, units, description, source | `si()`, `siUnits()`, `validate()` |
| `Variable` | a Parameter + its role: input, constant, calc (expression) or table output; saturations | (as Parameter) |
| `Breakpoint` | the input it indexes (e.g. `alpha`), bpID, units, values | |
| `Table` | output varID and name, breakpoints in table order, data, extrapolation, limits | `at`, `grid`, `toGriddedInterpolant`, `plot` |
| `DaveModel` | one DAVE-ML file: variables, breakpoints, tables, check cases | `variable`, `parameter`, `table`, `equation`, `list`, `evaluate`, `runChecks` |
| `AeroDatabase` | + reference S, b, cbar; the MRC axis; which variable is which coefficient, in which axes | `coefficients(in)` |
| `PropulsionData` | + engine axis; which variable is which force/moment | `thrust(in)` |
| `MassData` | + the inputs (F-16: CG_PCT_MAC); mass, inertia, CG found by their AIAA names | `massSI`, `inertiaSI`, `cgSI`, `evaluated(name)`, `massProperties(axis_cg)` |
| `ControlData` | a control law (F-16: `F16_control.dml`, `F16_gnc.dml`) | `parameter(name)` |
| `AircraftData` | name, geometry, axes, aero, propulsion, mass, control laws, controls, limits, check cases, provenance, runtime binding | `save`, `load`, `summary`, `validate`, `verifySources`, `toConfig`, `models` |

**Fast and exact.** The data object is the definition, not the hot path. The plant still runs the generated code. `evaluate` runs the same expressions, the same `vital.daveml.lookup` calls and the same saturations, so the data object and the generated code agree bit for bit on all nine files. `Table.at` agrees with the generated code at every grid node and at 20,000 random points, including clamping out of range. MATLAB's `griddedInterpolant` agrees to a few ulp as an independent check. `vital.aircraft.f16.model()` is now `fromData(vital.aircraft.f16.data(...))`, and it is bitwise the 0.9.1-CORE model over 1,100 states. Its time per call is unchanged. The files are parsed once per MATLAB session (about 8 s); later calls take about 20 ms, because the hashes are re-checked every time.

**Units and provenance are enforced.** An `AircraftData` cannot be built, or loaded, if any number lacks units (`vital:data:noUnits`) or a valid source (`vital:data:noProvenance`). The source files are read only through `data/MANIFEST.json`, and a changed file is refused (`vital:data:hashMismatch`). Derived numbers name the element they come from and say how in `note`. Examples: the alpha limit is "range of the ALPHA1 alpha breakpoints"; the CG axis origin is "[DXCG DYCG DZCG] ft from the MRC at CG_PCT_MAC = 25, x 0.3048".

**`config()` is still there.** `vital.aircraft.f16.config()` is unchanged. A test checks it against `f16_data.toConfig()` field by field (exact). It is now an independent hand copy that guards the reader.

### How to write a new aircraft's `.vital.json`

A `.vital.json` file is plain JSON. Write it by hand, or from a script that builds an `AircraftData` and calls `save`. The smallest complete example is `tests/M9/data/toy_glider.vital.json`, a toy aircraft with one lift table that the tests load. Top level:

| Key | Content |
|---|---|
| `format`, `formatVersion` | `"vital.aircraftdata"`, `1` |
| `name`, `description`, `options`, `meta` | text; free structs |
| `axes` | list of `{name, parent, dcm, origin}`; the root has `parent ""`; parents come first; `dcm` is C_this_parent (CONVENTIONS 3); `origin` is a Parameter in `m`, in the parent's axes |
| `aero` | `{class "AeroDatabase", name, role, source, reference {S, b, cbar}, mrcAxis, coefficientMap [{role, varID, axes}], variables, breakpoints, tables, checkCases}` |
| `propulsion` | `[]` (none), or `{class "PropulsionData", ..., engineAxis, outputMap [{role, varID}]}` |
| `mass` | `{class "MassData", ..., inputs {}, variables}`, using the AIAA names `totalMass`, `bodyMomentOfInertia_Roll/_Pitch/_Yaw`, `bodyProductOfInertia_XY/_ZX/_YZ`, `bodyPositionOfCmWrtMrc_X/_Y/_Z` |
| `controlLaws` | list of `{class "ControlData", ...}` |
| `controls` | list of `{name, role, varID, limit}`; `limit` names a key of `limits` |
| `limits` | `{key: Parameter}` |
| `provenance` | list of `{file, sha256, role, name}`; every model's `source.file` must be listed here with the same SHA-256 |
| `runtime` | `{loadsFcn, components [{name, kind "aero"/"propulsor", axis, fcn, channels, args "config"/""}], aeroScaleNames, configMeta, cgAxis, root}`; function names must be in the `vital` namespace; leave `components` empty if the aircraft has no AircraftModel yet |

Pieces:
- **Parameter:** `{"name", "value", "units", "description", "source"}`.
- **Source:** `{"file", "line", "sha256", "varID", "element", "note"}`. `file` is relative to the data root and should be listed in `data/MANIFEST.json`. `sha256` is the file's hash (64 hex digits). `line` is where the number is.
- **Variable:** a Parameter plus `varID`, `kind` (`input`, `constant`, `calc` or `table`), `minValue`, `maxValue`, `isInput`, `isOutput`, `expression` and optionally `deps`. An input's `value` is its default.
- **Breakpoint:** `{"bpID", "name", "units", "values", "source"}`.
- **Table:** `{"varID", "name", "units", "inputs" [input varIDs in table order], "bpIDs" [one per input], "data", "extrapolate" ["neither", ...], "source"}`. `lo` and `hi` are optional; they default to the breakpoint range.

Rules:
1. **Numbers.** Write a plain JSON number, or a JSON array (read as a row). For a matrix or N-D table use `{"size": [5, 12], "values": [...]}`, column-major, so the FIRST breakpoint varies fastest in `values`. (DAVE-ML lists the LAST breakpoint fastest; `vital.daveml.read` reorders.) Write `NaN`, `Inf` and `-Inf` as strings. `save` writes 17 significant digits, so a saved file round-trips bit for bit.
2. **Units.** Use the DAVE-ML abbreviations known to `vital.data.unitFactor` (`ft`, `ft2`, `slug`, `slugft2`, `lbf`, `deg`, `nd`, ...) or SI (`m`, `m2`, `kg`, `kgm2`, `N`, `Nm`, `rad`). An unknown unit is an error, never a silent factor of 1.
3. **Expressions.** A `calc` variable's `expression` uses `v_<varID>` for other variables. It may contain numbers, `+ - * / ^`, comparisons, `& | ~`, brackets, `abs cos sin tan exp floor ceil log min max atan2` and `vital.daveml.piecewise`. Anything else is refused on load (`vital:data:badExpression`). A data file can never run code.
4. **Check it.** `d = vital.data.AircraftData.load(file)` validates everything. Then use `d.summary()`, `d.aero.runChecks()` (if the file has check cases), and `d.aero.table(...).plot()`.

For an aircraft that has DAVE-ML files, prefer a builder like `vital.aircraft.f16.data` over hand-writing: add the files to `data/MANIFEST.json`, read each with `vital.data.DaveModel.partsFromDaveML`, and save the result. The X-57 (I8) will be written in this format.

**How we know it is right.** 32 tests in `tests/M9/data`, written before the classes:
- every entry of the nine files against an independent text scan;
- NASA's 25 check cases;
- the generated code bit for bit, and `griddedInterpolant`;
- the 1,100-state model equivalence and `config()` field for field;
- a bitwise JSON round trip, including -0, subnormals and NaN;
- validation and hash refusal;
- the timing.

Nine sabotages are each caught: a transposed table, swapped input names, an unconverted ft2, stripped provenance, `num2str` in the JSON writer, the CG taken from the MRC, a skipped hash check, a forgotten saturation, and a bypassed expression whitelist.
