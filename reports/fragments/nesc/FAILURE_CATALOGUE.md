# Failure-catalogue rows proposed by agent `nesc` (M5-C)

Six-column format of docs/FAILURE_CATALOGUE.md. IDs FC-61x are proposals; the coordinator assigns the final numbers.

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-610 | M5 | Rotating plant called with a wrong-size state, a zero quaternion, an incomplete environment or an unknown Earth model | argument/environment validation (no silent defaults) | `vital:badInput` | `tests/M5/tRotatingEom.m#badStateAndEnvRejected` |
| FC-611 | M5 | Gravity (gravitation + centrifugal) used in the rotating-frame EOM, double-counting the centrifugal term | inertial acceleration of a particle at inertial rest checked against the Aerospace Toolbox `gravityzonal`; localGravity against NESC | verification failure (sabotage S5C-2) | `tests/M5/tRotatingEom.m#j2GravitationMatchesAerospaceToolbox` |
| FC-612 | M5 | Coriolis term with the wrong sign or frame | analytic -2 w x v and an independent ode45 ECI integration | verification failure (sabotage S5C-1) | `tests/M5/tRotatingEom.m#coriolisAccelerationAndDeflection` |
| FC-613 | M5 | NESC case requested that the case matrix does not define | lookup in NESC_CASE_MATRIX.json | `vital:nesc:unknownCase` | `tests/M5/tNescCases01to10.m#unknownCaseRejected` |
| FC-614 | M5 | A band signal that no included reference simulation records is skipped or passed silently | comparison status per signal | `NOT_ASSESSABLE` (test fails on it) | `tests/M5/tNescCases01to10.m#signalWithoutReferenceIsNotAssessable` |
| FC-615 | M5 | A VITAL run stopped early (guard) is compared only over the part it flew | duration check before the envelope comparison | `FAIL` on every signal, with reason | `tests/M5/tNescCases01to10.m#shortRunFailsEverySignal` |
| FC-616 | M5 | A DAVE-ML control-law limit (minValue/maxValue) treated as documentation, on either side of any of the 22 limits (pilot inputs, deltaThetaCmd, deltaChiCmd, phiCmd, the four mixer totals; control and GNC laws) | independent hand evaluator driven to every limit on both sides, with an observability assertion per limit | verification failure (sabotages S5C-4, S5C-8 ... S5C-12, S5C-14) | `tests/M5/tF16ControlLaw.m#everyLimitIsObservableAndApplied` |
| FC-617 | M5 | Course-error wrap (+/-180 deg) missing from the autopilot | hand-evaluated wrap cases | verification failure (sabotage S5C-5) | `tests/M5/tF16ControlLaw.m#courseErrorWraps` |
| FC-618 | M5 | Quaternion norm drift in the rotating plant not guarded | the plant provides y.quatNorm; vital.sim.run stops | `vital:sim:quatNorm` | `tests/M5/tRotatingEom.m#quaternionGuardStopsRotatingRun` |
| FC-619 | M5 | An F-16 NESC case flown from a trim that is not OK (INFEASIBLE, NOT_CONVERGED, or clamped tables outside case 12) | trim status checked before the simulation | `vital:nesc:notTrimmed` | `tests/M5/tNescF16Cases.m#nonOkTrimIsRefusedAndOverrideIsScoped` |
| FC-620 | M5 | An initial-condition override requested for a case whose state does not come from the F-16 trim (would be silently ignored) | argument check | `vital:badInput` | `tests/M5/tNescF16Cases.m#nonOkTrimIsRefusedAndOverrideIsScoped` |
