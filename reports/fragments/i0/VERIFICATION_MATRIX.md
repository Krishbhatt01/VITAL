# VERIFICATION_MATRIX fragment (agent i0, 2026-10-27): increment I0 rows

Measured agreement from `reports/work/i0/measured_agreement.txt`.

| Claim | Evidence | Source | Test |
|---|---|---|---|
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
