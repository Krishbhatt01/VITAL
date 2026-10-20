# VITAL plan: M5 to M8 (F-16 baseline)

Authorized by the user on 2026-09-29: "plan and implement till M8. Use different agents to coordinate and ensure everything is working well and implemented correctly. Follow failure-test methods."

Every increment follows the same red-green discipline:
1. **Tests and stubs first.** Expectations and tolerances are pre-registered in each test file's header, before the implementation exists.
2. **RED run.** Every new test must be `RED_EXPECTED`, with 0 regressions. VACUOUS tests are only allowed when justified (e.g. guards on existing behaviour).
3. **Implement.**
4. **GREEN run** of everything up to and including the milestone.
5. **Sabotage run.** Every registered sabotage must be detected.
6. **Independent review** by a separate agent that did not write the code.

A tolerance is **never** loosened after a failing run. A failed pre-registered expectation is recorded as a failed hypothesis, as tF16Trim hypothesis 3 was, together with its corrected physics.

## Milestones and increments

| Increment | Scope | Owner (agent) | Depends on | Test tag / folder |
|---|---|---|---|---|
| M5-A | Linearization (step-study central differences) and flight modes (ported AAMF classifier + participation factors), `run_f16_modes`, aileron/rudder limits | `linear` | M4 | M5, `tests/M5` |
| M5-B | Fixed-step RK4 time simulation with discrete ZOH controller, inputs, guards, `run_f16_sim` | `sim` | M3 | M5 |
| M5-X | Linear-vs-nonlinear cross-check (perturbed-trim response) | `linear` (second task) | M5-A, M5-B | M5 |
| M5-C | Rotating WGS-84 EOM, NESC cases 1–10 (sphere, brick, cannonball), F-16 cases 11, 12, 13.1–13.4 (15, 16 per the case matrix) with the NESC control laws compiled from DAVE-ML | `nesc` | M5-B | M5 |
| M6 | MIL-F-8785C Class IV flying-qualities engine: curated rule records, metric extractors, status-aware condition search, Level + margin reports, pre-registered mutations | `fq` | M5-A (M5-B for time-domain metrics) | M6, `tests/M6` |
| M7 | Baseline pitch SAS + yaw damper (and the NESC LQR as a second controller); closed-loop linearization; design feedback confirmed by re-run | `ctrl` | M5-B, M6 | M7, `tests/M7` |
| M8 | Uncertainty: judgment-width groups, bound-worst margin over the joint-coverage box, Monte Carlo at the critical condition, Clopper–Pearson, Robust verdict | `uq` | M6, M7 | M8, `tests/M8` |

**Review agents** (read-only on implementation):
- R1 after M5-A/B
- R2 after M5-C and M6
- R3 after M7 and M8
- a final holistic review

Each one:
- re-runs the gates
- audits the tests for vacuity, weak tolerances and wrong physics
- proposes additional sabotages, which the coordinator registers and runs

## Parallel-work rules (enforced by infrastructure added before M5)
- `run_vital_tests('M5', 'Phase', 'red', 'Increment', {classes}, 'Baseline', {done}, 'Tag', 'A', 'ReportDir', ...)`. Other increments' unfinished tests are skipped, so they cannot break this gate. The full gate (no options) still runs everything.
- Sabotages go in `tests/M<k>/sabotages_<part>.json`, and `run_sabotage('M5', 'Parts', {'A'})` runs one part.
  - The tree-hash check assumes a quiet tree, so a hash mismatch during parallel work is not evidence of harm.
  - The coordinator runs the authoritative sabotage check with the tree quiet.
- **Shared documents are edited only by the coordinator:** CONVENTIONS, DECISIONS, FAILURE_CATALOGUE, VERIFICATION_MATRIX, CHANGELOG, `version.m`.
  - Agents write fragments to `reports/fragments/<agent>/`: `DECISIONS.md` (proposed ADRs), `FAILURE_CATALOGUE.md` (rows), `CHANGELOG.md`, `NOTES.md` (open issues).
- **Failure-catalogue rows for an open milestone** may stay `PLANNED` until the milestone closes. A closed milestone must have every row pointing at a real test (`docs/MILESTONES.json`).

## Interface contract (agents must not change these without the coordinator)

### Plant (existing, M3)
```
[xdot, y] = vital.plant.derivatives(x, u, AC, env)
```
- `x` has 13 elements: v_b, w_b, q (N→B), p_n.
- `u = [de da dr throttle]`.
- M5-B may **add** diagnostic fields to `y` (e.g. `quatNorm`, `nz`) but must not change existing ones.

### M5-A linear
```
lin = vital.linear.linearize(AC, env, tr, 'Name', value, ...)
```
- `tr` must have status OK, otherwise error `vital:linear:notTrimmed`.
- **State:** `x_lin = [u v w p q r phi theta psi pN pE h]` (12, SI, rad).
- **Output fields:**
  - `A` (12×12), `B` (12×4), `stateNames`, `inputNames`, `x0`, `u0`, `status` ('OK' | 'NOT_CONVERGED'), `reason`, `stepStudy`
  - `lon` (states u w q theta), `lat` (states v p r phi)
  - converters to `[V alpha q theta]` and `[beta p r phi]`
- Option `'Controller'` (M7) linearizes the closed loop.

```
J = vital.linear.jacobian(f, z0, h0, ...)
```
The generic step-study central difference, with FC-506 when no step plateau is found.

```
m = vital.linear.modes(lin)
```
Returns a struct array, one entry per mode, with fields:
- `name`: short_period | phugoid | dutch_roll | roll | spiral | other
- `eigenvalue`, `oscillatory`
- `wn`, `zeta`, `period`, `tHalf`, `tDouble`, `tau`
- `participation` (over the 8 states u v w p q r phi theta), `dominant`
- `status`: OK | NOT_OSCILLATORY (FC-507) | UNCLASSIFIED

Oscillatory pairs are reported once.

### M5-B sim
```
out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', T, 'Inputs', f, 'Controller', c, 'Plant', p, 'Guards', g)
```
- `Inputs`: `du = f(t)`, an additive control perturbation evaluated at the RK4 stage times, piecewise functions stepping exactly on step boundaries.
- `Controller`: a struct with fields `rate_hz`, `init` and `step`, where `[u, state] = step(t, x, y, u_ref, state)`. It is zero-order held across RK4 stages; `rate_hz` must divide 1/dt.
- `Plant`: a function handle with the plant signature (default `@vital.plant.derivatives`). The state is layout-agnostic; guards use `y` fields.
- **Output fields:** `t`, `x`, `u`, `y` (a struct of logged time series), `status` ('COMPLETED' | 'STOPPED'), `stopReason` (an identifier), `stopTime`.
- **Stop reasons:**
  - `vital:sim:nanState` (FC-302)
  - `vital:sim:quatNorm` (FC-601)
  - `vital:sim:envelope` (FC-602)
  - `vital:sim:ground`
  - `vital:sim:plantError`
- A bad `dt`/`tFinal` is an error `vital:sim:badStep` (FC-301).
- `vital.sim.rk4(f, x0, dt, N)` is the integrator core (used by the order tests).
- Input helpers: `vital.sim.doublet(t0, width, amp, channel)`, `vital.sim.stepInput(t0, amp, channel)`.

### M5-C rotating Earth
- `vital.plant.derivativesRotating(x, u, AC, env)`: WGS-84 or sphere, J2 or central gravitation per the TM, and its own state layout (documented).
- It runs through `vital.sim.run` via `'Plant'`.
- `vital.nesc.runCase(id)` returns time series in NESC signal names and units. The comparison uses `vital.verify.envelopeCheck` with the **pre-registered bands in `docs/NESC_CASE_MATRIX.json`**.

### M6 flying qualities
- Rules: `vital.fq.loadRules(folder)`, where each record passes `vital.io.validateRule`.
- `res = vital.fq.assess(rules, acFactory, conditions, ...)`:
  - per rule: Level, normalized margin, critical condition and status
  - non-OK points never improve a verdict (FC-702)
  - all points infeasible gives `NOT_ASSESSABLE` (FC-701)
- Metric extractors: `vital.fq.metrics(lin, modes, ...)`.

### M7 control
- Controllers follow the M5-B controller struct.
- `vital.ctrl.pitchSas`, `vital.ctrl.yawDamper`, `vital.ctrl.nescLqr`.
- Design feedback: `vital.ctrl.suggestGains(...)` must be confirmed by re-running `vital.fq.assess`.

### M8 uncertainty (contract fixed by the coordinator on 2026-10-07, before any M8 code)
**Question.** Does the augmented F-16's in-envelope MIL-F-8785C Level (M7 gains Kq 0.02 s, Ka 0.14, Kr 0.82 s) still hold when the aerodynamic data are uncertain?

**Uncertain parameters** are multipliers on NASA table terms (`AeroScale`, nominal 1). The 1-sigma widths are **engineering judgments, not published values**, and every report labels them `JUDGMENT`:

| Group | Parameters (AeroScale field: term scaled) | sigma | d | k_g = sqrt(chi2inv(0.99, d)) |
|---|---|---|---|---|
| pitchDamping | `Cm_q` (cmq) | 0.10 | 1 | 2.5758 |
| pitchStatic | `Cm_table` (cmt) | 0.05 | 1 | 2.5758 |
| latDamping | `Cl_p` (clp), `Cn_r` (cnr) | 0.10 | 2 | 3.0349 |
| latStatic | `Cl_table` (clt), `Cnt_table` (cnt) | 0.05 | 2 | 3.0349 |

- Rationale: damping (rotary) derivatives are less certain than static tables, so their sigma is doubled.
- `Cm_table`, `Cl_table`, `Cn_r` are new `AeroScale` fields. Every multiplier equal to 1 leaves the generated model untouched (bit-identical default path, as ADR ctrl-4).
- Parameters are independent normal N(1, sigma) for the Monte Carlo.

**Joint-coverage box.** Per group, half-width k_g * sigma, so the box contains the group's 99 % joint ellipsoid. The full box is the product of the group boxes.

**Bound-worst margin** (`vital.uq.boundWorst`), per target group, margin to its nominal in-envelope headline Level:
- Candidate conditions: the group's nominal critical condition plus the next 3 in-envelope conditions by margin.
- Search, all points kept: centre, 2^6 corners, a seeded Latin-hypercube sample of 32 points, then `fmincon` (sqp) from the 2 best points with a budget of 60 evaluations each.
- Bound-worst = minimum over every evaluated point. The arg-min parameters and condition form the active set.
- **Confirmation:** a fresh in-envelope `vital.fq.assess` of the augmented aircraft at the arg-min parameters. If it finds a smaller margin at another condition (a moving limit), that value and condition replace the search value, and the report says so.
- Status:
  - `OK`: the search converged and every evaluated point was OK.
  - `VIOLATED`: some evaluated point has margin < reserve. A found counterexample is definitive, even if the optimizer did not converge.
  - `NOT_ASSESSABLE`: optimizer not converged without a counterexample (FC-901), or a non-OK point inside the box (trim infeasible, metric NaN, ...).

**Monte Carlo** (`vital.uq.monteCarlo`): N = 200, seeded (`rng(2026, 'twister')`), at the group's nominal critical condition only, serial.
- Success = the group's Level at that condition is at least as good as the nominal headline Level.
- A non-OK sample counts as a failure and is listed.

**Clopper–Pearson** (`vital.uq.clopperPearson(x, n, conf, 'Sided', 'lower'|'two')`): exact binomial bounds via `betainv`. The verdict uses the one-sided 95 % lower bound.

**Verdict** (`vital.uq.verdict`), per group:
- `ROBUST`: bound-worst status OK with margin >= reserve (0), and the Clopper–Pearson lower bound >= 0.95.
- `NOT_ROBUST`: a violation was found, or the lower bound < 0.95.
- `NOT_ASSESSABLE`: anything else.
- The same verdict is also computed with all widths x0.5 and x1.5 and reported beside the headline (x1 only) as the sensitivity to the judgment.

**Entry point.** `run_f16_uq` writes `reports/uq/f16_uq_<label>.json/.md`. Default: the in-envelope conditions of `vital.ctrl.inEnvelopeConditions`, every group with a finite in-envelope headline Level.

**Pre-registered tests (tests/M8):**
- Toy counterexamples (closed-form margin functions, no aircraft):
  1. Cliff just outside the box: never seen; bound-worst = the in-box minimum.
  2. Interior interaction valley, off both axes: a one-at-a-time sweep misses it, boundWorst finds it.
  3. Moving limit: the critical condition changes with the parameter (gradient 0.100); the confirmation catches the move.
  4. Active-set switch inside the box: the reported critical record switches.
- Clopper–Pearson against closed forms: x = 0 and x = n, and the two-sided identity.
- An optimizer that does not converge gives NOT_ASSESSABLE.
- An F-16 run on 2 groups (3.2.2.1.1-CatA, 3.3.1.1-CatA-other). Structural invariants only, since no published answer exists:
  - bound-worst <= nominal margin
  - bound-worst is non-increasing with width (x0.5, x1, x1.5)
  - every Monte Carlo sample inside the box has margin >= bound-worst
  - d margin(3.3.1.1-CatA-other)/d Cn_r > 0 (more yaw damping, more Dutch-roll damping)
- `AeroScale` default path bit-identical.

**Amendment after review R3** (coordinator, 2026-10-09; the user approved the fix/accept split). It supersedes the M8 contract above where they differ. Original pre-registrations are kept in the test headers and marked superseded.

- **R3-M4, moving limit: re-search.**
  - If the confirmation finds a smaller margin at a condition that was not a candidate, that condition is added to the candidates and the search is re-run.
  - This repeats until the confirmation no longer moves, at most 3 rounds.
  - The status can be `OK` only if the final confirmation did not move. If it still moves after 3 rounds, the status is `NOT_ASSESSABLE` with a reason starting `MOVING_LIMIT`.
  - The report lists each round.
- **R3-M3, the four NOT_ASSESSABLE groups.**
  - **(a) Longitudinal groups (3.2.x) are searched over the longitudinal parameters only** (pitchDamping, pitchStatic), with the lateral parameters held at 1.
    - Justification: at a wings-level, beta = 0 trim the lateral multipliers do not change any longitudinal metric. This must be shown by a test at several in-envelope conditions and box corners, within 1e-9 relative. If it is not shown, (a) is not used.
    - Lateral groups keep the full box, because Cm_table moves the trim.
  - **(b) Groups whose margin is +Inf (3.3.1.3 spiral) are searched on a smooth surrogate:** the spiral root's real part. The search maximizes it (the most unstable spiral) over the box.
    - If the converged maximum is <= 0, the spiral is stable over the whole box. The bound-worst is +Inf with status `OK`, and the report says "stable over the box (surrogate search)".
    - If it is > 0, the time-to-double margin is computed at that point.
    - Candidate conditions for +Inf groups are ranked by the same surrogate, never by grid order.
- **R3-M2, nonsmooth objectives: accept, document and add one toy test.**
  - The report states that the bound-worst is a search estimate (an upper bound on the true minimum), not a proof.
  - Groups whose metric is binary or flat (3.3.1.4) are labelled "sampled only".
  - A new toy: a kinked interior valley, the minimum of two planes. Its expected status is pre-registered before the run.
- **R3-M5, Cm_table: accept and document.**
  - The report says that every multiplier acts on NASA's tables about the MRC (35 % MAC). Cm_table scales Cm0, M_alpha and M_de together, so it also moves the trim and the SAS's elevator authority.
  - The report prints the Mahalanobis distance of each arg-min.
  - A REG test gives the effective derivative ratios at the CG for Cm_table, Cl_table and Cnr_table at their x1 box edges.
- **Minor items in the same change:**
  - m2: print the joint-box coverage (0.9707 at x1).
  - m6: list the groups omitted for a NaN headline, with the reason.
  - m9: add a sentence that robustness of a box implies robustness of the boxes it contains, and that NOT_ASSESSABLE means "not established", not "fails".
  - m1: re-label tF16Uq hypothesis 2 as a guard.
  - m4: tF16Uq uses the longitudinal-only search where (a) applies, to cut its runtime.

**Amendment R4: judgment-light robustness** (coordinator, 2026-10-13; approved by the user after a literature review). It supersedes earlier M8 text where they differ. Original pre-registrations stay in the test headers, marked superseded.

Basis:
- Crespo, Kenny and Giesy (NASA LaRC), "A Verification-driven Approach to Control Analysis and Tuning": the Critical Similitude Ratio (CSR), the Critical Parameter Value (CPV) and the Maximal Set.
- GARTEUR FM-AG11 (NLR-TP-2004-147): optimisation-based worst-case search is the most promising clearance method. A global search does not guarantee the worst case, so hybrid global + local search is preferred.
- No published uncertainty exists for the NESC F-16 tables, so the widths stay a labelled JUDGMENT. The conclusion is made to depend on them as little as possible.

- **R4-1, CSR is the headline.**
  - For each group, alpha* is the largest scaling alpha in [0, AlphaMax = 3] of a reference box about the nominal, R(alpha) = [1 - alpha m, 1 + alpha m], for which the in-envelope margin to the nominal Level stays >= 0.
  - CPV = the parameter vector where the box first touches failure. The report also gives the parametric safety margin alpha* m in physical (multiplier) units.
  - Two reference shapes: (a) the judged half-widths m = k_g sigma (x1), the headline; (b) equal percentage, m_i = 0.10 for every parameter. That makes alpha* x 10 % the tolerated uniform tolerance, a cross-check that removes the judged ratios between parameters.
  - **Status:**
    - `OK`: alpha* found to +/- 0.01, with a confirmed CPV.
    - `ROBUST_TO_CAP`: no failure up to AlphaMax.
    - `NOT_ASSESSABLE`: the search could not decide, with the reason.
  - CSR is monotone in alpha because the boxes are nested. Any algorithm is allowed (bisection on alpha with the bound-worst search, or the direct form: minimize the scaled infinity norm ||p - p_bar||_inf,m subject to margin(p) <= 0), if it passes the known-answer tests.
  - The CPV is confirmed by a fresh in-envelope assessment, with the moving-limit rule of R3-M4.
- **R4-2, verdict.**
  - `ROBUST`: CSR status OK with alpha*(judged) >= 1, or ROBUST_TO_CAP; and the Monte Carlo Clopper-Pearson lower bound >= 0.95 (unchanged).
  - `NOT_ROBUST`: alpha*(judged) < 1 with a confirmed CPV, or the CP lower bound < 0.95.
  - Otherwise `NOT_ASSESSABLE`.
  - The default run no longer computes the x0.5 / x1.5 widths; CSR replaces them. They stay available as an option.
- **R4-3, two-parameter (longitudinal) groups are decided on a grid.**
  - Groups searched over 2 parameters use a dense grid with local refinement around the minimum, plus a Lipschitz bound estimated from the measured grid slopes with safety factor 2. The result is a certified lower bound on the margin between the grid points.
  - That decides the status: OK if the certified bound is >= 0; VIOLATED on a grid counterexample.
  - The status label says "grid-certified (Lipschitz estimate)". This replaces FC-901 for those groups.
- **R4-4, hybrid search for groups with more than 2 parameters.**
  - A seeded global stage (a VITAL implementation of differential evolution, since the Global Optimization Toolbox is not installed) with a stated budget, then a local derivative-free stage (`fminsearch`, Nelder-Mead, with a bound transform) in place of sqp, because the margins have kinks.
  - All points from the centre, corner, LHS, global and local stages are kept, and the bound-worst is the minimum over them.
  - Convergence is reported per stage. The result is still labelled a "search estimate".
- **R4-5, split Cm_table** (aero-database build-up).
  - New AeroScale fields: `Cm_basic` scales cmt(alpha, el = 0), the static part; `Cm_de` scales the elevator increment cmt(alpha, el) - cmt(alpha, 0), the elevator power.
  - Both multipliers equal to 1 leave the model bit-identical. Cm_table stays as a legacy field.
  - The pitchStatic group of the spec becomes {Cm_basic, Cm_de}: sigma 0.05 each, d = 2. The longitudinal-only search and its invariance gate include them.
  - A REG test of the effective CG-derivative ratios is required for the new fields.
- **R4-6, rename Cnr_table to Cn_r** (the plan's name), authorized by the user. The unknown-name example in tests/M6/tAeroScale.m#badAeroScaleRejected changes from 'Cn_r' to 'Cx_q'. That is the only edit to a closed-milestone test, and its header records why. Every registered sabotage pattern that names the field is updated to match.
- **Not in M8:** robust gain design (maximizing CSR with the M7 search) is a separate increment after M8.

**Amendment R4b** (coordinator, 2026-10-14; user decisions 1a, 2b, 3b after review). It corrects R4 where they differ.

- **R4-3 corrected: a shared adaptive lattice for the longitudinal groups.**
  - R4-5 made the longitudinal parameters 3 (Cm_q, Cm_basic, Cm_de), so R4-3 applies to the longitudinal search whatever its dimension (<= 3).
  - One lattice over the AlphaMax box (alpha = 3, judged shape), evaluated once per candidate condition and reused by every longitudinal group, both reference shapes and every CSR alpha.
  - Start at 11 points per axis, then refine cells adaptively: a cell is subdivided while its certified lower bound (cell minimum - L h, with L = 2 x the measured local slopes) is < 0 and its sampled minimum is > 0, i.e. only near the zero level set. There is a stated cap on levels and points.
  - For any box R(alpha) of either shape: OK if the certified bound over the cells inside the box is >= 0; VIOLATED on a lattice counterexample; otherwise NOT_ASSESSABLE ("GRID").
  - alpha* is read from the lattice to +/- 0.01, with a box search only to confirm the CPV.
  - Rejected alternative: Gaussian-process or other surrogates (they add model error to a certification answer).
- **R4-7 (new): breakpoint bracketing of linearization failures.** Investigated 2026-10-14:
  - The R4 smoke-run point at 13,000 ft / M 0.45 / CG 20 % failed because its trim alpha was 5.000036 deg, 3.6e-5 deg from the alpha = 5 deg table breakpoint.
  - theta x (1 -/+ 1e-3) trims at 5.0007 / 4.9994 deg, on opposite sides of the breakpoint, and both evaluate OK.
  - Rule: when a point's linearization is NOT_CONVERGED, and its trim alpha or elevator lies within 0.01 deg of a NESC aero-table breakpoint of that variable, evaluate the two parameter-perturbed points theta x (1 - d) and theta x (1 + d), with d = 1e-3 (increased up to 1e-2 if needed). This is accepted only if their trims lie on opposite sides of that breakpoint and both are OK.
  - The point's margin is then the WORSE of the two: the requirement must hold for both one-sided linearizations of the kinked model. It is status OK and is labelled `BRACKETED`, with both values reported.
  - In every other case the point stays non-OK exactly as before.
  - Physical failures are never bracketed: trim INFEASIBLE or NOT_CONVERGED, DIVERGENT modes, non-classical modes.
  - The breakpoint lists are read from the generated NESC models, never retyped.
- **R4-8 (new): staged default run.**
  - Stage 1: the whole default analysis at a reduced budget (NumCandidates 2, a smaller differential-evolution stage, the stated Monte Carlo N).
  - Stage 2: only groups whose CSR(judged) bracket overlaps [0.8, 1.2], or whose status is NOT_ASSESSABLE for budget reasons (FC-901), are re-run at the full budget. The longitudinal lattice groups need no stage 2.
  - The report states which stage decided each group.
- **R4-9 (new): lateral groups drop Cm_q.**
  - Cm_q acts only through the pitch rate, which is zero at the wings-level trim, so it cannot change lateral metrics.
  - This is gated by a test (lateral metrics unchanged within 1e-9 relative when Cm_q varies) and falls back to the full set if the gate fails.

**Amendment R5** (coordinator, 2026-10-14; the user approved all five recommendations from review R5, reports/review/R5_REVIEW.md). It supersedes earlier M8 text where they differ.

- **R5-1, lattice certificate uses h/2.** A cell's certified lower bound is (cell minimum - L * h/2), with L = 2 x the measured local slopes (own edges plus the 3^d base neighbourhood, as built). The half-edge geometric bound is valid under the same Lipschitz assumption and about 3x cheaper. Expectations pre-registered on the full-h form are kept and marked superseded (e.g. tUqLattice header 4: bound 0.08 becomes 0.14).
- **R5-2, the verdict comes from the judged box R(1).** ROBUST needs every lattice cell (longitudinal groups) or the box search (other groups) meeting R(1) to be certified >= 0, plus the Clopper-Pearson condition. alpha* is reported as a bracket [alphaLo, alphaHi]. The 0.01 resolution is required for the judged shape only; the equal-percentage shape is reported as a bracket at whatever resolution its budget allows. NOT_ROBUST still requires a confirmed CPV with ||.|| <= 1.
- **R5-3, piecewise certificate at table breakpoints.** Cells are split, or certified separately, on each side of an aero-table breakpoint crossed by the trim alpha (or elevator) of their vertices, using the breakpoint lists of R4-7. A cell is certified only if each one-sided piece is certified from vertices on its own side, and the report states that the margin is discontinuous there. Expected (R5 M1): 3.2.2.1.2-CatA/B are decided instead of exhausting the cap.
- **R5-4, the stage-1 band is measured.** Measure the stage-1 vs stage-2 CSR error on the smoke groups and on toy problems, and set the re-run band to cover the largest measured error x 2, never narrower than [0.8, 1.2]. Record the measurement in the ADR.
- **R5-5, the remaining findings are fixed:**
  - **M2:** state the candidate-condition scope in the report. Add fresh full in-envelope assessments at the corners of R(1) and R(alphaLo); a lower margin there overrides the lattice and is reported as a moving limit.
  - **M4:** add tests so that S8Q-1, 2, 3, 5, 6, 7, 8 and 9 (reports/work/R5/proposed_sabotages.json) are detected, and register them.
  - **Minors m1-m10:**
    - report text, including the narrow-feature limit;
    - a vital:badInput deep in the chain becomes an ERROR point, never an abort;
    - an all-+Inf cell is not certified;
    - a global lattice budget;
    - test runtimes;
    - tF16Uq no longer reads reports/;
    - the version string;
    - explicit judgment statements (Cm_basic and Cm_de independent; wings-level trims only).
- **R5-6, the default deliverable (R5 B1).** Rename the stale reports/uq/f16_uq_default.* (pre-R3) to *_superseded_2026-10-09. After the coordinator's gate, the staged default run_f16_uq is run on the final code, and a test pins its headline verdicts.

## Exit criteria for "done to M8"
1. `run_vital_tests('M8')` is GREEN from a fresh MATLAB session (`restoredefaultpath`, no `startup_vital`), with 0 excluded.
2. `run_sabotage('M5')` … `('M8')` detect every sabotage, with the tree unchanged.
3. Every failure-catalogue row for M5–M8 names a real test, and M5–M8 are closed in `docs/MILESTONES.json`.
4. Review agents report no unresolved defect. Anything unresolved is listed in the final report as an open issue, never hidden.
5. User entry points work: `run_f16_modes`, `run_f16_sim`, `run_f16_fq`, and the M7/M8 demonstrations.
