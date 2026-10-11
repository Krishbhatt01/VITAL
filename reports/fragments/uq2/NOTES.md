# M8 R3 amendment (agent uq2, 2026-10-09): notes, doubts, open issues

## Failed hypothesis (recorded in the test header; original kept, tolerance unchanged)
- **tUqR3F16 2e.** The prediction was that the M_alpha,cg ratio at the Cm_table lower edge lies in [k, 1]. The measured ratio is 1.0407, and the hypothesis failed.
  - It was found in a pre-RED check of the file, before any amendment code. The check exercises the existing model only.
  - Cause: at 13,000 ft / M 0.45 / CG 30 % the MRC (35 % MAC) pitching-moment slope is destabilizing. The transfer term DXCG Z_alpha is stabilizing and larger, with A/(A+B) = -0.316.
  - Corrected 2e' (ANALYTIC, independent): split the derivative into its MRC part (the plant at CG 35 %, where r_cg = 0) and its transfer part. Then (k A + B)/(A + B) reproduces both edges within 1e-8.
  - Physics consequence (R3-M5): a Cm_table below 1 makes the airframe MORE statically stable about the CG at this condition, while it cuts elevator power M_de by 12 %. The 3.2.2.1.1-CatA CAP counterexample at the Cm_table lower corner comes from the loss of elevator/SAS authority, not from less static stability.

## Pre-registered outcomes (all as registered unless noted)
- **Moving-limit chain toy.** 3 rounds give MOVING_LIMIT, value 0.02 at c4. MaxRounds 4 gives OK. MaxRounds 1 gives 0.75 at c2. The original toy 3 is now 2 rounds, OK, 0.090 at c5. The old expectation (OK after one moved confirmation) is marked SUPERSEDED in tBoundWorstToys.
- **Kinked valley.** The prediction NOT_ASSESSABLE (FC-901) held: both sqp starts exhaust 60 evaluations (exit flag 0). The value 0.100244 sits at u = (0.2996, -0.2075); the true minimum is 0.10. Shifted by -0.15 it is VIOLATED at -0.04976. This toy is VACUOUS in RED by design: it characterizes the unchanged search.
- **Lon/lat invariance (the gate of R3-M3(a)).** The largest relative deviation of any longitudinal metric was 3.8e-14 over 3 conditions x 2 lon settings x 4 lateral x1.5 corners (24 comparisons per metric, 10 metrics). The limit was 1e-9, so (a) is used.
- **Effective ratios.** These are documented in DECISIONS uq2-7.
- **Surrogate.** At the README point the spiral is stable over the x1 box: the largest Re is -0.00999 1/s at the corner [1.258 1.129 1.303 0.697 0.848 1.152]. For the nominal augmented aircraft, 5,000 ft / M 0.55 / CG 20 % is among the first four candidates by spiral Re (REG, R3).
- **tF16Uq hypothesis 9.** The lon-only CAP search gives the exact lower corner with margin -0.0058793 (R3), D = 3.6428.

## Deviations / interpretations
1. **Kinked toy shape.** R3 says "min of two planes". I built the interior V as the max of two planes, because a min of two planes is a ridge with its box minimum at a vertex (DECISIONS uq2-5).
2. **Meaning of "max 3 rounds".** I read it as 3 searches in total, each followed by a confirmation.
3. **Earlier rounds.** Any round's non-OK point blocks OK, and any round's counterexample is definitive.
4. **Surrogate source.** The surrogate is the mode classified 'spiral'. A point where the classifier gives no single spiral is non-OK; the metric's fallback root is not used.
5. **Runtime spot check.** I added a lon/lat spot check at runtime that falls back to the full box. The contract only required the gating test.
6. **Mahalanobis convention.** It uses the x1 judgment sigmas at every width, with dof = the number of searched parameters.
7. **Shared code.** No change to `uq/f16_uncertainty.json`, and none outside `+vital/+uq`, run_f16_uq.m and tests/M8.
8. **RED classification of tF16Uq.** In RED, all of tF16Uq is RED_EXPECTED, including its 8 unchanged tests. The analyze stub (`vital.uq.searchPlan`) stops its class setup. The 8 unchanged tBoundWorstToys tests were VACUOUS: they are pre-existing and unchanged.

## Open issues
- **Default report is stale.** `reports/uq/f16_uq_default.*` was produced by the pre-amendment code. The coordinator is to re-run `run_f16_uq` with defaults (about 90 min). I expect, unverified:
  - 3.2.2.1.2-CatA/B x1 to resolve (R3: 0.0164 / 0.186). Its kinked objective may still give FC-901 NOT_ASSESSABLE, as the kinked toy shows. The 2-D search has 4 corners, so it will likely be cheaper, but not necessarily conclusive.
  - 3.3.1.3 x1 to come out OK / +Inf if the surrogate converges. R3's corner maximum was -0.00055 1/s, nearly neutral.
- **Surrogate convergence in 6-D.** The surrogate search over 6-D with 60 evaluations per start may hit FC-901 if the maximum is interior. The README case converged at a vertex.
- **tF16Uq runtime.** About 408 s in the GREEN gate, down from about 794 s in R3's gate. The 3.3.1.1 group's 64 corners still dominate.
- **tUqR3Report runtime.** About 42-68 s, at the 60 s guideline.
