# CHANGELOG fragment (uq5, 2026-10-14/15): M8 amendment R5

## Implemented (docs/PLAN_M5_M8.md, "Amendment R5")
- R5-1 h/2 lattice certificate ('Certificate' 'half' default; 'full' = R4b form).
- R5-2 verdict from R(1): `lowerCertified`/`lowerReason` on every CSR (lattice and csr.m), `vital.uq.lowerEnd`, new verdict rule; lattice refinement priority (decide R(1), resolve judged, then equal).
- R5-3 piecewise certificate at the NESC alpha/el breakpoints (problem.switches, q.switchVals, discontinuity report).
- R5-4 `vital.uq.stageBand`; measured errors: F-16 0 / 0, toys max 0.075 -> band stays [0.8, 1.2].
- R5-5 M2 corner assessments of R(1) and R(alphaLo) (shared fresh assessments `F16Evaluator.assessShared`) and scope text; M4 tests + sabotages_R5.json (S8Q-1,2,3,5,6,7,8,9) + null control nullcontrol_R5.json; m1/m4/m6/m10 statements (`vital.uq.statements`, spec.judgments); m2 ERROR points / vital:uq:badPointResult; m3 all-+Inf cells; m5 global budget (LatticeTotalPoints 12000); m7 tUqLattice 86 -> 38 s; m8 tF16Uq pins the M7 values; m9 version 0.8.0-M8rc.
- R5-6 reports/uq/f16_uq_default.* -> *_superseded_2026-10-09.* (banner in the .md).

## Files
- New: +vital/+uq/lowerEnd.m, stageBand.m, statements.m; tests/M8/tUqR5.m, tUqR5F16.m, sabotages_uq5.json, sabotages_R5.json, nullcontrol_R5.json.
- Changed: +vital/+uq/lattice.m, csr.m, verdict.m, analyze.m, F16Evaluator.m, headline.m, writeReport.m, loadSpec.m; +vital/version.m; run_f16_uq.m; tests/M8/tUqLattice.m (header 4 superseded), tUqCsr.m (header 9 superseded), tF16Uq.m (m8).
- Reports: reports/uq/f16_uq_default_superseded_2026-10-09.*, reports/uq/f16_uq_r5smoke.*; reports/work/uq5/*.

## Gates
- RED: reports/work/uq5/M8_red_uq5.txt: TOTAL 658, PASS 634, RED_EXPECTED 17, VACUOUS 7, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, REGRESSION 0, EXCLUDED 0; GATE OK; 3303 s. The 7 VACUOUS are the M4 guards of existing behaviour written for review R5's sabotages (S8Q-1, 3, 5, 6, 7, 8, 9): they must pass on the as-built code by design and are proven non-vacuous by those sabotages.
- GREEN: reports/work/uq5/M8_green_uq5.txt: TOTAL 663, PASS 663, FAIL 0, EXCLUDED 0; GATE OK; 3096 s (663 includes the coordinator's 5 new M5 axis-display tests).
- After RED, before GREEN: tUqR5 header 12 got a pinned cap-branch reason (S8Q-2 was masked by the new R5-2 check); tUqR5F16.R54_ERRORS filled with the R5-4 measurement.

## Sabotages
- uq5 + R5 parts: reports/work/uq5/M8_sabotage_uq5_R5.txt: 14/14 DETECTED (S8Q-1,2,3,5,6,7,8,9; S8Y-1..6), tree unchanged 1.
- All M8 parts: reports/work/uq5/M8_sabotage.txt: 48/48 DETECTED, tree unchanged 1, all detected 1.
- Null control N-R5: NOT DETECTED (reports/work/uq5/nullcontrol_R5.txt), as required.

## Smoke (reports/uq/f16_uq_r5smoke.json/.md)
- run_f16_uq('Groups', {3.2.2.1.1-CatA, 3.2.2.1.2-CatA, 3.3.1.1-CatA-other, 3.3.1.3-CatA}, 'Label', 'r5smoke', NumLHS 8, NumStarts 1, MaxEvals 120, DE 8 x 4, N 60, LatticeMaxPoints 3000), staged (default). Runtime 10,156 s; 15,340 point evaluations; 40 fresh assessments (8 shared).
- 3.2.2.1.1-CatA NOT_ROBUST (confirmed CPV at 0.4875, R(0.38) certified); 3.2.2.1.2-CatA ROBUST (R(1) certified, alpha* in [1.14, 1.20]; alpha = 5 and el = -12 discontinuities certified piecewise); 3.3.1.1-CatA-other ROBUST (2.75); 3.3.1.3-CatA ROBUST (1.80). No stage 2 needed.
