# CHANGELOG fragment (agent m9a, 2026-10-25): 0.9.0-M9A

## Implemented (M9-A; Cesium and joystick are M9-B)
- docs/PLAN_M9.md: contract, architecture, pre-registered tolerances, guards, sabotages (written before code).
- +vital/+slx: build (model generator), structure (canonical text + SHA-256), simulate (vital.sim.run contract on Simulink), compare (PLAN_M9 metric), kernel (coder.extrinsic target), context (session store), modelFile.
- models/VitalPlant.slx: generated artifact (regenerate with vital.slx.build()).
- run_f16_simulink.m: README trim, M7 SAS, elevator doublet; Simulink vs vital.sim.run, printed and plotted.
- tests/M9: tSlxBuild, tSlxEquivalence, tSlxAttitude, tSlxGuards, tRunF16Simulink (23 tests); sabotages.json (S9-1..S9-6).
- Version 0.9.0-M9A. ADR-039 proposed. FC-1001..FC-1014.

## Measured
- E (max scaled state difference, Simulink vs vital.sim.run) = 0 exactly on E1-E5 and the stop cases (registered bound 1e-9).

## Corrections made after the RED run (test-side, documented in the files)
- tSlxBuild: Digital Clock BlockType is 'DigitalClock' (registered as 'DiscreteClock').
- tSlxEquivalence/compareMetricIsRight: tolerance 1e-20 -> 1e-15 (the hand-built expectation itself carries the 5.7e-14 ulp of 300; arithmetic error in the test).
- tSlxEquivalence and tSlxAttitude now simulate a fresh build in a temp folder (PLAN_M9 9: builder sabotages must show behaviourally).
