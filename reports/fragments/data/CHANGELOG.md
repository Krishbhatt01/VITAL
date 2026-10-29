# CHANGELOG fragment (agent data, 2026-10-27): 0.9.3-DATA (D1, aircraft data as objects)

## Added (docs/PLAN_DATA_LAYER.md; ADR-042 proposed)
- Package `+vital/+data`: value classes `Source`, `Parameter`, `Variable`, `Breakpoint`, `Table`, `DaveModel`, `AeroDatabase`, `PropulsionData`, `MassData`, `ControlData` and `AircraftData`; functions `unitFactor`, `sourceFile` (MANIFEST-checked reads), `writeJson`, `readJson` (lossless .vital.json); `+internal`: `locate`, `readCached`, `memo`, `checkExpression`, `topoOrder`, `num`, `field`, `asList`, `asCellstr`.
- Builders: `vital.aircraft.f16.data(CG_PCT_MAC, BfrpOffset, DataRoot)`, `vital.aircraft.nesc.bodyData`, `vital.aircraft.nesc.brick.data()`, `vital.aircraft.nesc.cannonball.data()`.
- `vital.AircraftModel.fromData(data, 'AeroScale', s)` (static, added to AircraftModel.m).
- `run_data_example.m`: the calls of plan section 2, with a printed summary; its JSON goes to tempdir and is deleted.
- tests/M9/data (tags M9 DATA): tDataInventory, tDataTables, tDataCheckCases, tDataModel, tDataJson, tDataValidate, tDataPerformance, tDataExample (32 tests); private helpers, including the frozen 0.9.1-CORE builder `legacyF16Model`; the hand-authored example `toy_glider.vital.json`; tests/M9/sabotages_data.json (SD-1..SD-9).
- FC-1060..FC-1079.

## Changed (behaviour unchanged, bitwise)
- `vital.aircraft.f16.model()` is now `vital.AircraftModel.fromData(vital.aircraft.f16.data(CG, Bfrp), 'AeroScale', s)`. Meta.source names the data object; everything else is isequal to 0.9.1-CORE.
- `vital.aircraft.f16.config()`: unchanged, and checked field for field against the data object.

## Measured
- RED (tests/M9/data, before implementation): 32 RED_EXPECTED, 0 RED_UNEXPECTED / SUSPICIOUS / VACUOUS / REGRESSION / EXCLUDED (reports/work/data/M9_red_data.txt).
- GREEN M0..M9: 779 PASS of 779 (747 existing + 32 new), 0 EXCLUDED, 4,322 checks (PUB 2244, INDEP 177, ANALYTIC 1043, REG 858), 3,314 s (reports/work/data/M9_green_data.txt).
- Inventory: the nine DAVE-ML files (298 variables, 6 breakpoint sets, 21 tables, 25 check cases) are all present with the file's values, units and lines.
- Tables: bitwise equal to the generated code at 852 nodes and 20,000 random points (12,618 out of range); griddedInterpolant within 8.3e-17 (aero) and 4.3e-16 of the table scale (all tables).
- NASA checkData through the data object: 25 of 25 shots (198 outputs).
- fromData vs 0.9.1-CORE: max difference 0 over 1,100 states (652 out of envelope); README trim identical.
- JSON round trip bitwise (F-16 4,515 doubles); re-save byte-identical.
- Plant time per call, fromData / 0.9.1-CORE: 0.991 (noise floor 0.991; first runs 0.982 and, before the order fix, 1.069). tCorePerformance in the same gate: 1.184 (bound 1.25).
- Sabotages: SD-1..SD-9 all DETECTED (after the SD-9 test addition, see PLAN_DEVIATIONS correction 4), tree unchanged; core SC-1..SC-8 8/8 DETECTED and M9 S9-1..S9-6 6/6 DETECTED, tree unchanged (reports/work/data/M9_sabotage_{data,core,main}.txt).
- After the test additions, tests/M9/data re-run: 32/32 PASS (fromData / 0.9.1-CORE 0.976, noise floor 0.970).
