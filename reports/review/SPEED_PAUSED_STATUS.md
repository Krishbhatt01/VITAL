# Speed-up increment (agent "speed"): stopped by the user 2026-10-21 ~08:10

## State
- Worktree: C:\VITAL_speed, branch `speedup` (cut from newtest 65d304d). Everything is UNCOMMITTED there. C:\VITAL (live tree) was never touched by this agent.
- Version string in the worktree: 0.8.2-SPEED.
- The agent was STOPPED because its second full GREEN run (run_green2, started 10-20 20:10) was still running about 12 h later (the first took 72 min), along with three leftover worker processes from 10-20 21:16 (vital.speed.workerMain shards 2,3,4). That looks like a HANG in one of the new multi-process tests (a worker that crashed or stalled, with the pool waiting forever). All its MATLAB processes were killed.

## What is done (in C:\VITAL_speed)
- New code: +vital/+speed/ (plantKernel MEX, mexStatus stale-binary check, useMex, plantMex, WorkerPool, workerMain), compare_uq_runs.m. Changed: fq/evaluatePoint, fq/f16Factory, linear/jacobian, linear/linearize, plant/derivatives, trim/solve (warm start), units/constants, uq/F16Evaluator, Study, analyze, boundWorst, csr, lattice, monteCarlo, writeReport, run_f16_uq.m, version.m. Test edited: tests/M8/tUqR4F16.m (reason not reviewed; see below).
- New tests: tests/M8/speed/, tests/M8/sabotages_speed.json.
- Fragments (not merged): reports/fragments/speed/ (ADR-038 proposed, FC rows, CHANGELOG, FRAMEWORK_GUIDE).
- RED run valid (red logs in reports/work/speed/).
- First full GREEN (reports/work/speed/M8_green_speed.txt): 728 tests, 727 PASS, 1 FAIL, GATE NOT OK. The failure is tUqR4F16/endToEndCsr: "header 5e: -0.00012795 vs -0.00012795" (the printed values are equal, so it is a tolerance or last-digit difference from the speed-up; the agent had edited this test, not reviewed).
- Sabotages SPD-1..11: all DETECTED, tree unchanged (sab.log).
- Smoke equivalence: compare_uq_runs says NO DIFFERENCES between the old-code and speed-code runs of the 4-group smoke (verdicts, CSR brackets, statuses identical; margins within 1e-6).
- Measured on the smoke run: base 14250 s (agent's own re-run of the old path, slower than the 10154 s recorded earlier, because the machine was shared), speed run runtime in f16_uq_r5smoke_speed.json (see compare in the log).

## Open items
1. Find the hanging test (look at reports/work/speed/green2.log, the last test started) and make WorkerPool fail with a clear error and timeout instead of waiting forever (the brief requires a clear error on worker failure).
2. Fix or justify the endToEndCsr failure (tolerance: show it is within a stated, justified bound; do not loosen blindly).
3. Re-run the full GREEN gate; then the coordinator compares against the full reference run: `compare_uq_runs('C:\VITAL\reports\uq\f16_uq_default.json', <speed run json>)`.
4. Merge fragments (ADR-038, FC numbers after FC-986), update the guide, then merge branch `speedup` into newtest only on the user's say-so.

## Important context from the M8 full reference run (finished 2026-10-21 05:36, 62613 s)
Report: C:\VITAL\reports\uq\f16_uq_default.md. 19 groups: 11 ROBUST, 2 NOT_ROBUST (3.2.2.1.1-CatA CAP, CSR [0.45, 0.46]; 3.3.1.1-CatA-COGA Dutch roll, counterexample margin -0.096), 6 NOT_ASSESSABLE (3.3.1.1-CatA-other, 3.3.1.1-CatB, 3.3.1.2-CatA/B, 3.3.1.3-CatA/B). Cause of the 6: in stage 2 (full budget) the Nelder-Mead local stage hit its 150-evaluation cap (exit flag 0), which the rule treats as FC-901, so a verdict is withheld. In the smaller smoke runs the same groups had converged and were ROBUST (Dutch roll other 2.75, spiral 1.80). The M8 close needs a decision on the lateral search (user was asked; no answer yet).
