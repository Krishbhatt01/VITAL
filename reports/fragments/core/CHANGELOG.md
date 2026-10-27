# CHANGELOG fragment (agent core, 2026-10-27): 0.9.1-CORE

## Added (docs/PLAN_CORE_FRAMES.md; ADR-040 proposed)
- `+vital`: value classes `Axis`, `Point`, `Vector`, `Loads`, `InertiaTensor`, `MassProperties`, `Component` (abstract), `AeroTableComponent`, `PropulsorComponent`, `FlightContext`, `AircraftModel`. No name collides with an existing class; `vital.Loads` resolves next to the `+loads` package (verified, reports/work/core/red_console.txt).
- `vital.aircraft.f16.model(opts)` (CG_PCT_MAC, AeroScale, BfrpOffset as config; returns a compiled model), `vital.aircraft.f16.aeroCoefficients`, `vital.aircraft.f16.engineThrust`.
- `tests/reference/coreTwinFixture.m`: the HYPOTHETICAL twin-engine F-16 (test fixture, not an aircraft).
- `run_core_example.m`: builds the F-16 model, trims it through the model, prints axes, per-component loads, totals at the BFRP and the CG, the whiteboard left engine, and the twin engine-out case.
- tests/M9/core: tCoreAxis, tCorePointVector, tCoreLoads, tCoreMass, tCoreModel, tCorePerformance (36 tests, tags M9 CORE); tests/M9/sabotages_core.json (SC-1..SC-8).
- Version 0.9.1-CORE. FC-1015..FC-1041.

## Changed (behaviour unchanged)
- `+vital/+aircraft/+f16/loads.m`: optional 6th argument `'aero'` returns the aero column only (PLAN_DEVIATIONS D2). The 5-argument path is unchanged; the sabotages that patch loads.m (S3-1, S6F-5, S8W-5) were re-run: all DETECTED.

## Measured
- RED (tests/M9/core, before implementation): 36 RED_EXPECTED, 0 RED_UNEXPECTED / SUSPICIOUS / VACUOUS.
- GREEN M0..M9: 747 PASS of 747 (711 existing + 36 new), 0 EXCLUDED, 3,983 checks (PUB 1978, INDEP 175, ANALYTIC 1039, REG 791), 3,213 s.
- Equivalence: F-16 model vs vital.plant.derivatives, 1,100 seeded states (652 out of envelope), 11 configurations (all 8 AeroScale multipliers alone and together, CG 30 % + BFRP offset): max relative difference 0 in xdot and y (gate 1e-12). README trim through model.toRuntime() identical (1e-12 gate).
- Performance (same process, README trim, interleaved 7 x 1,000): plant 638 us, compiled model 747 us, ratio 1.17 (target 1.25); object path 3,959 us (6.2 x, reported); new altitude every call: 1.09 (reported). Iterations ranged 1.17-1.18 after the speed-ups.
- Sabotages: SC-1..SC-8 all DETECTED, tree unchanged; M9 S9-1..S9-6 re-run, all DETECTED, tree unchanged.

## Corrections after the RED run (test-side, documented in PLAN_DEVIATIONS)
- tCoreAxis: ft expectation written as the product; two dcmTo expectations corrected to the header's own pre-registered contract (a.dcmTo(b) = C_ba).
- tCorePointVector: norm tolerance 0 -> 1e-15 rel (1 ulp).
- tCorePerformance: both paths timed with [xdot, y] (stricter).
