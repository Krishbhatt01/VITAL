# FAILURE_CATALOGUE fragment (agent m9a, 2026-10-25): 0.9.0-M9A rows (FC-1001 onward; FC-987..999 may be used by the speed-up)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-1001 | M9 | Committed VitalPlant.slx hand-edited or stale against the builder | structure hash of the committed file vs a fresh build | verification failure | `tests/M9/tSlxBuild.m#committedArtifactIsUnedited` |
| FC-1002 | M9 | Builder not reproducible | two builds, same hash and text | verification failure | `tests/M9/tSlxBuild.m#buildIsReproducible` |
| FC-1003 | M9 | Builder drops or rewires a block | registered block list and links | verification failure | `tests/M9/tSlxBuild.m#blockListAsRegistered` |
| FC-1004 | M9 | Wrong solver (not ode4 / not fixed-step / wrong step) | solver settings of the model | verification failure | `tests/M9/tSlxBuild.m#solverConfiguration` |
| FC-1005 | M9 | Simulink open-loop result differs from vital.sim.run (integrator, hold, input timing) | E <= 1e-9 (INDEP) | verification failure | `tests/M9/tSlxEquivalence.m#e1OpenLoopDoublet` |
| FC-1006 | M9 | Controller sampled at the wrong rate in Simulink | 50 Hz SAS equivalence and sample count | verification failure | `tests/M9/tSlxEquivalence.m#e3SasFiftyHz` |
| FC-1007 | M9 | Moment / attitude sign wrong in the Simulink path | CONVENTIONS 7 signs (ANALYTIC) | verification failure | `tests/M9/tSlxAttitude.m#elevatorPitchesNoseDown` |
| FC-1008 | M9 | Non-unit quaternion not stopped in the Simulink path | post-run quaternion-norm guard, log truncated | `vital:sim:quatNorm` | `tests/M9/tSlxGuards.m#quatNormGuardStops` |
| FC-1009 | M9 | Non-finite controller output in the Simulink path | kernel stop record, STOPPED at t_k | `vital:sim:nanState` | `tests/M9/tSlxGuards.m#nanControllerStops` |
| FC-1010 | M9 | Controller raises in the Simulink path | kernel stop record | `vital:sim:controllerError` | `tests/M9/tSlxGuards.m#controllerErrorStops` |
| FC-1011 | M9 | Model run outside vital.slx.simulate (no plant context) | kernel check | `vital:slx:noContext` | `tests/M9/tSlxGuards.m#kernelWithoutContextIsError` |
| FC-1012 | M9 | Smooth input given to the Simulink path (stage-time semantics differ) | option check | `vital:slx:unsupportedInput` | `tests/M9/tSlxGuards.m#smoothInputUnsupported` |
| FC-1013 | M9 | Model file missing | file check | `vital:slx:modelMissing` | `tests/M9/tSlxGuards.m#missingModelIsError` |
| FC-1014 | M9 | Bad dt / tFinal / controller rate in the Simulink path | same checks as vital.sim.run | `vital:sim:badStep` | `tests/M9/tSlxGuards.m#badStepIsError` |
