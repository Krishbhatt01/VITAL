# VITAL verification matrix

For each capability: what evidence establishes it, the evidence type, and where the evidence comes from.

Evidence types:
- **PUB:** a published reference.
- **INDEP:** an independent implementation.
- **ANALYTIC:** a closed form.
- **REG:** a pre-registered expectation.

Verification ("built right") and validation ("right model") are listed separately. A validation claim is never made from verification evidence alone.

| Capability | Milestone | Evidence | Type | Source |
|---|---|---|---|---|
| Test gate logic (RED/GREEN classification) | M0 | Synthetic fixtures with known outcomes | ANALYTIC | tests/fixtures |
| Tests can fail (not vacuous) | M0+ | Registered sabotages turn targets RED in separate processes | REG | tests/Mk/sabotages.json |
| Reference data integrity | M0 | SHA-256 against manifest | ANALYTIC | data/MANIFEST.json |
| Frames, DCM, quaternion, Euler | M1 | Round trips; orthonormality; Aerospace Toolbox `angle2dcm`/`quat2dcm` | ANALYTIC, INDEP | MATLAB Aerospace Toolbox |
| WGS-84 geodesy, J2 gravitation | M1 | `lla2ecef`/`ecef2lla`/`gravitywgs84`; TM Table 73 constants | INDEP, PUB | TM Vol II p.93 |
| Load transfer and summation | M1 | Couple invariance, round trip, hand cases | ANALYTIC | — |
| Mass properties | M1 | Point-mass and box analytic results | ANALYTIC | — |
| US 1976 atmosphere | M1 | Table values; `atmoscoesa` | PUB, INDEP | NASA-TM-X-74335 |
| Air data, CAS/EAS/TAS, vanes | M1 | Closed forms; `correctairspeed`; exact kinematics | ANALYTIC, INDEP | — |
| DAVE-ML import of the F-16 | M2 | Every embedded checkData case reproduced | PUB | F16_*.dml (NESC) |
| Rigid-body EOM, flat | M3 | Torque-free invariants; datum invariance | ANALYTIC | — |
| Rotating-Earth EOM; RK4 order | M5 | Coriolis/centripetal closed forms; dt⁴ order; NESC cases 1–10 within band | ANALYTIC, PUB | TM Vol II App. C/D |
| F-16 plant (aero, engine) | M3 | checkData; datum invariance; CG shift | PUB, ANALYTIC | F16_*.dml |
| Trim | M4 | NESC README Table 11; NESC case 11 pitch attitude | PUB | README.html; TM case 11 |
| Linearization, modes | M5 | linear vs nonlinear response; analytic mode systems | INDEP, ANALYTIC | — |
| Time-domain F-16 with NESC controller | M5 | NESC cases 11–13.4 within band (15, 16 as registered in the case matrix) | PUB | TM Vol II App. D |
| MIL-F-8785C Level assessment | M6 | Analytic engine cases; pre-registered mutations | ANALYTIC, REG | MIL-F-8785C (user-supplied) |
| Design feedback (SAS lever) | M7 | Closed-loop eigenvalues; confirmed re-run | ANALYTIC, REG | — |
| Uncertainty verdicts | M8 | Toy counterexamples; Clopper–Pearson closed form | ANALYTIC | Review 3/4 counterexamples |
| Simulink equivalence, visualization | M9 | Simulink vs MATLAB RK4; packet decode; attitude tests | INDEP, ANALYTIC | — |

**Validation (not only verification):** VITAL's F-16 is validated only to the extent the NESC multi-simulator results allow. They show that VITAL implements the same published model the way NASA's tools do. That is not a validation against F-16 flight data, and no report may present it as one.
| Simulink VitalPlant equals vital.sim.run, open loop (E <= 1e-9; measured 0) | ode4 + ZOH independent implementation | INDEP | tests/M9/tSlxEquivalence.m#e1OpenLoopDoublet |
| ... closed loop M7 SAS 100 Hz, 10 s (measured 0) | | INDEP | #e2ClosedLoopSas |
| ... M7 SAS 50 Hz multi-rate (measured 0) | | INDEP | #e3SasFiftyHz |
| ... NESC LQR 200 Hz (measured 0) | | INDEP | #e4NescLqr |
| Trimmed start stays trimmed through Simulink (tF16Sim bounds) | | REG | #e5TrimHold |
| Pitch/roll/yaw signs through Simulink | CONVENTIONS 7 | ANALYTIC | tests/M9/tSlxAttitude.m |
| Generated model reproducible and unedited | structure hash | REG | tests/M9/tSlxBuild.m |
| Guards and identifiers | | INDEP / exact ids | tests/M9/tSlxGuards.m |
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
