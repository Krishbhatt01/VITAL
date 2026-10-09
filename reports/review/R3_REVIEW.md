# Review R3: M7 (stability augmentation, closed) and M8 (uncertainty, verified, not closed)

Reviewer: R3 (independent; did not build M7 or M8). Dates: 2026-10-08, resumed and finished 2026-10-09.
Scope: read-only on the implementation. Everything I ran is in `reports/work/R3/`; my scratch scripts (`r3check1.m`, `r3check2.m`, `r3sab.m`, `r3child.m`) are in my temp folder, outside the tree.

## 1. Summary

- **Gate (re-run from a fresh session).** Full M0-M8 GREEN: **539/539 PASS**, 0 FAIL, 0 excluded, gateOK 1, 2381 s.
  - Counts per milestone: M0 50, M1 93, M2 29, M3 19, M4 26, M5 175, M6 73, M7 33, M8 41.
  - Command: `restoredefaultpath; startup_vital; run_vital_tests('M8','Phase','green',...)`. The coordinator asked for `startup_vital`. Exit criterion 1 asks for a run without it, which I did not do.
- **Registered sabotages.** M7 6/6 DETECTED and M8 5/5 DETECTED, tree unchanged 1 for both.
  - **Two of the M7 detections are not evidence under the official harness** (finding B1). A null sabotage (a whitespace change in a comment) is also "DETECTED" for `tCtrlSuggest` and for `tF16Uq`, because the sabotage copy has no `reports/` folder.
  - I re-ran S7C-4 and S7C-5 with the reports present, and both are genuinely DETECTED. The null control N-1 is NOT DETECTED under that runner.
- **Proposed sabotages.** 13 realistic bugs: **9 NOT DETECTED**, 4 DETECTED. All 9 undetected ones are test gaps, not errors in today's results.
- **The physics checks agree with the claims.**
  - The closed-loop A of the pitch SAS and yaw damper equals A + B K built by hand to 3.4e-11.
  - The suggested gains (Kq 0.02, Ka 0.14, Kr 0.82) give Level 1 for all three targets. No protected group regresses.
  - The k_g values, box half-widths and Clopper-Pearson bounds are exact.
  - The 3.2.2.1.1-CatA NOT_ROBUST counterexample reproduces exactly: margin -0.0058793 at the exact (Cm_q, Cm_table) lower corner, 13,000 ft / M 0.45 / CG 30 %.
- **My own scans resolve the four NOT_ASSESSABLE x1 groups.** All four are conservative, not hidden failures:
  - 3.2.2.1.2-CatA: true x1 minimum 0.0164 > 0
  - 3.2.2.1.2-CatB: 0.186 > 0
  - 3.3.1.3-CatA/B: the spiral is stable at all 32 corners × 30 IN conditions at x1 (max Re = -0.00055 1/s, nearly neutral)
- **Recommendation.** Do not close M8 until B1 (harness), M1 (pin the M7 gains) and the M6 test gaps are fixed, and M2-M5 are fixed or explicitly accepted. Nothing in M8's numbers is wrong. M7 needs no reopening of results; it needs an acceptance-note amendment and three added tests (section 7).

## 2. Gates I measured

| run | result | file |
|---|---|---|
| run_vital_tests('M8', green) | TOTAL 539, PASS 539, FAIL 0, EXCLUDED 0, VACUOUS 0, gateOK 1, 2381 s; checks PUB 1967 / INDEP 88 / ANALYTIC 706 / REG 738 | reports/work/R3/M8_green.txt/.json |
| run_sabotage('M7') | S7C-1..6 all DETECTED, tree unchanged 1 | reports/work/R3/M7_sabotage.txt |
| run_sabotage('M8') | S8U-1..5 all DETECTED, tree unchanged 1 | reports/work/R3/M8_sabotage.txt |
| null sabotages through the official harness (vital.test.runSabotageCase) | N-1 (comment whitespace in suggestGains.m, target tCtrlSuggest/badInputs): **DETECTED**, 247 s; N-2 (comment whitespace in box.m, target tF16Uq/labelledJudgment): **DETECTED**, 761 s | reports/work/R3/null_sabotages_official_result.json |

Note: `vital.version` still reports `0.2.0-M4`.

## 3. Independent checks (what I ran and saw)

All of these are in `reports/work/R3/check1.json` and `check2.json`.

1. **Closed loop by hand (M7).**
   - Method: K (4x12) from Kq e_q + Ka dalpha/d[u w] and Kr e_r, then A_hand = A_open + B_open K. Three trims: 13,000 ft/M0.45/CG30, 13,000/M0.45/CG20, and 10,013/M0.5/CG25.
   - Agreement with `linearize(...,'Controller')`:
     - max |A_hand - A_cl| (8x8) = 3.4e-11 (2.4e-13 relative)
     - eigenvalues agree to < 9e-10
     - B_cl = B_open exactly (Kref = I)
   - Signs: B(qdot, de) = -6.38 and B(rdot, dr) = -2.26 1/s^2 per rad. +de is nose-down and +dr is nose-left, as in CONVENTIONS 7.
   - Agreement with my own eigen-analysis: omega_sp, zeta_sp and zeta_d agree to 1e-9. The yaw damper takes zeta_d from 0.120 to 0.427 at CG 30 %.
2. **The M7 suggestion confirms (re-run).**
   - A fresh `vital.fq.assess` of the augmented aircraft over `inEnvelopeConditions` gives Level 1 for:
     - 3.2.2.1.1-CatA (margin 0.051249)
     - 3.3.1.1-CatA-COGA (0.053764)
     - 3.3.1.1-CatA-other (1.2185)
   - All 16 protected groups stay at Level 1, and every point has equivalentSystem CLASSICAL. This matches `reports/ctrl/f16_sas_suggestion.md` to all printed digits.
3. **The M8 box.** k_g = sqrt(2) erfinv(0.99) = 2.5758293 and sqrt(-2 ln 0.01) = 3.0348543. The implementation equals them exactly (diff 0), and so do the half-widths k_g sigma.
   - Probability content: 0.99 for each 1-D group box, 0.99519 for each 2-D group box. The joint 6-D box holds **0.97070**.
4. **Clopper-Pearson.** I checked against my own binomial tail sum (gammaln) with bisection, at x/n = 200..194/200, 20/20, 37/50, 0/20 and 1/20, one-sided and two-sided. The maximum difference is 9.8e-15.
   - 196/200 gives 0.95482 and 195/200 gives 0.94816, so ROBUST tolerates at most 4 failures in 200.
5. **The 3.2.2.1.1-CatA NOT_ROBUST finding.**
   - I re-evaluated it at the reported arg-min and condition, and at the exact corner (Cm_q = 1 - 0.257583, Cm_table = 1 - 0.128791, lateral 1):
     - CAP = 0.278354, margin **-0.0058793** (report -0.00587928)
     - n/alpha from my own constant-V transformation = 9.9524 g/rad, the same as the implementation
   - The lateral parameters are irrelevant: lon/lat invariance is 1.6e-16.
   - **Attribution:**

     | parameters at their lower bound | CAP margin |
     |---|---|
     | Cm_q only | +0.0060 |
     | Cm_table only | +0.040 |
     | both | -0.0059 |

     The counterexample needs both 1-D groups at their 2.576-sigma bounds together. That is Mahalanobis distance 3.64 in (Cm_q, Cm_table); the probability beyond it in that plane is about 1.3e-3. This is a legitimate product-box corner under the contract, and it explains why the Monte Carlo is 200/200.
   - **Sensitivity to the n/alpha definition.** A constant-u (body-axis) n/alpha differs by 2 % (10.20 vs 10.00 g/rad) and gives margin +0.031 nominal and -0.025 at the corner. The verdict is unchanged, but the CAP margin is only about 5 % and the definition matters at that level. The implementation's constant-speed (air-axis) form is the MIL-F-8785C one.
6. **Cm_table moves the trim.** At 13,000 ft/M0.45/CG30, Cm_table 0.871 moves the trim de from -2.49 to -2.77 deg and alpha from 4.592 to 4.626 deg. It lowers omega_sp from 1.716 to 1.700 rad/s.
   - Physically this is a re-trimmed airplane with a uniformly scaled MRC pitching-moment table. That is meaningful, but it fully correlates Cm0, M_alpha (MRC) and the elevator power M_de, which also scales the SAS's Ka/Kq authority. See finding M5.
7. **3.2.2.1.2 at x1 (NOT_ASSESSABLE in the report).**
   - Method: a 9x9 grid of (Cm_q, Cm_table) over the x1 box at the 4 candidates, plus a 41-point line at Cm_q = lo. The lateral parameters were held at 1; they are irrelevant, invariance 1.6e-16.
   - CatA minimum: 0.016431 at Cm_table 1.0773, equal to the search's best value 0.016432. CatB minimum: 0.1860. No point was non-OK on my grid.
   - The margin along Cm_table at Cm_q = lo is 0.0185, 0.0181, ..., 0.0165, then **jumps to 0.0527**. The minimum sits at a kink: the objective is nonsmooth there, which is why sqp burned its 60 evaluations.
   - Conclusion: the true x1 bound-worst is positive for both. NOT_ASSESSABLE is conservative, not hiding a violation.
8. **3.3.1.3 (+Inf margins).**
   - x1: all 32 corners of (Cm_table, Cl_p, Cn_r, Cl_table, Cnt_table) × all 30 IN conditions = 960 closed-loop points. The spiral is stable everywhere, but the maximum spiral Re is -0.00055 1/s at 5,000 ft/M0.55/CG20, so it is barely stable. Cm_q was held at 1 (decoupled).
   - x1.5: 115 of 960 are unstable. The minimum T2 is 23.44 s, i.e. margin 0.953 (CatA L1, 12 s) at 5,000/M0.55/CG20 at the corner [Cm_table 1.193, Cl_p 0.545, Cn_r 0.545, Cl_table 0.772, Cnt_table 1.228]. That is exactly the report's confirmation value 0.95298.
   - The x1.5 ROBUST (after a moving limit) is therefore right, here.

## 4. Findings

### BLOCKER

**B1. The sabotage harness gives vacuous detections for any target that reads `reports/`. This affects the closed M7 evidence (S7C-4, S7C-5) and any future tF16Uq sabotage.**
- **Where:**
  - `+vital/+test/applySabotage.m:20` excludes `reports` from the copy
  - `+vital/+test/runSabotageCase.m:41-43` redirects only `VITAL_DATA_ROOT`
  - `tests/M7/tCtrlSuggest.m:84` and `tests/M8/tF16Uq.m:81` read `fullfile(vital.paths('reports'), ...)` in TestClassSetup, and `vital.paths('reports')` resolves to the copy
- **Evidence:** I ran two null sabotages (whitespace inside a comment) through `vital.test.runSabotageCase`, and both came back "DETECTED":
  - target tCtrlSuggest/badInputs, 247 s
  - target tF16Uq/labelledJudgment, 761 s

  The class setup fails on the missing report file, after running the expensive search. So S7C-4 and S7C-5 (both targeting tCtrlSuggest) were never shown to be caught by the tests. Their "DETECTED" in M7's 121/121 and in my run is a harness artefact.
- **Re-check with the reports copied.**
  - Method: my runner copies `reports/ctrl` and `reports/fq` into the sabotage copy.
  - The null control N-1 comes out **NOT DETECTED**, so my runner is not vacuous.
  - S7C-4 and S7C-5 are **DETECTED** (their target methods fail while the null control's passes with the same class setup).
  - So the M7 suggestGains tests do catch these two defects. Only the official evidence was vacuous.
- **Fix:**
  1. Give `runSabotageCase` a `VITAL_REPORTS_ROOT` (or copy `reports/ctrl` and `reports/fq` read-only into the copy). Make `vital.paths('reports')` honour it the way `data` does.
  2. Add a permanent harness self-test: a null sabotage per milestone must be NOT DETECTED.
  3. Re-run every milestone's sabotages.
  4. Long-term: tests should not take expected values from mutable report files at all. Pin the expected values in the test header, which is how tCtrlFq already does it.

### MAJOR

**M1. The M7 proposal that M8 analyses is not pinned to a live re-derivation.**
- **Where:**
  - `+vital/+uq/augmentedBuilder.m:236-239` hard-codes Kq 0.02, Ka 0.14, Kr 0.82
  - `tests/M8/tF16Uq.m:94` compares them only with the stored `reports/ctrl/f16_sas_suggestion.json`
  - `tests/M7/tCtrlSuggest.m` never compares `s.gains.value` with that file or with fixed numbers
- **Evidence:** proposed sabotage S7R-2 (truncating instead of rounding, which gives Kq 0.01 and Kr 0.81) is **NOT DETECTED**: tCtrlSuggest#targetReachedAndConfirmed and #confirmationIsIndependentAssessment both pass. A changed suggestGains therefore passes M7 while M8 keeps analysing stale gains.
- **Fix:** add a REG pin in tCtrlSuggest (`s.gains.value == [0.02 0.14 0.82]`, exact) with the confirmation margins at 1e-12. Alternatively, have tF16Uq derive the gains from a stored, version-checked suggestion with a hash.

**M2. "Converged" is taken at face value on nonsmooth objectives, and the toy suite never exercises a kink.**
- **Where:** `+vital/+uq/boundWorst.m:256` (`o.converged = flag > 0`), and the status 'OK' it feeds (`:197-200`).
- **Evidence:**
  - In the default report most starts stop after 13-14 evaluations (initial point + one 7-point forward-difference gradient), at corners where the projected gradient vanishes.
  - 3.3.1.4 (binary metric, flat margin 0) "converges" after 7 evaluations, so "every start converged" means nothing there.
  - For 3.2.2.1.2-CatA x1, my scan (3.7) shows the true minimum is at a kink, where sqp cannot converge.
  - So the search reports OK or NOT_ASSESSABLE for reasons unrelated to whether the box was explored.
  - Mitigation: in this run every OK group I could check is consistent with my corner and grid scans.
- **Fix:**
  - State in the report that the bound-worst is a search estimate, i.e. an upper bound on the true minimum, not a proof.
  - Label groups with a binary or flat metric "sampled only".
  - Add a toy with a kinked min-of-two-planes valley (an interior V) and pre-register what status the search should give.
  - Optionally use lon/lat separability, below (M3).

**M3. The four NOT_ASSESSABLE headline groups are honest, but cheap to resolve.**
- **Where:** `+vital/+uq/analyze.m:125-138` searches the full 6-D box for every group.
- **Evidence:** the trim is wings-level with beta = 0, so the lon groups depend only on (Cm_q, Cm_table) (invariance 1.6e-16). The lateral groups depend on Cm_table plus the 4 lateral parameters.
  - A 2-D scan resolves 3.2.2.1.2-CatA (min 0.0164) and -CatB (0.186) at x1 as positive.
  - The 32-corner scan shows 3.3.1.3 stable at x1. It is very close to neutral, so the +Inf margin is fragile.
- **Judgment:** acceptable as documented for closing (no hidden pass, verdict logic correct). It is a real gap in the deliverable's answer, because 4 of 19 headline groups have no verdict. Recommended before or soon after closing:
  - search lon groups over the lon parameters only (a dense grid is cheap)
  - for +Inf groups, rank and search by a smooth surrogate, the spiral root Re(lambda), and report the T2 margin. In `F16Evaluator.inEnvelopeMargins` (`F16Evaluator.m:211`) all-Inf ties pick the first 4 grid points as "candidates", which is arbitrary.

**M4. A moving limit leaves the status 'OK' without re-searching at the moved condition.**
- **Where:** `+vital/+uq/boundWorst.m:143-148`; pre-registered as status OK in `tBoundWorstToys.m:159`.
- **Evidence:** 3.3.1.3-CatA/B x1.5 are ROBUST from a confirmation at 5,000/M0.55/CG20, a condition that was never a candidate. The search values were 1.79/0.675 elsewhere.
  - My corner scan shows the result happens to be the true worst corner (0.953).
  - In general, though, the arg-min theta was optimized for the wrong condition. Then "OK" plus ROBUST is not supported.
- **Fix:** when `confirmation.moved`, add the moved condition to the candidates and re-run the search (iterate until it no longer moves, bounded). Or mark the status `OK_MOVED`, and have the verdict treat that as NOT_ASSESSABLE unless re-searched. The contract (plan M8) needs a one-line amendment either way.

**M5. Cm_table scales Cm0, M_alpha (MRC) and M_de together.**
- **Where:** `+vital/+aircraft/+f16/loads.m:24-28`; ADR uq-2; `uq/f16_uncertainty.json`.
- **Evidence:**
  - Cm_table moves the trim (3.6), and it scales elevator power, so the SAS's own authority scales with it.
  - The headline NOT_ROBUST for 3.2.2.1.1-CatA needs Cm_table at its lower bound (3.5): Cm_q alone leaves +0.006.
  - This is a modelling JUDGMENT that the report does not explain. The report md never says the multipliers act on MRC coefficients (ADR R2-5 asked M8 to treat them so), and it gives no effective CG-derivative ratios for the new multipliers, unlike `tF16FqR2#aeroScaleEffectiveDerivatives` for the M6 ones.
- **Fix:**
  - Either split the parameter into M_alpha-only and M_de-only scalings, or accept the coupled scaling explicitly in the M8 acceptance text.
  - Add REG effective-derivative ratios for Cm_table, Cl_table and Cnr_table (e.g. Cm_table × 0.87 → M_alpha,cg × ?, M_de × 0.87).
  - Print the MRC note and the arg-min's Mahalanobis distance in the report.

**M6. Additional gaps exposed by the proposed sabotages.** Details in section 6.
- **S8R-5, NOT DETECTED.** A verdict that treats +Inf bound-worst as ROBUST passes every test. The truth table (`tMonteCarloVerdict.m:115-128`) has no Inf/NaN rows, and that "fix" is exactly the one the open 3.3.1.3 issue invites.
- **S8R-6, NOT DETECTED.** A non-OK point that keeps a finite margin at another candidate condition is silently not counted (FC-903 with several conditions). `tBoundWorstToys#nonOKPointIsNotAssessable` uses one condition only.
- **S7R-3, NOT DETECTED.** The 3.1.12 equivalent-system flag can ignore extra or non-OK modes. `tCtrlFq#equivalentSystemFlag` only exercises a case where a classical name is missing.
- **S8R-1, NOT DETECTED.** The Monte Carlo can be drawn with the x1 sigma at every width. The x0.5/x1.5 Monte Carlo columns are never checked against the width.
- **S8R-2, NOT DETECTED.** A cache key printed with %.4g lets fmincon's finite-difference points (1e-3 relative) and nearby samples reuse another point's margin. That gives zero gradients and false convergence.
- **S8R-7, NOT DETECTED.** `F16Evaluator.levelMargin` can ignore EXCLUDED in-envelope points (`F16Evaluator.m:185`), so a moving limit into a non-trimmable point would be hidden.
- **S8R-8, NOT DETECTED.** `F16Evaluator.inEnvelopeMargins` can rank EXTRAPOLATED points as candidates (`F16Evaluator.m:199`).
- **S7R-1, NOT DETECTED.** `suggestGains.m:217` can treat a protected group that becomes NOT_ASSESSABLE (NaN headline) as not regressed, so TARGET_REACHED would be claimed. This is the FC-702 rule (non-OK never improves a verdict), now in M7.
- **Fix:**
  - add truth-table rows (OK/Inf, NOT_ASSESSABLE/Inf, OK/NaN)
  - a 2-condition non-OK toy
  - a FLAGGED case with an 'other' mode at the README point
  - a test that a protected group becoming NOT_ASSESSABLE is reported "worse than bare"

### MINOR

- **m1. tF16Uq hypothesis 2 is true by construction.** `tests/M8/tF16Uq.m:110-117` ("bound-worst <= nominal margin") cannot fail: the centre is evaluated and the candidates contain the critical condition. It guards only that the centre is evaluated. Re-label it as a guard. The other three invariants are real.
- **m2. The joint coverage of the box is not reported.** The 6-D box holds 0.9707, not 0.99. The fact is in NOTES and the CHANGELOG, but not in `reports/uq/f16_uq_default.md` or the spec. Print it beside the half-width table (`writeReport.m`). Acceptable as documented once printed.
- **m3. Cnr_table vs the plan's Cn_r (ADR uq-1).** Acceptable as documented: it is the lower-risk choice, consistent with Cnt_table. The coordinator should either amend the plan text or schedule the rename together with the M6 unknown-name example.
- **m4. tF16Uq takes about 10 min** (the 64 corners dominate) and tCtrlSuggest 5-6 min. Under B1 they are also the two classes that cannot be sabotage targets today.
  - Acceptable, or defer.
  - Option: a 2-group, 3-parameter variant for the gate (lon groups over lon parameters, M3) would cut it to about 1 min. Keep the full one as an opt-in tag.
- **m5. `reports/uq/f16_uq_default.json` is 10 MB.** It holds every evaluated point for every group and width. Defer: write the points to a separate `_points.json`, or deduplicate the shared centre, corner and LHS points, since every group shares them.
- **m6. Groups with a NaN in-envelope headline are dropped silently from the default M8 group list.** `+vital/+uq/analyze.m:78-81` drops them instead of listing them as NOT_ASSESSABLE (the CatC groups by policy). List the omitted groups in the report.
- **m7. The version string is stale.** `+vital/version.m:3` still says `0.2.0-M4` after M7 closed.
- **m8. No test pins the stored default report.** No test re-derives or pins any headline value of `reports/uq/f16_uq_default.*`. They are reproducible: I reproduced the CAP and spiral values, and the 3.2.2.1.2 x1 value. Consider a REG pin of the x1 headline verdicts against a re-run at reduced budget for the two tF16Uq groups. That already holds for H1/H2.
- **m9. The x1/x1.5 3.3.1.3 ordering reads as contradictory.** x1 is NOT_ASSESSABLE while x1.5 is ROBUST, although the x1 box is inside the x1.5 box. Add a sentence in the report: robustness of a box implies robustness of the boxes it contains; NOT_ASSESSABLE here only means "not searchable".

## 5. Test audit (M7, M8)

- **Evidence tags.** I found no REG value labelled PUB.
  - tF16Uq #5 calls a sign from an approximate Dutch-roll formula "ANALYTIC". That is acceptable for a sign.
  - tClopperPearson #6 cites scipy values in the header and checks them against an in-test bisection, which is a fair use of INDEP.
- **Circularity.**
  - tF16Uq #1 compares the M8 nominal margin with the M7 JSON. That is consistency, not correctness; it is labelled REG.
  - tCtrlClosedLoop builds K by hand from measurement Jacobians, so it is not circular. I confirmed it independently.
- **Failed hypotheses.** Each is recorded with the original text kept and no tolerance loosened:
  - tUqSpec 3a and 3b
  - tF16Uq 5b
  - tCtrlClosedLoop (b)
  - tCtrlLaws 4
  - tCtrlSimAgreement 1

  The tF16Uq 5b correction (Cm_q instead of Cm_table) is weaker evidence than the original, but it is justified, and the failure itself is physical (finding M5).
- **Error identifiers.** The failure-mode tests use the exact identifiers of FC-801..816 and FC-901..913. I found no mismatch.
- **Physics and sign errors shared by a test and the code.** I found none. The signs were confirmed from the open-loop B matrix (3.1), and the closed loop from A + B K.

## 6. Sabotages

### Registered
- M7: S7C-1..6 DETECTED.
  - S7C-4 and S7C-5 are **vacuous** under the official harness (B1).
  - Re-check with reports present (my runner, null control N-1 NOT DETECTED): S7C-4 DETECTED, S7C-5 DETECTED.
- M8: S8U-1..5 DETECTED. None of them targets tF16Uq, so B1 does not affect them.

### Proposed (`reports/work/R3/proposed_sabotages.json`)
Each pattern occurs exactly once (checked). I tested detection on a copy of the tree with `reports/ctrl` and `reports/fq` present, running the target methods of each class in one child process. Results are in `reports/work/R3/proposed_sabotages_final_result.json`. Totals: 4 DETECTED and **9 NOT DETECTED** of 13. In every NOT DETECTED run the child ran every target method and each one PASSED with the defect in place; no run errored.

| id | file | defect | result |
|---|---|---|---|
| S8R-1 | +vital/+uq/analyze.m | Monte Carlo uses x1 sigma at every width | **NOT DETECTED** |
| S8R-2 | +vital/+uq/F16Evaluator.m | cache key with %.4g (FD points collide) | **NOT DETECTED** |
| S8R-3 | +vital/+uq/boundWorst.m | exit flag 0 counted as converged | DETECTED |
| S8R-4 | +vital/+uq/verdict.m | NOT_ASSESSABLE becomes ROBUST | DETECTED |
| S8R-5 | +vital/+uq/verdict.m | +Inf bound-worst becomes ROBUST | **NOT DETECTED** |
| S8R-6 | +vital/+uq/boundWorst.m | non-OK point with a partial margin not counted | **NOT DETECTED** |
| S8R-7 | +vital/+uq/F16Evaluator.m | excluded in-envelope points ignored in levelMargin | **NOT DETECTED** |
| S8R-8 | +vital/+uq/F16Evaluator.m | candidates include EXTRAPOLATED points | **NOT DETECTED** |
| S7R-1 | +vital/+ctrl/suggestGains.m | NaN protected headline not a regression | **NOT DETECTED** |
| S7R-2 | +vital/+ctrl/suggestGains.m | floor instead of round (gains not pinned) | **NOT DETECTED** |
| S7R-3 | +vital/+fq/evaluatePoint.m | 3.1.12 flag ignores extra / non-OK modes | **NOT DETECTED** |
| S7R-4 | +vital/+ctrl/yawDamper.m | interconnect sign | DETECTED |
| S7R-5 | +vital/+ctrl/closedLoop.m | improvement reported for an unstable loop | DETECTED |
| N-1 (control) | suggestGains.m comment | null sabotage with reports present | NOT DETECTED (correct; my runner is not vacuous) |

## 7. Recommendation

- **M8: do not close yet.** These need fixes first:
  - **B1:** give the harness a reports root and a null-sabotage self-test, then re-run every milestone's sabotages on a quiet tree.
  - **M1:** pin the M7 gains in tCtrlSuggest (S7R-2 is undetected today).
  - **M6:** add tests for the undetected sabotages S8R-1, S8R-2, S8R-5, S8R-6, S8R-7 and S8R-8. The verdict and in-envelope gaps (S8R-5, S8R-7, S8R-8) matter most, because they guard the "NOT_ASSESSABLE never becomes a pass" and "in-envelope only" claims.
  - **M2-M5:** fix them, or accept them explicitly in `M8_acceptance` with the text of this review.
  - **None of these changes an M8 number.** Every value I re-derived matches the report. No NOT_ASSESSABLE hides a pass or a violation: my scans show all four x1 NOT_ASSESSABLE groups are in fact positive.
- **M7: no physics or claim needs reopening.** The closed loop (A + B K to 3e-11), signs, confirmation (Level 1 for all three targets, no regression) and equivalent-system results were verified. S7C-4 and S7C-5 are genuinely detected once the reports are present.
  - Amend the M7 acceptance note: the 121/121 sabotage count included two harness-vacuous detections, since re-proven.
  - Add M7 tests for S7R-1 (NaN protected group must be "worse than bare"), S7R-2 (gains pinned) and S7R-3 (3.1.12 flag with an extra or non-OK mode). These can go in as M8-era tests without reopening M7's results.

## 8. Not verified

- **No run without `startup_vital`** (exit criterion 1). I followed the coordinator's command.
- **The full-budget `run_f16_uq` was not re-run** (about 90 min). I re-derived the specific values listed in section 3 instead.
- **No positive control for tF16Uq in my runner.** I had no tF16Uq sabotage known to be detectable. The undetected tF16Uq results rest on the child having run each target method and seen it PASS, which it did.
- **The spiral scan covers corners only, not interior points.** The spiral root may be non-monotone in the parameters.
- **My n/alpha cross-check uses the same constant-speed definition** in my own coordinates. It is a recomputation, not a second physical model.
- **The 3.2.2.1.2 grid holds the lateral parameters at 1.** Exact decoupling was verified at one point (1.6e-16), not everywhere.
