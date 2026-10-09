# FAILURE_CATALOGUE fragment (r3tests, 2026-10-09)

Proposed new rows (IDs are proposals; the coordinator assigns the final numbers). Six-column format of docs/FAILURE_CATALOGUE.md.

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-914 | M8 | Monte Carlo drawn with the x1 sigmas at every width scale (the x0.5/x1.5 columns silently repeat the x1 Monte Carlo) | analyze: MC sigma = w sigma and the samples regenerated from the seeded stream at each width; x1.5/x0.5 deviation ratio 3 | test failure | `tests/M8/tUqR3.m#monteCarloSigmaScalesWithWidth` |
| FC-915 | M8 | Point-evaluation cache key too coarse: nearby theta (finite-difference points, close samples) reuse another point's result (zero gradients, false convergence) | two theta 1e-5 apart are two evaluations, each equal to a fresh evaluator's result; the same theta is a cache hit | test failure | `tests/M8/tUqR3.m#cacheKeyDistinguishesNearbyTheta` |
| FC-916 | M8 | A +Inf bound-worst (no record applies at any sampled point; the box was never searched) declared ROBUST | verdict truth-table rows NOT_ASSESSABLE/+Inf, NOT_ASSESSABLE/NaN, OK/NaN; all-+Inf toy through boundWorst (FC-901) and verdict | `NOT_ASSESSABLE` | `tests/M8/tUqR3.m#infBoundWorstIsNotRobust` |
| FC-917 | M8 | In-envelope margin computed over the rated points only when an in-envelope point is EXCLUDED (e.g. no trim at the arg-min parameters): a moving limit into a non-trimmable point hidden | F16Evaluator.levelMargin returns NaN (confirmation NOT_OK) when a record has nExcluded > 0 | NaN margin -> `NOT_OK` confirmation -> `NOT_ASSESSABLE` | `tests/M8/tUqR3.m#excludedInEnvelopePointGivesNaN` |
| FC-918 | M8 | EXTRAPOLATED (outside the NESC validity envelope) points ranked as candidate conditions of the search | F16Evaluator.inEnvelopeMargins returns exactly the IN points; an extrapolated worst point never becomes a candidate | test failure | `tests/M8/tUqR3.m#candidatesAreInEnvelopeOnly` |
| FC-817 | M7 | The M7 gain proposal drifts (search or rounding change) while M8 keeps analysing the hard-coded confirmed gains | live default suggestGains pinned to Kq 0.02, Ka 0.14, Kr 0.82 (REG, M7_acceptance); rounding to the nearest 0.01 checked independently (also on a MaxIter-0 start) | test failure | `tests/M7/tCtrlR3.m#m7GainsPinned` |

Extensions of existing rows (add to their Detection text as "also covered by"):

- FC-903 (non-OK point dropped): a point that fails at one candidate condition but is OK at another keeps a finite margin and must still count as non-OK: `tests/M8/tUqR3.m#partialMarginNonOKPointCounted`.
- FC-816 / FC-702 (regression; non-OK never improves a verdict): a protected group that becomes NOT_ASSESSABLE (NaN headline) with the proposed gains is "worse than bare": `tests/M7/tCtrlR3.m#notAssessableProtectedGroupIsRegression`.
- FC-811 (3.1.12 equivalent system): all five classical names present but six modes, two of them NOT_OSCILLATORY (split short period) -> FLAGGED: `tests/M7/tCtrlR3.m#equivalentSystemFlagAllNamesPresent`.
