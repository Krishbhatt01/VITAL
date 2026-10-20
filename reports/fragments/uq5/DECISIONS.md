## ADR-036 (proposed; agent uq5, 2026-10-14/15): M8 amendment R5, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment R5": R5-1..R5-6, after review R5, reports/review/R5_REVIEW.md). These are the choices where it left room. No contract decision was changed.

### uq5-1: h/2 certificate (R5-1; `vital.uq.lattice` 'Certificate')
- Default `'half'`: bound = min(vertex margins) - sum_i L_i h_i / 2, L = 2 x the measured local slopes (own edges + 3^d base neighbourhood, as built). `'full'` keeps the R4b form (used only to show the superseded value).
- tUqLattice header 4: 0.08 -> 0.14 (superseded text kept; the full-h 0.08 is still checked with 'full'). tUqR5 header 1.
- Side effect: tUqLattice runs in about 38 s (was 86 s; review R5 m7).

### uq5-2: verdict from R(1) (R5-2; `vital.uq.lowerEnd`, `verdict`, lattice refinement order)
- Every CSR result (lattice and `vital.uq.csr`) carries `lowerCertified` and `lowerReason`: R(alphaLo) is certified clean over the FINAL candidate conditions.
  - Lattice: the cells meeting R(alphaLo) are certified by construction of alphaLo; in addition no confirmation item of the final round moved, and no check inside R(alphaLo) (corners, box arg-mins with alpha <= alphaLo, the cap arg-min when alphaLo is the cap) has a failing or non-OK point evaluation or fresh confirmation. A status OK / ROBUST_TO_CAP whose lower end is not certified becomes NOT_ASSESSABLE.
  - csr.m: R(lo) was searched clean; a moving limit invalidates it until a box >= lo is searched clean again with the new candidate; the nominal must be OK and pass.
- `vital.uq.verdict(csr, mc)`: ROBUST = lowerCertified and alphaLo >= 1 (and CP >= 0.95); NOT_ROBUST unchanged (confirmed CPV with norm <= 1, or CP < 0.95, NaN counts as low); else NOT_ASSESSABLE. `vital.uq.lowerEnd` reads a legacy R4 struct (no lowerCertified) as before (certified = status OK / ROBUST_TO_CAP, lo = alphaStar), so the R4 truth table is unchanged.
- Superseded: tUqCsr header 9 (K9, R(1) searched clean): verdict NOT_ASSESSABLE -> ROBUST.
- Lattice refinement priority per group: (1) the cells deciding R(DecideAt = 1) of the judged shape, (2) the judged shape to 0.01, (3) the other shapes at what the per-group / global caps leave. The equal shape is reported as a bracket; its status is OK only if it was resolved.

### uq5-3: piecewise certificate (R5-3; `problem.switches`, `q.switchVals`)
- Generic interface: `problem.switches` (name, breakpoints), `q.switchVals` per (point, condition). The side of a point = number of breakpoints strictly below its value (a value exactly on a breakpoint counts on the lower side).
- analyze ('Piecewise' true) passes the trim [alpha_deg de_deg] of every lattice point (F16Evaluator point summary, so a BRACKETED point carries its raw trim) against the alpha and el lists of `vital.uq.breakpoints` (R4-7's lists).
- Slopes are never measured over an edge whose ends lie on different sides (own edges and the 3^d base neighbourhood; this also applies to non-straddling cells next to a jump).
- A straddling cell: per condition and per side, min(margins of that side's vertices) - sum L_i h_i with the FULL edge (a planar cut leaves each side a vertex within one edge), L = 2 x the slopes at that condition from the non-crossing edges; the cell bound is the minimum over conditions and sides. A vertex whose side is unknown (NaN) is counted on every side (conservative).
- Report: `res.groups(g).discontinuity` (present, nCells, nCertified, variables, breakpoints, maxJump, crossings, text); analyze `plan.lattice.discontinuity`; the report states the discontinuity.
- Limit (stated in the report): a breakpoint surface that enters and leaves a cell through the same side of the vertices is invisible (the narrow-feature limit).

### uq5-4: stage-1 band (R5-4; `vital.uq.stageBand`)
- Rule: e = max measured |stage-1 - stage-2| of the judged CSR bracket ends (alpha units); band = [min(0.8, 1 - 2e), max(1.2, 1 + 2e)].
- Measurement (reports/work/uq5/r5band_toys.txt, r5band_f16.txt, r5band_f16_spiral.txt): 
  - F-16 (the smoke groups that have a stage 2; budgets of the R4b smoke: NumLHS 8, NumStarts 1, MaxEvals 120; stage 1 NumCandidates 2, DE 8 x 4; stage 2 NumCandidates 4, DE 16 x 8): 3.3.1.1-CatA-other judged alpha* 2.75 in both stages (bracket identical, |d| = 0); 3.3.1.3-CatA judged 1.7976 [1.7976, 1.8076] in both stages (|d| = 0); equal ROBUST_TO_CAP in both. The lattice groups have no stage 2. Runtimes: 3.3.1.1 + 3.3.1.3 both stages about 2 h; 3.3.1.3 alone 3,573 s (5,296 evaluations).
  - Toys (6 parameters, hybrid search, 4 conditions, defaults otherwise): LIN 0 / 0 (both NOT_ASSESSABLE [0, 1.002]), QUAD 0 (both OK 1.2175), COND3 0 (both OK 0.3914; the critical condition is the 3rd by nominal margin, found by the moving limit in stage 1), KINK |d alphaHi| = 0.07505 (both NOT_ASSESSABLE; [0, 1.5033] vs [0, 1.4283]), MIXED 0.
  - Largest measured error e = 0.075 (a bracket end of an undecided toy); every decided judged alpha* agreed exactly.
- Result: 2e = 0.15 < 0.2, so the band stays the floor [0.8, 1.2] (vital.uq.stageBand([0 0 0 0 0 0.07505 0])). analyze / run_f16_uq default Stage2Band [0.8 1.2]; tests/M8/tUqR5F16.m#endToEndR5 pins r.stages.band = stageBand(the measured errors). Caveat: two F-16 groups and five toys at reduced LHS/NM budgets; the measurement does not show the stage-1 error is small for every lateral group, only that none was seen.

### uq5-5: corner assessments, scope, minors (R5-5)
- M2: every round confirms each lattice group at the 2^d corners of R(1) and R(alphaLo) of the judged shape (option 'CornerChecks' / analyze 'LatticeCorners', default true). Corners are lattice points when they lie on the lattice, else EXTRA check points (evaluated by pointFcn at the group's conditions, never cell vertices, not counted in nPoints). They go through the same moving-limit line as the CPV and arg-min items (so S8Q-9's defect affects them too). Fresh assessments are shared between groups at the same theta (`F16Evaluator.assessShared`).
- Scope statement: `res.groups(g).scope`, `plan.lattice.scope` and `vital.uq.statements('limits')`.
- M4: tests for S8Q-1,2,3,5,6,7,8,9 (tUqR5, tUqR5F16); sabotages_R5.json with the R5 ids. S8Q-7's pattern was adapted (the robustCsr line was rewritten by R5-2; same defect at the same place). N-R5 is kept as a documented null control in tests/M8/nullcontrol_R5.json (NOT in a sabotages*.json, because run_sabotage requires every registered entry to be detected); it stays NOT DETECTED (reports/work/uq5/nullcontrol_R5.txt).
- S8Q-8 test: a controller with a small two-way crossfeed (dr += 1e-3 q, de += 1e-3 r) couples the axes so the lateral margin moves by 1.6e-5 relative with Cm_q: the 1e-9 gate fails (correct), a 1e-2 gate would pass.
- m1/m4/m6/m10: `vital.uq.statements('judgments'|'limits')` printed verbatim by headline/writeReport; `loadSpec` carries spec.judgments (the spec file uq/f16_uncertainty.json is outside uq5's write access; the coordinator may add the text there too). Stale report texts replaced.
- m2: any exception inside a lattice point is an ERROR point; a malformed result raises vital:uq:badPointResult.
- m3: an all-+Inf cell is not certified and not refined.
- m5: global lattice budget 'MaxTotalPoints' (analyze 'LatticeTotalPoints' 12000; the per-group cap 6000 stays). With the global cap binding, sharing CAN change an answer (unlike the per-group cap, ADR-035 uq4-1); the reason says 'global'.
- m7: tUqLattice 86 -> 38 s; tF16Uq (452 s) unchanged (its budgets pin R3 values).
- m8: tF16Uq pins the M7 confirmation values (tF16Uq.pinnedSas) instead of reading reports/.
- m9: `vital.version` = '0.8.0-M8rc' (no test pins the old string).

### uq5-6: R5-6
- reports/uq/f16_uq_default.json/.md renamed to f16_uq_default_superseded_2026-10-09.json/.md, with a SUPERSEDED banner at the top of the .md. No code or test referenced the old name (run_f16_uq's default label writes a fresh f16_uq_default.*).

**Evidence.** tests/M8/tUqR5.m (20), tUqR5F16.m (4); superseded items in tUqLattice header 4 and tUqCsr header 9.
