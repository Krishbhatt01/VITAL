# Review R5: M8 (uncertainty), complete section after amendments R3, R4 and R4b

Reviewer: R5 (independent; did not build M8). Date: 2026-10-14.
Scope: read-only on the implementation. Runs and scratch output are in `reports/work/R5/`. My scratch scripts (`r5toys.m`, `r5gap.m`, `r5levers.m`, `r5corners.m`, `r5line.m`, `r5line2.m`, `r5misc.m`, `r5alpha.m`, `r5sab.m`) are in my temp folder, outside the tree.

## 1. Summary

- **Nothing I re-derived is numerically wrong.** k_g, the joint coverage, Clopper-Pearson, the AeroScale default path and the Cm_basic/Cm_de split all check out independently. The CAP failure mechanism is physical. The verdict logic never turns NOT_ASSESSABLE or unknown into a pass on any path I traced.
- **The default analysis of the final design has never been run.** `reports/uq/f16_uq_default.*` dates from 2026-10-09, before R3, R4 and R4b, so the M8 question has no current answer (B1).
- **The lattice has a structural problem the builders did not see (M1).**
  - The margins are discontinuous where the trim alpha crosses the alpha = 5 deg table breakpoint.
  - That surface runs through the judged box at 13,000 ft / M 0.45 / CG 20 %, the critical condition of 3.2.2.1.2-CatA/B. The nominal trim alpha there is 5.050 deg.
  - A Lipschitz certificate can never certify a cell that straddles a jump larger than half the local margin. A 1-D F-16 lattice shows it:
    - it refines to MaxLevel 10 and stays uncertified (bound -0.048);
    - the margin is >= 0.017 everywhere on that line;
    - it ends NOT_ASSESSABLE ('GRID') at alpha 0.47.
  - Predicted for the default run: 3.2.2.1.2-CatA ends NOT_ASSESSABLE after spending its 6,000-point cap along the breakpoint surface. Its true x1 margin is positive (R(1) corner minimum 0.0165, and R3's grid gave 0.0164).
- **The certificate's scope is overstated (M2).** It covers only the 2 stage-1 candidate conditions. The other in-envelope points are checked only at the CPV and arg-min confirmations. The report calls the result an "in-envelope margin". A toy shows the lattice reporting ROBUST (alpha* 1.28) where the truth is NOT_ROBUST (alpha* 0.75).
  - On the F-16 I found no such case: at the 16 corners of R(1) and R(2), the critical condition of 3.2.2.1.1-CatA and 3.2.2.1.2-CatA/B never changed.
- **Cost (M3).** The literal certificate (full edge h, factor 2) together with the 0.01 resolution requirement is the cost driver.
  - **Switching to h/2** cuts points by 2.4-3.0x on the toys where both versions resolve, at the same safety factor. It resolved a toy that the as-built lattice could not.
  - **Deciding the verdict from R(1) alone** cuts points by 4-13x. It gives the correct verdict where the as-built lattice gives NOT_ASSESSABLE (true alpha* 1.05).
- **Tests (M4).** Of my 9 proposed realistic sabotages, **8 are NOT DETECTED**. The 1 detected one doubles as the positive control, and the null control is NOT DETECTED.
- **Recommendation: do not close M8 yet.**
  - **Required before the 10-20 h default run:** fix or explicitly accept M1, M2, M3 and M5, and add the tests for M4.
  - **After the run:** pin the headline verdicts. That closes B1.

## 2. What I ran

| run | result | file |
|---|---|---|
| Subset of the M8 classes re-run in one fresh session (runtests): tUqLattice, tUqBracket, tUqStaged, tUqCsr, tMonteCarloVerdict, tClopperPearson, tUqSpec, tUqHybrid, tUqGridCert, tBoundWorstToys, tUqR3Fixes, tAeroScaleUq, tUqR3, tUqR4bF16 | see section 2.1 | reports/work/R5/m8_subset_rerun.txt |
| Full M0-M8 gate | not re-run. I accept the coordinator's 634/634 (reports/work/coord_r4b/M8_green.txt) | - |
| Registered M8 sabotages | not re-run. I accept 33/33 (reports/work/uq4/M8_sabotage.txt) | - |
| Proposed sabotages S8Q-1..9 + null control N-R5 through `vital.test.runSabotageCase` (official harness, reports copied) | 1 DETECTED, 8 NOT DETECTED, null NOT DETECTED, tree unchanged 1 | reports/work/R5/proposed_sabotages.json, proposed_sabotages_result.txt |
| Toy lattice experiments (notch, band, h vs h/2, candidate gap, flat, NaN, Inf) | section 3 | reports/work/R5/toys.txt, toys_gap.txt, toys_levers.txt |
| F-16: fresh in-envelope assessments at the nominal and the 16 corners of the judged lon boxes R(1), R(2) | 17 x 36 points; section 3.5 | reports/work/R5/f16_corners.txt, f16_alpha.txt, f16_corners.mat |
| F-16: line scans through alpha = 5 deg at 13,000/0.45/CG20, and a 1-D lattice on each | section 3.6 | reports/work/R5/f16_line.txt (Cm_basic), f16_line2.txt (Cm_de, Cm_q at its x1 lower edge) |
| Statistics and AeroScale checks | section 3.1 | reports/work/R5/misc.txt |

### 2.1 Subset re-run
All 14 classes pass: 98 of 98 tests, 0 failed, 0 incomplete.

| class | tests | time |
|---|---|---|
| tUqLattice | 11 | 86 s |
| tUqBracket | 11 | 1 s |
| tUqStaged | 5 | 1 s |
| tUqCsr | 12 | 7 s |
| tMonteCarloVerdict | 6 | 1 s |
| tClopperPearson | 7 | 0.5 s |
| tUqSpec | 6 | 1 s |
| tUqHybrid | 9 | 3 s |
| tUqGridCert | 8 | 21 s |
| tBoundWorstToys | 9 | 2 s |
| tUqR3Fixes | 6 | 1 s |
| tAeroScaleUq | 4 | 3 s |
| tUqR3 | 6 | 16 s |
| tUqR4bF16 | 4 | 114 s |

## 3. Independent checks

### 3.1 Statistics and the AeroScale extension (all agree)
- **k_g.**
  - k_g(1) = 2.5758293035 = sqrt(2) erfinv(0.99).
  - k_g(2) = 3.0348542588 = sqrt(-2 ln 0.01).
  - The spec's kg and half-widths match: [0.2576 0.1517 0.1517 0.3035 0.3035 0.1517 0.1517].
- **Joint coverage of the R4 box.** The closed form gives 0.97579. My own Monte Carlo (1e6 samples) gives 0.97585 +/- 0.00031. A 2-D group box holds 0.99519 >= 0.99.
- **Clopper-Pearson.**
  - The lower bound equals the 0.05 quantile of Beta(x, n - x + 1) at x = 194..197 of 200: 0.94165 / 0.94816 / 0.95482 / 0.96169. ROBUST therefore tolerates at most 4 failures in 200.
  - N/N reaches 0.95 only from N = 59 (58: 0.94966, 59: 0.95049, 60: 0.95130). So the stage-1 N = 200 (ADR uq4-3) and the smoke N = 60 are justified.
- **Default path.** `loads` is isequal with and without the aeroScale field.
- **Cm_basic = Cm_de = k equals the legacy Cm_table = k.** At k = 0.85 and 1.15, max |dM| = 1.5e-11 N m against |M| = 9e4, and dF = 0.
- **The generated model builds cm = cmt + cq2v cmq** (aero.m:123). The rebuilt cm in loads.m:36 therefore drops no term.

### 3.2 Lattice certificate: when do measured slopes fail? (toys, tests/M8/tUqLattice helpers)
- **T1, notch narrower than a base cell.** m = 0.5 - 0.7 exp(-|s - (0.3,0.3,0.3)|^2 / 0.05^2) has true minimum -0.2 inside R(0.3).
  - The lattice reports **ROBUST_TO_CAP**, and R(1) "certified" with lower bound 0.5, after 1331 points.
  - No vertex and no neighbourhood edge sees the notch, so every slope is about 0.
- **T1b, step band** (margin -0.1 for 0.32 < s1 < 0.38): also **ROBUST_TO_CAP**.
- **Why this matters.** The lattice is labelled "Lipschitz estimate, not a proof", which is honest. But the report and the ROBUST verdict of a longitudinal group rest on it alone. Features of bounded support are plausible in a flying-qualities margin: a record whose applicability changes in a band (e.g. n/alpha ranges), or a mode-classification switch. The factor 2 and the full-h term do not protect against them.
- **Min over conditions and records.** The minimum of Lipschitz functions is concave across a switch, so it creates no hidden minimum. Curvature inside a cell is covered by the factor 2 together with the 3^d neighbourhood (KINK and QUAD toys).
- **Jumps (table breakpoints).** These are the real F-16 case (3.6). They make the measured slopes large, which is conservative, but they make certification impossible. They are never unsafe: a plane cutting a cell leaves at least one vertex on each side.
- **+Inf margins (T5c).** A cell whose vertices are all +Inf is certified (slopes NaN -> 0, bound +Inf). This happens even if a finite failing pocket lies between the vertices. No longitudinal F-16 group had +Inf margins in my runs, so this is a latent case.

### 3.3 h versus h/2 (ADR uq4-1: "cell min - sum L_i h_i, full edge")
- **The geometric bound is valid at h/2.** Every point of a cell is within h_i/2 of some vertex along each axis. With an axis-separable Lipschitz bound, min_v m(v) - sum L_i h_i / 2 is therefore a valid lower bound. The as-built bound with the full edge is a further factor 2, i.e. in effect 4 x the measured secant on the geometric bound.
- **Cost, measured.** `LipschitzFactor` 1 on the current code is exactly "h/2 with factor 2".

  | toy (true alpha* judged / equal) | as built: points, judged bracket | h/2: points, judged bracket |
  |---|---|---|
  | LIN (2.000 / 2.769) | 18,999, OK [1.9969, 2.0062] | 7,402, OK, same |
  | KINK (1.45 / 1.45) | 18,026, OK [1.4438, 1.4531] | 6,026, OK, same |
  | QUAD (1.8819 / 2.2325) | 19,997, **NOT_ASSESSABLE** (20k cap) | 9,752, OK [1.875, 1.884] |
  | SIN (1.2605 / 2.5196) | 20,000, NOT_ASSESSABLE [0.60, 1.50] | 19,997, NOT_ASSESSABLE [0.975, 1.35] |

  - At h/2 every bracket still contains the truth.
  - h/2 is not a weaker guarantee in any sense that matters: the cases that defeat the estimate (3.2) defeat any factor.

### 3.4 Other cost levers (reports/work/R5/toys_levers.txt)
Points to reach a decision, judged shape:

| toy (true alpha*) | as built (2 shapes) | judged only | judged only + h/2 | decide R(1) only | decide R(1) only + h/2 | verdict as built / decide-R(1) |
|---|---|---|---|---|---|---|
| LIN (2.0) | 18,999 | 10,680 | 4,431 | 1,464 | 1,331 | ROBUST / ROBUST |
| KINK (1.45) | 18,026 | 18,026 | 6,026 | 2,001 | 1,719 | ROBUST / ROBUST |
| QUAD (1.88) | 19,997 | 17,057 | 6,336 | 1,614 | 1,350 | **NOT_ASSESSABLE** / ROBUST |
| NEAR1 (1.05) | 20,000 | 14,424 | 6,046 | 4,988 | 2,450 | **NOT_ASSESSABLE** / ROBUST |

- "Decide R(1) only" was emulated with Resolution 3 and DecideAt 1. The verdict then rests on "every cell meeting R(1) certified", i.e. alphaLo >= 1. That is exactly the evidence R4-2 asks for. The 0.01 resolution is a reporting nicety, and it is what consumes the cap.

### 3.5 F-16: does the critical condition move inside the judged box? (reports/work/R5/f16_corners.txt)
- **Coverage.** Fresh assessments at the nominal and at the 8 corners of R(1) and of R(2) over (Cm_q, Cm_basic, Cm_de). Every IN point is OK.
- **3.2.2.1.1-CatA (CAP).**
  - The critical condition is 13,000/0.45/30 at every corner.
  - R(1) corners range from -0.0624 at [Cm_q lo, Cm_basic hi, Cm_de lo] to +0.165. R(2) worst is -0.176 at the same corner.
  - This confirms the smoke CPV direction and the physics in 4.1.
- **3.2.2.1.2-CatA.**
  - The critical condition is 13,000/0.45/20 at every corner.
  - R(1) corners are all positive: minimum 0.0165 at [lo, hi, lo]; 0.0188 at [lo, lo, lo].
  - Four R(2) corners are negative (-0.072, -0.068, -0.048, -0.028), so alpha*(judged) lies in (1, 2).
  - At one R(2) corner, 13,000/0.45/25 ranks second, and it was not among the nominal top 3.
- **Other longitudinal groups.**
  - 3.2.1.1 / 3.2.2.2 (speed divergence rate): margins stay 0.0107-0.0118 at every corner. They are nearly insensitive and positive.
  - 3.2.1.2 (phugoid zeta) stays 0.47-0.57. 3.2.2.1.1-CatB stays above 2.2.
- **Conclusion.** For these corners the 2 stage-1 candidates would have sufficed. The gap in M2 is a scope and claim problem, with no observed F-16 counterexample.
- **Trim ranges** (f16_alpha.txt).
  - Elevator stays between -9.3 and -1.2 deg at every IN point, so no el breakpoint (0, -12) is crossed in R(2).
  - The alpha = 5 breakpoint is crossed inside R(1) at 13,000/0.45/20 (4.943-5.197 deg) and inside R(2) at 13,000/0.45/25 (4.685-5.075). The CAP conditions (CG 30 %) never cross.

### 3.6 F-16: the breakpoint makes the margin discontinuous (reports/work/R5/f16_line2.txt)
- **Line.** Cm_de from 0.85 to 1.25, with Cm_q at its x1 lower edge (0.7424) and the rest at 1, at 13,000/0.45/20. The trim alpha passes 5 deg at Cm_de of about 1.071.

  | group | alpha > 5 side (Cm_de 1.07) | alpha < 5 side (1.08) | jump |
  |---|---|---|---|
  | 3.2.2.1.2-CatA | 0.01700 | 0.04936 | +0.032 |
  | 3.2.2.1.2-CatB | 0.18650 | 0.22425 | +0.038 |
  | 3.2.2.1.1-CatA | 1.7361 | 1.6529 | -0.083 |
  | 3.2.1.2-CatA | 1.0247 | 0.8978 | -0.127 |

  - This is the "kink" R3 found in 3.2.2.1.2-CatA (0.0165 jumping to 0.0527 along Cm_table). It is a jump, not a kink.
  - Cm_basic alone barely moves alpha (5.041-5.060 over 0.85-1.15; f16_line.txt).
- **The 1-D lattice on this line** (3.2.2.1.2-CatA, one condition, the code of the tree):
  - judged **NOT_ASSESSABLE ('GRID') [0.4693, Inf]**, after 26 points;
  - the straddling cell was refined to the finest step 8.9e-5 (MaxLevel 10, so exhausted);
  - its measured slope there was 367/unit, and its bound stayed -0.048 at every level;
  - R(1) is NOT_ASSESSABLE, yet the margin is >= 0.017 everywhere on the line;
  - 1 lattice point was BRACKETED (R4-7 worked).
- **Why it can never certify.** At every level, the bound of a straddling cell is min vertex - 2 x jump, independent of h. It is never certified when 2 x jump > local margin, here 0.064 > 0.017. At h/2 it would be 1 x jump, 0.032 > 0.017, so still never certified.
- **In 3-D.** The straddling cells form a surface. Every one of them is refined to MaxLevel until the 6,000-point per-group cap stops the group.

### 3.7 Candidate-condition gap (toy, reports/work/R5/toys_gap.txt)
- **Setup.**
  - Condition c1 is the group's only candidate (lowest nominal margin); it fails at s1 = 1.32.
  - Condition c2 has a larger nominal margin but fails at s2 = -0.75.
- **Result.**
  - Lattice: **OK, alpha* 1.284, verdict ROBUST**. The CPV is confirmed at c1, and the confirmation at the CPV sees c2 = +0.15, so it does not move.
  - Truth: alpha* 0.75, NOT_ROBUST.
  - With both conditions as candidates the lattice gives NOT_ROBUST.
- **Same structure for a robust group (T4).** ROBUST_TO_CAP is reported where the true alpha* is 1.75.

## 4. Physics
1. **CAP failure mechanism (3.2.2.1.1-CatA).** The worst corner is Cm_q low, Cm_basic HIGH, Cm_de low.
   - At CG 30 % (ahead of the 35 % MRC), the MRC static slope is destabilizing (ADR uq2-7: A/(A+B) = -0.316). Cm_basic > 1 therefore lowers M_alpha,cg stiffness.
   - Cm_de < 1 cuts both the elevator power and the SAS's alpha and q feedback (Ka 0.14, Kq 0.02 act through M_de).
   - Cm_q < 1 lowers M_q.
   - All three lower omega_sp^2 and hence CAP = omega_sp^2/(n/alpha). This is consistent, and the split exposes a combination the coupled Cm_table could not represent (uq3 NOTES). Plausible.
2. **The split is about the MRC only.** It scales the MRC pitching-moment increment cmt(el) - cmt(0). The elevator's lift (cz, cx with el) is not scaled, so "elevator power about the CG" = Cm_de x the MRC part + an unscaled transfer part.
   - Correct as documented ("about the MRC"). tUqR4F16 header 7 has the effective ratios.
   - Because cmt is bilinear on [-12, 0] deg x [alpha cell], d cmt/d el is piecewise constant in el and depends on alpha. Cm_de scales it exactly.
3. **Lateral results (smoke).**
   - 3.3.1.1-CatA-other: alpha* 2.75. Its CPV has Cn_r and Cl_p at 0.16 and Cnt_table at 0.58, i.e. Dutch-roll damping lost at large yaw/roll-damping cuts.
   - 3.3.1.3-CatA: the spiral is nearly neutral at x1 (max Re -0.00035 1/s), with alpha* 1.80.
   - Physically plausible. The spiral's x1 margin is thin, as R3 noted.
4. **Lon/lat invariance and R4-9** are valid because every assessed condition is a 1-g, wings-level, gamma = 0 trim (conditions_f16.json fixed gamma_deg 0; beta = 0). Asymmetric conditions (turns, sideslip) would invalidate it. The runtime gates check one point per group (the critical condition) and would not catch a new non-level candidate. That is acceptable today and should be stated as a precondition.
5. **Independent normal priors.**
   - Reasonable as a stated JUDGMENT.
   - Cm_basic and Cm_de come from one wind-tunnel table (cmt). Treating them as independent is itself a judgment that should be printed.
   - Normal multipliers with 10 % sigma give negligible negative-value probability.
   - The CSR (headline) does not depend on the distribution. Only the Monte Carlo and the k_g box do.
6. **Other breakpoints.** Beta = 0 sits on a breakpoint of the beta tables, but those tables multiply aileron and rudder deflections, which are 0 at the trim. Their beta derivative therefore does not enter. The thrust-table breakpoints (Mach 0.2 steps, 10,000 ft) are avoided by the grid design (conditions_f16.json) and do not move with theta. Restricting R4-7 to alpha and el is therefore adequate for this model.

## 5. Findings

### BLOCKER

**B1. The M8 deliverable for the final design does not exist, and the stored default report is stale.**
- **Where:** `reports/uq/f16_uq_default.json/.md` (2026-10-09). It is pre-R3: spec v1 with Cm_table, sqp, x0.5/x1.5 boxes, no CSR. It is 9 MB.
- **Evidence:**
  - Only two reduced smoke runs exist: 3 groups, N = 60, lattice cap 3,000 (r4bsmoke), and the earlier r4smoke.
  - The plan's question ("does the Level hold?") has no current answer for 19 groups.
  - Exit criterion 5 (the M8 demonstration) is not met.
- **Classification:** a process blocker, not a code defect.
- **Fix:**
  1. Rename or mark the stale default report as SUPERSEDED.
  2. After M1-M3 below are fixed or accepted, run `run_f16_uq` with its defaults.
  3. Pin the headline verdicts (and alpha* brackets) of that run in a REG test that re-derives one or two of them at reduced budget.

### MAJOR

**M1. Margin discontinuities at aero-table breakpoints defeat the lattice certificate. 3.2.2.1.2-CatA will end NOT_ASSESSABLE after burning its cap.**
- **Where:** `+vital/+uq/lattice.m:372-389` (`cellStats`: slopes and bound), :456-474 (`selectRefine`), :494-557 (`split`). R4-7 (`bracket.m`) treats only the linearization *at* a breakpoint, not the jump *across* it.
- **Evidence:** 3.6 above.
  - At the critical condition of 3.2.2.1.2-CatA/B, the nominal trim alpha is 5.050 deg and the alpha = 5 surface crosses R(1).
  - The margin jumps by +0.032 (CatA), so a straddling cell's bound is min - 2 x jump at every level.
  - The F-16 1-D lattice exhausts MaxLevel and reports NOT_ASSESSABLE at alpha 0.47, although the margin is >= 0.017 on the whole line.
  - In 3-D the straddling cells form a surface, refined until the per-group cap (6,000 points x 2 conditions, about 2 h) stops it.
  - The true answer is close to resolvable: the R(1) corners are all >= 0.0165, and alpha* lies in (1, 2).
- **Fix (piecewise certificate).**
  1. Record each lattice point's trim alpha and de per condition. `F16Evaluator` already has `S.alpha_deg` and `S.de_deg`; pass them through `latticePoint`.
  2. Mark a cell edge as "straddling" when its endpoints lie on opposite sides of an alpha or el breakpoint at that condition.
  3. Exclude straddling edges (and straddling base edges in the 3^d neighbourhood) from the slope estimate.
  4. Bound each side by its own vertices with its own slopes. For a planar cut each side holds at least one vertex, and the full-edge term covers the distance to it.
  5. Do not refine a cell whose sides are both certified.

  Alternative, if the coordinator prefers: accept this explicitly and do not refine cells whose only obstruction is a breakpoint straddle (to save the cap), and pre-register 3.2.2.1.2-CatA as NOT_ASSESSABLE.

  Either way, the report must say that the margin is discontinuous at table breakpoints. R4-7 only brackets the linearization.

**M2. The certificate and the CSR cover the candidate conditions only, but the report claims an in-envelope margin.**
- **Where:**
  - `analyze.m:343-345, 386-402`: the lattice's candidate conditions are the stage-1 NumCandidates = 2 per group (`stageBudget.m`), and lattice groups never get stage 2 (`stagePlan.m:67-70`).
  - `lattice.m:559-596`: other conditions are checked only at the CPV, cap-box arg-min and width-box arg-min.
  - `headline.m:52-53` ("in-envelope margin ... stays >= 0").
- **Evidence:**
  - Toy 3.7: ROBUST reported, NOT_ROBUST true; ROBUST_TO_CAP reported, alpha* 1.75 true.
  - F-16 (3.5): no counterexample at 16 corners, but the second-ranked condition changed at one corner.
  - The R3-era design had 4 candidates; the R4b default for lattice groups has 2.
- **Fix:**
  1. State the scope in the report: "certified over the candidate conditions <list>; the other in-envelope points are checked by a fresh assessment at the CPV and at the box arg-mins only".
  2. Add cheap envelope-wide confirmations: fresh assessments at the 2^d corners of R(1) and of R(alphaLo) for each longitudinal group. That is 16 assessments per group, about 10 min. A smaller margin at a non-candidate condition then triggers the existing moving-limit rule.
  3. Optionally give lattice groups NumCandidates 3-4. Base cost +1331 points per extra condition, shared.

**M3. The literal certificate and the 0.01 resolution make the lattice unable to decide in its budget. Clear cost levers exist that do not weaken the verdict.**
- **Where:**
  - `lattice.m:387` (`bound = mn - sum(L .* hT, 2)`, full edge);
  - `lattice.m:720` and `verdict.m:182` (ROBUST needs CSR status OK, i.e. a bracket resolved to 0.01);
  - analyze's per-group cap of 6,000.
- **Evidence:**
  - Toys 3.3/3.4: the as-built lattice cannot resolve QUAD or NEAR1 within 20,000 points, so their verdicts are NOT_ASSESSABLE. "Decide R(1) only" gives the correct ROBUST with 1,350-4,988 points.
  - F-16: uq4 measured 5,994 points (cap) in 7,860 s for 3.2.2.1.1-CatA with the bracket still at [0.34, 0.49].
- **Fix (in order of value):**
  1. Amend R4-2 so that ROBUST also follows from "every cell meeting R(1) certified (alphaLo >= 1) and the Clopper-Pearson bound >= 0.95". The alpha* bracket is then reported as is. NOT_ROBUST already accepts an unresolved bracket. This is the same evidence; the resolution is a reporting nicety.
  2. Use the geometric certificate h/2 with factor 2: 2.4-3.0x fewer points, with every toy bracket still containing the truth. tUqLattice header 4's bound becomes 0.14; record the old 0.08 as superseded.
  3. Require resolution 0.01 only for the judged shape, and report the equal shape's bracket.
  4. Refine the equal shape only to the resolution its report needs.

  Together these should bring the longitudinal lattice from "capped, NOT_ASSESSABLE" to decided in well under the current cap.

**M4. Test gaps: 8 of 9 proposed realistic sabotages are NOT DETECTED** (section 6). The four that matter most guard the "unknown never becomes a pass" and "a counterexample is definitive" claims:
- S8Q-1: a lattice point failing at one condition but not OK at another is not a counterexample. Plausible on the F-16 near alpha = 5.
- S8Q-2: ROBUST_TO_CAP despite a failing confirmation.
- S8Q-5: worseOf keeps a finite margin when side B is NaN.
- S8Q-7: a NaN Clopper-Pearson bound counts as adequate in the R4 verdict.

The others:
- S8Q-3: mean instead of max slope.
- S8Q-6: elevator field takes alpha.
- S8Q-8: analyze's runtime R4-9 gate loosened to 1e-2.
- S8Q-9: a moving limit is recognized only when the confirmation fails.

Fix: add the toys listed per sabotage in section 6 and register the sabotages.

**M5. The stage-1 acceptance band [0.8, 1.2] for hybrid (lateral) groups is not backed by evidence.**
- **Where:** `stagePlan.m:74`.
- **Problem:** A stage-1 judged alpha* outside the band is final, although it comes from a weaker search (2 candidates, DE 8 x 4) and a "clean" hybrid box is only a search estimate. No measurement shows the stage-1 error is below 20 %.
- **Evidence:** in the smoke, no stage-2 re-run happened. tUqR4bF16#stagedEndToEnd checks the mechanics, not the size of the stage-1 error.
- **Fix (either):**
  - Re-run the three smoke groups at the full budget and record |alpha*(stage 1) - alpha*(stage 2)|.
  - Or widen the band for ROBUST stage-1 verdicts (e.g. [0.8, 1.5]).
  - Or accept explicitly in M8_acceptance.

### MINOR
- **m1. Report text is stale or inaccurate after R4b.**
  - `writeReport.m:162` says "Lateral groups use the full box, because Cm_table moves the trim", while R4-9 drops Cm_q.
  - `writeReport.m:170` says "a box of at most 2 searched parameters is decided on a grid", while the longitudinal groups (3 parameters) use the lattice.
  - `headline.m:53` says "bracketed to 0.01 by searched boxes: alpha* is the largest box searched clean", which is not the lattice's definition. The same line claims scope too broadly (M2).
  - The bracketing paragraph (`headline.m:152`) does not mention the jump across breakpoints (M1).
  - The report never says that the Lipschitz estimate cannot see features narrower than a cell (3.2 T1/T1b).
- **m2.** `lattice.m:301` rethrows any `vital:badInput` raised inside pointFcn. One input error deep in the F-16 chain would abort a multi-hour run instead of marking the point ERROR (the other searches catch everything). Use a dedicated identifier for a malformed q (checkQ) and treat every other exception as an ERROR point.
- **m3.** Lattice cells whose vertices are all +Inf are certified (toy T5c). This is latent: the longitudinal F-16 margins are finite. Treat an all-Inf cell like a 'surrogate' case or leave it uncertified.
- **m4. Bracketing details** (`bracket.m:93`, `F16Evaluator.m:131-146`):
  - The sides theta x (1 +/- d) scale every parameter, including the held lateral ones and the parameters at a box edge, so a side can lie outside the box (by at most 1 %).
  - "Worse of two one-sided linearizations" is an engineering rule, not a bound for the switched system. That is fine, but it should be said once in the report.
  - The fresh confirmation (`assessAt`) is unbracketed. A CPV or arg-min within 1e-4 deg of a breakpoint at any IN point gives a NOT_OK confirmation, i.e. NOT_ASSESSABLE, never a silent pass. The probability is very small: no lattice CPV is preferentially near the breakpoint surface.
  - Proximity 0.01 deg is ample: the step study only fails within about 1e-4 deg (factor-10 steps from about 0.4 deg).
- **m5. No global lattice budget.** The cap is per group (ADR uq4-1). With 10 longitudinal groups the worst case is 10 x 6,000 points x their conditions.
  - From the corners, I expect 3 groups to refine: 3.2.2.1.1-CatA, 3.2.2.1.2-CatA (the breakpoint surface) and probably 3.2.2.1.2-CatB.
  - uq4's 10-20 h estimate is reasonable. M1 and M3 are the levers.
- **m6.** The Monte Carlo runs at the critical condition only, so its Clopper-Pearson bound is a per-condition success probability. That is contract, but it should be stated beside the verdict.
- **m7.** Test runtimes are above the 60 s guideline: tF16Uq 452 s, tUqR4bF16 115 s, tUqLattice 85 s, tRunF16Uq 56 s (coordinator gate XML). This was accepted earlier and is noted again.
- **m8.** `tests/M8/tF16Uq.m:120` still reads `reports/ctrl/f16_sas_suggestion.json`. The harness now copies reports, so sabotage runs are not vacuous, but the test depends on a mutable file. The M7 gains are pinned in tCtrlR3, so the risk is small.
- **m9.** `+vital/version.m` still reports 0.2.0-M4 (R3 m7, unresolved; every gate header shows it).
- **m10.** State the independence of Cm_basic and Cm_de (one table) as a JUDGMENT in the spec and report (4.5), and state the wings-level precondition of LonOnly and R4-9 (4.4).

### Verified, no finding
- **Verdict truth tables.** NOT_ASSESSABLE or NaN never becomes ROBUST in `verdict.m`: a NaN cpLower gives `lowP` true. The exception is S8Q-7, a hypothetical regression with no test.
- **Every path I traced turns failures into an honest status:**
  - a non-OK nominal point;
  - an error in pointFcn (except m2) or in confirmFcn;
  - a NOT_OK confirmation;
  - MOVING_LIMIT after MaxRounds;
  - the caps ('GRID');
  - an empty or NaN headline (`r.omitted`);
  - a failed lon/lat spot check (full box);
  - a failed R4-9 gate (`gatePlan`).
- **Cache keys** are %.17g of the full theta plus the condition, so no collisions.
- **The Nelder-Mead bound transform** z0 = asin(u) + 3, theta = lo + (hi - lo)(1 + sin(z - 3))/2 is an exact inverse pair. Its first simplex is no longer degenerate.
- **CSR stepping** (csr.m):
  - monotone by nesting;
  - a failing point inside a box called clean resets alphaLo (`csr.m:367`);
  - a ray beyond the cap bounds nothing (`csr.m:365`).
- **Lattice alphaLo <= alphaHi always:** a failing vertex makes every cell containing it uncertified.
- **The meets() rule** certifies R(alphaLo) itself.
- **The nominal-failing case** gives alpha* 0 and NOT_ROBUST.

## 6. Proposed sabotages (reports/work/R5/proposed_sabotages.json)
- **Method.** Every pattern occurs exactly once (checked with Python on the tree). Each case ran through `vital.test.runSabotageCase` on a copy, with reports copied minus reports/work.
- **Controls.** S8Q-4 is the positive control for tUqLattice; N-R5 is the null control.
- **Tree.** Unchanged after the run.
- **Results:** reports/work/R5/proposed_sabotages_result.txt.

| id | file | defect | targets | result | test to add |
|---|---|---|---|---|---|
| S8Q-1 | lattice.m `V.fail` | a point failing at an OK condition but not OK at another is not a counterexample | 8 tUqLattice methods | **NOT DETECTED** | 2-condition toy: c1 fails, c2 'NOT_CONVERGED' at the same points; box VIOLATED, CPV confirmed |
| S8Q-2 | lattice.m ROBUST_TO_CAP branch | ROBUST_TO_CAP although the cap arg-min confirmation fails | 5 tUqLattice methods | **NOT DETECTED** | confirmFcn that disagrees with pointFcn (fails at a candidate); expect NOT_ASSESSABLE |
| S8Q-3 | lattice.m `slopes` | mean instead of max over the parallel edges | 6 tUqLattice methods | **NOT DETECTED** | non-separable toy (e.g. m = c - s1 s2) where parallel edges differ; pin certificate.maxSlope |
| S8Q-4 | lattice.m `sl = max(own, NB)` | 3^d neighbourhood dropped | kinkedHiddenBand, +2 | DETECTED (positive control) | - |
| S8Q-5 | F16Evaluator.worseOf | NaN only on side B ignored | tUqBracket worseOfTwoSides, bracketedKnownShape; tUqR4bF16 bracketKnownCase | **NOT DETECTED** | add the mirrored row (side B NaN) to header 10 |
| S8Q-6 | F16Evaluator.rawSummary | S.de_deg takes the trim alpha | tUqR4bF16 bracketKnownCase, 2 tUqBracket | **NOT DETECTED** | pin S.de_deg of the known case (REG) and of a fresh evaluatePoint |
| S8Q-7 | verdict.m csrVerdict | NaN cpLower treated as adequate | tUqCsr verdictTruthTableR4, nominalFails; tMonteCarloVerdict verdictTruthTable | **NOT DETECTED** | R4 truth-table rows with cpLower NaN (expect NOT_ROBUST or NOT_ASSESSABLE, never ROBUST) |
| S8Q-8 | analyze.m latGate | runtime R4-9 gate tolerance 1e-9 -> 1e-2 | tUqStaged gateFallback, invarianceCheckToys; tUqR4bF16 stagedEndToEnd | **NOT DETECTED** | analyze with a Controller or spec where Cm_q does move a lateral margin (or an injected pointFcn), expect plan.latCheck.passed false and Cm_q searched |
| S8Q-9 | lattice.m confirmPoint | moving limit recognized only when the confirmation fails | tUqLattice movingLimit, +2 | **NOT DETECTED** | ML toy variant where c2 at the arg-min is smaller but positive and fails elsewhere |
| N-R5 | lattice.m comment | whitespace (null) | cornerFirstLinear, robustToCap | NOT DETECTED (correct) | - |

In every NOT DETECTED case the child ran every target and each one passed (per-target results in the result file).

## 7. Runtime and cost (dimension 6)
- **Gate.** The full gate is 2,853 s (coordinator), with M8 classes about 880 s of it (XML). The default paths of M6/M7 are bit-identical: the coordinator's gate shows M6/M7 green, and my loads isequal and legacy-equivalence checks are in 3.1.
- **Default run estimate (uq4, 10-20 h).** It is reasonable for the code as it stands. My breakdown:
  - base lattice 1331 x 6-10 union conditions, about 8-13k evaluations, 1.5-2.5 h;
  - 3 refining longitudinal groups x 12k evaluations, about 6 h;
  - 11 lateral groups, 3-7 h;
  - Monte Carlo under 1 h.
- **Biggest levers that do not weaken the guarantee:**
  1. ROBUST from R(1) certified (M3.1): 4-13x fewer lattice points on the toys.
  2. h/2 (M3.2): 2.4-3.0x.
  3. The piecewise certificate at breakpoints (M1). Without it, one group's whole cap is wasted for a NOT_ASSESSABLE.
  4. Resolution only on the judged shape (M3.3): up to 1.8x.
  - A further, untested lever: a Piyavskii-type bound that uses all vertex values instead of the minimum vertex, e.g. (m_a + m_b)/2 - L h/2 in 1-D. It is valid under the same assumption and tighter wherever the vertex values differ.
- **Report size.** r4bsmoke.json is 1.26 MB for 3 groups, so a full run is about 8-10 MB (the stored default is 9 MB). Acceptable (R3 m5 deferred); consider a separate `_points.json`.

## 8. Recommendation
- **M8 should not be closed yet. Order:**
  1. Decide on M1 (piecewise certificate or explicit acceptance), M3.1-M3.2 (verdict from R(1), h/2) and M5 (band evidence or acceptance).
  2. Fix the report text (M2, m1).
  3. Add the tests for S8Q-1/2/5/7 (at least) and register the sabotages.
  4. Rename the stale default report.
  5. Re-run the gate and sabotages on a quiet tree.
  6. Run the default `run_f16_uq` (B1) and pin its headline.
- **No number in the current smoke results is wrong:**
  - the 3.2.2.1.1-CatA NOT_ROBUST is real: R(1) corner -0.062 at a fresh assessment, physically explained;
  - the lateral ROBUST results are consistent with their CSR evidence.

## 9. Not verified
- I did not re-run the full M0-M8 gate or the registered 33 M8 sabotages (I accept the coordinator's results). I ran a subset of classes (2.1).
- I did not run the default `run_f16_uq`, or any 3-D F-16 lattice. The 3-D prediction for 3.2.2.1.2-CatA (M1) is extrapolated from the 1-D lattice and the corner and line scans.
- The jump sizes were measured on one line at one condition. The 3-D geometry of the alpha = 5 surface inside R(3) was not mapped.
- The F-16 candidate-gap check covers corners of R(1) and R(2) only, not interior points or R(3).
- The stage-1 versus stage-2 error of the hybrid search (M5) was not measured.
- The Piyavskii-type bound is a suggestion and was not implemented or measured.
- No run was made without `startup_vital` (exit criterion 1).
