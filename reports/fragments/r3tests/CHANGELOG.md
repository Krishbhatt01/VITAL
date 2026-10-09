# CHANGELOG fragment (r3tests, 2026-10-09)

## R3 test gaps closed (findings M1, M6): tests only, no implementation change

- New `tests/M7/tCtrlR3.m` (TestTags M7, 4 tests, ~263 s):
  - the 3.1.12 flag with all five classical names present (split short period)
  - a NOT_ASSESSABLE protected group counts as a regression
  - rounding to the nearest 0.01
  - the M7 proposal pinned to Kq 0.02 s, Ka 0.14, Kr 0.82 s from a live default `suggestGains` (R3 M1)
- New `tests/M8/tUqR3.m` (TestTags M8, 6 tests, ~34 s):
  - Monte Carlo sigma scales with the width
  - cache key distinguishes nearby theta
  - +Inf / NaN bound-worst is never ROBUST
  - a non-OK point with a partial multi-condition margin is counted
  - an excluded in-envelope point gives a NaN level margin
  - candidates are IN points only
- New sabotage sets `tests/M7/sabotages_R3.json` (S7R-1..5) and `tests/M8/sabotages_R3.json` (S8R-1..8), the 13 sabotages proposed by R3. The patterns are unchanged and each occurs exactly once.

## Gate evidence

- Full M0-M8 GREEN gate (no Increment): `run_vital_tests('M8', 'Phase', 'green', 'Tag', 'r3tests', 'ReportDir', 'C:\VITAL\reports\work\r3tests', 'Quiet', true)`.
  - TOTAL 552 | PASS 552 FAIL 0 | REGRESSION 0 | EXCLUDED 0 | 2827.5 s. GATE OK.
  - That is the 542 existing tests plus the 10 new ones.
  - Report: `reports/work/r3tests/M8_green_r3tests.txt`.
- Sabotages:
  - `run_sabotage('M8', 'Parts', {'R3'}, ...)`: 8/8 DETECTED (`reports/work/r3tests/M8_sabotage_R3.txt`).
  - `run_sabotage('M7', 'Parts', {'R3'}, ...)`: 5/5 DETECTED (`reports/work/r3tests/M7_sabotage_R3.txt`).
  - Tree unchanged: 1 in both.
  - The 9 sabotages R3 found NOT DETECTED (S8R-1, -2, -5, -6, -7, -8, S7R-1, -2, -3) are now all DETECTED. For S7R-2, both targets fail.
- No pre-registered expectation failed. No real bug found.
