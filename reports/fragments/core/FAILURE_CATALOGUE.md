# FAILURE_CATALOGUE fragment (agent core, 2026-10-27): 0.9.1-CORE rows (FC-1015 onward)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-1015 | M9 | Axis built from a non-orthonormal or left-handed DCM, bad Euler, NaN, a 4-vector, a non-Axis parent or an unknown unit | constructor checks | `vital:badInput` | `tests/M9/core/tCoreAxis.m#badInputs` |
| FC-1016 | M9 | Passive and active rotations mixed up in an axis chain | chains of depth 1-5 against the product of passive DCMs, both directions | verification failure | `tests/M9/core/tCoreAxis.m#chainsResolveBothWays` |
| FC-1017 | M9 | Axis composition disagrees with the toolbox pose composition | se3 product (INDEP) | verification failure | `tests/M9/core/tCoreAxis.m#compositionMatchesSe3` |
| FC-1018 | M9 | Point transfer between branches of a frame tree wrong | UAV Toolbox transformTree (INDEP) | verification failure | `tests/M9/core/tCoreAxis.m#compositionMatchesTransformTree` |
| FC-1019 | M9 | Transform between axes of two different trees | root comparison | `vital:axis:noCommonRoot` | `tests/M9/core/tCoreAxis.m#noCommonRootIsError` |
| FC-1020 | M9 | Station frame (x aft, z up) not equal to body rotated 180 deg about y | diag(-1, 1, -1) and vital.frames.stationToBody | verification failure | `tests/M9/core/tCoreAxis.m#stationFrameIsBodyRotatedAboutY` |
| FC-1021 | M9 | Wind, stability or body-in-NED axes wrong | dcmbody2wind, analytic C_sb, angle2dcm (INDEP) | verification failure | `tests/M9/core/tCoreAxis.m#windStabilityAndNed` |
| FC-1022 | M9 | A position transformed without its translation, or a free vector with one | 5 m offset case: the Point moves, the Vector does not | verification failure | `tests/M9/core/tCorePointVector.m#pointTranslatesVectorDoesNot` |
| FC-1023 | M9 | Vectors in different axes added | axis check in plus/minus | `vital:axis:mismatch` | `tests/M9/core/tCorePointVector.m#mixingIsAnError` |
| FC-1024 | M9 | A force added to a moment | quantity check in plus/minus | `vital:vector:quantityMismatch` | `tests/M9/core/tCorePointVector.m#mixingIsAnError` |
| FC-1025 | M9 | Moment transfer sign (r x F) wrong | Loads.transform vs vital.loads.transferLoad | verification failure | `tests/M9/core/tCoreLoads.m#transformEqualsTransferLoad` |
| FC-1026 | M9 | Load transfer not physically consistent | power F.v_P + M_P.omega the same about every point (ANALYTIC) | verification failure | `tests/M9/core/tCoreLoads.m#powerIsInvariant` |
| FC-1027 | M9 | Two loads about different points added without transfer | reference-axis check in plus | `vital:loads:refMismatch` | `tests/M9/core/tCoreLoads.m#mismatchesAreErrors` |
| FC-1028 | M9 | Parallel-axis theorem applied about a point that is not the CG | off-origin masses; composite inertia about the composite CG | verification failure | `tests/M9/core/tCoreMass.m#parallelAxisThroughCgOnly` |
| FC-1029 | M9 | Component build-up of mass properties wrong | 1,000-sub-box analytic inertia, off-origin, rotated reference; vs vital.mass.massProps | verification failure | `tests/M9/core/tCoreMass.m#combineReproducesBox` |
| FC-1030 | M9 | Ixy, Iyz signs not flipped (or Ixz flipped) under the station rotation | vs vital.frames.inertiaStationToBody | verification failure | `tests/M9/core/tCoreMass.m#stationProductsFlipSign` |
| FC-1031 | M9 | Negative mass, non-physical or non-symmetric inertia tensor in the object core | constructor checks | `vital:mass:negativeMass`, `vital:mass:nonPhysicalInertia`, `vital:badInput` | `tests/M9/core/tCoreMass.m#errors` |
| FC-1032 | M9 | d'Alembert terms summed into the load total (counted twice with the EOM) | loadsTotal = components + weight only, at a state where -w x J w is large | verification failure | `tests/M9/core/tCoreModel.m#dAlembertNeverInTotal` |
| FC-1033 | M9 | The F-16 AircraftModel differs from vital.plant.derivatives | 1,100 seeded states, all AeroScale multipliers, out-of-envelope points; 1e-12 relative (measured 0) | verification failure | `tests/M9/core/tCoreModel.m#f16EquivalenceGate` |
| FC-1034 | M9 | The compiled fast path differs from the object path | F-16 and twin, 30 states each, 1e-12 relative | verification failure | `tests/M9/core/tCoreModel.m#compiledEqualsObjectPath` |
| FC-1035 | M9 | compile() reuses a stale axis chain (cached by name) | two twins with the same axis names, different geometry | verification failure | `tests/M9/core/tCoreModel.m#compileIsNotStale` |
| FC-1036 | M9 | A component reads another component's control channel | twin with asymmetric throttles: N = d (T_le - T_re) | verification failure | `tests/M9/core/tCoreModel.m#twinEngineOut` |
| FC-1037 | M9 | A component reads a control the model does not have | model validation | `vital:model:unknownControl` | `tests/M9/core/tCoreModel.m#modelErrors` |
| FC-1038 | M9 | A component axis (or an axis) outside the model's tree | model validation | `vital:model:axisOutsideTree` | `tests/M9/core/tCoreModel.m#modelErrors` |
| FC-1039 | M9 | Two axes of one model share a name | model validation | `vital:model:duplicateAxis` | `tests/M9/core/tCoreModel.m#modelErrors` |
| FC-1040 | M9 | The README trim changes when it goes through the model | vital.trim.solve(model.toRuntime()) vs the config struct, 1e-12 | verification failure | `tests/M9/core/tCoreModel.m#readmeTrimUnchanged` |
| FC-1041 | M9 | The compiled model is too slow for the uncertainty runs | same-process interleaved timing, ratio to the plant <= 1.25 | verification failure | `tests/M9/core/tCorePerformance.m#compiledWithinTarget` |
