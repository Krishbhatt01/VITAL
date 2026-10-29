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
| Per-component loads of tilted, toed-in, offset engines (one chained on a dihedral wing axis, with torque) at the BFRP, object and compiled paths | hand F_k = T th_k C_ek_b' e1, M_k = r_k x F_k + Q_k d_k; max error 3.6e-12 N m (gate 1e-12 of scale, about 2e-8) | ANALYTIC | tests/M9/i0/tI0CoreKnownAnswers.m#p1PerComponentLoadsAtBfrp |
| loadsTotal about a rotated CG axis and about the BFRP | hand sums plus weight; max error 7.3e-12 (gate about 5e-8) | ANALYTIC | #p1TotalsAtCgAndBfrp |
| Compiled and object derivatives of the rotated twin = hand 6-DOF xdot | Stevens & Lewis flat-Earth equations; error 1.4e-14 (gate 5.7e-11) | ANALYTIC | #p1DerivativesAgainstHandXdot |
| combine with rotated self-inertia, also in a rotated, offset reference | hand composite (m 400, CG [-0.5 1.5 0], J [325 300 0; 300 315 0; 0 0 635]); error 0 to 5.7e-14 | ANALYTIC | #p2CombineRotatedSelfInertia |
| about() a rotated, offset axis and a chained one | hand C (J + m(d'd I - d d')) C'; error 9.1e-13 (gate 4.6e-9) | ANALYTIC | #p3AboutRotatedOffsetAxis |
| Weight with a rotated, chained CG axis at a non-zero attitude (CG axis, BFRP, NED) | m C_bn [0 0 g]', r_cg x W, [0 0 m g]'; error 3.6e-12 (gate 7.4e-9) | ANALYTIC | #p4WeightRotatedChainedCgAxis |
| Analytic linear-derivative aircraft: xdot on the compiled, object and toRuntime + plant paths | hand 6-DOF with the written-out derivative loads; error 7.1e-15 (gate 4.5e-11) | ANALYTIC | tests/M9/i0/tI0LinearDerivativeAircraft.m#xdotExact |
| Analytic aircraft trim at the reference state and at 60 m/s | reference steady state (Etkin & Reid 1996 sec. 4.9); scalar reduction + fzero; error 2.8e-17 / 4.2e-17 (gate norm(inv(J)) tr.tol, about 1.7e-9) | ANALYTIC | #trimAtReferenceState, #trimOffDesign |
| Analytic aircraft A, B from vital.linear.linearize | body-axis small-disturbance matrices; A error 1.63e-8 (truncation bound g h^2/6 = 1.6e-8, gate 1e-7), B error 6.1e-13 (gate 1e-9) | ANALYTIC | #linearModelClosedForm |
| Analytic aircraft eigenvalues (eig of A_lon, A_lat, A(1:8,1:8); vital.linear.modes short period, phugoid, Dutch roll, roll, spiral) | exact roots of the written-out characteristic quartics; error 1.9e-10 max (gate 1e-8) | ANALYTIC | #eigenvaluesClosedForm |
| NESC dropped sphere, tumbling bricks, cannonballs (cases 1, 2, 3, 9, 10) as AircraftModels with zero controls, rotated CG axis, rotated and offset aero data axis | NASA/TM-2015-218675 Vol II check cases; registered bands (ADR-009); every signal inside (worst excess -1.5e-7 to -2.4e-7 in signal units) | PUB | tests/M9/i0/tI0NescAircraftModel.m#case01DroppedSphere ... #case10NorthwardCannonball |
| The NESC model path equals the struct path (vital.nesc.runCase) | same physics, same steps; max difference about 1e-13 of scale (gate 1e-9 of scale plus 1e-3 of the band floor) | REG | #modelPathEqualsStructPath |
| The NESC model's compiled inertia (rotated CG axis) = the published tensor | C' (C J C') C = J; gate 1e-12 of max J | ANALYTIC | #zeroControlModelBuilds |
| Sabotages A, B, C are invisible to the pre-I0 core tests and visible to I0 | SC-9, SC-10, SC-11: 35/35 pre-I0 core tests pass with each; each is DETECTED by its I0 targets | REG | tests/M9/sabotages_core.json; reports/work/i0/red_sabotages_vs_preI0_core.txt, reports/work/i0/M9_sabotage_core.txt |
| Every variableDef, breakpointDef and table of the nine NASA DAVE-ML files (F16_aero/prop/inertia/control/gnc, brick and cannonball aero/inertia) is in the data objects with the file's values (exact), units and start-tag line | independent regex scan of the file text; 250 + 48 variables, 6 breakpoint sets, 21 tables | PUB | tests/M9/data/tDataInventory.m#everyEntryPresentWithFileValues |
| Every Parameter, Variable, Table, Breakpoint and axis origin of the F-16, brick and cannonball has units and a valid source (file, line, SHA-256) | validate() and a walk over all items | REG | #everyItemHasUnitsAndSource |
| 16 aero + 9 prop check cases carried with their staticShot lines; S, b, cbar = 300 ft2, 30 ft, 11.32 ft at the sref/bspan/cbar lines | F16_aero.dml, F16_prop.dml | PUB | #checkCasesCarriedWithLines, #geometryByName |
| Table.at = generated runtime code = stored datum at all 852 grid nodes | vital.models.f16.aero / prop | REG | tests/M9/data/tDataTables.m#everyBreakpointBitwise |
| Table.at = generated code bitwise at 10,000 aero + 10,000 prop random points (7,803 / 4,815 outside a range, clamped identically) | vital.models.f16.aero / prop | REG | #randomPointsBitwise |
| Lookup by name in any order = positional = generated code (CXT inputs el, alpha in deg; T_MIL inputs RMACH, ALT) | F16_aero.dml "Basic CX", F16_prop.dml T_MIL_fn | PUB / REG | #lookupByNameAnyOrder |
| Table.at = MATLAB griddedInterpolant inside the range: aero max 8.3e-17 abs (gate 1e-12); all 21 tables max 4.3e-16 of the table scale (gate 1e-12; the registered 1e-12 abs failed on the thrust tables at 2 ulp, documented) | MATLAB griddedInterpolant | INDEP | #griddedInterpolantIndep |
| NASA checkData through the data object: 16 aero shots (144 outputs), 9 prop shots (54 outputs), all within NASA's tolerance | F16_aero.dml, F16_prop.dml checkData | PUB | tests/M9/data/tDataCheckCases.m#aeroCheckData, #propCheckData |
| DaveModel.evaluate = the generated function of the same file, bitwise, for all nine files at 301 input sets each | vital.models.f16.*, vital.models.nesc.* | REG | #evaluateEqualsGeneratedCode |
| vital.AircraftModel.fromData(f16_data) = the frozen 0.9.1-CORE model = vital.aircraft.f16.model(), bitwise in xdot and y over the 1,100-state set (652 out of envelope) | 0.9.1-CORE builder from config() | REG | tests/M9/data/tDataModel.m#fromDataBitwiseOver1100States |
| Same axes, mass properties, Ref, Limits, Controls and components | 0.9.1-CORE builder | REG | #sameModelStructure |
| config() = data object field for field (two configurations) | the hand copy in config.m | PUB (F16 files) | #configEqualsData |
| Brick and cannonball S, b, cbar, mass, J, r_cg = vital.nesc.vehicle | generated code | REG | #nescBodiesEqualVehicle |
| README trim through fromData unchanged (1e-12) | config trim | REG | #readmeTrimUnchanged |
| .vital.json round trip bitwise (F-16 4,515 doubles, brick 172, cannonball 116); re-save byte-identical; -0, subnormals, realmax, NaN, Inf kept; loaded object works (checks, model) | bit comparison | REG | tests/M9/data/tDataJson.m |
| A hand-authored .vital.json loads; CL(5 deg) = 0.7 | linear table | ANALYTIC | tests/M9/data/tDataJson.m#handAuthoredFile |
| No units / no provenance / changed source file / file not in manifest are refused | error identifiers | REG | tests/M9/data/tDataValidate.m |
| data/ unchanged: the nine DAVE-ML files hash to data/MANIFEST.json | MANIFEST.json | PUB | tests/M9/data/tDataValidate.m#dataFolderUnchanged |
| Plant time per call of the model built from the data <= 1.05 x the 0.9.1-CORE model (measured 0.98; noise floor 0.96) | same-process timing | REG | tests/M9/data/tDataPerformance.m |
| NESC F-16 README trim in the Simulink 6DOF model equals NASA's table | theta 2.6542 deg, elevator -3.2412 deg, throttle 13.9012 % (README 2.6538, -3.2410, 13.9019) | PUB | tests/M9/tF16Trim6dof.m#t1TrimEqualsNescReadme |
| Net load at the CG is zero at the trim | force/weight 1.1e-15, moment/(weight cbar) 2.3e-17 | ANALYTIC | #t2LoadsBalanceAtTrim |
| Trimmed F-16 flies flat lines for 10 s in the Aerospace Blockset 6DOF (Quaternion) | V, alpha, h, beta, phi, psi change 0; theta 8e-16 deg; p, q, r 8e-15 deg/s | REG | #t3TenSecondHoldIsFlat |
| Position ramps at V t along heading 45 deg | error ~1e-11 m | ANALYTIC | #t4PositionRampsAlongHeading |
| The 6DOF model responds to a 1 deg elevator doublet | max dalpha 0.89 deg, q < 0 first | ANALYTIC | #t5DoubletShowsTheModelIsLive |
| MathWorks 6DOF block equals VITAL's EOM (vital.sim.run) under the doublet | E = 1.1e-12 (criterion 1e-6) | INDEP | #t6AgreesWithVitalEom |
| Without the weight the trim breaks | dh 410 m in 10 s | ANALYTIC | #t7HoldIsNotVacuous |
| The Simulink trim model's mass, inertia and c-bar are the NASA data objects' values; the trim through the AircraftModel equals the config trim | exact; trim x, u to 1e-12 | PUB / REG | tests/M9/tF16Trim6dof.m#t8InputsAreTheNasaDataObjects |
| Plotted V, alpha, beta, h, hdot are Aerospace Blockset signals on the 6DOF states; Mach agrees with atmosisa | 1e-12; Mach 1e-6 relative | ANALYTIC / INDEP | #t9AirDataAreSimulinkBlocks |
| Simulink-only result: flat lines on the Simulink signals; pressing Run writes the figures from the model log | V, alpha, h 0; hdot 6e-15 ft/s; 3 figures written by the StopFcn | REG | #t10SimulinkOnlyResult |
