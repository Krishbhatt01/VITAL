# Open issues and doubts (agent `linear`, M5-A)

1. **Rudder range and the ARI.** In the NESC law, `rdr = -30 totPedal + 0.008 ail`. With full pedal and full lateral stick the commanded rudder is +/-30.172 deg. `limits.dr_deg` is set to +/-30 (the pedal scaling, as the task specified). The interconnect margin (0.172 deg) is not included. If M7 closes the NESC law through the plant, this may need a decision.
2. **Aileron normalization.** The aero model normalizes by `dail = ail/20` (F16_aero.dml), but the control law scales stick to +/-21.5 deg. So full stick is dail = 1.075, i.e. beyond the unit normalization. The aero model defines no aileron limit and there is no clamp. This is recorded, not changed.
3. **`'Controller'` option.** The contract's `'Controller'` option (M7, closed-loop linearization) is NOT implemented in `vital.linear.linearize`. M7 (`ctrl`) will need to add it, or ask the coordinator. The file is owned by `linear`.
4. **Air-axis converters.**
   - The converters are exact at beta0 = 0 (all vital.trim.solve trims).
   - Within each partition they include the wind-attitude term, but cross-partition terms are ignored. That is exact only for decoupled, symmetric trims.
   - `n_alpha` is NaN (with a note in `lin.notes`) when the wind is nonzero, because its derivation assumes zero wind.
5. **Definition of `n_alpha`.** It is the wind-axis normal load factor of the non-gravity forces, per rad of alpha, at constant V, q and theta: `n_alpha = -(V/g) Z_alpha + sin(gamma0)`. This is the MIL-F-8785C n/alpha quantity in the usual short-period sense. M6 should confirm that it is the definition its rules need (some texts use body-axis n_z).
6. **Excluded states.** `vital.linear.modes` uses only the 8 dynamic states. The height mode (h enters through density and thrust) and the heading/position integrals are excluded, as the contract specifies. The very slow altitude-density coupling is not reported.
7. **Fixed thresholds in the classifier.**
   - lonFraction 0.5
   - "dominant" = 80 % cumulative participation
   - oscillatory if |Im| > 1e-9 |lambda|
   - cond(V) > 1e10 means UNCLASSIFIED
   
   These are design choices, not published values. The F-16 at the tested conditions is far from each of them (SP w + q = 0.999; lon/lat exactly decoupled).
8. **Sabotage count.** Only 5 sabotages are registered (the brief's 2-5 rule). Three more were run and detected: S5LX-1 kink check removed, S5LX-2 raw eigenvector magnitudes, S5LX-3 missing sin(gamma0) in n_alpha. Their definitions are below, so the coordinator can register them if wanted. The temporary file `tests/M5/sabotages_linearextra.json` was deleted after the run.
   - S5LX-1: `+vital/+linear/jacobian.m`, pattern `if asym(acc) > opts.KinkTol * scale + opts.AbsTol && asym(acc) >= 0.5 * asym(acc-1)`, replacement `if false`. Targets `tLinearJacobian/kinkAtPointIsDetectedNotAveraged` and `tF16Linearize/tableBreakpointIsReportedAsKink`.
   - S5LX-2: `+vital/+linear/modes.m`, pattern `P = abs(V .* Wl.');`, replacement `P = abs(V);`. Targets `tModes/classicModesNamedWithExactValues` and `tModes/participationIsInvariantToUnits`.
   - S5LX-3: `+vital/+linear/linearize.m`, pattern `lin.n_alpha = -(V0 / g) * lin.lon.air.A(2, 2) + sin(lin.gamma0);`, replacement without `+ sin(lin.gamma0)`. Target `tF16Linearize/nAlphaMatchesDirectLoadFactorSlope`.
9. **Test-side fix during GREEN (not a tolerance change).** `vital.test.provenance` cannot JSON-encode complex numbers. One tModes check compared a complex eigenvalue, so it now compares [Re Im] with the same 1e-9 tolerance. Suggestion: `provenance` could store complex values as [re im].
10. **Tolerances versus achieved accuracy.** The tolerances in the tF16Linearize (a) checks (1e-6 x row scale / typical perturbation) are method-derived and loose compared with the achieved accuracy. The provenance slack shows that the errors are at least 100x below the tolerance, and the Taylor remainder ratios are 4.003, 4.001 and 4.001. A reviewer may want tighter checks, registered as new pre-registered checks, not by editing these.

# M5-X additions (agent `linear`)

11. **8-state phugoid bias.** The contract's 8-state modes exclude h, but density and thrust vary with altitude.
    - At the README trim this moves the phugoid from -0.0071 +/- 0.0745i (8 states) to -0.0062 +/- 0.0801i (with h), which is what the nonlinear plant flies. That is +7.0 % in wd, and the zeta changes from 0.095 to 0.077.
    - It also adds a height mode at -0.0016 1/s.
    - `modes(lin, 'IncludeHeight', true)` gives the 9-state result; the default is unchanged.
    - **Recommendation for M6 (fq):** judge the phugoid requirements (MIL-F-8785C zeta_p) with IncludeHeight, or record the choice.
12. **Estimator choice.** The coordinator's suggested estimator (zero crossings or log decrement of raw q) was replaced by a matrix pencil for the short period and the phugoid.
    - Reason: the linear model showed phugoid content of 3 % of q at t = 0, which is 5-15 % of the SP amplitude by the 2nd extremum.
    - The zero-crossing check is kept as a secondary check for the Dutch roll (clean signal: +0.12 %).
13. **Closed-loop linearization scope.**
    - A continuous approximation: the ZOH sampling delay (about half a sample, e.g. 5 ms at 100 Hz) is not modelled. M7 should account for it when margins are small.
    - Static controllers only, and they must declare `static = true`. The state is compared (isequal) after every call, at the trim and at every perturbed point.
    - The controller sees y at (x, u_ref), as in vital.sim.run.
    - n_alpha is always the open-loop airframe value.
14. **Test strengthened after a sabotage run (not a tolerance change).** In the first S5L-6 run, `tClosedLoopLinearize/pitchDamperAddsShortPeriodDamping` still passed: `verifyWithin(dz, 0, Inf)` admits equality, and an ignored controller gives equal zetas. The pre-registered ordering is strict, so explicit strict `verifyGreaterThan` checks were added. Both S5L-6 targets now fail under the sabotage.
15. **Test-code bug fixed before GREEN.** The matrix-pencil helper in tLinearVsNonlinear had an operator-precedence error (`z.' .^ (0:N-1).'` parses as `(z.' .^ (0:N-1)).'`). It was fixed before any result was used; no expectation changed.
16. **fromPlantState normalizes the quaternion** before extracting the Euler angles. This avoids the `vital:frames:quatNotUnit` warning on sim output (norm drift of about 1e-10, M5-B NOTES 1). The plant does the same silently.

# Review R1 round (agent `linear`)

17. **vital:linear:controllerError** (a controller that raises inside linearize, via `vital.sim.sampleController`) is implemented but has no dedicated test yet. Suggest adding one with a failure-catalogue row.
18. **RED classification for bug fixes.** Tests of NEW behaviour in EXISTING functions (B1, B3, M1, M9-C3, ADR-026, MINOR 5, M5) cannot be RED_EXPECTED without a stub that breaks every existing caller. They were RED_SUSPICIOUS, each failing on its registered check. Examples:
    - verifyError 'no exception' for notEquilibrium
    - status OK instead of NOT_CONVERGED for 1e10 + sin z
    - K 0.0621 vs 0.0682 for the nz loop
    - explicit field-existence assertions for columnStatus, n_alpha_ss and modesHeight

    The 28 VACUOUS tests are guards of existing, correct behaviour whose absence R1 proved with escaped mutations; each is now the target of a registered, detected sabotage. The rest are the unchanged tests of tF16Linearize (whose fLin helper was rewritten) and tF16Modes (MINOR 2).
19. **n_alpha_ss is defined for level trims only.** It is NaN with NOT_LEVEL otherwise, as in fq. A climb or dive definition (gravity terms of alphadot) is not provided.
20. **Consumers of columnStatus.** vital.fq.metrics still requires lin.status 'OK', so fq will be NOT_ASSESSABLE at 20,000 / 30,000 ft even though the 8-state modes are fine. fq may use lin.columnStatus (columns 1-8 and the de column 13 for n/alpha) if it wants those points.
21. **Newton tolerances.** The ADR-026 loop tolerances (1e-14 converged, 1e-11 stalled) are design constants. For controllers that do not read u-dependent y, the loop exits after one fixed-point step, and the results are bit-identical to before.
22. **Held-out test now in the GREEN list.** tClosedLoopSimAgreement runs against the ADR-026 sim (confirmed by the coordinator). It detects R1-C2 (adapted as "y at u_ref").
23. **Test-side provenance limitation (again).** A verifyExact on a complex eigenvalue crashed provenance writing. It now compares [Re Im]. Suggest `vital.test.provenance` store complex values as [re im].
