## ADR-034 (proposed; agent uq3, 2026-10-13): M8 amendment R4, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment R4: judgment-light robustness", R4-1..R4-6). These are the choices where it left room, and one contract inconsistency.

### uq3-1: CSR algorithm: bisection on alpha with the box searches (R4-1)
- **Decision.** `vital.uq.csr` brackets alpha* between box searches ("clean" / "failing") and refines every failing point along its ray from the nominal. Not the direct form (min ||p - pbar||_inf,m subject to margin(p) <= 0).
- **Why.**
  - The direct form only returns a failing point, i.e. an UPPER bound on alpha*. Claiming alpha* to +/- 0.01 also needs the box just below to be free of failures, which is a box search anyway. The bisection backs both ends with evidence: the lower end by a box searched clean (grid-certified or hybrid search estimate), the upper end by a failing point confirmed by a fresh in-envelope assessment.
  - It reuses everything the bound-worst already has: the grid certificate (R4-3), the hybrid search (R4-4), the moving-limit confirmation (R3-M4), the evaluator cache, and the x1 bound-worst result as a prior.
  - The scaled infinity norm is homogeneous, so a ray bisection from the nominal to a failing point (one point evaluation per step, not a box search) moves the upper end to the first sign change on that ray. For margins where the box corner touches first, the ray of the cap search's arg-min IS the CPV direction, and the bracket closes with one more box search (tests/M8/tUqCsr.m: K1, K2, K6 need 2 box searches).
- **Details.**
  - alphaStar := alphaLo, the largest box searched clean; alphaHi := the scaled norm of the CPV; OK means alphaHi - alphaLo <= 0.01 and a confirmed CPV.
  - Steps: the cap box R(3) first (clean: ROBUST_TO_CAP); then the box at alphaHi - 0.01 ("optimistic"), and after two consecutive failed optimistic steps the bisection midpoint; at most MaxSearches = 15 box searches per shape.
  - The nominal failing gives alpha* = 0 with CPV = the nominal.
  - DecideAt = 1 for the judged shape: if the bracket straddles 1 the box R(1) is searched, so "alpha*(judged) >= 1" is always decided by a search of exactly the judged box.
  - Priors: the x1 bound-worst result is the judged shape's prior; every judged search and the judged CPV are the equal shape's priors. A clean prior box that contains R(a) gives alphaLo >= a, and a prior failing point gives alphaHi <= its norm. If the judged cap box is clean, the equal shape is ROBUST_TO_CAP without a search (3 x k_g sigma >= 0.30 for every parameter).
  - Candidate conditions: the CSR keeps every condition its box searches added (moving limits). The CPV confirmation applies R3-M4: if its critical condition is not a candidate and its margin is smaller, the condition is added, the largest clean box is searched again, and after MaxRounds = 3 rounds the status is NOT_ASSESSABLE (MOVING_LIMIT).
  - A cap box that cannot be decided gives NOT_ASSESSABLE; the DecideAt boxes are still searched, so alphaLo is reported as a lower bound.
- **Evidence.** tests/M8/tUqCsr.m (11 tests, 9 known-answer cases).

### uq3-2: R4 verdict: "alpha*(judged) < 1 with a confirmed CPV" (R4-2)
- NOT_ROBUST when cpvConfirmed and alphaHi <= 1 (a confirmed failing point inside the closed judged box), or when the Clopper-Pearson lower bound is below 0.95. This holds even when the bracket was not resolved (CSR NOT_ASSESSABLE): a confirmed counterexample inside the judged box is definitive, as for the bound-worst.
- ROBUST when the CSR is OK with alphaStar >= 1, or ROBUST_TO_CAP, and the CP lower bound is >= 0.95. Anything else is NOT_ASSESSABLE.
- `vital.uq.verdict` dispatches on its first argument: a CSR result (field alphaStar) gives the R4 headline verdict; a bound-worst result gives the original box verdict. The box verdict is still reported per width (r.groups.widths.verdict) beside the headline (r.groups.verdict). The R3 truth tables (tMonteCarloVerdict, tUqR3) are unchanged.

### uq3-3: Grid certification (R4-3)
- The grid is an integer lattice on the box coordinate t = (theta - lo)/(hi - lo): 11 points per dimension, refined by halving down to 1/2^8 of the base spacing, so keys are exact and the box corners are on the grid.
- Local refinement around the minimum: the cells touching the best lattice point are halved three times (GridLocalLevels).
- Lipschitz estimate: per axis i, L_i = 2 x the largest |dm|/dt_i over every grid edge ever evaluated (a running maximum, so refining never lowers it). Cell bound = min(vertex margins) - sum_i L_i dt_i / 2: every point of the cell is within dt_i/2 of a vertex along each axis (separable Lipschitz bound).
- Cells whose bound is below the reserve are halved and the slopes re-measured, until:
  - certified (OK);
  - a grid point violates (VIOLATED);
  - a grid point is not OK (NOT_ASSESSABLE);
  - the finest spacing or the GridBudget (5000 lattice points; 2000 in vital.uq.analyze) is reached (NOT_ASSESSABLE, reason starting 'GRID').
- The label is always 'grid-certified (Lipschitz estimate)': the slope bound is an estimate from measured secants, not a proof.
- Evidence: tests/M8/tUqGridCert.m. The uq2 kinked valley (FC-901 under sqp) is now certified OK.

### uq3-4: Hybrid search (R4-4)
- **Global stage:** `vital.uq.diffEvolution`, DE/rand/1/bin (Storn and Price 1997), F 0.7, CR 0.9, seeded with Seed + 1. Its initial population is the round's LHS points (no extra cost), topped up with seeded uniform points if needed.
  - Bounds: a component is reflected at the bound it crossed, and drawn uniformly if it is still outside, so every point lies in the box.
  - The budget is fixed (no early stop). Convergence (the population spread) is reported, not required.
- **Local stage:** `fminsearch` from the NumStarts best distinct points of all earlier stages, on z with theta = lo + (hi - lo)(1 + sin(z - 3))/2, budget MaxEvals per start, TolX (in z; 1e-3 in boundWorst, 1e-2 in vital.uq.analyze) and TolFun 1e-4.
  - The offset 3 was found necessary during the implementation. fminsearch's first simplex is 5 % of each non-zero component but only 0.00025 for a zero one, so a start at the exact centre (z = 0) stopped at once with "converged". The offset gives first steps of 0.07-0.23 rad (regression test tUqHybrid#centreStartDoesNotStopAtOnce).
  - A point that is not OK is +Inf to Nelder-Mead.
- **Status:** OK needs every Nelder-Mead start to end with exit flag 1; otherwise FC-901 (as for sqp). The stage table (bw.stages) lists each stage's points and convergence.
- **Measured cost:** at a vertex optimum the sin transform is flat. Nelder-Mead needs about 60-140 evaluations in 3-D and about 140-400 in 7-D to meet the tolerances (scratch characterization with MATLAB's fminsearch; failed hypothesis tUqHybrid 2).
- Evidence: tests/M8/tUqHybrid.m.

### uq3-5: Method rule and the R4-3 / R4-5 inconsistency (DEVIATION NOTE)
- `vital.uq.searchMethod(d)`: 'grid' for d <= GridMaxDim (2) searched parameters, 'hybrid' above. The rule goes by the number of SEARCHED parameters, as R4-3 ("groups searched over 2 parameters") and R4-4 ("more than 2 parameters") state it.
- **Inconsistency.** R4-3 calls the 2-parameter groups "(longitudinal)", but R4-5 makes the longitudinal search {Cm_q, Cm_basic, Cm_de}, i.e. 3 parameters. With the R4 spec, no default F-16 group has <= 2 searched parameters, so every group is searched by the hybrid method and R4-3 is exercised only by the toys and by tUqR4F16#endToEndCsr (a 1-parameter spec).
- `vital.uq.analyze('GridMaxDim', 3)` grids the longitudinal groups instead. Its cost is 11^3 = 1331 lattice points per box before refinement, times 4 candidates. The coordinator decides; nothing in the contract was changed.

### uq3-6: Cm_basic / Cm_de (R4-5)
- loads.m evaluates the generated model a second time with el = 0 (the same alpha, beta, rates and Mach), but only when Cm_basic or Cm_de is not 1. Then:
  - cmt <- Cm_basic cmt0 + Cm_de (cmt - cmt0)
  - then the legacy Cm_table multiplies the result
  - cm = cmt + cq2v Cm_q cmq
- With both at 1 the block is skipped, so the generated model and the R3 Cm_table path are bit-identical (tUqR4F16#splitPitchingMomentTable, #defaultPathAndRename; tAeroScaleUq).
- Spec v2 (`f16_uncertainty_v2`): pitchStatic = {Cm_basic, Cm_de}, sigma 0.05 each, d = 2, so k_g = 3.0349 and the x1 half-width is 0.1517 (was 0.1288 for Cm_table).
- The joint x1 box coverage becomes 0.97579 (was 0.97070).
- The term labels are 'cmt(el=0)' and 'cmt-cmt(el=0)'.

### uq3-7: R3-era tests pinned to the R3 design
- tF16Uq and tUqR3Report test the R3 design's numbers: Cm_table, sqp, the x0.5/x1/x1.5 widths, and the CAP corner -0.0058793. They now run it explicitly on an embedded v1 spec (Cn_r field), with 'Method' 'sqp' and 'CSR' false. Their expectations are unchanged.
- tRunF16Uq and tUqR3#monteCarloSigmaScalesWithWidth add 'Method' 'sqp' and 'CSR' false to keep their runtime.
- tUqR3F16#lonLatInvariance builds the R3 x1.5 box from the R3 table.
- The R4 design on the F-16 is tested in tests/M8/tUqR4F16.m.

### uq3-8: Default budgets of vital.uq.analyze / run_f16_uq (stated in the header and the report)
- WidthScales 1.
- NumLHS 32, NumCandidates 4, MaxRounds 3, N = 200, seed 2026: unchanged.
- grid: 11 points, 3 local levels, 8 refinement levels, 2000 points.
- hybrid: DE 16 x 8, then Nelder-Mead from 2 starts x 150 evaluations, with TolX 1e-2 in z (about 0.5 % of the box in the interior and finer near a bound) and TolFun 1e-4.
- CSR: AlphaMax 3, resolution 0.01, EqualPct 0.10, MaxSearches 15.
- MaxEvals is 150, not 60: measured from a 7-D vertex start, Nelder-Mead needs 92 evaluations with TolX 1e-2 and 142 with TolX 1e-3. With 60, every 7-D box would be FC-901.
