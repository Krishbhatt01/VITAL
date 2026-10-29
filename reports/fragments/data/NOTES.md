# NOTES (agent data, 2026-10-27): D1 open points for the coordinator

1. **Merge overlaps with I0 (tests/M9/i0, C:\VITAL).**
   - `+vital/AircraftModel.m`: D1 ADDS one `methods (Static)` block with `fromData`, placed just before `methods (Access = private)`. If I0 edits AircraftModel.m, merge by hand. Sabotage SD-6 patches the line `axis_cg = ax.(rt.cgAxis);` inside fromData.
   - `+vital/+aircraft/+f16/model.m` is rewritten: it now calls `vital.AircraftModel.fromData(vital.aircraft.f16.data(...))`. If I0 changed model.m, re-apply I0's change on top of the data path. The 0.9.1-CORE body is frozen in tests/M9/data/private/legacyF16Model.m.
   - New only (no overlap expected): `+vital/+data/**`, `+vital/+aircraft/+f16/data.m`, `+vital/+aircraft/+nesc/**`, `tests/M9/data/**`, `tests/M9/sabotages_data.json`, `run_data_example.m`.
   - IDs: ADR-042, FC-1060..FC-1079 (I0 uses FC-1042..1059).
   - `+vital/version.m` is not touched (0.9.3-DATA at merge).
2. **Criterion 4, "passes the I0 known-answer tests":** not runnable in this worktree. Run tests/M9/i0 after the merge. `vital.aircraft.f16.model()` is now built from the data and is bitwise the 0.9.1-CORE model, so a pass is expected.
3. **tests/M9/core/tCorePerformance (not changed by D1)** measured 1.236 against its 1.25 bound in one run here, under load from the other agent. Model and plant are unchanged by D1 (fromData's model is bitwise the old one, and its time ratio against the frozen model is 0.98). The margin is thin on a loaded machine; re-run on a quiet machine if it trips.
4. **First call cost:** `vital.aircraft.f16.data()` / `model()` parses the five DAVE-ML files once per MATLAB session (about 8 s cold). Later calls take about 20 ms, because the five SHA-256 checks run on every call.
5. **Units table:** `nim_h` in F16_control.dml:481 (trimmedKEAS) is treated as `nmi_h` (knots). That is a typo in the NASA file and is noted in `vital.data.unitFactor`.
6. **Unverified / assumption:** the cannonball's reference lengths b = cbar = 0.5 ft come from the header text ("6\" diameter"), as vital.nesc.vehicle already assumes; the file defines none.
