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
