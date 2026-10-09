# NOTES (r3tests, 2026-10-09)

Scope: close the R3 test gaps (findings M1 and M6). Tests only; no implementation, shared doc or existing test changed.

## Files
- tests/M7/tCtrlR3.m (TestTags M7), tests/M7/sabotages_R3.json (S7R-1..5)
- tests/M8/tUqR3.m (TestTags M8), tests/M8/sabotages_R3.json (S8R-1..8)
- reports/work/r3tests/ (gate and sabotage reports)

## Open issues / doubts
1. **tCtrlR3 runtime ~4.4 min (263 s), above the ~3 min budget.** 256 s is `m7GainsPinned`, the full default `vital.ctrl.suggestGains()` search, the only live re-derivation of the M7 proposal (R3 M1). It cannot be shortened without changing the search's result. S7R-2 is also detected by the cheap `roundingIsToNearest` (2 s), so if the coordinator wants the time back, `m7GainsPinned` could move to an opt-in tag. Doing so would lose the guard against a changed search (as opposed to a changed rounding).
2. **The command in the task brief fails as written.** `run_vital_tests('M8', 'Increment', {'tCtrlR3','tUqR3'}, ...)` raises "not a test class of milestone M8: tCtrlR3", because Increment/Baseline accept only current-milestone classes. I ran the full M0-M8 green gate (no Increment), which runs both new classes as ordinary tests.
3. **Design inputs came from exploration.** In tCtrlR3, the gains (Kq 1 / Ka -1 for the split short period; Kr 2 for the NaN 3.3.1.1 groups) and the rounding start [0.017 0.141 0.816] were picked from an exploration run of the real chain, so that each test hits the defect's blind spot. The class header says so. Their outcomes are labelled REG, not ANALYTIC.
4. **Synthetic edits of a real result.** tUqR3 #5 and #6 edit a copy of a real bare `vital.fq.assess` result: `nExcluded` = 1 on one record, and one EXTRAPOLATED point made OK with margin -10. They do not produce a real excluded in-envelope point. That would need a condition that fails to trim in the envelope, and no such condition exists today.
5. **OK/+Inf verdict.** `verdict(OK, +Inf)` is ROBUST by the contract and is pre-registered as such. `boundWorst` cannot currently return OK with +Inf, because fmincon cannot start from a non-finite objective (FC-901). If a future search change (e.g. R3 M3's spiral surrogate) makes OK/+Inf reachable, revisit this row.
6. **S7R-3 coverage.** The real flag rejects (a) more than five modes and (b) any non-OK mode. The test case has both: six modes, two of them NOT_OSCILLATORY. Case (b) cannot occur alone with exactly five distinct classical names, because `modes` renames an unclassified mode to 'other'. A sabotage dropping only one of the two conditions would therefore still be caught.
