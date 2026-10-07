# M5-C (agent `nesc`): rotating-Earth EOM and the NESC atmospheric check-cases

## Gate evidence (final, quiet tree, 2026-09-30)
- **RED** `reports/work/nesc/M5_red_nesc.*`, Increment {tRotatingEom, tF16ControlLaw, tNescCases01to10, tNescF16Cases, tNescF16Circles}, Baseline {tSimCore, tSimGuards, tF16Sim}:
  - PASS 247, RED_EXPECTED 51, RED_UNEXPECTED 0, RED_SUSPICIOUS 0, VACUOUS 0, REGRESSION 0, EXCLUDED 0; gateOK = 1
  - an earlier attempt had 1 RED_UNEXPECTED: the run_nesc_case stub's signature did not match; fixed and re-run
  - tests added after this RED run (`tNescCases01to10` failure modes, `tF16ControlLaw/stageFormHoldsTrimAndSteps` and `everyLimitIsObservableAndApplied`, `tNescF16Cases/nonOkTrimIsRefusedAndOverrideIsScoped`, the KNOWN tests) guard behaviour that already existed, so they could not be RED against a stub; each is shown to depend on its behaviour by a sabotage (S5C-4, 6, 7, 8-14)
- **GREEN** `reports/work/nesc/M5_green_nesc.*`, same Increment, Baseline {tSimCore, tSimGuards, tF16Sim, tSimR1, tLinearJacobian, tF16Linearize, tModes, tF16Modes, tLinearVsNonlinear, tClosedLoopLinearize, tLinearizeR1, tJacobianR1, tModesR1, tClosedLoopR1, tClosedLoopSimAgreement}:
  - **388 tests: PASS 388, FAIL 0, REGRESSION 0, EXCLUDED 0, gateOK = 1; 864.9 s**
  - an intermediate GREEN run had 2 FAILs in M0 `tSpecDocs`, caused by the pipe characters in the cells of FC-515 of the shared catalogue; fixed by the coordinator

| File | Time (final run) |
|---|---|
| tRotatingEom | 8.5 s |
| tF16ControlLaw | 1.2 s |
| tNescCases01to10 | 51.5 s |
| tNescF16Cases | 301.6 s |
| tNescF16Circles | 351.6 s |
| **M5-C total** | **714.5 s (11.9 min; the ~8-minute target is not met)** |

- **Runtime:** dt and tolerances were not touched.
  - The only pure-overhead saving found was building the control-law base input once (about 2 %, results bit-identical, checked on case 13.1). A trim cache was tried and removed (a trim costs 0.1-1.7 s).
  - Profile of stage-mode case 15 (3201 plant calls): F-16 aero `lookup` 22 % (vital.daveml.lookup, an M2 file), compiled GNC/control law 16 %, loads 43 % in total, the rest of the plant 15 %.
  - Every repeated run (case, step study, known-discrepancy tests) is already reused within one MATLAB session through the runCase cache.
  - Cases 15 and 16 are 180 s at dt = 0.005 s (144 000 plant calls each) and account for 350 s of the set.
- **Sabotages:** `tests/M5/sabotages_nesc.json`, S5C-1 ... S5C-14; `run_sabotage('M5','Parts',{'nesc'})`: **all 14 DETECTED, tree unchanged = 1, allDetected = 1** (`reports/work/nesc/M5_sabotage_nesc.*`).
  - S5C-4 had been NOT DETECTED: `saturationsAreApplied` drove each clamp to one side only (alpha = +60 reaches only the lower stick limit). Fixed by `everyLimitIsObservableAndApplied`, which drives all 22 limits on both sides with an observability assertion each.
  - S5C-8 ... S5C-12 and S5C-14 add one detected sabotage per remaining mixer total (totLatStk, totPedal, totThrottle), a pilot-input limit, the phiCmd limit and a GNC limit; S5C-13 covers `vital:nesc:notTrimmed`.

## Per-case result (worst envelope excess over the case's 25 band signals; <= 0 is inside)
| Case | Signals compared | Inside | Outside | Worst (signal: excess, excess/delta, t) | Verdict | VITAL run time (s) |
|---|---|---|---|---|---|---|
| 1 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009549, -0.955 delta, t=27.40 | PASS | 5.5 |
| 2 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009548, -0.955 delta, t=27.70 | PASS | 5.7 |
| 3 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009548, -0.955 delta, t=27.70 | PASS | 6.3 |
| 4 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009565, -0.956 delta, t=14.30 | PASS | 5.1 |
| 5 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009565, -0.956 delta, t=14.30 | PASS | 4.5 |
| 6 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009567, -0.957 delta, t=11.80 | PASS | 4.5 |
| 7 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009567, -0.957 delta, t=11.80 | PASS | 4.2 |
| 8 | 25 | 25 | 0 | speedOfSound_ft_s: -0.009567, -0.957 delta, t=11.80 | PASS | 3.5 |
| 9 | 25 | 25 | 0 | ambientPressure_lbf_ft2: -0.2083, -0.984 delta, t=0.10 | PASS | 5.1 |
| 10 | 25 | 25 | 0 | ambientPressure_lbf_ft2: -0.2083, -0.984 delta, t=0.10 | PASS | 4.4 |
| 11 | 25 | 24 | 1 | aero_bodyMoment_ftlbf_M: +2.821e-4, +69.4 delta, t=1.60 | FAIL (known) | 44.5 |
| 12 | 25 | 23 | 2 | aero_bodyMoment_ftlbf_M: +1.292e-4, +23.8 delta, t=0.40 | FAIL (known) | 38.1 |
| 13.1 | 25 | 19 | 6 | bodyAngularRateWrtEi_deg_s_Pitch: +0.2573, +7.63 delta, t=5.20 | FAIL (known) | 17.9 |
| 13.2 | 25 | 22 | 3 | aero_bodyMoment_ftlbf_N: +1.429, +7.37 delta, t=0.00 | FAIL (known) | 14.9 |
| 13.3 | 25 | 15 | 10 | bodyAngularRateWrtEi_deg_s_Pitch: +0.2161, +21.6 delta, t=15.80 | FAIL (known) | 20.8 |
| 13.4 | 25 | 11 | 14 | aero_bodyMoment_ftlbf_N: +9.299e4, +654 delta, t=20.00 | FAIL (known) | 42.6 |
| 15 | 25 | 15 | 10 | aero_bodyMoment_ftlbf_N: +3143, +7.33 delta, t=0.00 | FAIL (known) | 136.4 |
| 16 | 25 | 18 | 7 | aero_bodyMoment_ftlbf_N: +39.17, +9.56 delta, t=37.30 | FAIL (known) | 136.1 |

- "Worst" for the passing cases is the signal with the smallest margin. Cases 1-10 are PASS on every signal.
- 53 of the 200 F-16 band signals are outside (36 in 11-13.4, 17 in 15-16). They are listed with their measured excesses in the `KNOWN` tables of tests/M5/tNescF16Cases.m and tNescF16Circles.m. Causes and evidence are in NOTES.md section 3.
- Run times are for the working dt. The step-size studies are extra.

## Decisions (reports/fragments/nesc/DECISIONS.md)
- N1-N11 proposed before any comparison run.
- N6r (continuous-time evaluation of the stateless law), N6c (Earth-relative rates to the law) and N11r (revised F-16 dt and studies) were changed after comparison runs, on documented evidence. No band, tolerance or expected value of NESC_CASE_MATRIX.json was changed.
