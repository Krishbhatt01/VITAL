## M6: MIL-F-8785C Class IV flying-qualities engine (agent `fq`, 2026-09-29/30)

| Step | Result | Evidence |
|---|---|---|
| RED | 41 new M6 tests (tFqRules 8, tFqMetrics 9, tFqEngine 12, tAeroScale 3, tFqMutations 4, tF16Fq 5), all RED_EXPECTED; 0 RED_UNEXPECTED, 0 RED_SUSPICIOUS, 0 VACUOUS, 0 EXCLUDED; 286 earlier tests PASS. gateOK false ONLY because of 50 REGRESSION in agent nesc's unfinished M5-C classes (tF16ControlLaw 11, tNescCases01to10 14, tNescF16Cases 12, tNescF16Circles 4, tRotatingEom 9; all `vital:notImplemented` at the time) | `reports/work/fq/M6_red_fq.txt` |
| Mid-course change (coordinator, after M5-X) | phugoid metrics moved to `vital.linear.modes(lin, 'IncludeHeight', true)`; tF16Fq identity 3 updated before GREEN (3a), guard test `heightCouplingOnlyMovesPhugoid` added (3b, 42 tests total) | `tests/M6/tF16Fq.m` header |
| GREEN | 379 tests: 363 PASS, 16 FAIL; all 42 M6 tests PASS; every M0-M5 test PASS except 16 in agent nesc's M5-C classes (tF16ControlLaw 1, tNescCases01to10 1, tNescF16Cases 10, tNescF16Circles 4); 0 EXCLUDED; 459 s (the M6 classes take about 40 s) | `reports/work/fq/M6_green_fq.txt` |
| Sabotage | S6F-1..5 all DETECTED, tree unchanged | `reports/work/fq/M6_sabotage_fq.txt` |
| Default assessment | `run_f16_fq` (default grid 75 points + 87 refinement): 154 OK, 7 INFEASIBLE, 1 trim NOT_CONVERGED; 0.17-0.30 s per point | `reports/fq/f16_fq.md`, `.json` |

New:
- `+vital/+fq`: loadRules, loadConditions, gridPoints, loadCoverage, metricNames, metrics, f16Factory, evaluatePoint, assess, writeReport.
- `rules/mil_f_8785c/records/*.json` (95 records), `coverage.json` (66 entries: 172 candidates not curated + 6 PILOT paragraphs + Category C), `conditions_f16.json` (OFE proxy, category policy, grids default/test/readme/mutation).
- `run_f16_fq.m`.
- `tests/M6/*` and `tests/M6/sabotages_fq.json`.

Changed:
- `vital.aircraft.f16.config`: option `AeroScale` (Cm_q, Cl_p, Cn_beta; default 1) and field `AC.aeroScale`.
- `vital.aircraft.f16.loads`: applies a multiplier that is not 1 to exactly one term; untouched otherwise (bit-identical; all M2-M5 tests unchanged).

Pre-registered mutations (REG, `tests/M6/tFqMutations.m`), all registered checks held:
- CG 25 -> 30 % MAC: omega_nsp 2.503 -> 1.777 rad/s, CAP 0.424 -> 0.205, 3.2.2.1.1-CatA Level 1 -> 2 (registered). Failed sub-hypothesis in the derivation: n/alpha(6.2) at CG 30 % is 15.37 > 14.90, so the derived CAP sub-interval [0.21, 0.24] did not hold (the registered band [0.16, 0.28] did).
- Cm_q x 0.3: zeta_sp 0.452 -> 0.341; trim and lateral metrics unchanged.
- Cn_beta x 0.2: omega_nd 3.32 -> 2.04 rad/s; short period and phugoid unchanged.
- Cl_p x 0.4: tau_R x 2.44 / 2.55; short period and phugoid unchanged; Cat B stays Level 1.

## M6: review R2 fixes (agent `fq`, 2026-10-05; quiet tree, only agent running)

| Step | Result | Evidence |
|---|---|---|
| RED | 10 classes in Increment (6 edited existing classes, 4 new: tFqRulesR2, tFqMetricsR2, tFqEngineR2, tF16FqR2). 461 tests: 388 PASS (M0-M5), RED_EXPECTED 9, RED_SUSPICIOUS 22, VACUOUS 42, RED_UNEXPECTED 0, REGRESSION 0, EXCLUDED 0; GATE OK. The SUSPICIOUS and VACUOUS tests are justified in NOTES item 18. Test-file SHA-256 at RED: `reports/work/fq/M6_R2_red_test_hashes.txt` | `reports/work/fq/M6_red_fqR2.txt` |
| GREEN, full (M0-M6, no Increment) | 461/461 PASS, 0 EXCLUDED, 1252 s; checks PUB 1967, INDEP 68, ANALYTIC 605, REG 710 | `reports/work/fq/M6_green_fqR2.txt` |
| Sabotage (Parts fq, fqR2) | 15/15 DETECTED (S6F-1..5, S6FR-1..10 = R2's 10 escaped mutations), tree unchanged: 1 | `reports/work/fq/M6_sabotage_fq_fqR2.txt` |
| Default report | `reports/fq/f16_fq_default_baseline.{json,md}` (229 points with refinement: 219 OK, 9 INFEASIBLE, 1 NOT_CONVERGED; 30 IN, 199 EXTRAPOLATED); `reports/fq/f16_fq_exploration_baseline.*`; the old `f16_fq.*` files were removed | |

Failed hypotheses, both kept in the test headers:
- tF16FqR2 "V about 177.4 m/s" was copied from R2. The true value is 177.97 m/s.
- tF16FqR2 "lon divergence rate 0.2029". That is the 8-state root; the registered 9-state definition gives 0.2060.

Superseded registrations (coordinator decisions), each with a dated header note:
- tFqRules counts and lists;
- tF16Fq 3.2.1.1 Level and file names;
- tFqMetrics split-phugoid status;
- the Cn_beta -> Cnt_table rename.
