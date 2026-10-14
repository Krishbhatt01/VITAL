# M8 amendment R4 (agent uq3, 2026-10-13): notes, doubts, open issues

## Failed hypotheses
Each is recorded in its test header. The original is kept and no tolerance was changed.
- **tUqHybrid 1b.** The prediction was that the local-only VITAL search misses the global minimum of the Rastrigin-like toy. It found the global minimum from the centre start instead.
  - Cause: the first simplex of the VITAL Nelder-Mead stage is wide (the z offset, below), and it hops the toy's 0.25-wide basins.
  - Corrected 1b' (tUqHybrid#localMinimumBasinNeedsGlobalStage): a bowl-plus-cone toy whose start is a strict local minimum in a basin wider than any first step.
  - **1b' FAILED as well** (1b''). The local-only stage left the 0.3-wide bowl and reached the cone tip (-0.149867): Nelder-Mead's reflections and expansions are not confined to its first simplex.
  - Not corrected a third time. The claim "the VITAL local stage alone misses the global minimum" is NOT established. What stands is: 1a (INDEP: plain fminsearch from the given starts misses), plus 1c and the hybrid part of 1b' (the hybrid finds the global minimum).
  - **Open point:** a toy where the VITAL local stage provably misses, if the coordinator wants that demonstration.
- **tUqHybrid 2.** The prediction was status 'OK' with the default local budget of 60 evaluations. The status was FC-901: Nelder-Mead needs 60-140 evaluations at a box vertex in 3-D. Corrected 2': the same toy with MaxEvals 300.

## Defect found during the implementation (fixed, regression-tested)
- **fminsearch false convergence.** fminsearch's first simplex is 5 % of each NON-ZERO coordinate and 0.00025 for a zero one. With the plain bound transform theta = lo + (hi - lo)(1 + sin z)/2, a start at the exact centre has z = 0. The simplex is then 0.00025 wide, and Nelder-Mead "converged" after 4-8 evaluations at a non-minimum.
  - Measured: d = 7, linear margin, it reported the centre value 0.49996 against a true minimum of -0.125.
  - Fixed with the offset z -> z + 3 (period 2 pi, so the transform is unchanged).
  - Regression test: tUqHybrid#centreStartDoesNotStopAtOnce (header 9, added during the implementation).

## Defect found by the reduced smoke run (fixed, regression-tested, gates re-run)
- In the first smoke run (reports/uq/f16_uq_r4smoke, before the fix), the equal-percentage CSR of 3.3.1.1-CatA-other and 3.3.1.3-CatA searched boxes at alpha 8.37, 5.83 and 5.47, all above AlphaMax 3.
  - Cause: a judged-shape failing point (a prior) had an equal-shape norm above the cap, and the CSR took it as its upper bound.
  - Fix in csr.m: a ray result above AlphaMax bounds nothing, so the cap box decides.
  - Regression test tUqCsr#capRespectedWithFarPrior (header 12). It was written after the finding, shown failing on the unfixed code (alpha* 4.99), then passing. Sabotage S8W-7 added.
  - The GREEN gate, the sabotages and the smoke run were re-run after the fix. The pre-fix sabotage logs are kept as reports/work/uq3/prefix_*.

## Test-code fix (not an expectation change)
- tUqCsr#cornerTouchesFirst passed a 1 x 2 tolerance to verifyTol, which accepts only a scalar, so the test errored.
- It is now checked axis by axis with the registered per-axis tolerance 0.01 m_i. The expected CPV (1.175, 1.0875) is unchanged.

## Algorithm change found by a pre-registered expectation (not a test change)
- tUqCsr header 7 requires that the priors never cost extra searches. The first CSR stepping rule (bisect after one failed optimistic step) needed 3 searches with the prior and 2 without, so the expectation failed.
- The stepping rule is now: optimistic steps until two in a row fail, then bisect. The expectation was kept and now holds.

## Contract inconsistency (reported, not resolved by me)
- R4-3 grids the "two-parameter (longitudinal) groups", but R4-5 makes the longitudinal search three-parameter (Cm_q, Cm_basic, Cm_de).
- With the R4 spec, no default F-16 group has <= 2 searched parameters, so all 19 groups use the hybrid search and R4-3 is used only by the toys and by 1-2 parameter specs.
- `'GridMaxDim', 3` grids the longitudinal groups. Each box is then 1331 lattice points before refinement, times 4 candidates, about 35 min per box at 0.4 s per point evaluation. The coordinator should decide.

## Interpretations
1. **alpha*.** alpha* := the largest box searched clean (alphaLo), and alphaHi := the norm of the confirmed CPV. "alpha*(judged) < 1 with a confirmed CPV" is read as cpvConfirmed and alphaHi <= 1, so a confirmed counterexample inside the judged box gives NOT_ROBUST even if the bracket did not close (ADR uq3-2).
2. **Two verdicts.** `vital.uq.verdict` keeps the bound-worst "box verdict" per width, the R3 truth tables, unchanged. The headline is the R4 verdict from the CSR.
3. **Hybrid convergence.** The hybrid status needs only the local (Nelder-Mead) stage converged. The DE convergence (the population spread) is reported, not required: the global stage has a fixed budget.
4. **Legacy pins.** R3-era tests that pin R3 numbers (tF16Uq, tUqR3Report) run the R3 design explicitly on an embedded v1 spec. Their expectations are unchanged, and they are regression guards of the legacy fields (Cm_table) and of the sqp method.

## Smoke-run observations (reduced budget; see CHANGELOG.md)
- **3.2.2.1.1-CatA (CAP).**
  - x1 bound-worst -0.0624, VIOLATED, at the lower corner (Cm_q 0.742, Cm_basic 1.152, Cm_de 0.848).
  - CSR judged alpha* 0.443, CPV at 0.453, confirmed: NOT_ROBUST.
  - The equal-percentage tolerance is 8.1 %.
  - The x1 violation is about 10 times R3's -0.0059. Cm_de now ranges over +/-15.2 % (k2 sigma) instead of Cm_table's +/-12.9 %. The worst corner also has Cm_basic HIGH, a combination the coupled Cm_table could not represent.
- **3.3.1.1-CatA-other and 3.3.1.3-CatA: NOT_ASSESSABLE.**
  - The 7-D x1 search met a point that is not OK inside the box: EXCLUDED, NOT_CONVERGED at the linearize stage ("no step plateau") at 13,000 ft / M 0.45 / CG 20 %.
  - The local stage did not converge with MaxEvals 120 (FC-901).
  - The CSR boxes below the cap could not be decided for the same reasons. The cap boxes did contain failures (judged alpha* <= 2.76 and <= 1.81).
  - **Open issue for the full run:** isolated linearization non-convergence makes whole 7-D boxes NOT_ASSESSABLE (FC-903 rule: a non-OK point never improves a verdict). This is correct under the contract, but it may leave most lateral groups NOT_ASSESSABLE.
- **N = 20 in the smoke run** gives a Clopper-Pearson lower bound of at most 0.861 < 0.95, so every smoke verdict is NOT_ROBUST by the Monte Carlo alone. That is a budget artefact: the default N = 200 needs at most 4 failures.

## Open issues
- **Runtime of the full default run_f16_uq** (not run, as instructed): about 15-18 h in a single uncontended MATLAB (CHANGELOG.md). The search budget dominates, at about 0.4 s per closed-loop point evaluation.
- **Nelder-Mead cost at vertex optima.** The sin transform is flat at the bounds, so the local stage is the most expensive part of a hybrid search (about 92 evaluations from a 7-D vertex with TolX 1e-2, several hundred from interior starts). FC-901 can still occur with MaxEvals 150; it gives NOT_ASSESSABLE, never a pass.
- **The x1 bound-worst under R4-5 is a different quantity from R3's.** R3's headline CAP violation was at the Cm_table corner. With the split it is searched over (Cm_q, Cm_basic, Cm_de) with k2 = 3.03 (half-width 0.152 instead of 0.129), so the R3 and R4 numbers are not comparable.
- **Stale default report.** reports/uq/f16_uq_default.* still predates R3 and R4.
