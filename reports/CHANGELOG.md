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
