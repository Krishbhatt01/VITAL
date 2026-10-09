# Proposed ADR-032: Uncertainty analysis (M8; agent uq, 2026-10-07)

The M8 design itself is the coordinator's contract (docs/PLAN_M5_M8.md, "M8 uncertainty"). The decisions below are the agent's choices where the plan left room, and one deviation.

### ADR-0xx (uq-1): AeroScale field `Cnr_table` for the plan's parameter `Cn_r` (DEVIATION)
- **Context.** The plan names the new AeroScale field `Cn_r` (scales `cnr`). `tests/M6/tAeroScale.m#badAeroScaleRejected` uses `'Cn_r'` as its example of an UNKNOWN multiplier and must keep raising `vital:badInput`; an M8 agent may not edit M6 tests.
- **Decision.** The field is `Cnr_table` (consistent with `Cnt_table`, `Cm_table`, `Cl_table`: "scale the NASA table X"). The uncertainty parameter keeps the plan's name `Cn_r`; `uq/f16_uncertainty.json` maps it (`"name": "Cn_r", "aeroScale": "Cnr_table"`), and every report prints both.
- **To undo.** If the coordinator prefers `Cn_r`, change the unknown-name example in tAeroScale (e.g. to `'Cx_q'`), rename the field in config.m/loads.m and the spec file; tests/M8 reference `Cnr_table` in tAeroScaleUq, tUqSpec and tF16Uq.

### ADR-0xx (uq-2): AeroScale extension, order of operations
- `Cm_table`: `cm = (Cm_table*cmt) + cq2v*(Cm_q*cmq)`; `Cl_table`: `cl1 = Cl_table*clt + dclda*dail + dcldr*drdr`, `cl = cl1 + b2v*(Cl_p*clp*p + clr*r)`; `Cnr_table`: `cnr <- Cnr_table*cnr` before `cn` is rebuilt (with or without `Cnt_table`). Each block runs only when one of its multipliers is not 1, so the default path is the generated model, bit-identical (tests/M8/tAeroScaleUq.m#defaultPathBitIdentical; the M6 Cnt_table line and its sabotage S6F pattern are unchanged).
- `Cm_table` scales the WHOLE pitching-moment table cmt(el, alpha) about the MRC: M_alpha and M_de together, and the trim moment that balances the normal-force moment about the CG. A Cm_table change therefore moves the trim (tF16Uq failed hypothesis 5b), unlike Cm_q.

### ADR-0xx (uq-3): Search details not fixed by the plan
- LHS: own stratified construction `(randperm - rand)/n` per dimension from `RandStream('mt19937ar', 'Seed', 2026)` (no global rng, no lhsdesign).
- The fmincon starts are the NumStarts best DISTINCT points of the centre/corner/LHS phases (sort by margin, stable).
- fmincon: sqp, bounds = the box (sqp honours bounds in its finite differences; every evaluated point is inside the box, tBoundWorstToys#cliffOutsideNeverSeen), forward differences with step 1e-3 relative to theta (well above the step-study linearization noise), MaxFunctionEvaluations = the budget, and a hard budget in the objective wrapper. A non-OK point is NaN to the optimizer; a -Inf (divergent) point stops it (a definitive counterexample).
- A point's margin is the minimum over the candidate conditions that are OK; the point is OK only if all are. A start whose objective is not finite (e.g. +Inf: the 3.3.1.3 spiral T2 of a stable spiral) cannot be optimized and counts as not converged -> NOT_ASSESSABLE (FC-901), never OK.
- Status precedence: VIOLATED (any evaluated point or the confirmation below the reserve) > NOT_ASSESSABLE (non-OK point, non-OK confirmation, or FC-901) > OK.
- Margin of a group at a point = min over the group's records at the nominal Level L0 of their margin (NOT_APPLICABLE records ignored), the M7 levelMargin definition at one point; the in-envelope margin uses vital.ctrl.suggestGains' definition (vital.uq.F16Evaluator.levelMargin).
- Candidate ranking: per in-envelope point, the margin to L0; stable sort (ties in point order).
- Monte Carlo: `RandStream('mt19937ar', 'Seed', 2026)`, `randn(stream, N, d)`, identical to rng(2026, 'twister') + randn (tMonteCarloVerdict#seededSamples), global state untouched. A sample whose AeroScale would be negative is a vital:badInput exception -> a listed failure.
- Verdict: a finite bound-worst value below the reserve also counts as a violation (only reachable with a reserve > 0).
- Evaluations are cached by (theta, condition) in one vital.uq.F16Evaluator per analysis, so groups share the centre/corner/LHS points.
- The analysis is run on the conditions of vital.ctrl.inEnvelopeConditions (36 points, 30 IN); only IN points are candidates or count in the confirmation.

**Evidence.** tests/M8/tBoundWorstToys.m, tMonteCarloVerdict.m, tClopperPearson.m, tUqSpec.m, tAeroScaleUq.m, tF16Uq.m, tRunF16Uq.m.
