## M7: baseline stability augmentation and design feedback (agent `ctrl`, 2026-10-06; quiet tree, only agent running)

| Step | Result | Evidence |
|---|---|---|
| RED | 32 new M7 tests in 6 classes, all RED_EXPECTED except tCtrlFq/defaultPathBitIdentical: RED_SUSPICIOUS, because isequal of two identical P structs that hold NaN is false. Fixed to isequaln before implementation; it is now the registered VACUOUS guard of the M6 path. 0 RED_UNEXPECTED, 0 REGRESSION, 0 EXCLUDED; gate OK | `reports/work/ctrl/M7_red_ctrl_run1.txt` (= `M7_red_ctrl.txt`) |
| GREEN (first) | 497 tests, all PASS (before the guard test regressionIsNotASuccess and the run_f16_sas status printout were added) | `reports/work/ctrl/M7_green_ctrl_run1.txt` |
| GREEN (final) | full M0-M7 gate: 498 tests, 498 PASS, 0 FAIL, 0 EXCLUDED, gate OK, 1464 s (33 M7 tests) | `reports/work/ctrl/M7_green_ctrl.txt` |
| Sabotage | S7C-1..6 all DETECTED; allDetected 1, tree unchanged 1 (quiet tree) | `reports/work/ctrl/M7_sabotage_ctrl.txt` |
| Demonstration | run_f16_sas('Suggest', true): TARGET_REACHED, Kq 0.02 s, Ka 0.14, Kr 0.82 s, confirmed over the 30 in-envelope points | `reports/ctrl/f16_sas_suggestion.md`, `.json` |

New:
- `+vital/+ctrl`: pitchSas, yawDamper, combine, nescLqr, closedLoop, suggestGains, inEnvelopeConditions, refAtTrim.
- `run_f16_sas.m` (user entry: bare vs augmented modes and Levels side by side; the suggestion on request).
- `tests/M7`: tCtrlLaws, tCtrlClosedLoop, tCtrlSimAgreement, tCtrlFq, tCtrlSuggest, tRunF16Sas, sabotages_ctrl.json.
- `reports/ctrl/f16_sas_suggestion.md` and `.json`.

Changed:
- `+vital/+fq/f16Factory.m`: option 'Controller' (a builder b(AC, env, tr)); default [] adds no field.
- `+vital/+fq/evaluatePoint.m`: with ac.controllerFcn, the closed loop is linearized, and info.closedLoop and info.equivalentSystem are set (3.1.12 flag). The default path is unchanged and bit-identical.

Results (README trim, 565.6854 ft/s, 10,013 ft, CG 25 %; 8-state modes):

| mode | bare | pitch SAS + yaw damper (suggested Kq 0.02, Ka 0.14, Kr 0.82) | NESC LQR (sasOn 1, apOn 0) |
|---|---|---|---|
| short period | -1.131 +/- 2.233i (wn 2.503, zeta 0.452) | -1.240 +/- 2.497i (2.788, 0.445) | -23.39 +/- 17.10i (28.97, 0.807) |
| phugoid | -0.0071 +/- 0.0745i (0.0748, 0.095) | -0.0072 +/- 0.0751i (0.0754, 0.096) | split: -16.03, -0.762 (NOT_OSCILLATORY) |
| Dutch roll | -0.389 +/- 3.296i (3.318, 0.117) | -1.847 +/- 2.879i (3.421, 0.540) | -1.429 +/- 6.009i (6.177, 0.231) |
| roll | -2.956 | -2.925 | coupled roll-spiral -37.23 +/- 37.09i (UNCLASSIFIED) |
| spiral | -0.0101 | -0.0623 | (in the coupled pair) |

Design feedback (in-envelope, confirmed by a fresh assessment):

| target | bare | augmented |
|---|---|---|
| 3.2.2.1.1-CatA | Level 2, m -0.280 (CAP 0.202 at 13,000 ft / M 0.63 / CG 30 %) | Level 1, m 0.0513 (13,000 / 0.45 / 30) |
| 3.3.1.1-CatA-other | Level 2, m -0.428 (zeta_d 0.109 at 13,000 / 0.63 / 20) | Level 1, m 1.218 |
| 3.3.1.1-CatA-COGA | Level 2, m -0.729 | Level 1, m 0.0538 |

No protected group is worse than bare, and no equivalent-system flag was raised.
