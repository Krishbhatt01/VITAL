# Paused 2026-10-27: I0 and D1 merged, combined gate running

## State
- **Pushed:** `newtest` through 169995f (0.9.1-CORE + CORE_AUDIT).
- **Uncommitted in C:\VITAL:**
  - **I0** (ADR-041, FC-1042..1054, tests/M9/i0, tests/reference fixtures, SC-9..11, 13, 14). Verified on its own: 765/765.
  - **D1** (ADR-042, FC-1060..1079, +vital/+data, f16/data.m, +nesc, AircraftModel.fromData, tests/M9/data, SD-1..9, run_data_example.m). Verified in C:\VITAL_data: 779/779. Copied into C:\VITAL.
  - Version 0.9.3-DATA. The fragments are merged and the M0 catalogue gate is OK.
- **Combined gate: DONE.** GREEN 797/797 (5,662 s), all M9 sabotages detected; reports in `reports/work/merged/`.
- **Leave out of the commits** (the user's own edits): `run_f16_trim.m`, `reports/force_audit/*`, `reports/axis_checks/*.png`, `reports/fq/f16_fq_default_baseline_20261021*`.
- The worktree `C:\VITAL_data` (branch data-layer) can be removed after the push.

## Next
1. Check the combined gate: expect 797 tests (747 + 18 + 32), all sabotages detected, tree unchanged.
2. The user approves I0 and D1, then push as two short one-liners with no attribution.
3. Then I1, planned in CORE_AUDIT section 6, using reports/fragments/i0/FINDINGS_FOR_I1.md. It needs the user's go-ahead.

## Open, unchanged
- **M8:** the decision on the 6 NOT_ASSESSABLE lateral groups.
- **Speed-up:** paused.
- **M9-B:** to be planned with the user.
- **tCorePerformance:** near its limit (1.236-1.239 vs 1.25).
