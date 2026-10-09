# M8 (agent uq): open issues, doubts, deviations

## Deviation from the plan
1. **AeroScale field `Cnr_table`, not `Cn_r`** (proposed ADR uq-1). `tests/M6/tAeroScale.m#badAeroScaleRejected` asserts that `config('AeroScale', struct('Cn_r', 0.5))` is `vital:badInput`; adding a field named `Cn_r` would make that M6 test a REGRESSION, and an M8 agent may not edit it. The parameter is still called `Cn_r` in the spec and reports. The coordinator can rename it after changing the M6 test's unknown-name example.

## Failed hypotheses (recorded in the test headers; tolerances and original text kept)
- tUqSpec 3a: k_g literals typed with 13 digits checked at 1e-15 abs (test-design error, the literals are truncated); corrected to full-precision closed forms.
- tUqSpec 3b: "fraction of samples inside the group box >= 0.99" is wrong for d = 1, where the 99 % interval IS the box (observed 0.98991); corrected to the exact box probability erf(k/sqrt2)^d +/- 4 standard errors.
- tF16Uq 5b: "|d margin(3.3.1.1-CatA-other)/d Cm_table| <= 1e-6 (lon/lat decoupling)" failed (0.0298). Cm_table scales the whole MRC table cmt, which is non-zero at the trim (it balances the normal-force moment about the CG), so it moves the trim alpha and with it the lateral derivatives. Corrected to Cm_q (zero at a q = 0 trim): measured -1.7e-14.
- tClopperPearson 6 was corrected BEFORE the RED run (not a failed hypothesis of the implementation): my first header said x = 195/200 meets 0.95; an independent scipy computation while writing the header gave 196 (0.95482) and 195 (0.94816).

## Things to know about the results
- **3.2.2.1.1-CatA (CAP) at x1 is VIOLATED (bound-worst -0.0059)** while all 200 Monte Carlo samples hold Level 1 (CP lower 0.985). The verdict is NOT_ROBUST from the bound-worst side only. This is exactly the case the plan's two-sided verdict is built for: the 99 % box reaches parameter combinations a 200-sample MC rarely visits.
- Groups whose margin is +Inf at every sampled point (3.3.1.3 spiral T2 of a stable spiral) cannot be optimized: fmincon is not run from a +Inf start, the start counts as not converged, and the bound-worst status is NOT_ASSESSABLE (FC-901). In the default run this happens for 3.3.1.3-CatA/CatB at x0.5 and x1. At x1.5 some box points make the spiral divergent with a finite T2, the search runs, and the confirmation catches a MOVING LIMIT (5,000 ft / Mach 0.55 / CG 20 %, margin 0.953 CatA and 0.172 CatB instead of the search values 1.79 / 0.675): verdict ROBUST at x1.5 while x1 is NOT_ASSESSABLE. That ordering looks odd but is honest. A surrogate objective (e.g. the spiral root itself) would be needed to search a +Inf group; not built.
- 3.2.2.1.2-CatA x1 and -CatB x1/x1.5 are NOT_ASSESSABLE because fmincon exhausted its 60-evaluation budget (FC-901); 3.2.2.1.2-CatB x1 also has 2 of 217 points whose linearization did not converge (FC-510 step-study, in the box at Cm_q 0.74). No counterexample there; the Monte Carlo is 200/200.
- Groups with margin exactly 0 everywhere (3.3.1.4 prohibition records) give bound-worst 0 >= reserve 0: OK if the optimizer converges on the flat objective.
- The candidate set is the critical condition plus the next 3 in-envelope conditions of the NOMINAL aircraft; the confirmation over all 30 IN points is what protects against a moving limit (and it is reported when it happens).
- The F-16 test (tF16Uq) runs with a reduced budget (stated in its header) and takes about 10 minutes, at the upper end of the brief's limit. The 64 corners are the dominant cost and are fixed by the plan.
- The default run_f16_uq run took 5,379 s (about 90 min, partly concurrent with the GREEN gate): 9,583 single-point closed-loop assessments, 31,301 cache hits, 58 full assessments (no Parallel Computing Toolbox); evaluations are cached by (theta, condition) and shared between groups, which is what makes the duplicate CatA/CatB groups cheap.
- MC samples and box: the box bounds the 99 % ellipsoid PER GROUP; the joint 6-parameter box therefore covers about 0.99^2 x 0.995^2 ~ 0.97 of the joint normal at x1. Samples outside the box are flagged (mc.inBox) and still counted in the Monte Carlo.

## Unverified / assumptions
- fmincon convergence (exit flag > 0) on a nonsmooth objective (min over conditions and records) is taken at face value; exit flag 2 (step below tolerance) counts as converged.
- The finite-difference step 1e-3 (relative) for fmincon is a choice; its bias on the toy quadratic is ~2e-5 in margin.
- No published uncertainty exists for the NESC F-16 aero tables; all widths are JUDGMENT and every report says so.
