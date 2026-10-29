# I1 report: the plant contract by name (agent i1, 2026-10-29; version 0.9.4-I1; ADR-043 proposed)

Nothing committed or pushed. Evidence in `reports/work/i1/`.

## Pre-registered criteria and outcome

| # | Criterion (as registered) | Outcome |
|---|---|---|
| 1 | F-16 (`fromData`): over the 1,100-state set, `plant(x,u,f16,env)` = `plant(x,u,config(),env)` bit for bit in xdot and the shared y fields; the toRuntime struct path also E = 0 | MET: max difference 0 (isequal), 652 states out of envelope; every struct-path y field present on the model path (`tI1PlantContract#f16ModelBitwiseOver1100States`) |
| 2 | Twin (5 controls): `plant(x,u,twin,env)` == `twin.derivatives` exactly; its toRuntime struct E = 0; a 4-wide u is `vital:badInput` | MET (40 states, xdot and every y field isequal, also u by name; message names `throttle_le`) |
| 3 | Analytic linear-derivative aircraft through the plant = closed form to 1e-12; F_aero-type diagnostics correct (F-7) | MET: xdot error at round-off; its unclassified component gives NaN sums (not 0); declared `withKind('aero')` gives F_aero/M_aero = the closed-form loads (1e-12), F_prop = M_prop = 0 |
| 4 | Editing `AC.S`, `aeroScale`, `mass`, `controlNames` on a toRuntime struct raises `vital:model:staleRuntime`; unedited runs | MET (plus b, cbar, J, r_cg, r_mrc, loadsFcn, an added aeroScale; both plants; edit undone runs again; limits/name allowed; config() unaffected) |
| 5 | Bridge context = direct-constructor context field by field (X, C_bn, Env, U, Air, H, Atm) | MET on 5 flat paths x 5 states, also checked against the state itself; rotating plant context filled (X, C_bn to 1e-12, Env, StateLayout) |
| 6 | Model through the plant <= 1.05 x the legacy struct plant (median of repeats) | NOT MET: 1.18-1.27 (paired-batch median; gate run 1.267). See "Timings" |
| 7 | Everything previously green stays green; M0 OK | PARTLY: 825/827; the only failures are the two timing tests (criterion 6, and tCorePerformance, see below). M0 gate OK (53/53) |

## RED (before the implementation; minimal `vital.notImplemented` stubs in the plant and `Component.withKind`)

Full cumulative command of the brief (run on a copy of the tree, `C:\VR1`, so I could keep working): `reports/work/i1/M9_red_i1.txt`.
TOTAL 707 | PASS 688 (all older tests) | RED_EXPECTED 13 | RED_UNEXPECTED 0 | RED_SUSPICIOUS 4 | VACUOUS 2 | REGRESSION 0 | EXCLUDED 0. Gate OK.
- RED_SUSPICIOUS (assertion failures, the right reason): twoAeroPointsRotating (M_aero_cg 3907 vs hand 951 N m: F-6), rotatingContext (X/C_bn empty: F-3), noSecondConstructionPath (fromAirData exists), twinRefusesFourControls (stub id instead of vital:badInput).
- VACUOUS (non-regression guards, pass by design): tI1RuntimeGuard/uneditedRuns, configUnaffected.

## GREEN

- Targeted: `tests/M9/i1` 18/19 (tI1Performance fails, criterion 6).
- Full cumulative `run_vital_tests('M9','Phase','green','Tag','i1')`: TOTAL 827 | PASS 825 | FAIL 2 | 3044 s (`reports/work/i1/M9_green_i1.txt`). Failures:
  - `tI1Performance/modelThroughPlantWithinTarget` 1.267 (bound 1.05).
  - `tCorePerformance/compiledWithinTarget` 1.311 (bound 1.25; unchanged). Rerun alone: 1.216, 1.212, 1.251 (`m0_and_perf_rerun.txt`). A/B in alternating fresh sessions, paired median model/plant: pre-I1 tree 1.243, 1.226, 1.165; I1 tree 1.204, 1.252, 1.224. No measurable I1 slowdown of the compiled path; the 1.25 bound was already at the edge (I0 gate 1.239). The F-11 change (median of paired batch ratios) did not make it robust enough. The bound was NOT loosened.
- M0: `run_vital_tests('M0','Quiet',true)` gateOK, 53 tests.

## Sabotages (`run_sabotage('M9','Parts',{p})`, reports `reports/work/i1/M9_sabotage_<p>.txt`)

| Part | Result |
|---|---|
| i1 (new) | 12/12 DETECTED, tree unchanged |
| core | 13/13 DETECTED (SC-14 pattern moved with the kind-sum refactor; same mutation) |
| data | 9/9 DETECTED |
| trim6dof | 7/7 DETECTED |

| ID | Sabotage | Detected by |
|---|---|---|
| SI1-1 | struct-path width check removed | structWidthByControlNames |
| SI1-2 | staleRuntime guard call removed | editsRaiseStaleRuntime, noRuntimeAeroScaleField |
| SI1-3 | aeroScale left out of the guard | editsRaiseStaleRuntime |
| SI1-4 | context drops X | sameContextOnEveryFlatPath, rotatingContext |
| SI1-5 | rotating-plant context drops C_bn | rotatingContext |
| SI1-6 | model dispatch to the object path | f16ModelBitwiseOver1100States, twinThroughPlant |
| SI1-7 | uncompiled model not compiled | uncompiledModelIsCompiled |
| SI1-8 | NaN rule for unclassified removed (F-7) | unclassifiedIsNaN |
| SI1-9 | compiled y without the kind sums (F-8) | f16ModelBitwise..., twinPropulsionSums, declaredAeroIsExact |
| SI1-10 | F-6 transfer term dropped | twoAeroPointsRotating |
| SI1-11 | rotating-plant width check removed | rotatingPlantWidth |
| SI1-12 | AeroTableComponent loses Kind 'aero' | f16ModelBitwise..., twinPropulsionSums, twoAeroPointsRotating |

## Timings (this machine, F-16 at the README trim, [xdot, y])

- Struct plant 590-725 us; plant(model) 700-830 us, ratio 1.18-1.27; plant(toRuntime) ratio 1.23-1.36 (includes the guard, about 25 us); model.derivatives directly 1.10-1.25.
- FlightContext constructor 88-111 us (pre-I1 ~97 us): not worse.
- Where the model path's ~100-150 us goes (unprofiled loops): the FlightContext object (~35-40 us above the same arithmetic inline), the y struct (~35 us, also paid by the struct plant), the per-component calls and their info structs. The I1 additions (dispatch, kind sums) are ~10 us and were offset by removals (cached unit constants in engineThrust, an `f16.loads(...,'coeff')` mode, inline r x F). Getting to 1.05 needs the "reduce FlightContext's cost" work of CORE_AUDIT section 6 (e.g. fewer value-object property sets, lighter per-component info), which I judged out of scope.

## Files

Changed: `+vital/+plant/derivatives.m`, `+vital/+plant/derivativesRotating.m`, `+vital/AircraftModel.m`, `+vital/FlightContext.m`, `+vital/Component.m`, `+vital/AeroTableComponent.m`, `+vital/PropulsorComponent.m`, `+vital/+aircraft/+f16/loads.m` ('coeff' mode), `+vital/+aircraft/+f16/aeroCoefficients.m`, `+vital/+aircraft/+f16/engineThrust.m` (persistent unit constants), `+vital/version.m` (0.9.4-I1), `tests/M9/core/tCorePerformance.m` (F-11 statistic), `tests/M9/sabotages_core.json` (SC-14 pattern), `docs/DECISIONS.md` (ADR-043), `docs/FAILURE_CATALOGUE.md` (FC-1090..1103), `docs/VERIFICATION_MATRIX.md` (8 rows), `docs/FRAMEWORK_GUIDE.md` (12c.2), `reports/CHANGELOG.md`. All doc diffs are added lines only, line endings preserved.
Added: `tests/M9/i1/{tI1PlantContract,tI1RuntimeGuard,tI1FlightContext,tI1Diagnostics,tI1Performance}.m`, `tests/M9/sabotages_i1.json`, `tests/reference/{ContextSink,ContextProbeComponent,linearDerivativeXdot}.m`, this report, `reports/work/i1/*`.
Not touched: `run_f16_trim.m`, `reports/force_audit/*`, `reports/axis_checks/*.png`, `reports/fq/f16_fq_default_baseline_*`, `data/`, and the pre-existing edits to `+vital/Axis.m` and `tests/M9/core/tCoreAxis.m`. A scratch copy of the tree for the RED run is at `C:\VR1` (delete when done).

## Deviations from the brief

1. RED ran against minimal `vital.notImplemented` stubs (plant: model input, struct u, nu ~= 4; `Component.withKind`), so new tests are RED_EXPECTED rather than unexpected errors. The stubs were replaced by the implementation.
2. The RED run was executed on a copy of the tree (`C:\VR1`) with ReportDir in `C:\VITAL\reports\work\i1`; the GREEN and sabotage runs on `C:\VITAL` itself.
3. The toRuntime struct now carries the model (`AC.runtimeModel`) and both plants evaluate it; its `loadsFcn` errors if called on its own (`vital:model:runtimeLoadsFcn`). This is how "one FlightContext path" was achieved without a second constructor. The rotating plant fills the context through the same constructor with its own kinematics (6th argument), and X is then the rotating state (`StateLayout 'rotating13'`).
4. The guard compares against the model's compiled values, not a snapshot taken by toRuntime, so a wrong copy written by toRuntime itself is also refused (this keeps SC-13 detected).
5. Model y field order differs from the struct path (coeff, thrust_lbf last; extra M_aero_R); isequal/struct consumers are unaffected.
6. M0 was run with ReportDir `reports/work/i1` so as not to overwrite the already-modified `reports/M0_green.*`.
7. Criterion 6 is not met, and tCorePerformance failed in the gate run (see above). Neither bound was changed.

## Findings for I2 (trim by role)

- `+vital/+trim/solve.m`: unknowns fixed to {'alpha','de','throttle'} (the `Unknowns` option is checked against that list); the control vector is built as `uu = [zz(2); 0; 0; zz(3)]` (4 controls, F-16 order); bounds from `lim.alpha_deg`, `lim.de_deg`, `lim.throttle` with `Bounds` overrides by those names; starts and the `scale` vector are for (alpha, de, throttle). With I1 a 5-control model now gets a clear `vital:badInput` from the plant instead of a silently wrong trim.
- `+vital/TrimResult.m`: `U` documented as [de da dr throttle]; no control names stored (the result cannot be read by name).
- `+vital/FlightCondition.m`: uses `aircraft.toRuntime()` of the M8 `vital.Aircraft` (F-16 only) for the mass; no model input.
- Linearize (F-10) still takes exactly 4 inputs (`numel(u) ~= 4`) and reads `de_deg`, `da_deg`, `dr_deg`, `throttle` limits; `vital.ctrl.closedLoop` expects 4 controller outputs.
- Consumers (sim.run, trim, linearize) still need a struct: they read `AC.limits`, `AC.controlNames`; I2/I3 should accept the model and read `model.Limits`/`Controls` (and role tags) directly.
- `tCorePerformance` remains marginal at 1.25 independently of I1; a cheaper FlightContext would give it margin before I5.

## I1 speed fix (agent i1-speed, 2026-10-29): outcome = measured floor, criterion 6 NOT reachable

Brief: bring `tI1Performance` (<= 1.05) and `tCorePerformance` (<= 1.25) to pass without changing behaviour or bounds. Stopped as the brief allows: 1.05 is not reachable without either breaking the component/FlightContext contract or making the model path skip shared physics work the struct plant still does. No bound, test or sabotage was changed.

Kept (small, behaviour-neutral):
- `AircraftModel.compile` no longer stores `runtimeLoadsFcn` in `Compiled`; `toRuntime` and `checkRuntime` use `@vital.AircraftModel.runtimeLoadsFcn` directly (isequal of named handles is true). Measured: a struct holding a function handle costs ~4.5 us per object-property read (`f16.Compiled` 4.2 us vs 0.5 us without the handle), and the plant reads `Compiled` twice per call.
- `FlightContext` passes `ref` straight to `airData` (it reads only `ref.b`, `ref.cbar`) instead of building `struct('b',..,'cbar',..)` per call (~5 us).
Neither changes a number: xdot and y stay isequal to before (checked at the README trim; targeted suites below).

Measured after the change (3 fresh `matlab -batch` runs of both tests):
- tCorePerformance/compiledWithinTarget: 1.229, 1.200, 1.231 (all pass, still marginal).
- tI1Performance/modelThroughPlantWithinTarget: 1.169, 1.211, 1.129 (fail; bound 1.05).

Why 1.05 is out of reach (ablations with paired batches; scratch scripts not kept in the tree):
- Model with a pre-built context (illegal shortcut, measurement only): 0.975. So the whole gap is the context plus component/y plumbing, not the physics.
- Context as a plain struct instead of the FlightContext object: same ratio as the object (1.176 vs 1.177). Removing the object therefore does not help, and the tests require an object (`isprop`).
- Everything inlined, struct context, direct calls to aeroCoefficients/engineThrust (no Component objects): 1.10 (same run: plant(model) 1.19). This is the floor of the design without objects; the remaining ~+0.10 is the extra work of the compiled contract itself (control struct U by name, per-component info structs, kind sums, a y with F_R/M_R/componentNames/M_aero_R) and is paid in memory allocation.
- Skipping the atmosphere arguments block on the model path only (a shared-kernel fast entry): -0.01. Not done (touches M1/M8 sabotage targets for ~1 %).
- Run-to-run noise on this machine: +-0.04 in the ratio, and the full-suite gate reads 0.05-0.10 higher than a fresh session.
A cache on an exact repeat of (x, u, env) would pass the test (it repeats one state) but would be benchmark-gaming; not done.
Options for the user: re-register criterion 6 at a measured bound (e.g. 1.20, with the paired statistic), or accept a design change (e.g. a model-specific fused evaluator) as a later increment.
Verification of the two kept edits: `runtests` on tests/M9/i1, M9/core, M9/data (fresh session): 88 tests, 87 pass, the one failure is tI1Performance (1.132 in that run; tCorePerformance 1.189). F-16 1,100 states E = 0 (plant and tCoreModel), tDataModel E = 0, runtime-guard and context tests pass. The full cumulative M9 run, the sabotage parts and M0 were NOT re-run (stopped at the floor); the sabotage patterns of i1/core are untouched by these edits.
