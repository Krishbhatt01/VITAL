# VERIFICATION_MATRIX fragment (agent core, 2026-10-27): 0.9.1-CORE rows

| Claim | Evidence | Source | Test |
|---|---|---|---|
| Axis orientation from DCM, Euler (rad, deg), quaternion and so3 agree | angle2dcm; probed toolbox conventions (quaternion frame = passive, so3 active) | ANALYTIC / INDEP | tests/M9/core/tCoreAxis.m#orientationInputsAgree |
| Axis chains depth 1-5 resolve both ways; A -> B -> A = identity | product of passive DCMs | ANALYTIC | #chainsResolveBothWays |
| Axis composition = se3 composition; = transformTree on a two-branch tree | UAV Toolbox / MATLAB se3, transformTree | INDEP | #compositionMatchesSe3, #compositionMatchesTransformTree |
| Station frame = body rotated 180 deg about y = diag(-1, 1, -1); station points = stationToBody | CONVENTIONS 2 | ANALYTIC / INDEP | #stationFrameIsBodyRotatedAboutY |
| Wind, stability, body-in-NED axes | dcmbody2wind, analytic C_sb, angle2dcm | INDEP / ANALYTIC | #windStabilityAndNed |
| Point rotates and translates; Vector only rotates; lengths invariant; batches | analytic | ANALYTIC | tests/M9/core/tCorePointVector.m |
| Loads.transform = vital.loads.transferLoad; aggregate = sumLoadsAtCG (no gravity) | M1-verified functional core | INDEP | tests/M9/core/tCoreLoads.m#transformEqualsTransferLoad, #aggregateEqualsSumLoadsAtCG |
| Power of a load is the same about every point | rigid-body kinematics | ANALYTIC | #powerIsInvariant |
| Parallel axis only through the CG; 1,000-sub-box build-up exact; = massProps | M1 box test | ANALYTIC / INDEP | tests/M9/core/tCoreMass.m#parallelAxisThroughCgOnly, #combineReproducesBox |
| F-16 mass properties | F16_inertia.dml (m 637.1595 slug, Ixx 9496, Iyy 55814, Izz 63100, Ixz 982 slug ft2, DXCG) | PUB | #f16MatchesNasa |
| Ixy, Iyz flip and Ixz keeps its sign under the station rotation | inertiaStationToBody | INDEP | #stationProductsFlipSign |
| weightLoads = the plant's gravity term; zero moment about the CG | sumLoadsAtCG | INDEP | #weightLoadsEqualGravityTerm |
| F-16 AircraftModel = vital.plant.derivatives (1,100 states, all AeroScale, out of envelope; gate 1e-12, measured 0) | the existing plant | REG | tests/M9/core/tCoreModel.m#f16EquivalenceGate |
| Compiled path = object path (gate 1e-12) | object path | REG | #compiledEqualsObjectPath |
| README trim unchanged through the model | vital.trim.solve on the config struct | REG | #readmeTrimUnchanged |
| Force audit (wind-axis equilibrium, sum of forces and moments zero at trim, M_cg by hand, effect signs) holds through the model | run_force_moment_audit checks | ANALYTIC | #forceAuditThroughModel |
| Twin engine-out dN = +d T/2, mirror image, own throttle channels | analytic | ANALYTIC | #twinEngineOut |
| d'Alembert loads never in the total | sumLoadsAtCG with gravity | INDEP | #dAlembertNeverInTotal |
| Compiled model <= 1.25 x the plant per call | same-process timing | REG | tests/M9/core/tCorePerformance.m#compiledWithinTarget |
