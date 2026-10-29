# CHANGELOG fragment (agent i0, 2026-10-27): 0.9.2-I0

## Added (ADR-041 proposed; test hardening, no behaviour change)
- `tests/M9/i0/`: 18 tests, tags M9 I0:
  - `tI0CoreKnownAnswers` (P1-P4, ANALYTIC, rotated axes throughout);
  - `tI0LinearDerivativeAircraft` (analytic aircraft: xdot, trim at design and off design, A/B, eigenvalues and modes);
  - `tI0NescAircraftModel` (NESC cases 1, 2, 3, 9, 10 as AircraftModels, PUB bands; model path equals struct path; compiled inertia).
- `tests/reference/`: `LinearDerivativeComponent.m`, `linearDerivativeAircraft.m`, `nescAircraftModel.m`, `nescModelRun.m` (test fixtures, not in +vital).
- `tests/M9/sabotages_core.json`: SC-9, SC-10, SC-11 (CORE_AUDIT A, B, C), SC-13 (the bridge drops Ixz), SC-14 (the bridge reports M_aero about the root). SC-12 is reserved for I1.
- FC-1042..FC-1054.

## Changed
- `+vital/version.m`: 0.9.2-I0. This is the only edit under `+vital` (`git diff --stat -- +vital`: 1 file, 1 line).

## Measured
- RED evidence:
  - With SC-9, SC-10 and SC-11 each applied, all 35 pre-I0 core tests (tCoreAxis, tCorePointVector, tCoreLoads, tCoreMass, tCoreModel) PASS, so each sabotage is NOT DETECTED (`reports/work/i0/red_sabotages_vs_preI0_core.txt`; tree unchanged).
  - RED-phase gate on the I0 classes: 18 VACUOUS, 0 RED_UNEXPECTED, 0 REGRESSION, 0 EXCLUDED, gateOK 1. Justified in ADR-041: these are known-answer tests on existing code (`reports/work/i0/M9_red_i0.txt`).
- GREEN M0..M9: 765 PASS of 765 (747 + 18), 0 EXCLUDED; 4,205 checks (PUB 2103, INDEP 175, ANALYTIC 1086, REG 841); 3,832 s (`reports/work/i0/M9_green_i0.txt`).
  - F-16 anchors unchanged within this gate:
    - tCoreModel equivalence max e = 0 over 1,100 states;
    - README trim unchanged;
    - Simulink E1-E5 E = 0;
    - M7 and M8 tests pass.
  - tCorePerformance ratio 1.239 (bound 1.25; no code on that path changed).
- Sabotages:
  - `run_sabotage('M9', 'Parts', {'core'})`: SC-1..SC-11, SC-13 and SC-14 all DETECTED, tree unchanged.
  - `run_sabotage('M9', 'Parts', {'main'})`: S9-1..S9-6 all DETECTED, tree unchanged (`reports/work/i0/M9_sabotage_core.txt`, `M9_sabotage_main.txt`).
- Known-answer agreement (gate in brackets):
  - P1 loads 3.6e-12 N m (about 2e-8);
  - P1 xdot 1.4e-14 (5.7e-11);
  - P2 5.7e-14;
  - P3 9.1e-13;
  - P4 3.6e-12 N;
  - analytic xdot 7.1e-15;
  - trim 2.8e-17 and 4.2e-17 (1.7e-9);
  - A 1.63e-8 (1e-7), B 6.1e-13 (1e-9);
  - eigenvalues 1.9e-10 (1e-8);
  - NESC: every band signal inside, model path vs struct path about 1e-13 of scale.
