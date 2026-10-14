# M8 amendment R4b (agent uq4, 2026-10-14): notes, doubts, open issues

## Interpretations (no contract decision changed; see DECISIONS.md ADR-035)
1. **Refinement of straddling cells (R4-3 corrected).** The literal rule ("subdivide while bound < 0 and sampled minimum > 0") never subdivides a cell that already has a failing vertex, so alpha* could not be read to +/- 0.01 (a failing vertex can sit a whole base cell, 0.6 in alpha, above the clean side). I also subdivide straddling cells, but only cells that can still move alpha* (entry alpha below alphaHi - 0.01). This is still "only near the zero level set". If the coordinator meant something else, the place is `selectRefine` in +vital/+uq/lattice.m.
2. **"cell minimum - L h" taken literally** (full edge h, summed over the axes), i.e. twice as conservative as the geometric bound with h/2 that uq3's grid used. This is the main cost driver (below). Pre-registered as such in tUqLattice header (the LIP bound 0.08); switching to h/2 would be a coordinator decision.
3. **"Local slopes"** = own edges plus the 3^d base neighbourhood (a kink inside a base cell is invisible to the cell's own equal-valued vertices).
4. **MaxPoints is per group** (the points of the group's own cells). With a global cap, sharing could change an answer (the 3-group toy needs about 37,000 points in total while each group alone fits in 20,000); per group, shared == alone exactly (tUqLattice header 9d).
5. **"A box search only to confirm the CPV"** read as: alpha* from the lattice, the CPV confirmed by the fresh in-envelope assessment (R4-1's confirmation, with R3-M4). No box search runs (nSearches 0).
6. **Stage-1 Monte Carlo N = 200** (unchanged): with a smaller N the Clopper-Pearson bound cannot reach 0.95 (N >= 59 needed), so every stage-1 verdict would be NOT_ROBUST by budget. The MC runs at the critical condition only and is cheap relative to the searches.
7. **Lattice candidates in the staged run** = the stage-1 NumCandidates (2) per group, plus moving-limit additions; lattice groups get no stage 2 (contract).
8. **Bracketing requires every near breakpoint to be straddled** when alpha and el are both within 0.01 deg of a breakpoint.

## Open issues
- **Lattice cost in 3-D.** With the literal certificate, resolving alpha* to 0.01 needs roughly 1,000 new lattice points per halving level near the touching point (toy, corner-first: about 9,000-10,000 points per shape). On the F-16 each point costs one closed-loop single-point assessment per candidate condition (0.4-0.9 s). See CHANGELOG.md for the measured F-16 numbers and the runtime estimate. The per-group cap (6000 in analyze) makes a group that cannot be resolved NOT_ASSESSABLE ('GRID') with its bracket reported, never a pass.
- **tUqLattice runtime** is about 110 s (target 60 s): the shared-lattice test runs the 3-group lattice and three single-group lattices (about 19k points each for LIN / KINK). Not optimized further.
- **The fresh assessment is not bracketed.** `F16Evaluator.assessAt` (vital.fq.assess over all conditions, the confirmation) does not apply R4-7: vital.fq is read-only for M8. A CPV or arg-min exactly at a breakpoint point would give a NOT_OK confirmation (NOT_ASSESSABLE). Probability-zero in practice, but not excluded.
- **Monte Carlo samples are bracketed** (they use the cached point summaries), which is consistent with R4-7 (a point, not a box).
- The R3-pinned classes tF16Uq and tUqR3Report now pass 'LatDropCmq' false; their expectations are unchanged.

## Found after GREEN (fixed; recorded)
- **Lost sabotage coverage (S8W-2).** R4b moved tUqR4F16#endToEndCsr's 1-parameter longitudinal group onto the lattice, so S8W-2's line (the non-lattice equal shape in analyze.m) was no longer reached.
  - A first replacement check in tUqR4bF16#stagedEndToEnd (header 3g) could not see it either: its lateral parameter Cn_r has sigma 0.10 = EqualPct.
  - Fixed by a new test, tUqR4bF16#nonLatticeEqualShape (header 4: Cm_de, sigma 0.05, 'Lattice' false), added as an S8W-2 target in sabotages_uq3.json; a new sabotage S8X-9 covers the lattice line.
  - Final all-M8 run: 33/33 DETECTED. The full GREEN gate was not re-run after adding the test; the two affected classes were re-run and pass.

## Smoke observations (reports/uq/f16_uq_r4bsmoke.*)
- 3.2.2.1.1-CatA: the lattice reached its 3,000-point cap; the judged bracket is [0.22, 0.60] with a confirmed CPV, so NOT_ROBUST. The 6,000-point probe narrowed the bracket to [0.3375, 0.4875] but still did not close it to 0.01.
- 3.3.1.1-CatA-other and 3.3.1.3-CatA: ROBUST (alpha* 2.75 and 1.80). In the uq3 R4 smoke both were NOT_ASSESSABLE. This run met no NOT_CONVERGED point, so bracketing was not exercised on the F-16 search path.
