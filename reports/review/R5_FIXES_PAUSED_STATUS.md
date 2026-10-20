# R5 fixes (agent uq5): paused 2026-10-14 ~23:00 at the user's request

## State
- **M8 is OPEN; M0-M7 are closed.** Contract: docs/PLAN_M5_M8.md "Amendment R5" (R5-1..R5-6), approved by the user.
- **Git:** pushed through commit 756736f. Everything below is UNCOMMITTED on disk, including the R5 amendment text in the plan.
- **Agent uq5 was stopped mid-implementation.** No MATLAB batch runs are left running. The user's own interactive MATLAB is open and untouched.

## What uq5 had done
- **RED run** (reports/work/uq5/M8_red_uq5.txt): 658 tests; PASS 634, RED_EXPECTED 17, VACUOUS 7; 0 RED_UNEXPECTED, 0 RED_SUSPICIOUS, 0 REGRESSION, 0 EXCLUDED. Valid.
- **R5 sabotages pre-checked against the new tests** (M8_sabotage_R5.txt):
  - S8Q-1, 3, 5, 6, 7, 8, 9: DETECTED.
  - S8Q-2: NOT DETECTED yet (needs the R5-2 implementation).
  - Null control N-R5: NOT DETECTED, as it should be (nullcontrol_R5.txt).
- **New tests:** tests/M8/tUqR5.m and tUqR5F16.m.
- **Sabotage files:** sabotages_R5.json, sabotages_uq5.json, nullcontrol_R5.json.
- **Changed tests:** tUqLattice, tUqCsr, tF16Uq.
- **Partial implementation, NOT verified:**
  - Changed: +vital/+uq/F16Evaluator, analyze, csr, headline, lattice, loadSpec, verdict, writeReport; run_f16_uq.m; +vital/version.m.
  - New: lowerEnd.m, stageBand.m, statements.m.
- **R5-6 done:** reports/uq/f16_uq_default.* renamed to f16_uq_default_superseded_2026-10-09.*.
- **R5-4 band measurement:**
  - Toys: r5band_toys.txt.
  - F-16, r5band_f16_console.log: 3.3.1.1-CatA-other judged CSR alpha* 2.75 in stage 1 AND stage 2 (no difference). The spiral group's stage-2 run did not finish.
- **Fragments:** only a stub NOTES.md. No ADR-036 or FC rows yet.

## Other on-disk changes noticed (not from the R5 contract)
- `run_f16_trim.m`: whitespace-only change (two `end` moved to new lines). Harmless; origin unclear, possibly an editor. Revert or keep; no behaviour change.
- `reports/axis_checks/*.png`: regenerated on 2026-10-14 at 22:04 with the same content. They will be redrawn anyway by the axis-display fix below.

## To resume
1. **Resume uq5** (or a fresh agent with this note): finish R5-1..R5-6.
   - Make S8Q-2 detected.
   - Finish the spiral stage-2 band measurement.
   - GREEN full gate; all M8 sabotages; 4-group smoke run (r5smoke); fragments (ADR-036, FC-958..).
2. **Coordinator:** verify; merge fragments; staged full default run_f16_uq; pin its headline; M8 guide chapter; M7 note; then the user's close decision.
3. **QUEUED, approved by the user: axis-figure fix** (+vital/+viz/axisChecks.m). Do this after uq5 so its tree checks stay valid.
   - **Mirrored figures:** 10 of 13 are drawn MIRRORED (the [N, E, -D] display map has det -1): yaw, pitch, roll, combined, level, climb, sideslip, gravity, control, path. cg, station and earth are correct.
   - **Fix:** one right-handed display map, x = right/East, y = forward/North, z = up (det +1). Update the labels.
   - **New test first** (tests/M5/tAxisChecksDisplay.m): det +1; N x E drawn as Down; axis labels.
   - **New sabotage:** restore the mirrored map; it must be caught.
   - **Explanations:** a "what this shows / why it matters" panel per figure, a meaning line per numeric check, and reports/axis_checks/README.md.
   - **Side-view labels:** cg = seen from the right wing; station = seen from the left wing.
   - Do not print the explanations to the console: tAxisChecks counts 'PASS' lines (14).

> 2026-10-14 23:40: the axis-figure fix (step 3 above) is DONE and verified. M0-M5 gate 400/400; S5AX-1..6 all detected, tree unchanged. Uncommitted, kept separate from the paused uq5 work.
