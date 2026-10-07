# VITAL agent brief (every implementation and review agent reads this first)

VITAL (Virtual Test and Analysis Lab) is a MATLAB flight-simulation and virtual-certification framework in `C:\VITAL`. The baseline aircraft is the NASA NESC F-16 (DAVE-ML). M0–M4 are closed: foundations, DAVE-ML import, flat-earth plant, and trim reproducing NASA's published answers. You are building part of M5–M8 under `docs/PLAN_M5_M8.md`, which is your contract.

## Read before writing anything
1. `docs/PLAN_M5_M8.md`: scope, owners and the **interface contract**.
2. `docs/CONVENTIONS.md`: units (SI inside), frames, quaternion, Euler 3-2-1, control signs, trim status codes, error identifiers, evidence tags.
3. `docs/DECISIONS.md` and `docs/FAILURE_CATALOGUE.md`.
4. Test style:
   - `+vital/+test/VitalTestCase.m`: `verifyTol(act, exp, tol, 'abs'|'rel', SOURCE, citation, 'Quantity', q, 'Unit', u)`, `verifyWithin`, `verifyExact`.
   - `tests/M4/tF16Trim.m` and `tests/M4/tF16LoadsReport.m`: pre-registered headers, failure-mode tests.
5. The code you build on:
   - `+vital/+plant/derivatives.m` and `+vital/+trim/solve.m`
   - `+vital/+aircraft/+f16/config.m`, `loads.m` and `trimLevel.m`
   - `+vital/+eom/rigidBodyDerivs.m`
6. The runner: `run_vital_tests.m` (header) and `run_sabotage.m`.

## Environment
- MATLAB R2025b is installed: Aerospace Toolbox/Blockset, Optimization, Statistics, Simulink, Symbolic.
- **Not installed:** Control System, Global Optimization, Parallel Computing and Stateflow. Use `eig`, your own RK4 and serial loops.
- Run MATLAB only as `matlab -batch "restoredefaultpath; cd C:\VITAL; <commands>"`. Use the PowerShell or Bash tool. Allow long timeouts; a full gate takes a few minutes.
- No git or version control. `data/` is read-only and SHA-256 verified; never write there.
- Scratch files go in your own temp folder, never in the VITAL tree. Reports go in `reports/work/<agent>/`.

## The red-green method (mandatory, in this order)
1. **Tests and stubs.** Write the test files first, tagged `TestTags = {'M<k>'}` in `tests/M<k>/`.
   - Put every expected value and tolerance, with its rationale and source (PUB/INDEP/ANALYTIC/REG), in the class header **before** the implementation exists. That is the pre-registration.
   - Stubs call `vital.notImplemented('name')`, and any argument blocks must match the stub's signature.
   - Include failure-mode tests. Each asserts an **exact** error identifier `vital:<area>:<condition>` with `verifyError`, or an exact status string.
2. **RED run:**
   ```
   s = run_vital_tests('M5', 'Phase', 'red', 'Increment', {'tYourClass1','tYourClass2'}, 'Baseline', {<finished M5 classes, if any>}, 'Tag', '<agent>', 'ReportDir', 'C:\VITAL\reports\work\<agent>', 'Quiet', true)
   ```
   Requirements:
   - `s.gateOK` must be true.
   - Every new test must be `RED_EXPECTED`.
   - There must be 0 REGRESSION and 0 EXCLUDED.
   - Any VACUOUS test (already passing) must be justified in writing, e.g. as a guard on existing behaviour. Otherwise fix the test so it genuinely depends on the new code.
   - RED_SUSPICIOUS or RED_UNEXPECTED means the test is wrong. Fix it and re-run.
3. **Implement.**
4. **GREEN run:** the same command with `'Phase', 'green'`. Everything up to and including your increment must pass.
5. **Sabotages.** Put 2–5 in `tests/M<k>/sabotages_<agent>.json`, as an array of `{id, file, pattern, replacement, targets, rationale}`.
   - The pattern must occur exactly once in the file.
   - Use ids like `S5A-1`.
   - Each sabotage models a realistic bug (a sign, a missing term, a skipped guard, a wrong index).
   - Run `run_sabotage('M5', 'Parts', {'<agent>'}, 'ReportDir', 'C:\VITAL\reports\work\<agent>')`. Every sabotage must be DETECTED.
   - "Tree unchanged: 0" is expected while other agents are editing, so ignore it. The coordinator re-runs on a quiet tree.
6. **If a pre-registered expectation fails**, do not loosen the tolerance and do not change the expected value to match your output.
   - Investigate, and find the physics or the bug.
   - If the expectation itself was wrong, record it as a failed hypothesis. Keep the original in the test header (see `tests/M4/tF16Trim.m` hypothesis 3), add a corrected test with an independent justification, and report it.

## Rules
- **Files.**
  - Touch only the packages and files your task assigns you.
  - Never edit another agent's files. Never edit the shared documents (CONVENTIONS, DECISIONS, FAILURE_CATALOGUE, VERIFICATION_MATRIX, PLAN, MILESTONES, CHANGELOG, `+vital/version.m`) or earlier milestones' tests.
  - If you need a shared change, write it to `reports/fragments/<agent>/`:
    - `DECISIONS.md` (proposed ADR text)
    - `FAILURE_CATALOGUE.md` (rows in the catalogue's six-column format, with real test references)
    - `CHANGELOG.md` (your gate evidence)
    - `NOTES.md` (open issues, doubts, anything unverified)
- **Physics conventions:** SI internally; English units only at boundaries and in user printouts; the conventions of CONVENTIONS.md.
- **No silent fixes.**
  - Never clamp, catch-and-ignore, or return a plausible number when the answer is unknown.
  - Report a status (`NOT_CONVERGED`, `NOT_ASSESSABLE`, ...) or raise an identified error.
- **Honest evidence tags:**
  - PUB: a published value with a citation.
  - INDEP: an independent implementation.
  - ANALYTIC: a closed form in the test.
  - REG: a pre-registered expectation without an external answer.
  - Never label a regression-only value as PUB.
- **MATLAB pitfalls found in this project:**
  - A test class method must not be named `run`.
  - Do not `warning('off','all')` around a gate; tests check warnings.
  - The function line and the `arguments` block must list the same inputs.
  - A test file that fails to parse is EXCLUDED and fails the gate.
  - `jsondecode` turns arrays of objects into struct arrays.
- **Keep tests fast.** Aim for under about 60 s per test file, with time simulations as short as the evidence allows.
- **Style:** match the surrounding code, i.e. function headers with a usage block, units, errors and sources, and comments where the physics needs them.

## Final report to the coordinator (your last message)
- The files you created or changed.
- The RED report path and counts, the GREEN report path and counts, and the sabotage results.
- Each pre-registered expectation and its outcome, including any failed hypotheses.
- Anything unverified, any assumption you made, and any doubt about the physics.
- The fragment files you wrote.
