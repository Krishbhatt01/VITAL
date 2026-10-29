# DECISIONS fragment (agent i0, 2026-10-27)

## ADR-041 (proposed; agent i0, 2026-10-27): known-answer tests and non-F-16 known-answer aircraft for the object core (increment I0, no behaviour change)

**Status:** proposed. Version 0.9.2-I0. Increment I0 of the migration plan in `reports/review/CORE_AUDIT.md` section 6. Extends ADR-040.

**Context.** The independent core audit (CORE_AUDIT finding M2, minor m5) showed that the 0.9.1-CORE tests could not see three real frame errors:
- A: the compiled path uses Cᵀ instead of C;
- B: the weight is rotated into the CG axis with the transposed DCM;
- C: the compiled path drops the component rotation.

There were two reasons:
- Every component and CG axis in `tCoreModel` and `coreTwinFixture` is unrotated, and the default F-16 has r_mrc = r_engine = 0. So `Compiled.identity` is always true.
- The 1,100-state equivalence gate compares the model with `vital.plant.derivatives`, and both call `vital.aircraft.f16.loads`. It proves plumbing, not physics.

Re-measured for this ADR: with each of A, B, C applied, all 35 pre-I0 core tests pass (`reports/work/i0/red_sabotages_vs_preI0_core.txt`).

**Decision.**
1. **Known answers come from outside VITAL.** The new tests in `tests/M9/i0/` take their expected values from:
   - a hand derivation (source ANALYTIC), written in the class header and computed with `vital.frames.dcm321`, `cross` and algebra only. No `Axis`, `Loads` or `MassProperties` call appears on the expected side.
   - or a published check case (source PUB).
2. **Every core known-answer test uses rotated axes** (`tI0CoreKnownAnswers`, P1-P4):
   - tilted and toed-in engines, one chained on a dihedral wing axis, with propeller torque;
   - a rotated CG axis with the inertia given in its components;
   - `combine` with rotated self-inertia and a rotated reference;
   - `about()` a rotated, offset axis and a chained one;
   - the weight with a rotated, chained CG axis at a non-zero attitude.
3. **Non-F-16 known-answer aircraft**, built only from test-side code (`tests/reference/`, never `+vital`):
   - **The analytic linear-derivative aircraft.** `LinearDerivativeComponent` has constant dimensional derivatives, controls `de da dr throttle` and Ixz ≠ 0. The aircraft is trimmed at a reference steady state chosen to be an exact equilibrium. Its closed forms (Etkin & Reid 1996 sec. 4.9, body axes with W_e kept) are:
     - the trim at the reference speed;
     - a trim at another speed, reduced to one scalar equation;
     - the body-axis A and B;
     - the exact roots of the longitudinal and lateral quartics, with the coefficients written out.

     The aircraft runs through the unchanged consumers: `toRuntime`, `vital.plant.derivatives`, `vital.trim.solve`, `vital.linear.linearize` and `vital.linear.modes`.
   - **The NESC sphere and brick as AircraftModels.** They have zero controls, a rotated CG axis, and aero data on a rotated and offset axis. They run through `toRuntime` and `vital.plant.derivativesRotating` in NESC cases 1, 2, 3, 9 and 10, against the registered M5 bands (PUB, ADR-009). This is the first PUB evidence that the object core's rotation and transfer paths are right.
4. **Tolerances are derived, never tuned:**
   - round-off of the sums: 1e-12 of the scale;
   - ||J⁻¹||∞ · tr.tol for the trim;
   - the central-difference truncation g·h²/6 = 1.6e-8 for the A matrix (gate 1e-7);
   - 1e-8 for the eigenvalues (the CORE_AUDIT I0 criterion);
   - the registered bands for NESC.
5. **Sabotages.** `tests/M9/sabotages_core.json` gets:
   - SC-9, SC-10, SC-11 (the audit's A, B, C);
   - SC-13: the bridge drops Ixz;
   - SC-14: the bridge reports the aero moment about the root.

   SC-12 is reserved for the audit's "bridge drops X" (M4), which belongs to I1.
6. **No production behaviour changes in I0.** `+vital/version.m` is the only file edited under `+vital`. Every check that would need a production change is left out of I0 and listed in `reports/fragments/i0/FINDINGS_FOR_I1.md`.

**Consequences.**
- The compiled and object rotation paths, the weight in a rotated CG axis, and the inertia rotation now have independent known answers. Two of these are published (the NESC brick and the cannonball).
- The non-F-16 path through trim, linearize and modes has closed-form evidence. Its limits (4 F-16-named controls, F-16-named limit fields, no state in the bridge's FlightContext, diagnostics that ignore custom component classes) are documented findings for I1, not workarounds in production code.
- The suite grows by 18 tests, about 85 s.
- RED for pure known-answer tests on existing code cannot come from stubs, because there is nothing to stub. The RED evidence is the sabotage pair instead:
  - A, B and C are NOT DETECTED by the pre-I0 core tests;
  - they ARE DETECTED by the I0 tests.

  The RED-phase gate run lists the 18 new tests as VACUOUS, and this ADR is their written justification (`docs/AGENT_BRIEF.md`).
