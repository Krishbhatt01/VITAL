# CHANGELOG fragment (uq4, 2026-10-14): M8 amendment R4b

## Implemented (docs/PLAN_M5_M8.md, "Amendment R4b")
- **R4-3 corrected:** `vital.uq.lattice`, ONE shared adaptive lattice for the longitudinal groups (dimension <= 3) over the AlphaMax box of the judged shape.
  - Each (point, condition) is evaluated once; one pointFcn call gives every group's margin. The results are reused by both shapes, every CSR alpha and every width box.
  - Certificate per cell: min vertex - sum L_i h_i, with L = 2 x the measured local slopes (own edges + the 3^d base neighbourhood).
  - Refinement only near the zero level set: uncertified cells that can still move alpha*, anisotropic.
  - Caps: MaxLevel 10 per axis; MaxPoints per group (20000 default, 6000 in analyze / run_f16_uq).
  - Per box: OK / VIOLATED / NOT_ASSESSABLE ('GRID'). alpha* is read from the lattice to 0.01, with the CPV confirmed by a fresh assessment and the moving-limit rule.
  - `analyze` uses it for every longitudinal group (plan.method 'lattice'); with a judged half-width below 10 % it falls back to vital.uq.searchMethod.
- **R4-7:** `vital.uq.breakpoints` (parsed from the generated aero.m) and `vital.uq.bracket` (eligibility, d = 1e-3 up to 1e-2, straddle + both OK, physical failures never bracketed).
  - `F16Evaluator`: option 'Bracket' (default true); worse of the two sides (`worseOf`); label BRACKETED; both values listed in E.bracketed / r.bracketed / the report.
- **R4-8:** `vital.uq.stageBudget` (stage 1: NumCandidates 2, DE 8 x 4, N 200 unchanged) and `vital.uq.stagePlan` (bracket overlapping [0.8, 1.2] or a budget NOT_ASSESSABLE; lattice groups never).
  - `analyze('Staged', true)`: run_f16_uq's default. The report column "decided by" and g.stage give the deciding stage.
- **R4-9:** `searchPlan('LatDropCmq', true)` (mode 'lateral', plan.dropped).
  - Runtime gate `vital.uq.invarianceCheck` at the critical condition with fallback `vital.uq.gatePlan`.
  - Class gate tUqR4bF16#lateralInvarianceCmq: worst deviation 9.4e-15 against a 1e-9 limit.

## Files
- **New:**
  - code: +vital/+uq/lattice.m, bracket.m, breakpoints.m, stagePlan.m, stageBudget.m, gatePlan.m, invarianceCheck.m
  - tests: tests/M8/tUqLattice.m, tUqBracket.m, tUqStaged.m, tUqR4bF16.m, sabotages_uq4.json
- **Changed:**
  - code: +vital/+uq/F16Evaluator.m, analyze.m, searchPlan.m, headline.m, writeReport.m; run_f16_uq.m
  - tests/M8/tUqR4F16.m: header 5c "plan.method 'grid'" marked SUPERSEDED BY R4b, and its assertion replaced by a comment; the replacement is tUqR4bF16 header 3d.
  - tests/M8/tF16Uq.m and tUqR3Report.m: their analyze calls add 'LatDropCmq' false (they keep the R3 design); header notes added; expectations unchanged.
  - tests/M8/sabotages_uq3.json: S8W-2 gets the extra target tUqR4bF16/nonLatticeEqualShape (see below); pattern unchanged.

## Gates
- **RED:** reports/work/uq4/M8_red_uq4.txt.
  - TOTAL 633, PASS 603, RED_EXPECTED 29, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 1, REGRESSION 0, EXCLUDED 0; GATE OK; 2350 s.
  - The one VACUOUS test, tUqR4bF16#lateralInvarianceCmq, is the R4-9 gate itself: a property of the existing chain that justifies the new plan, so it passes before the implementation by design.
- **GREEN:** reports/work/uq4/M8_green_uq4.txt. TOTAL 633, PASS 633, FAIL 0, EXCLUDED 0, VACUOUS 0, REGRESSION 0; GATE OK; 2769 s.
- **After GREEN:** tUqR4bF16 header 3g and the new method #nonLatticeEqualShape (header 4) were added; see "Sabotage coverage" below.
  - tUqR4bF16 and tUqR4F16 were re-run on their own: all 4 + 5 tests pass (nonLatticeEqualShape 50 s).
  - The full GREEN gate was NOT re-run after this addition (one new passing test). The coordinator's quiet-tree gate will include it.

## Sabotages
- **uq4 part (8):** reports/work/uq4/M8_sabotage_uq4.txt. S8X-1..8 8/8 DETECTED, tree unchanged.
- **All M8 parts, first run** (04:58): S8W-2 NOT DETECTED.
  - Cause: tUqR4F16#endToEndCsr's 1-parameter longitudinal group now runs on the lattice, whose equal shape is built on another line, so the sabotaged non-lattice line was no longer reached.
  - A first fix (tUqR4bF16#stagedEndToEnd, header 3g) still did not detect it, because that test's lateral group searches only Cn_r, whose sigma is 0.10 = EqualPct.
  - Final fix: the new test tUqR4bF16#nonLatticeEqualShape (Cm_de, sigma 0.05, 'Lattice' false: csr.equal.m = 0.10 exactly) is added as an S8W-2 target. A new sabotage S8X-9 covers the same bug on the lattice line.
- **All M8 parts, final run** (08:54): reports/work/uq4/M8_sabotage.txt. 33/33 DETECTED (S8R-1..8, S8U-1..5, S8V-1..4, S8W-1..7, S8X-1..9), tree unchanged 1, all detected 1.

## Evidence (pre-registered outcomes)
- **tUqLattice (toys, exact alpha*):**
  - LIN corner-first: judged alpha* 2 and equal 36/13, both bracketed to 0.01 with the CPV at the corner.
  - KINK, a hidden band found only by refinement: 1.45 / 1.45.
  - CAP: ROBUST_TO_CAP, exactly 1331 points.
  - LIP: L = [0.4 0.5 0.4] and bound 0.08 exactly.
  - NOM: alpha* 0. ML: c2 added, alpha* 2. NONOK: alphaLo 1.8 exactly. Caps: GRID.
  - Shared lattice (3 groups, 2 conditions): no (theta, condition) evaluated twice; the 1331 base points once at each condition; box queries at 12 alphas x 2 shapes x 3 groups add 0 calls; shared results isequaln single-group results.
  - Point counts to 0.01 (both shapes): LIN alone 18,999 lattice points, KINK alone 18,026.
- **tUqBracket:** every row as pre-registered.
- **tUqR4bF16#bracketKnownCase** (13,000 ft / M 0.45 / CG 20 %, the R4 smoke point):
  - Unbracketed: NOT_CONVERGED at linearize, alpha 5.000036.
  - Bracketed at d = 1e-3, side alphas 5.000692 / 4.999388.
  - 3.3.1.1-CatA-other L1 side margins 1.0366 (theta x 0.999) and 1.0358 (theta x 1.001); the point's margin is exactly 1.0358, the worse side.
  - 3 point evaluations.
- **tUqStaged:** truth tables as pre-registered.
- **tUqR4bF16#stagedEndToEnd:**
  - The lateral group (Cn_r) is re-run in stage 2 (1 -> 2 candidates).
  - The longitudinal group (Cm_q) is decided by the lattice in stage 1; the CPV is re-checked independently.

## F-16 lattice cost (measured; scratch probe = the code of the tree)
- Setup: vital.uq.analyze on 3.2.2.1.1-CatA alone, NumCandidates 2, N 20, LatticeMaxPoints 6000.
- The lattice used 5,994 points (cap reached): 11,987 single-point evaluations, 3 confirmations, 7,860 s (about 0.66 s per evaluation, run beside the GREEN gate).
- judged: NOT_ASSESSABLE ('GRID'), alpha* in [0.3375, 0.4875]. The CPV at 0.4875 is confirmed (margin -0.00147), so the verdict is NOT_ROBUST (a confirmed CPV inside the judged box).
- equal: alpha* in [0.626, 0.911] (6.3-9.1 %).
- x1 box: VIOLATED, -0.0374 at theta (Cm_q 0.845, Cm_basic 1.137, Cm_de 0.863).
- Consistent with uq3's hybrid R4 smoke result (judged alpha* 0.443, equal 0.81; uq3's x1 value -0.0624 lies in the corner, which this lattice resolves at only 4,578 points inside R(1)).
- With the literal certificate, the lattice did not close the bracket to 0.01 within 6,000 points per group.

## Smoke run (reduced; reports/uq/f16_uq_r4bsmoke.json/.md)
- **Command:** run_f16_uq('Groups', {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other', '3.3.1.3-CatA'}, 'Label', 'r4bsmoke', 'NumCandidates', 3, 'NumLHS', 8, 'NumStarts', 1, 'MaxEvals', 120, 'DEPopulation', 8, 'DEGenerations', 4, 'N', 60, 'LatticeMaxPoints', 3000), staged (the default).
  - Stage 1: NumCandidates 2, DE 8 x 4, N 60. Stage 2: NumCandidates 3.
  - N = 60 is the smallest N whose Clopper-Pearson bound can reach 0.95 (60/60 gives 0.9513).
- **Runtime:** 6,869 s; 9,284 single-point assessments, 48 cache hits, 13 full assessments.
  - It ran beside the all-M8 sabotage run. An earlier attempt was killed when the session ended and was re-run from scratch.
- **Shared lattice, 3.2.2.1.1-CatA:** 2 conditions; 2,993 lattice points (cap 3,000 reached); 5,985 point evaluations; 3 confirmations; 4,288 s (0.72 s per evaluation).
- **Headline:**
  - **3.2.2.1.1-CatA: NOT_ROBUST** (decided by stage 1, lattice).
    - x1 box VIOLATED, -0.0374.
    - CSR judged NOT_ASSESSABLE ('GRID', cap reached) with alpha* in [0.22, 0.60]. The CPV at 0.60 is confirmed (margin -0.00608 at 13,000 ft / M 0.45 / CG 30 %), so alpha*(judged) < 1 is established. Equal shape: in [4.6 %, 9.1 %].
    - MC 60/60 (CP 0.9513).
  - **3.3.1.1-CatA-other: ROBUST** (stage 1; bracket [2.75, 2.76] does not overlap [0.8, 1.2]).
    - CSR judged alpha* 2.75 (OK; CPV at 2.76 confirmed, margin -0.00248). Equal ROBUST_TO_CAP (>= 30 %).
    - x1 0.9025 OK; MC 60/60.
    - R4-9: searched without Cm_q, gate passed.
    - In the R4 smoke (uq3) this group was NOT_ASSESSABLE because of the breakpoint point (FC-950). In this run the search found no NOT_CONVERGED point, so R4-7 was not exercised (BRACKETED points: 0); it is shown on the known point by tUqR4bF16#bracketKnownCase.
  - **3.3.1.3-CatA: ROBUST** (stage 1; bracket [1.80, 1.81]).
    - Surrogate search: CSR judged alpha* 1.798 (OK; CPV at 1.81 confirmed, margin -0.00275 at 5,000 ft / M 0.55 / CG 20 %). Equal ROBUST_TO_CAP.
    - x1 Inf OK (stable spiral over the box); MC 60/60.
  - **Stage 2 re-ran no group** (no lateral bracket overlapped [0.8, 1.2]; no budget NOT_ASSESSABLE).

## Runtime estimate of the staged full default run (not run)
Rough, single uncontended MATLAB, about 0.4-0.7 s per closed-loop single-point evaluation:
- **Lattice (longitudinal groups, stage 1 only).**
  - Base: 1,331 points x the union of the groups' stage-1 candidate conditions (2 per group; about 6-10 distinct), i.e. 8k-13k evaluations.
  - Each group whose zero level set lies inside the cap box refines up to the cap: 6,000 points x 2 conditions, about 12k evaluations, 1.5-2.5 h per group.
  - 3.2.2.1.1-CatA does (measured: 5,994 points in 7,860 s at the 6,000 cap, still NOT_ASSESSABLE 'GRID' because the literal certificate needs more points). Assuming 2-4 such groups: 4-10 h.
- **Lateral groups (about 11), stage 1:** about 15-40 min each at the default NumLHS 32, DE 8 x 4 and Nelder-Mead 2 x 150 (the smoke measured 15 min per group at its reduced budget): 3-7 h.
- **Stage 2:** only groups whose bracket overlaps [0.8, 1.2] or are FC-901, at the full budget (about 40-60 min each); likely 0-4 groups: 0-4 h.
- **Monte Carlo:** 200 x about 19 groups, at the critical conditions: under 1 h.
- **Total:** about 10-20 h, dominated by the lattice. The longitudinal groups whose alpha* lies inside the cap will mostly end NOT_ASSESSABLE ('GRID'), with a bracket and, as for 3.2.2.1.1-CatA, possibly a confirmed CPV (then NOT_ROBUST). Resolving them to 0.01 would need either a larger LatticeMaxPoints (about 10k-20k per group, from the toys, i.e. hours more per group) or the geometric certificate (h/2), which is a coordinator decision.
