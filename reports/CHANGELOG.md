# VITAL gate history

There is no version control (ADR-004). Each gate is recorded here with its reports and the code tree hash (`vital.test.treeHash(root, 'Exclude', {'data','reports'})`).

## M0: Specification, data acquisition, test infrastructure (2026-09-29)

**Result: GREEN 44/44, sabotage 4/4 detected, awaiting your approval.**

| Step | Outcome | Evidence |
|---|---|---|
| Data | 5 NESC files downloaded with your permission (43 MB) and SHA-256 hashed; originals read-only | `data/MANIFEST.json` (15 entries) |
| Data | MIL-F-8785C download refused (HTTP 403); left for you to supply before M7 | ADR-010 |
| RED | 44 tests written. Plain matlab.unittest was used for this run, because the VITAL runner itself is under test in M0. 44 of 44 were RED-expected (`vital:notImplemented`) and none failed for any other reason | `M0_red_bootstrap.txt` |
| GREEN | 44 of 44 pass. Gate OK | `M0_green.txt/.json/.xml` |
| Sabotage | S0-1 … S0-4 all DETECTED, each in a separate MATLAB process; the real tree was unchanged | `M0_sabotage.txt/.json` |
| Tree hash | `57b65d89172bf6ba87bab3f5a48a499b397f8bf75cf137ad2769bd153aa6a460` | |

**Defect found by the M0 tests during GREEN, and fixed:** the classifier first recognized stubs by searching the *message text* for "vital:notImplemented". The fixture's own message ("An error that is not vital:notImplemented") fooled it, so an unrelated error was counted as RED-expected. It now matches the error **identifier**, or the "Actual Exception" line reported by verifyError. Sabotage S0-2 re-introduces the bug and confirms the test catches it.

**Deliverables:**
- **Docs:** `docs/CONVENTIONS.md`, `docs/DECISIONS.md` (ADR-001 … 012), `docs/FAILURE_CATALOGUE.md` (47 failure modes; 19 tested in M0, the rest PLANNED), `docs/VERIFICATION_MATRIX.md`
- **NESC matrix:** `docs/NESC_CASE_MATRIX.md/.json` (18 cases with pre-registered bands), plus cited extracts in `docs/nesc/`
- **Rules:** `rules/schema/RULE_SCHEMA.md`
- **Code:** `vital.test.*` (VitalTestCase, provenance, classifier, milestone selection, sabotage harness, tree hash), `vital.io.*` (rule validator, catalogue reader, sha256), `run_vital_tests.m`, `run_sabotage.m`

**Findings from the NESC documents that change later milestones** (details in `NESC_CASE_MATRIX.md`):
- The NESC F-16 has no engine power lag and no engine gyroscopic term.
- The CG is at 25% MAC, with moments about 35% MAC.
- The control laws are static, with saturations held only in minValue/maxValue attributes.
- Tables clamp (`extrapolate="neither"`), and the last breakpoint varies fastest.
- Case 12 uses the subsonic tables at Mach 2.
- The TM states no pass tolerance, hence the pre-registered band (ADR-009).

## M1: Foundations (2026-09-29)

**Result: GREEN 123/123 (M0 + M1, no regressions), sabotage 5/5 detected, awaiting your approval.**

| Step | Outcome | Evidence |
|---|---|---|
| Data | MIL-F-8785C supplied by you, stored read-only and hashed (ADR-013) | `data/MANIFEST.json` |
| RED | 70 new tests, all RED-expected; the 44 M0 tests still passed | `M1_red.txt` |
| RED increment | 9 envelope-check tests, all RED-expected | `M1_red_increment_envelope.txt` |
| GREEN | 123 of 123. Checks by source: PUB 16, INDEP 14, ANALYTIC 76 | `M1_green.txt/.json/.xml`, `M1_green_provenance.json` |
| Sabotage | S1-1 … S1-5 all DETECTED; tree unchanged | `M1_sabotage.txt/.json` |
| Tree hash | `08f0f55d64d30dd5626418e6a3a91924cb4ae1c16851ca67ec6d8db0439a6936` (after the version bump to 0.1.0-M1; the only change since the sabotage run is that version string and docs) | |

**Failures during M1 GREEN, and how each was resolved:**
1. **`nonPhysicalInertiaRejected`: a real code bug.** `inertiaTensor` passed a vector to a formatted `error()`, so the failure raised the wrong exception. Fixed in the code.
2. **`vaneCorrectionSignsE1`: my test expectation was wrong.** The linear vane forms are an expansion about α = β = 0; at α ≈ 3° they leave out an α·q·z_v/V term of about 4e-5 rad. The sign test now runs at α = β = 0. A new test checks that `vaneAngles` is exact kinematics at arbitrary α, and CONVENTIONS §5 is corrected.
3. **`matchesNescConsensus`: my tolerance was stricter than the pre-registered criterion.**
   - The NASA consensus sims disagree with each other by up to 2e-5 in p and ρ.
   - Sim 3's **last frame** is off by 0.19 K; the TM documents this kind of last-frame artifact (E.2.4).
   - Resolution: I implemented the pre-registered ADR-009 envelope criterion (`vital.verify.envelopeCheck`), red-green with 8 analytic tests of its own (ADR-015). No frame was excluded.

**Established by M1:**
- The NESC reference atmosphere uses **geopotential** altitude (checked against the data, and sabotage S1-3 confirms the test would catch a mistake).
- NESC `localGravity` is the J2 gravitation component along the geodetic down, matching to 1e-9 relative at 0° and at 89.95° latitude.

**After the M1 gate (docs and data only, no code change):**
- `docs/MIL8785C_EXTRACT.md` was added: Class IV criteria transcribed from page images, with citations. Tables IV, VI, VII and VIII were independently re-checked against pp.13, 22 and 23.
- `rules/mil_f_8785c/candidates_from_extract.json` was added: 235 candidate records. They become validated rule records only in M7.

## Runner fix + M2 (DAVE-ML import) + M3 (F-16 plant) + M4 (trim) (2026-09-29)

**Why:** you ran the gate in a session without `startup_vital` and got 44 tests where there should have been 123. You also asked me to re-check that the approach leads to a trimmable, testable F-16. It does, but trim was scheduled too late (ADR-016).

| Step | RED (right reason) | GREEN | Sabotage | Notes |
|---|---|---|---|---|
| Runner fix (FC-110/111) | 4 tests reproduce both defects | 127/127 | S1-6 | ADR-018 |
| M2 DAVE-ML | 28 RED-expected, 0 unexpected (after two fixes: M2 catalogue rows made real; one try/catch test rewritten as verifyError) | 156/156 | S2-1 … S2-5 detected | All **16 aero + 9 prop** NASA checkData shots reproduced (1,077 PUB checks) |
| M3 plant | 19 RED-expected | 175/175 | S3-1 … S3-5 detected | Control-sign, unit-boundary, 35 → 25 % MAC moment transfer, datum-invariance tests |
| M4 trim | 14 + 5 RED-expected; 1 M1 regression reproduced (single-sample envelope) | 194/194 | S4-1 … S4-5 (see M4_sabotage) | |

**Defects and wrong expectations found along the way, each fixed red-green:**
1. **Runner** ran without its path, and silently excluded test files. Fixed; the gate now fails on any exclusion.
2. **DAVE-ML reader:**
   - NASA wraps `<piecewise>` in an operator-less `<apply>` (F16_aero.dml:611). A fixture and test were added before the fix.
   - A 0×1 dependency cell made a `for` loop run once. Fixed.
3. **Test-design error:** the checkData-corruption test corrupted a table cell that no NASA shot uses. Moved to the "Nominal" shot's cell (α = 5°, el = 0).
4. **`envelopeCheck`** could not compare single-instant references (a trim at t = 0). A test was added first, then the fix.
5. **Pre-registered hypothesis 3 failed:** "the README-vs-NESC pitch difference is gravity alone." Gravity gives 0.0074° of the 0.0150°; Coriolis and curvature explain the rest (ADR-017). The test was replaced, keeping the registered 0.005° tolerance.

**F-16 trim results** (10,013 ft, CG 25 % MAC):

| Reference | Condition | VITAL | Published | Difference |
|---|---|---|---|---|
| NASA F16 README Table 11 | g = 32.174 ft/s², 565.6854 ft/s | θ 2.6542°, δe −3.2412°, PLA 13.9012 % | 2.6538°, −3.2410°, 13.9019 % | 0.0004°, 0.0002°, 0.0007 pts |
| NESC case 11, sims 4/5 | level-flight gravity at 36.019° N, V_NED = [400, 400, 0] ft/s | θ 2.63883° | 2.63873°, 2.63893° | inside, ±0.0001° |

## M4 increment: force and moment breakdown (2026-09-29)
User-facing view of the loads the plant already computed: `run_f16_loads` / `vital.aircraft.f16.loadsReport`.

| Step | Result | Evidence |
|---|---|---|
| RED increment | 8 tests in `tF16LoadsReport`, all RED-expected; 0 regressions | `M4_red_increment_loads.txt` |
| GREEN | 202/202 pass, 0 excluded | `M4_green.txt` |
| Sabotage | S4-6 (MRC→CG moment transfer dropped), S4-7 (lift sign) detected; M4 7/7 | `M4_sabotage.txt` |

**What the tests hold the report to:**
- Aero + thrust + gravity rows add to the plant's own total, which is zero at a trim.
- Gravity row is W[−sin θ, 0, cos θ].
- Aero row is q̄S·C, with moments moved from the MRC (35 % MAC) to the CG.
- Wind-axis lift/drag balance in level flight and a 5° climb.
- A specified state is labelled SPECIFIED, never a trim; its accelerations equal F/m and J⁻¹M.

At the README trim: lift 20,390 lbf, drag 2,364 lbf, thrust 2,366 lbf, weight 20,500 lbf, L/D 8.63.

## M5 complete: gate verified by the coordinator on a quiet tree (2026-10-01)
- **Full M5 gate:** `run_vital_tests('M5')`, no increment filter: 388/388 PASS, 0 excluded, 885 s (`reports/work/coordinator/M5_green_coord_full.txt`).
- **All M5 sabotages:** 66/66 DETECTED, tree unchanged (`reports/work/coordinator/M5_sabotage.txt`).

| Part | Sabotages |
|---|---|
| linear and linearR1 | 30 |
| sim and simR1 | 22 |
| nesc | 14 |

- **Increments:** M5-A (linearization, modes), M5-B (simulation), M5-X (linear vs nonlinear, closed loop), the review R1 fixes, and M5-C (rotating Earth, NESC cases).
- **NESC result:**
  - Cases 1-10: every one of the 25 band signals is inside its band.
  - F-16 cases 11-16: 53 of 200 band signals are outside. They are recorded as failed pre-registered expectations (KNOWN tables in tNescF16Cases and tNescF16Circles), with the agent's evidence in `reports/fragments/nesc/NOTES.md` section 3. No band was changed.
- **Open:**
  - The M5-C test set runs 11.9 min, against an 8-minute target.
  - The SIM 4/5 control-law execution form is inferred, not documented.
  - **M5 is NOT yet marked closed in `docs/MILESTONES.json`.** Closing it accepts the 53 known F-16 discrepancies, which is the user's decision.

## M5 closed (2026-10-05)
Closed by the user's decision, with the 53 known F-16 NESC discrepancies accepted as documented. `docs/MILESTONES.json` now lists M0-M5 as closed.

## Re-verification after closing M5 (2026-10-05)
- **Gate:** full gate, M0-M5, on a quiet tree: 388/388 PASS, 0 excluded, 1049 s (`reports/work/coordinator/M5_green_close_check.txt`).

| Milestone | Tests |
|---|---|
| M0 | 50 |
| M1 | 93 |
| M2 | 29 |
| M3 | 19 |
| M4 | 26 |
| M5 | 171 |

- **Sabotages:** every milestone's sabotages, 96/96 DETECTED, tree unchanged (`reports/work/coordinator/close_check/`).

| Milestone | Detected |
|---|---|
| M0 | 5/5 |
| M1 | 8/8 |
| M2 | 5/5 |
| M3 | 5/5 |
| M4 | 7/7 |
| M5 | 66/66 |

- **Documentation:** corrected stale statements in `docs/FRAMEWORK_GUIDE.md`: the test counts, the sabotage status of M5-C, and the closed milestones.

## M6 after review R2: verified by the coordinator (2026-10-06)
- **Gate:** full gate M0-M6 on a quiet tree: 461/461 PASS, 0 excluded, 853 s (`reports/work/coordinator/M6_green_m6_check.txt`). M6 has 73 tests.
- **Sabotages:** all milestones, 111/111 DETECTED, tree unchanged.

| Milestone | Detected |
|---|---|
| M0 | 5 |
| M1 | 8 |
| M2 | 5 |
| M3 | 5 |
| M4 | 7 |
| M5 | 66 |
| M6 | 15 (original 5 + R2's 10 escapes) |

- **Review R2 findings:**
  - B1: a pitch/AoA divergence now fails 3.2.2.2 instead of being excluded.
  - B2: a group with unrated points never shows an achieved Level; the tau_R fallback is in place.
  - M8: points are tagged IN or EXTRAPOLATED against the NESC model envelope; the headline Level is in-envelope only.
  - M9: reports are named by grid and AeroScale.
- **Merged:** failure modes FC-703..721 and ADR-030.
- **M6 is NOT yet closed:** that is the user's decision (the validity-radius judgment; the 3.2.2.2 1-g interpretation).

## M6 closed (2026-10-06)
Closed by the user, accepting the validity-region judgment and the 3.2.2.2 level-flight interpretation. `docs/MILESTONES.json` lists M0-M6 as closed.

## Visual axis checks (2026-10-06, user request)
- **What:** `run_axis_checks` / `vital.viz.axisChecks` draw 13 vector-plot cases with 58 numeric checks. Every check compares VITAL's vectors with an independent closed form (ANALYTIC) or the Aerospace Toolbox (INDEP). Figures are saved in `reports/axis_checks/`.
- **Cases:**
  - rotations: yaw, pitch, roll, combined 3-2-1
  - velocities: level and climb trim velocity; sideslip and wind
  - frames and points: gravity in body axes, CG and BFRP, station-to-body
  - physics: control moment signs; a simulated flight path
  - Earth: NED on the WGS-84 Earth
- **Gates:**
  - RED: 4/4 RED_EXPECTED, 0 regressions.
  - GREEN: 221 tests (M0-M4 + tAxisChecks) all pass.
  - Sabotages S5AX-1..4 (`tests/M5/sabotages_axis.json`: pitch-matrix sign, station flip, CG transfer sign, ECEF-to-NED down row) all DETECTED, tree unchanged.
- **Placement:** the test is tagged M5 (closed) because it uses the M5 simulator; it adds coverage and changes no M5 behaviour.

## M7 verified by the coordinator (2026-10-07)
- **Gate:** full M0-M7 on a quiet tree: 498/498 PASS, 0 excluded, 1685 s.

| Milestone | Tests |
|---|---|
| M0 | 50 |
| M1 | 93 |
| M2 | 29 |
| M3 | 19 |
| M4 | 26 |
| M5 | 175 |
| M6 | 73 |
| M7 | 33 |

- **Sabotages:** all milestones, 121/121 DETECTED, tree unchanged.
- **Design feedback:** the suggested gains Kq 0.02 s, Ka 0.14, Kr 0.82 s take the three in-envelope Level 2 groups to Level 1, confirmed by re-assessment (`reports/ctrl/f16_sas_suggestion.md`).
- **Merged:** FC-801..816 and ADR-031.
- **Status:** M7 is NOT yet closed; that awaits the user's decision.

## M7 closed (2026-10-07)
Closed by the user ("go ahead with the next stage"), on the 2026-10-07 coordinator verification (498/498, 121/121 sabotages; only the separate SciComp folder changed since). `docs/MILESTONES.json` lists M0-M7 as closed. Accepted judgments are in `M7_acceptance`.
## M8 uncertainty (agent uq, 2026-10-07/08)

- New package `+vital/+uq/`: loadSpec, box, boundWorst, monteCarlo, clopperPearson, verdict, F16Evaluator, analyze, headline, writeReport, augmentedBuilder. New entry point `run_f16_uq.m`. New spec `uq/f16_uncertainty.json` (label JUDGMENT).
- AeroScale extended (`vital.aircraft.f16.config`, `loads`): `Cm_table` (cmt), `Cl_table` (clt), `Cnr_table` (cnr; the plan's `Cn_r`, renamed, see NOTES). Default path bit-identical (tAeroScaleUq#defaultPathBitIdentical, full M0-M7 gate).
- Tests `tests/M8/`: tUqSpec, tClopperPearson, tBoundWorstToys, tMonteCarloVerdict, tAeroScaleUq, tF16Uq, tRunF16Uq (41 test methods).

### Gate evidence
- RED: `reports/work/uq/M8_red_uq.txt` — TOTAL 539 | PASS 498 | RED_EXPECTED 41 | RED_UNEXPECTED 0 | RED_SUSPICIOUS 0 | VACUOUS 0 | REGRESSION 0 | EXCLUDED 0 (gateOK).
- GREEN (full M0-M8): `reports/work/uq/M8_green_uq.txt` — TOTAL 539 | PASS 539 | FAIL 0 | EXCLUDED 0 (2,250 s).
- Sabotage: `reports/work/uq/M8_sabotage_uq.txt` — S8U-1..S8U-5 all DETECTED, tree unchanged 1.
- Failed hypotheses recorded in headers: tUqSpec 3a, 3b; tF16Uq 5b (NOTES.md).
- Report: `reports/uq/f16_uq_default.json/.md` (run_f16_uq defaults, 5,379 s).

## M8 verified by the coordinator (2026-10-08)
- **Gate:** full M0-M8 on a quiet tree: 539/539 PASS, 0 excluded, 2078 s (`reports/work/coord_m8/M8_green.txt`).
- **Sabotages:** every milestone re-run because the M8 agent changed the M4/M6 aircraft files (config.m, loads.m): 126/126 DETECTED, tree unchanged (`reports/work/coord_m8/M*_sabotage.txt`).
- **Merged:** ADR-032 (uq-1 to uq-3) and FC-901..913.
- **Open:** AeroScale field `Cnr_table` instead of the plan's `Cn_r` (ADR uq-1); NOT_ASSESSABLE groups 3.2.2.1.2-CatA/B (fmincon budget) and 3.3.1.3-CatA/B (+Inf margin, no surrogate); joint box covers ~97 % of the joint normal; fmincon convergence on a nonsmooth objective taken at face value.
- **Status:** M8 is NOT yet closed; that awaits the user's decision.

## R3 B1 fixed: sabotage copies now include reports/ (2026-10-09, coordinator)
- **Defect (review R3 B1):** `vital.test.applySabotage` did not copy `reports/`. tCtrlSuggest and tF16Uq read committed reports, so in a sabotage copy they failed on any edit. A null sabotage was "DETECTED", which made the M7 detections of S7C-4 and S7C-5 vacuous.
- **Fix:** the copy now includes `reports/` except the scratch folder `reports/work` (+vital/+test/applySabotage.m). Copying, rather than an environment variable pointing at the real reports, keeps anything a sabotaged test writes inside the copy.
- **Red-green:** new `tests/M0/tSabotageReports.m`, with the fixture `tests/fixtures/sabotage_reports_tree`.
  - RED (`reports/work/harness/M0_red_harness.txt`): copyHasReportsButNotScratch and nullSabotageNotDetected failed by assertion, i.e. the defect reproduced. realSabotageDetected was VACUOUS, justified in its header (it passed before for the wrong reason and guards the fix).
  - GREEN: 3/3.
- **New sabotage S0-6** (undoes the fix) and **failure-catalogue row FC-020**.
- **Re-verification on a quiet tree** (`reports/work/harness/`):
  - Full M0-M8 gate: 542/542 PASS, 0 excluded.
  - Sabotages: every milestone all detected, tree unchanged, 127 in total (M0 6, M1 8, M2 5, M3 5, M4 7, M5 70, M6 15, M7 6, M8 5).
  - R3 null controls on the real tree: N-1 (tCtrlSuggest) and N-2 (tF16Uq) ran and were NOT detected (`null_controls_after_fix.json`).
  - S7C-4 and S7C-5 are therefore genuinely detected under the fixed harness.
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
# CHANGELOG fragment (uq2, 2026-10-09): M8 amendment after review R3

- Implemented the R3 amendment (docs/PLAN_M5_M8.md):
  - R3-M4: moving-limit re-search, at most 3 rounds, MOVING_LIMIT status.
  - R3-M3(a): longitudinal-only search of 3.2.x groups, gated by an invariance test (worst deviation 3.8e-14 against 1e-9).
  - R3-M3(b): spiral surrogate search, with candidates ranked by the surrogate.
  - R3-M2: "search estimate (upper bound), not a proof", the "sampled only" label, and the kinked-valley toy.
  - R3-M5: the MRC note, the Mahalanobis distance of each arg-min, and the effective CG-derivative ratios.
  - Minor items: m1 (tF16Uq hypothesis 2 is now a guard), m2 (joint coverage 0.9707), m4 (tF16Uq uses the longitudinal-only search), m6 (omitted groups listed), m9 (box-nesting sentence).
- New: +vital/+uq/searchPlan.m, surrogateWorst.m, mahalanobis.m, boxCoverage.m.
- Changed: +vital/+uq/boundWorst.m, analyze.m, F16Evaluator.m, writeReport.m, headline.m, and run_f16_uq.m.
- Tests:
  - New: tests/M8/tUqR3Fixes.m, tUqR3F16.m, tUqR3Report.m.
  - Changed: tBoundWorstToys.m (3 SUPERSEDED, 3' added) and tF16Uq.m (m1 relabel, hypothesis 9).
  - Sabotages: tests/M8/sabotages_uq2.json (S8V-1..4).
- **RED:** reports/work/uq2/M8_red_uq2.txt.
  - TOTAL 539, PASS 505, RED_EXPECTED 23, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 11, REGRESSION 0, EXCLUDED 0; gateOK 1.
  - The 11 VACUOUS are 8 unchanged tBoundWorstToys tests plus 3 guards of existing behaviour: lonLatInvariance, effectiveDerivativeRatios and kinkedValley.
- **GREEN:** reports/work/uq2/M8_green_uq2.txt. TOTAL 569, PASS 569, FAIL 0, EXCLUDED 0, VACUOUS 0, REGRESSION 0; gateOK 1; 1855 s.
- **Sabotage:** reports/work/uq2/M8_sabotage_uq2.txt and M8_sabotage_uq_R3.txt.
  - uq2: S8V-1..4, 4/4 DETECTED.
  - uq + R3: S8U-1..5 and S8R-1..8, 13/13 DETECTED.
  - Tree unchanged 1 in both runs.
- **Runtime:** tF16Uq took 408 s in the gate, against 794 s in R3's gate.
- **Not run:** the full default run_f16_uq (left to the coordinator), so reports/uq/f16_uq_default.* is stale.

## M8 default analysis re-run after the R3 amendment (2026-10-09, coordinator)
- `run_f16_uq('Overwrite', true)`, 5,272 s. Report: `reports/uq/f16_uq_default.md/.json`. The previous version is in git (commit 5085581).
- **Headline at x1:**
  - 13 groups ROBUST. 3.3.1.3-CatA/B are now ROBUST through the spiral surrogate: stable over the box. They were NOT_ASSESSABLE before.
  - 2 NOT_ROBUST, unchanged: 3.2.2.1.1-CatA (CAP, -0.005879) and 3.3.1.1-CatA-COGA (-0.09506).
  - 2 NOT_ASSESSABLE: 3.2.2.1.2-CatA (search value 0.0164) and -CatB (0.186). The cause is FC-901: the true minimum lies at a kink, as the kinked-valley toy predicts. R3's independent 2-D grid gives the same positive minima, so no violation is hidden.
- **Other widths:** x0.5 is ROBUST except 3.3.1.1-CatA-COGA. At x1.5 the NOT_ROBUST groups are 3.2.2.1.1-CatA, 3.2.2.1.2-CatA and 3.3.1.1-CatA-COGA.
# CHANGELOG fragment (uq3, 2026-10-13): M8 amendment R4 (judgment-light robustness)

## Implemented (docs/PLAN_M5_M8.md, "Amendment R4")
- **R4-1:** `vital.uq.csr`, the Critical Similitude Ratio. It brackets alpha* by bisection over box searches, with ray refinement and optimistic steps.
  - Two reference shapes: judged (k_g sigma) and equal percentage (10 %).
  - Statuses OK / ROBUST_TO_CAP / NOT_ASSESSABLE.
  - The CPV is confirmed by a fresh in-envelope assessment, with the moving-limit rule.
  - The report gives the parametric safety margin alpha* m.
- **R4-2:** `vital.uq.verdict(csr, mc)` gives the R4 headline. The box verdict `verdict(bw, mc)` is kept per width. Default WidthScales = 1; x0.5/x1.5 stay available.
- **R4-3:** `vital.uq.boundWorst(..., 'Method', 'grid')`: dense lattice grid, local refinement around the minimum, a Lipschitz certificate with factor 2 on the measured slopes, and the label "grid-certified (Lipschitz estimate)". A box without a certificate is NOT_ASSESSABLE with a reason starting 'GRID'.
- **R4-4:** `'Method', 'hybrid'`: `vital.uq.diffEvolution` (own seeded DE/rand/1/bin with bound reflection) followed by fminsearch with a bound transform. Per-stage convergence is in bw.stages. `vital.uq.searchMethod` picks grid for <= 2 searched parameters and hybrid above.
- **R4-5:** AeroScale Cm_basic (cmt at el = 0) and Cm_de (cmt - cmt(el = 0)). The default path is bit-identical, and Cm_table remains as the legacy field.
  - Spec `f16_uncertainty_v2`: pitchStatic = {Cm_basic, Cm_de}, sigma 0.05 each, d = 2.
  - The longitudinal search includes them, gated by tUqR4F16#lonLatInvarianceR4 at the CSR cap lateral corners. Worst deviation 5.2e-14 against a 1e-9 limit.
- **R4-6:** Cnr_table renamed Cn_r in config, loads, the spec and tests/M8. tests/M6/tAeroScale.m now uses 'Cx_q' as its unknown name, with a header note. No registered sabotage pattern named the field.

## Files
- **New:** +vital/+uq/csr.m, diffEvolution.m, searchMethod.m; tests/M8/tUqCsr.m, tUqGridCert.m, tUqHybrid.m, tUqR4F16.m, sabotages_uq3.json.
- **Changed:**
  - code: +vital/+uq/boundWorst.m, analyze.m, verdict.m, searchPlan.m, surrogateWorst.m, writeReport.m, headline.m; run_f16_uq.m; +vital/+aircraft/+f16/config.m and loads.m; the +vital/+fq/f16Factory.m header; uq/f16_uncertainty.json
  - tests/M8: tAeroScaleUq, tUqSpec, tUqR3, tUqR3F16, tUqR3Fixes, tF16Uq, tRunF16Uq, tUqR3Report (superseded parts marked)
  - tests/M6/tAeroScale.m (one line and a header note)

## Gates
- **RED:** reports/work/uq3/M8_red_uq3.txt.
  - TOTAL 600, PASS 527, RED_EXPECTED 31, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 42, REGRESSION 0, EXCLUDED 0; gateOK.
  - Every new test is RED_EXPECTED except tUqR4F16#defaultPathAndRename.
  - The 42 VACUOUS have unchanged expectations (renamed fields, legacy-pinned R3 classes, spec data written with the stubs, config guards).
- **GREEN, first run:** TOTAL 602, PASS 602; 3429 s.
- **GREEN, final** (after the cap fix): reports/work/uq3/M8_green_uq3.txt. TOTAL 603, PASS 603, FAIL 0, EXCLUDED 0, VACUOUS 0, REGRESSION 0; gateOK; 3311 s.
- **Runtimes in GREEN (class sums):** tUqCsr 11 s, tUqGridCert 37 s, tUqHybrid 3 s, tUqR4F16 119 s. Legacy classes: tF16Uq 662 s, tRunF16Uq 144 s, tUqR3Report 82 s.

## Sabotages
- **Pre-fix run** (reports/work/uq3/prefix_*):
  - uq3 S8W-1..6: 6/6 DETECTED
  - all M8 parts: 23/23 DETECTED
  - M6: 15/15 DETECTED
  - tree unchanged 1 in each
- **Final run** (after the cap fix; reports/work/uq3/M8_sabotage_uq3.*, M8_sabotage.*, M6_sabotage.*):
  - uq3 S8W-1..7: 7/7 DETECTED
  - all M8 parts (S8R-1..8, S8U-1..5, S8V-1..4, S8W-1..7): 24/24 DETECTED
  - M6: 15/15 DETECTED
  - tree unchanged 1 in all three runs

## Smoke run
- reports/uq/f16_uq_r4smoke.json/.md: 3 groups, reduced budget (NumCandidates 2, NumLHS 8, DE 8 x 3, Nelder-Mead 1 x 120, N 20).
- Final run, after the cap fix: 5205 s, 5505 single-point evaluations, run beside the sabotage runs.
- Results:
  - 3.2.2.1.1-CatA: x1 bound-worst -0.0624, VIOLATED. CSR judged alpha* 0.443 (CPV at 0.453, confirmed). Equal percentage: alpha* 0.809, i.e. an 8.1 % uniform tolerance. NOT_ROBUST.
  - 3.3.1.1-CatA-other and 3.3.1.3-CatA: CSR NOT_ASSESSABLE (judged alpha* in [0, 2.76] and [0, 1.81]). Cause: a point inside the 7-D boxes that is not OK (linearization not converged), and FC-901.
  - Every smoke verdict also fails the Clopper-Pearson bound, because N = 20 gives at most 0.861 (a budget artefact).
- See NOTES.md for the findings.

## Runtime estimate of the full default run (not run)
- **Per search.** A default 7-D hybrid search evaluates about 540 points x 4 candidates, roughly 2,200 single-point evaluations. A 3-D longitudinal search evaluates about 1,500. A smoke search evaluated about 560.
- **Searches per group.** The smoke run needed 3-5 box searches per group (x1 + CSR, both shapes). The default should be similar.
- **Total.** About 19 groups x 4.5 searches x roughly 1,800 evaluations, plus 19 x 200 Monte Carlo samples, is about 160k evaluations. At 0.35-0.4 s each in a single uncontended MATLAB that is about 15-18 h; at the 0.9 s observed beside other MATLAB jobs, about 40 h.
- **Lighter option.** NumCandidates 2 and DEGenerations 4 would roughly halve this.
# CHANGELOG fragment (uq4, 2026-10-14): M8 amendment R4b

## Implemented (docs/PLAN_M5_M8.md, "Amendment R4b")
- **R4-3 corrected:** `vital.uq.lattice`, ONE shared adaptive lattice for the longitudinal groups (dimension <= 3) over the AlphaMax box of the judged shape.
  - Each (point, condition) is evaluated once; one pointFcn call gives every group's margin. The results are reused by both shapes, every CSR alpha and every width box.
  - Certificate per cell: min vertex - sum L_i h_i, with L = 2 x the measured local slopes (own edges + the 3^d base neighbourhood).
  - Refinement only near the zero level set: uncertified cells that can still move alpha*, anisotropic.
  - Caps: MaxLevel 10 per axis; MaxPoints per group (20000 default, 6000 in analyze / run_f16_uq).
  - Per box: OK / VIOLATED / NOT_ASSESSABLE ('GRID'). alpha* is read from the lattice to 0.01, with the CPV confirmed by a fresh assessment and the moving-limit rule.
  - `analyze` uses it for every longitudinal group (plan.method 'lattice'); with a judged half-width below 10 % it falls back to vital.uq.searchMethod.
- **R4-7:** `vital.uq.breakpoints` (parsed from the generated aero.m) and `vital.uq.bracket` (eligibility, d = 1e-3 up to 1e-2, straddle + both OK, physical failures never bracketed).
  - `F16Evaluator`: option 'Bracket' (default true); worse of the two sides (`worseOf`); label BRACKETED; both values listed in E.bracketed / r.bracketed / the report.
- **R4-8:** `vital.uq.stageBudget` (stage 1: NumCandidates 2, DE 8 x 4, N 200 unchanged) and `vital.uq.stagePlan` (bracket overlapping [0.8, 1.2] or a budget NOT_ASSESSABLE; lattice groups never).
  - `analyze('Staged', true)`: run_f16_uq's default. The report column "decided by" and g.stage give the deciding stage.
- **R4-9:** `searchPlan('LatDropCmq', true)` (mode 'lateral', plan.dropped).
  - Runtime gate `vital.uq.invarianceCheck` at the critical condition with fallback `vital.uq.gatePlan`.
  - Class gate tUqR4bF16#lateralInvarianceCmq: worst deviation 9.4e-15 against a 1e-9 limit.

## Files
- **New:**
  - code: +vital/+uq/lattice.m, bracket.m, breakpoints.m, stagePlan.m, stageBudget.m, gatePlan.m, invarianceCheck.m
  - tests: tests/M8/tUqLattice.m, tUqBracket.m, tUqStaged.m, tUqR4bF16.m, sabotages_uq4.json
- **Changed:**
  - code: +vital/+uq/F16Evaluator.m, analyze.m, searchPlan.m, headline.m, writeReport.m; run_f16_uq.m
  - tests/M8/tUqR4F16.m: header 5c "plan.method 'grid'" marked SUPERSEDED BY R4b, and its assertion replaced by a comment; the replacement is tUqR4bF16 header 3d.
  - tests/M8/tF16Uq.m and tUqR3Report.m: their analyze calls add 'LatDropCmq' false (they keep the R3 design); header notes added; expectations unchanged.
  - tests/M8/sabotages_uq3.json: S8W-2 gets the extra target tUqR4bF16/nonLatticeEqualShape (see below); pattern unchanged.

## Gates
- **RED:** reports/work/uq4/M8_red_uq4.txt.
  - TOTAL 633, PASS 603, RED_EXPECTED 29, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 1, REGRESSION 0, EXCLUDED 0; GATE OK; 2350 s.
  - The one VACUOUS test, tUqR4bF16#lateralInvarianceCmq, is the R4-9 gate itself: a property of the existing chain that justifies the new plan, so it passes before the implementation by design.
- **GREEN:** reports/work/uq4/M8_green_uq4.txt. TOTAL 633, PASS 633, FAIL 0, EXCLUDED 0, VACUOUS 0, REGRESSION 0; GATE OK; 2769 s.
- **After GREEN:** tUqR4bF16 header 3g and the new method #nonLatticeEqualShape (header 4) were added; see "Sabotage coverage" below.
  - tUqR4bF16 and tUqR4F16 were re-run on their own: all 4 + 5 tests pass (nonLatticeEqualShape 50 s).
  - The full GREEN gate was NOT re-run after this addition (one new passing test). The coordinator's quiet-tree gate will include it.

## Sabotages
- **uq4 part (8):** reports/work/uq4/M8_sabotage_uq4.txt. S8X-1..8 8/8 DETECTED, tree unchanged.
- **All M8 parts, first run** (04:58): S8W-2 NOT DETECTED.
  - Cause: tUqR4F16#endToEndCsr's 1-parameter longitudinal group now runs on the lattice, whose equal shape is built on another line, so the sabotaged non-lattice line was no longer reached.
  - A first fix (tUqR4bF16#stagedEndToEnd, header 3g) still did not detect it, because that test's lateral group searches only Cn_r, whose sigma is 0.10 = EqualPct.
  - Final fix: the new test tUqR4bF16#nonLatticeEqualShape (Cm_de, sigma 0.05, 'Lattice' false: csr.equal.m = 0.10 exactly) is added as an S8W-2 target. A new sabotage S8X-9 covers the same bug on the lattice line.
- **All M8 parts, final run** (08:54): reports/work/uq4/M8_sabotage.txt. 33/33 DETECTED (S8R-1..8, S8U-1..5, S8V-1..4, S8W-1..7, S8X-1..9), tree unchanged 1, all detected 1.

## Evidence (pre-registered outcomes)
- **tUqLattice (toys, exact alpha*):**
  - LIN corner-first: judged alpha* 2 and equal 36/13, both bracketed to 0.01 with the CPV at the corner.
  - KINK, a hidden band found only by refinement: 1.45 / 1.45.
  - CAP: ROBUST_TO_CAP, exactly 1331 points.
  - LIP: L = [0.4 0.5 0.4] and bound 0.08 exactly.
  - NOM: alpha* 0. ML: c2 added, alpha* 2. NONOK: alphaLo 1.8 exactly. Caps: GRID.
  - Shared lattice (3 groups, 2 conditions): no (theta, condition) evaluated twice; the 1331 base points once at each condition; box queries at 12 alphas x 2 shapes x 3 groups add 0 calls; shared results isequaln single-group results.
  - Point counts to 0.01 (both shapes): LIN alone 18,999 lattice points, KINK alone 18,026.
- **tUqBracket:** every row as pre-registered.
- **tUqR4bF16#bracketKnownCase** (13,000 ft / M 0.45 / CG 20 %, the R4 smoke point):
  - Unbracketed: NOT_CONVERGED at linearize, alpha 5.000036.
  - Bracketed at d = 1e-3, side alphas 5.000692 / 4.999388.
  - 3.3.1.1-CatA-other L1 side margins 1.0366 (theta x 0.999) and 1.0358 (theta x 1.001); the point's margin is exactly 1.0358, the worse side.
  - 3 point evaluations.
- **tUqStaged:** truth tables as pre-registered.
- **tUqR4bF16#stagedEndToEnd:**
  - The lateral group (Cn_r) is re-run in stage 2 (1 -> 2 candidates).
  - The longitudinal group (Cm_q) is decided by the lattice in stage 1; the CPV is re-checked independently.

## F-16 lattice cost (measured; scratch probe = the code of the tree)
- Setup: vital.uq.analyze on 3.2.2.1.1-CatA alone, NumCandidates 2, N 20, LatticeMaxPoints 6000.
- The lattice used 5,994 points (cap reached): 11,987 single-point evaluations, 3 confirmations, 7,860 s (about 0.66 s per evaluation, run beside the GREEN gate).
- judged: NOT_ASSESSABLE ('GRID'), alpha* in [0.3375, 0.4875]. The CPV at 0.4875 is confirmed (margin -0.00147), so the verdict is NOT_ROBUST (a confirmed CPV inside the judged box).
- equal: alpha* in [0.626, 0.911] (6.3-9.1 %).
- x1 box: VIOLATED, -0.0374 at theta (Cm_q 0.845, Cm_basic 1.137, Cm_de 0.863).
- Consistent with uq3's hybrid R4 smoke result (judged alpha* 0.443, equal 0.81; uq3's x1 value -0.0624 lies in the corner, which this lattice resolves at only 4,578 points inside R(1)).
- With the literal certificate, the lattice did not close the bracket to 0.01 within 6,000 points per group.

## Smoke run (reduced; reports/uq/f16_uq_r4bsmoke.json/.md)
- **Command:** run_f16_uq('Groups', {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other', '3.3.1.3-CatA'}, 'Label', 'r4bsmoke', 'NumCandidates', 3, 'NumLHS', 8, 'NumStarts', 1, 'MaxEvals', 120, 'DEPopulation', 8, 'DEGenerations', 4, 'N', 60, 'LatticeMaxPoints', 3000), staged (the default).
  - Stage 1: NumCandidates 2, DE 8 x 4, N 60. Stage 2: NumCandidates 3.
  - N = 60 is the smallest N whose Clopper-Pearson bound can reach 0.95 (60/60 gives 0.9513).
- **Runtime:** 6,869 s; 9,284 single-point assessments, 48 cache hits, 13 full assessments.
  - It ran beside the all-M8 sabotage run. An earlier attempt was killed when the session ended and was re-run from scratch.
- **Shared lattice, 3.2.2.1.1-CatA:** 2 conditions; 2,993 lattice points (cap 3,000 reached); 5,985 point evaluations; 3 confirmations; 4,288 s (0.72 s per evaluation).
- **Headline:**
  - **3.2.2.1.1-CatA: NOT_ROBUST** (decided by stage 1, lattice).
    - x1 box VIOLATED, -0.0374.
    - CSR judged NOT_ASSESSABLE ('GRID', cap reached) with alpha* in [0.22, 0.60]. The CPV at 0.60 is confirmed (margin -0.00608 at 13,000 ft / M 0.45 / CG 30 %), so alpha*(judged) < 1 is established. Equal shape: in [4.6 %, 9.1 %].
    - MC 60/60 (CP 0.9513).
  - **3.3.1.1-CatA-other: ROBUST** (stage 1; bracket [2.75, 2.76] does not overlap [0.8, 1.2]).
    - CSR judged alpha* 2.75 (OK; CPV at 2.76 confirmed, margin -0.00248). Equal ROBUST_TO_CAP (>= 30 %).
    - x1 0.9025 OK; MC 60/60.
    - R4-9: searched without Cm_q, gate passed.
    - In the R4 smoke (uq3) this group was NOT_ASSESSABLE because of the breakpoint point (FC-950). In this run the search found no NOT_CONVERGED point, so R4-7 was not exercised (BRACKETED points: 0); it is shown on the known point by tUqR4bF16#bracketKnownCase.
  - **3.3.1.3-CatA: ROBUST** (stage 1; bracket [1.80, 1.81]).
    - Surrogate search: CSR judged alpha* 1.798 (OK; CPV at 1.81 confirmed, margin -0.00275 at 5,000 ft / M 0.55 / CG 20 %). Equal ROBUST_TO_CAP.
    - x1 Inf OK (stable spiral over the box); MC 60/60.
  - **Stage 2 re-ran no group** (no lateral bracket overlapped [0.8, 1.2]; no budget NOT_ASSESSABLE).

## Runtime estimate of the staged full default run (not run)
Rough, single uncontended MATLAB, about 0.4-0.7 s per closed-loop single-point evaluation:
- **Lattice (longitudinal groups, stage 1 only).**
  - Base: 1,331 points x the union of the groups' stage-1 candidate conditions (2 per group; about 6-10 distinct), i.e. 8k-13k evaluations.
  - Each group whose zero level set lies inside the cap box refines up to the cap: 6,000 points x 2 conditions, about 12k evaluations, 1.5-2.5 h per group.
  - 3.2.2.1.1-CatA does (measured: 5,994 points in 7,860 s at the 6,000 cap, still NOT_ASSESSABLE 'GRID' because the literal certificate needs more points). Assuming 2-4 such groups: 4-10 h.
- **Lateral groups (about 11), stage 1:** about 15-40 min each at the default NumLHS 32, DE 8 x 4 and Nelder-Mead 2 x 150 (the smoke measured 15 min per group at its reduced budget): 3-7 h.
- **Stage 2:** only groups whose bracket overlaps [0.8, 1.2] or are FC-901, at the full budget (about 40-60 min each); likely 0-4 groups: 0-4 h.
- **Monte Carlo:** 200 x about 19 groups, at the critical conditions: under 1 h.
- **Total:** about 10-20 h, dominated by the lattice. The longitudinal groups whose alpha* lies inside the cap will mostly end NOT_ASSESSABLE ('GRID'), with a bracket and, as for 3.2.2.1.1-CatA, possibly a confirmed CPV (then NOT_ROBUST). Resolving them to 0.01 would need either a larger LatticeMaxPoints (about 10k-20k per group, from the toys, i.e. hours more per group) or the geometric certificate (h/2), which is a coordinator decision.

## Axis-check figures: right-handed display and explanations (2026-10-14, coordinator; user request)
- **Finding (user):** in 04_combined, with North into the screen and Up up, East appeared on the left.
  - Cause: the drawing map (forward, right, down) -> plot (x, y, -z) is diag(1, 1, -1), i.e. North-East-Up, which is LEFT-handed (det -1).
  - 10 of the 13 figures were mirror images: yaw, pitch, roll, combined, level, climb, sideslip, gravity, control, path.
  - cg, station and earth were drawn correctly.
  - The 58 numeric checks were unaffected, because they are computed before drawing.
- **Independent verification of the frames themselves** (scratch script, not in the tree), all agree:
  - VITAL vs Aerospace Toolbox over 2,000 random attitudes:
    - dcm321 exact;
    - eul2quat equal up to the q / -q sign;
    - quat2dcm 7.8e-16;
    - dcm2eul 3.3e-15.
  - Through the plant:
    - +q gives +5 deg/s pitch rate;
    - +p gives +5 deg/s bank rate (right wing down);
    - heading 090 moves East at 172.4 m/s.
- **Fix:**
  - New `vital.viz.displayMap` (M = [0 1 0; 1 0 0; 0 0 -1], det +1: x = East / right, y = North / nose, z = Up), used by every 3-D figure. Labels updated.
  - The two side views now say which wing they are seen from.
  - New `vital.viz.axisNotes`: a per-case explanation and a per-check meaning, shown on each figure (an explanation panel plus a meaning line under each check).
  - `run_axis_checks` writes `reports/axis_checks/README.md`. The console output is unchanged.
- **Red-green:**
  - New `tests/M5/tAxisChecksDisplay.m`: 5 tests, pre-registered.
  - RED (`reports/work/axisdisplay/M5_red_axisdisplay.txt`): 5 RED_EXPECTED, 0 regressions.
  - New sabotages S5AX-5 (restore the mirrored map) and S5AX-6 (drop the meanings) in `tests/M5/sabotages_axisdisplay.json`.
  - New failure-catalogue row FC-519.
  - The 13 figures were redrawn and inspected.
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

## 0.8.1-OOP: object layer, atmosisa (2026-10-19)

**Result: GREEN 688/688, sabotages OOP 9/9 and M1 8/8 detected, 0 Level/status changes (reports/work/oop/levels_compare.md).**


## Implemented
- **Object layer** (ADR-037): vital.Aircraft, FlightCondition, TrimResult, LinearModel; vital.modes.Mode and subclasses ShortPeriod, Phugoid, DutchRoll, Roll, Spiral; vital.rules.Rule and RuleSet; vital.fq.Assessment; vital.atmos.Atmosphere and IsaAtmosphere; vital.ctrl.ControlLaw with PitchSasLaw, YawDamperLaw, NescLqrLaw, CombinedLaw; vital.uq.Study.
- **Atmosphere:** vital.env.atmosphere (an atmosisa wrapper with geopotential conversion, a range error and an exact one-entry cache). Every core caller uses it. vital.env.atmosphereUS76 is a thin alias.
- **Air data:** vital.airdata.tasToCasEas now uses the ISA sea-level constants (rho0 = 1.225, R = p0/(rho0 T0)), so CAS = EAS = TAS at sea level stays exact with atmosisa. tAirData was NOT edited.
  - vital.nesc.equivalentAirspeed keeps its US 1976 rho0, because it reproduces the NESC TM KEAS (proposed ADR N6).
- **Frames and geodesy:** NOT switched to the toolbox; each toolbox function measured 6-64x slower per call (ADR-037).
- **Version:** 0.8.1-OOP.

## User decisions 2026-10-19 and their execution
1. **Level tables re-run with atmosisa:** the default and exploration grids (run_f16_fq) and the M7 SAS suggestion (run_f16_sas('Suggest', true)).
   - Comparison: reports/work/oop/levels_compare.md. **0 Level or status changes.** This covers every group, record verdict, point status and envelope class, the SAS status, the rounded gains [0.02 0.14 0.82] and the confirmation Levels.
   - Margins moved by <= 6e-6, except the near-neutral spiral group 3.3.1.3 on the default grid (up to 3.4e-3; still Level 1, same verdict).
   - The regenerated reports are stored alongside the originals; nothing was overwritten: reports/fq/f16_fq_default_baseline_atmosisa.json/.md, f16_fq_exploration_baseline_atmosisa.json/.md, reports/ctrl/f16_sas_suggestion_atmosisa.json/.md.
2. **Re-baselined tests.** Each has the comment "re-baselined 2026-10-19 for atmosisa (ADR-037), was X, now Y, user-approved". Source tags are kept.
   - tests/M1/tAtmosphere.m:
     - seaLevel: rho0 changed to the ISA defining value 1.225.
     - deltaIsaShiftsTemperatureOnly: ISA's R.
     - tropopauseAnalytic: ISA closed form with ISA's R.
     - matchesAtmoscoesa: p and rho checked at 1e-6 below 10 km, 5e-6 over 0-32 km, and 1e-5 over 0-84.5 km. This tolerance was LOOSENED because atmosisa's R differs from US 1976 by 7e-7 and that enters the barometric exponent (measured 8.6e-6 at 84.5 km). T and a keep 1e-6.
   - tests/M1/tAirData.m#seaLevelCasEqualsTas: not edited; fixed in the core (tasToCasEas, above).
   - tests/M6/tF16FqR2.m#factoryMachUsesLocalSpeedOfSound: closed form with ISA's R.
   - tests/M7/tCtrlFq.m#defaultPathBitIdentical: CAP and zeta_d re-pinned (cited to the _atmosisa report).
   - tests/M7/tCtrlSuggest.m: now reads f16_fq_default_baseline_atmosisa.json. The pins work by reading this report file.
   - tests/M8/tF16Uq.m#pinnedSas: achievedMargin re-pinned from f16_sas_suggestion_atmosisa.json.
   - tests/M8/tUqR4bF16.m#bracketKnownCase: side alphas re-pinned to [5.000695 4.999390].
   - tests/M5/tLinearizeR1.m#windAirAxisConverters: 1e-8 changed to 5e-8 abs. This tolerance was LOOSENED. The reason is the rounding of the central-difference reference: |V| eps/h = 3.9e-8 with h = 1e-6. The measured error was 1.42e-8 = 2^-26, one rounding step.
3. **Atmosphere tolerance:** the revised tolerance (1e-6 below 10 km, 5e-6 over 0-32 km) was accepted. The original 1e-6 claim stays recorded as a failed hypothesis in tOopAtmosphere.
4. **Cache test and sabotage:** tOopAtmosphere#scalarCacheNeverStale added (FC-977), with sabotage SOOP-3 (stale cache). The guide fragment counts (25 tests, 9 sabotages) are now correct.

## Gates
- **RED:** reports/work/oop/M8_red_oop.txt. 24 new tests, all RED_EXPECTED, 0 RED_UNEXPECTED. scalarCacheNeverStale was added after the user's decision and did not go through a RED run; its sabotage SOOP-3 shows that it can fail.
- **First GREEN:** M8_green_oop.txt. 687 tests, 676 passed, 11 failed: the atmosisa value pins listed above.
- **Final GREEN:** M8_green_oop_final.txt (counts in the final report).
- **Sabotage:** M8_sabotage_oop.txt and M1_sabotage.txt.
