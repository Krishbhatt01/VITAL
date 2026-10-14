# CHANGELOG fragment (uq3, 2026-10-13): M8 amendment R4 (judgment-light robustness)

## Implemented (docs/PLAN_M5_M8.md, "Amendment R4")
- **R4-1:** `vital.uq.csr`, the Critical Similitude Ratio. It brackets alpha* by bisection over box searches, with ray refinement and optimistic steps.
  - Two reference shapes: judged (k_g sigma) and equal percentage (10 %).
  - Statuses OK / ROBUST_TO_CAP / NOT_ASSESSABLE.
  - The CPV is confirmed by a fresh in-envelope assessment, with the moving-limit rule.
  - The report gives the parametric safety margin alpha* m.
- **R4-2:** `vital.uq.verdict(csr, mc)` gives the R4 headline. The box verdict `verdict(bw, mc)` is kept per width. Default WidthScales = 1; x0.5/x1.5 stay available.
- **R4-3:** `vital.uq.boundWorst(..., 'Method', 'grid')`: dense lattice grid, local refinement around the minimum, a Lipschitz certificate with factor 2 on the measured slopes, and the label "grid-certified (Lipschitz estimate)". A box without a certificate is NOT_ASSESSABLE with a reason starting 'GRID'.
- **R4-4:** `'Method', 'hybrid'`: `vital.uq.diffEvolution` (own seeded DE/rand/1/bin with bound reflection) followed by fminsearch with a bound transform. Per-stage convergence is in bw.stages. `vital.uq.searchMethod` picks grid for <= 2 searched parameters and hybrid above.
- **R4-5:** AeroScale Cm_basic (cmt at el = 0) and Cm_de (cmt - cmt(el = 0)). The default path is bit-identical, and Cm_table remains as the legacy field.
  - Spec `f16_uncertainty_v2`: pitchStatic = {Cm_basic, Cm_de}, sigma 0.05 each, d = 2.
  - The longitudinal search includes them, gated by tUqR4F16#lonLatInvarianceR4 at the CSR cap lateral corners. Worst deviation 5.2e-14 against a 1e-9 limit.
- **R4-6:** Cnr_table renamed Cn_r in config, loads, the spec and tests/M8. tests/M6/tAeroScale.m now uses 'Cx_q' as its unknown name, with a header note. No registered sabotage pattern named the field.

## Files
- **New:** +vital/+uq/csr.m, diffEvolution.m, searchMethod.m; tests/M8/tUqCsr.m, tUqGridCert.m, tUqHybrid.m, tUqR4F16.m, sabotages_uq3.json.
- **Changed:**
  - code: +vital/+uq/boundWorst.m, analyze.m, verdict.m, searchPlan.m, surrogateWorst.m, writeReport.m, headline.m; run_f16_uq.m; +vital/+aircraft/+f16/config.m and loads.m; the +vital/+fq/f16Factory.m header; uq/f16_uncertainty.json
  - tests/M8: tAeroScaleUq, tUqSpec, tUqR3, tUqR3F16, tUqR3Fixes, tF16Uq, tRunF16Uq, tUqR3Report (superseded parts marked)
  - tests/M6/tAeroScale.m (one line and a header note)

## Gates
- **RED:** reports/work/uq3/M8_red_uq3.txt.
  - TOTAL 600, PASS 527, RED_EXPECTED 31, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 42, REGRESSION 0, EXCLUDED 0; gateOK.
  - Every new test is RED_EXPECTED except tUqR4F16#defaultPathAndRename.
  - The 42 VACUOUS have unchanged expectations (renamed fields, legacy-pinned R3 classes, spec data written with the stubs, config guards).
- **GREEN, first run:** TOTAL 602, PASS 602; 3429 s.
- **GREEN, final** (after the cap fix): reports/work/uq3/M8_green_uq3.txt. TOTAL 603, PASS 603, FAIL 0, EXCLUDED 0, VACUOUS 0, REGRESSION 0; gateOK; 3311 s.
- **Runtimes in GREEN (class sums):** tUqCsr 11 s, tUqGridCert 37 s, tUqHybrid 3 s, tUqR4F16 119 s. Legacy classes: tF16Uq 662 s, tRunF16Uq 144 s, tUqR3Report 82 s.

## Sabotages
- **Pre-fix run** (reports/work/uq3/prefix_*):
  - uq3 S8W-1..6: 6/6 DETECTED
  - all M8 parts: 23/23 DETECTED
  - M6: 15/15 DETECTED
  - tree unchanged 1 in each
- **Final run** (after the cap fix; reports/work/uq3/M8_sabotage_uq3.*, M8_sabotage.*, M6_sabotage.*):
  - uq3 S8W-1..7: 7/7 DETECTED
  - all M8 parts (S8R-1..8, S8U-1..5, S8V-1..4, S8W-1..7): 24/24 DETECTED
  - M6: 15/15 DETECTED
  - tree unchanged 1 in all three runs

## Smoke run
- reports/uq/f16_uq_r4smoke.json/.md: 3 groups, reduced budget (NumCandidates 2, NumLHS 8, DE 8 x 3, Nelder-Mead 1 x 120, N 20).
- Final run, after the cap fix: 5205 s, 5505 single-point evaluations, run beside the sabotage runs.
- Results:
  - 3.2.2.1.1-CatA: x1 bound-worst -0.0624, VIOLATED. CSR judged alpha* 0.443 (CPV at 0.453, confirmed). Equal percentage: alpha* 0.809, i.e. an 8.1 % uniform tolerance. NOT_ROBUST.
  - 3.3.1.1-CatA-other and 3.3.1.3-CatA: CSR NOT_ASSESSABLE (judged alpha* in [0, 2.76] and [0, 1.81]). Cause: a point inside the 7-D boxes that is not OK (linearization not converged), and FC-901.
  - Every smoke verdict also fails the Clopper-Pearson bound, because N = 20 gives at most 0.861 (a budget artefact).
- See NOTES.md for the findings.

## Runtime estimate of the full default run (not run)
- **Per search.** A default 7-D hybrid search evaluates about 540 points x 4 candidates, roughly 2,200 single-point evaluations. A 3-D longitudinal search evaluates about 1,500. A smoke search evaluated about 560.
- **Searches per group.** The smoke run needed 3-5 box searches per group (x1 + CSR, both shapes). The default should be similar.
- **Total.** About 19 groups x 4.5 searches x roughly 1,800 evaluations, plus 19 x 200 Monte Carlo samples, is about 160k evaluations. At 0.35-0.4 s each in a single uncontended MATLAB that is about 15-18 h; at the 0.9 s observed beside other MATLAB jobs, about 40 h.
- **Lighter option.** NumCandidates 2 and DEGenerations 4 would roughly halve this.
