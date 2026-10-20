# M8 amendment R5 (agent uq5, 2026-10-14/15): notes, doubts, open issues

## Interpretations (no contract decision changed; ADR-036)
1. "R(1) certified" for lattice groups = alphaLo >= 1 AND lowerCertified (no moving item left in the final round; no failing / non-OK fresh check inside R(alphaLo)). A moved item of ANY kind in the final round invalidates the lower end (conservative).
2. Piecewise pieces use the FULL edge h (review R5 text); non-straddling cells h/2.
3. Corner checks are on the judged shape only (R(1) and R(alphaLo)); the equal shape gets none.
4. The R5-4 error metric is the largest |difference| of the judged bracket ends between stages. On the F-16 both measured groups agree exactly; the only nonzero value is a toy's undecided bracket end (0.075), so the band stays [0.8, 1.2].
5. N-R5 is kept as a documented null control outside the sabotages*.json files (run_sabotage has no "expected NOT DETECTED" entry).
6. S8Q-7's pattern was adapted to the R5-2 verdict line (same defect).

## Open issues
- 3.2.2.1.2-CatA in the smoke run is ROBUST from R(1) certified while its lattice hit the reduced 3000-point cap: alpha* only bracketed [1.14, 1.20]. The el = -12 deg breakpoint is also crossed, not only alpha = 5.
- 3.2.2.1.1-CatA: still capped (bracket [0.38, 0.4875]); NOT_ROBUST is decided by the confirmed CPV.
- Global cap: when it binds, sharing can change a group's answer (unlike the per-group cap).
- Piecewise limit: a breakpoint surface that crosses a cell without separating its vertices is invisible; a vertex exactly on a breakpoint counts on the lower side.
- The spec file uq/f16_uncertainty.json does not itself contain the judgment statements (outside my write access); loadSpec adds them.
- Runtimes (m7): tF16Uq still ~450 s (R3-pinned budgets); tUqR5 ~60 s; tUqR5F16 ~90 s.
- Not done (coordinator): the full staged default run_f16_uq and the test pinning its headline.
- run_f16_trim.m whitespace change and the axis-display files are not mine; untouched.
