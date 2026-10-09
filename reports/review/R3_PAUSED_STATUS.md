# R3 review: paused 2026-10-08 (user request)

## Where things stand
- **M0-M7 closed.** M7 was closed 2026-10-07.
- **M8 built and verified by the coordinator, NOT closed.**
  - Gate: 539/539.
  - Sabotages: 126/126 across M0-M8.
  - ADR-032 and FC-901..913 merged.
  - Report: `reports/uq/f16_uq_default.md`.
- **R3 review (independent, read-only) was stopped part-way.** Its draft is `reports/review/R3_REVIEW.md` and its runs are in `reports/work/R3/`.

## What R3 had finished
- **Gates re-measured:**
  - M8 GREEN: 539/539, 0 excluded.
  - M7 sabotages: 6/6 DETECTED.
  - M8 sabotages: 5/5 DETECTED.
- **Independent physics checks: all agree with the claims.**
  - Closed loop A + B K matches to 3e-11.
  - The M7 gains give Level 1.
  - k_g and Clopper-Pearson values are exact.
  - The CAP NOT_ROBUST counterexample (margin -0.00588) reproduces.
  - The four NOT_ASSESSABLE groups are conservative, not hidden failures.
- **Draft findings:**
  - **B1 BLOCKER: the sabotage harness gives vacuous detections for tests that read `reports/`.**
    - Cause: `applySabotage.m:20` does not copy `reports/`. `tCtrlSuggest` and `tF16Uq` read report files, so any change "fails" them, even a null change in a comment.
    - Effect: M7's S7C-4 and S7C-5 were never really proven.
    - Fix: give the harness a reports root (like `VITAL_DATA_ROOT`); add a null-sabotage self-test; re-run all sabotages; long-term, pin the expected values in the test headers.
  - **M1:** M7 gains not pinned to a live re-derivation.
  - **M2:** fmincon "converged" taken at face value on a nonsmooth objective; no toy with a kink.
  - **M3:** the four NOT_ASSESSABLE groups are cheap to resolve.
  - **M4:** a moving limit leaves the status OK without re-searching at the moved condition.
  - **M5:** Cm_table scales Cm0, M_alpha and M_de together.
  - **M6:** gaps exposed by the proposed sabotages.
  - MINOR items: see the draft.
- **Proposed sabotages** (`reports/work/R3/proposed_sabotages.json`):

| Result | Sabotages |
|---|---|
| DETECTED | S8R-3, S8R-4, S7R-4, S7R-5 |
| **NOT DETECTED** | S8R-5 (+Inf bound-worst becomes ROBUST), S8R-6 (non-OK partial margin), S7R-3 (3.1.12 flag) |
| PENDING (not run) | S8R-1, S8R-2, S8R-7, S8R-8, S7R-1, S7R-2, the S7C-4/S7C-5 re-check with reports present, and the null control N-1 |

## To resume
1. Restart R3 (read-only), pointing it at this note and its draft. It should:
   - finish the PENDING sabotage checks, with `reports/ctrl` and `reports/fq` copied into the sabotage copy;
   - confirm the null control N-1 is NOT DETECTED;
   - finalize `R3_REVIEW.md`.
2. Bring the findings to the user. Then, one fix agent at a time:
   - fix B1 (harness);
   - re-run every milestone's sabotages;
   - add tests for the undetected sabotages;
   - decide M1-M5: fix them, or accept them in `M8_acceptance`;
   - amend the M7 acceptance note: 121/121 included two vacuous detections.
3. Close M8 only on the user's decision.
4. Not pushed to git yet: the M7 closure, all of M8, the merged docs and R3. `newtest` holds only the SciComp commit; the user picks the commit message.
> 2026-10-09: R3 resumed and COMPLETED. Final review: R3_REVIEW.md. Fixes not started (awaiting the user).
