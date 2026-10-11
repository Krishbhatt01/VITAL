# Proposed ADR-033 (agent uq2, 2026-10-09): M8 amendment after review R3, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment after review R3"). These are the choices where it left room.

### uq2-1: Moving limit, re-search (R3-M4)
- `vital.uq.boundWorst(..., 'MaxRounds', 3)`. A **round** = one full search (centre, earlier arg-mins as phase 'previous', 2^d corners, LHS, fmincon) followed by one confirmation. "At most 3 rounds" = at most 3 searches.
- If the confirmation moves (status OK and margin < the round's search value), the moved condition (`c.cond`, which confirmFcn must now return to allow a re-search) is added to the candidates, and the round's arg-min theta is re-evaluated first in the next round, so the moved condition is seen where it was found.
- Stop when: the confirmation does not move (settled); any round has a counterexample (definitive, no further rounds); MaxRounds is reached; confirmFcn returns no `cond`; or the moved condition is already a candidate (the point evaluation and the confirmation disagree). In the last three cases the status is `NOT_ASSESSABLE` with a reason starting `MOVING_LIMIT`, and the confirmation value replaces the search value (as before).
- `OK` needs all of these: every point of the final round OK, no non-OK point in any earlier round, every start of the final round converged, and a final confirmation that is OK and did not move.
- New fields: `bw.rounds` (round, candidates, nEvaluated, searchValue, theta, cond, record, converged, nNonOK, nViolating, confirmation), `bw.nRounds`, `bw.conditions/condLabels` (the final candidates), `bw.condition` (the arg-min's condition object), `bw.points.condIndex`. `bw.points` is the final round's point set.

### uq2-2: Longitudinal-only search (R3-M3(a))
- `vital.uq.searchPlan` gives mode 'longitudinal' to groups whose name starts with `3.2.` when `LonOnly` is true (the default). The searched parameters are the AeroScale fields in `LonFields` = {Cm_q, Cm_table} that are present in the box; if none is present, the mode is 'full'. Parameters are chosen by AeroScale field, so `uq/f16_uncertainty.json` is unchanged.
- The gate is tests/M8/tUqR3F16.m#lonLatInvariance: 3 IN conditions x lon {1, x1.5 lower corner} x 4 lateral corners of the x1.5 box. Every longitudinal metric must agree within 1e-9 relative; the measured worst deviation is 3.8e-14.
- `vital.uq.analyze` adds a runtime spot check at the group's critical condition: the margin with the lateral multipliers at the widest box's lower corner must equal the nominal one within 1e-9 relative. If it does not, the full box is searched and the plan says so.
- The result is reported over all six parameters (`bw.theta`, `bw.points.theta` and `bw.rounds.theta`, with the held parameters at 1), plus `bw.searchNames/searchIndex`. The `bw.optimizer` starts stay in the searched coordinates.
- The Monte Carlo is unchanged and still samples all six parameters; its samples of the first two parameters are identical either way.

### uq2-3: Surrogate search of +Inf groups (R3-M3(b))
- Mode 'surrogate' applies when the nominal in-envelope margin is +Inf and every metric of the group is `spiral_T2_s`. It searches all parameters.
- The surrogate is the real part of the mode the classifier names 'spiral' (`vital.linear.modes`, via `res.points.info.modes`). It is kept in the cached point summary (`S.spiralRe`).
  - If a point has no single 'spiral' mode, it is non-OK ('NO_SPIRAL').
  - The metric's fallback root is NOT used as a surrogate.
- `vital.uq.surrogateWorst(problem, marginFcn)` is generic. It runs boundWorst on -s with Reserve -Inf: the surrogate itself never "violates", and its moving limits are re-searched like margins. The confirmation is a fresh in-envelope assessment, taking the largest spiral Re over the IN points.
- Mapping to the true margin:
  - s_max <= 0: value +Inf. The status is OK (when the surrogate search is OK), with the reason "stable over the box (surrogate search) ...".
  - s_max > 0: the true margin at the arg-max (theta, condition). The status is VIOLATED if that margin is below the reserve, else the surrogate search's status.
  - No finite s anywhere: NOT_ASSESSABLE.
- The candidates and the Monte Carlo condition (the critical condition) are ranked by the surrogate, most unstable first (`F16Evaluator.inEnvelopeSurrogate`, `F16Evaluator.candidates`).

### uq2-4: "Sampled only" (R3-M2)
This is a label, not a verdict change. It applies when any metric has unit '0/1' (vital.fq.metricNames; 3.3.1.4), or when every evaluated margin is equal (flat).

### uq2-5: Kinked toy (R3-M2)
- R3 called it a "min-of-two-planes valley". A minimum of two planes is a ridge whose box minimum is at a vertex. So the interior V was built as the larger of two planes meeting along u1 = 0.3, which is the shape R3 found for 3.2.2.1.2-CatA.
- Pre-registered and observed: NOT_ASSESSABLE / FC-901. sqp exhausts 60 evaluations at the crease, with value 0.10024 against a true minimum of 0.10. Shifted below zero, the result is VIOLATED.

### uq2-6: Mahalanobis, coverage (R3-M5, m2)
- `vital.uq.mahalanobis` gives D in the x1 (judgment) sigmas, and the tail P(chi2_k >= D^2) with k = the number of searched parameters (2 for longitudinal groups, as in R3 3.5).
- `vital.uq.boxCoverage` gives prod erf(k_g/sqrt2) = 0.9707. It is identical at every width, because the box and the Monte Carlo sigma scale together.

### uq2-7: Effective CG-derivative ratios (R3-M5; tests/M8/tUqR3F16.m, bare trim 13,000 ft / M 0.45 / CG 30 %)

| multiplier (value) | effective CG-derivative ratio |
|---|---|
| Cm_table (0.8712) | M_alpha,cg x 1.0407 (note: above 1), M_de,cg x 0.8761 |
| Cm_table (1.1288) | M_alpha,cg x 0.9593, M_de,cg x 1.1239 |
| Cl_table (0.8483) | L_beta,cg x 0.848257 (exact) |
| Cnr_table (0.6965) | N_r,cg x 0.7100 |

At this condition the MRC part of M_alpha is destabilizing (A/(A+B) = -0.316). Scaling cmt down therefore makes M_alpha about the CG MORE stable, while it cuts elevator power by 12 %. The coupled Cm_table perturbation is not "less static stability". Accepted and documented (amendment R3-M5).

**Evidence.** tests/M8/tUqR3Fixes.m, tUqR3F16.m, tUqR3Report.m, tBoundWorstToys.m (3'), tF16Uq.m (9, m1 guard).
