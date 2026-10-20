# VITAL architecture decision records

Each ADR records a decision, the reason for it, and what it rules out. A decision changes only through a new ADR that supersedes the old one.

## ADR-001: The F-16 is the baseline aircraft, using NASA NESC data (2026-09-29)
- **Decision:** VITAL is built and validated first on the F-16 model distributed with NASA/TM-2015-218675 (NESC 6-DOF check-cases). It is in DAVE-ML (ANSI/AIAA S-119), with `checkData` embedded, and comes with reference time histories from up to six independent simulations.
- **Why:** it is the only public F-16 data set that is traceable (a NASA file with a SHA-256 in `data/MANIFEST.json`), machine-readable, and has published multi-simulator results to compare against. The AAMF F-16 lookups (`F16Lookup.m`, `F16ABrandtLookup.m`) are not reused: their tables have no source, or are conceptual.
- **Consequence:** the X-57 and FAA rule sets come later, on the same architecture.

## ADR-002: MIL-F-8785C flying qualities first; FAA later (2026-09-29)
- **Decision:** the first rule set is MIL-F-8785C, Class IV (fighter).
- **Why:** the F-16 has no FAA certification basis. MIL-F-8785C is the flying-qualities specification that fits its class.
- **Consequence:** FAA Part 23/25 rule sets arrive with the X-57 (a concept aircraft). The rule schema already supports both, through the `Q-SPEC` and `Q-CFR` classes.

## ADR-003: matlab.unittest with provenance-tagged checks (2026-09-29)
- **Decision:** every numeric check goes through `vital.test.VitalTestCase` (verifyTol / verifyWithin / verifyExact), which records its source tag (PUB / INDEP / ANALYTIC / REG) and citation.
- **Why:** it carries the AAMF X-57 idiom onto the standard framework, and every gate produces a provenance table.

## ADR-004: No version control; gate history lives in reports/ (2026-09-29)
- **Decision:** at your request, no git.
- **How history is kept:** every gate writes reports/Mk_red.*, Mk_green.* and Mk_sabotage.*, and appends to reports/CHANGELOG.md. Tree hashes (`vital.test.treeHash`) identify the code state at each gate.

## ADR-005: Pure functions and flat numeric structs at runtime (2026-09-29)
- **Decision:** the runtime physics uses no handle objects and no `containers.Map`. `AC` is numeric; `ACmeta` carries names and provenance.
- **Why:** one `plantDerivatives` must serve trim, linearization, the MATLAB RK4, Simulink and MATLAB Coder. AAMF's interpreted S-function holding a handle object blocked all of fixed-step, rapid accelerator and codegen.

## ADR-006: One body-dynamics core with flat and WGS-84 rotating kinematics (2026-09-29)
- **Decision:** `env.earthModel` is `flat` or `wgs84`.
  - Trim, linearization and flying-qualities analysis are flat-earth.
  - NESC reproduction uses whatever Earth model each case specifies.
- **Why:** 8 of the 10 non-aircraft cases and all the F-16 cases fly over a rotating Earth (TM Vol II Tables 25–34).

## ADR-007: Reference data live in data/, originals are read-only (2026-09-29)
- **Decision:** downloads go to data/nesc/original and data/mil/original, read-only. Extracted archives go to data/nesc/extracted. Every file is hashed in data/MANIFEST.json.
- **Deviation:** the plan said aircraft\f16\source. The NESC package covers spheres, bricks and the F-16, so one data root is clearer. aircraft\f16 will hold only the compiled F-16 definition.

## ADR-008: The TM's Table 73 constants take precedence over the spreadsheet (2026-09-29)
- **Decision:** Earth constants come from TM Vol II Table 73 (p.93).
- **Why:** Initial_Conditions.xlsx uses truncated values (e.g. a = 6378137 × 3.28084 ft). Every reference CSV matches Table 73, and E.2.1 says all tools eventually used Tables 73/74.
- **Case 2/3 starting altitude:** 30,000 ft (text and every CSV), not the 0 ft in Tables 26/27.

## ADR-009: The NESC comparison band is pre-registered (2026-09-29)
- **Context:** the TM deliberately states no pass tolerance (Vol I p.10). It reports achieved mismatch only (eq. 38, Table 77).
- **Decision:** VITAL passes a signal if, on the reference time base, it lies within `[min_sims − δ, max_sims + δ]` with `δ = max(floor_abs, floor_rel·max|ref|, k·spread(t))`. floor and k are fixed per signal in `NESC_CASE_MATRIX.json` **before any VITAL run**.
- **Exclusions:** reference signals the TM itself excludes (E.1.1–E.1.2, e.g. SIM 2 Euler angles) are left out of the envelope.
- **Why:** this is a stated, reproducible criterion that is no looser than the disagreement between NASA's own tools.

## ADR-010: MIL-F-8785C source (2026-09-29)
- **Context:** the scripted download from everyspec.com returned HTTP 403. We don't work around download protections.
- **Decision:** you supply the PDF as data/mil/original/MIL-F-8785C.pdf before M7, and it is then hashed into the manifest.
- **Consequence:** the MIL criteria extract (`MIL8785C_EXTRACT.md`) moves from M0 to the start of M7. No MIL numbers are entered from memory.

## ADR-011: A missing deliverable counts as not implemented (2026-09-29)
- **Decision:** tests of documents and data call `vital.io.requireDeliverable`, which raises `vital:notImplemented` when the file is absent.
- **Why:** a missing specification is RED for the right reason. A file-open error would otherwise be misread as an unexpected failure.

## ADR-012: Sabotage checks run in separate MATLAB processes (2026-09-29)
- **Decision:** `run_sabotage` applies each defect to a temporary copy and runs the target tests in a new `matlab -batch` process. It requires them to turn RED, and it checks that the real tree's hash is unchanged.
- **Why:** two +vital trees on one path merge, and function caching makes in-process results depend on load order. Harness problems (pattern missing or ambiguous, unknown target, no status file) are errors, never detections.

## ADR-013: MIL-F-8785C supplied; supersedes the deferral in ADR-010 (2026-09-29)
- **Decision:** you supplied `MIL-F-8785C.pdf` (95 pages, 3,465,219 bytes). It is stored read-only at `data/mil/original/MIL-F-8785C.pdf` and hashed into `data/MANIFEST.json`, which `tSpecDocs/manifestHashesMatch` now verifies.
- **Note:** the scan's text layer is OCR-corrupted. The Class IV criteria are therefore transcribed from **rendered page images**, with paragraph and page citations, into `docs/MIL8785C_EXTRACT.md`. Nothing is taken from memory. The extract is a precondition of M7.

## ADR-014: NESC findings change M2, M4 and M6 (2026-09-29)
- **Context:** the NESC F-16 package (DAVE-ML files and TM Vol II) shows:
  - no engine power lag and no engine gyroscopic term
  - CG at 25% MAC, while aero and thrust moments are about the 35% MAC reference point
  - static control laws (LQR gain matrices plus proportional outer loops) with no integrators, whose limits exist only as `minValue`/`maxValue` attributes
  - clamped tables (`extrapolate="neither"`) stored with the last breakpoint varying fastest
  - case 12 flying at Mach 2 on the subsonic aero tables
- **Decisions:**
  - **M2:** the DAVE-ML importer honours `minValue`/`maxValue` as saturations, honours `extrapolate`, and reshapes tables in the published order. Each of these is a named failure/fidelity test.
  - **M4:** power lag and h_eng exist only as options that are **off by default**. They can be enabled only with a registered, cited source. The NESC configuration keeps them off. The moment transfer from 35% to 25% MAC is tested explicitly.
  - **M6:** the NESC static control laws are implemented as published.
  - **Case 12:** runs as published, and every clipped lookup is flagged OUT_OF_DATA_ENVELOPE.
  - **Cases 15/16:** autopilot baseline commands missing from the TM are recovered from the reference data at t = 0, and labelled as recovered.

## ADR-015: Reference comparisons use the envelope criterion, not per-simulation tolerances (2026-09-29)
- **Context:** in M1, a per-simulation tolerance I chose failed on NESC sim 3's last recorded frame (−0.19 K at t = 30 s). Every other sim-3 row agreed to 4e-4 K, and sims 4–6 agreed exactly. The TM itself documents first/last-frame recording artifacts (E.2.4). The consensus sims also disagree among themselves by up to 2e-5 in pressure and density.
- **Decision:** every PUB comparison against NESC data uses `vital.verify.envelopeCheck` with the pre-registered band from `NESC_CASE_MATRIX.json`. VITAL must lie inside the envelope of the NASA simulations, widened by δ. Frames are never hand-excluded after the data have been seen.

## ADR-016: Milestones re-sequenced so trim comes before rotating-Earth work (2026-09-29)
- **Context:** you asked to step back and confirm VITAL leads to trimming and virtual testing of the F-16. Trim needs a verified aircraft model and a flat-earth plant; it does not need ECEF propagation or the NESC time histories. The earlier plan put trim at M5, behind both.
- **New order:**
  - M2: DAVE-ML import
  - M3: F-16 plant (flat earth)
  - **M4: trim (with known answers)**
  - M5: linearization, modes, time simulation, ECEF and the NESC dynamic cases
  - M6: MIL-F-8785C engine
  - M7: baseline SAS and design feedback
  - M8: uncertainty
  - M9: Simulink, Cesium, joystick
- **Consequence:** failure-catalogue rows were moved to their new milestones (FC-301/302 → M5; FC-401/402 → M3; FC-501–505 → M4).

## ADR-017: Level-flight gravity for flat-earth trims of rotating-Earth cases (2026-09-29)
- **Context:** pre-registered hypothesis 3 of the M4 trim tests said the README-vs-NESC pitch difference (2.6538° vs 2.6388°) comes from gravity alone. **It failed:** gravity (J2 + centrifugal) accounts for 0.0074° of the 0.0150°.
- **Finding:** steady level flight over the rotating ellipsoid also carries the Coriolis (Eötvös) and path-curvature accelerations. For case 11 these are −0.0472 and −0.0153 ft/s², against a gravitation of 32.1885 and a centrifugal term of −0.0729 ft/s².
- **Decision:** `vital.geo.levelFlightGravity` supplies that effective down-acceleration. With it the flat-earth F-16 trim gives θ = 2.63883°, between NESC sims 4 and 5 (2.63873°, 2.63893°).
- **Test change:** the failed test was replaced by `rotatingEarthExplainsNescTrim`, which keeps the originally registered 0.005° tolerance. The original failure is recorded in `reports/CHANGELOG.md`.
- **Scope:** this is exact only for steady, straight, constant-height flight. Maneuvering flight over the rotating Earth needs the ECEF equations of motion (M5).

## ADR-018: The runner is self-contained and refuses silent exclusions (2026-09-29)
- **Context:** you ran `run_vital_tests('M1')` in a session where `startup_vital` had not been run. matlab.unittest excluded 8 test files with only warnings, and the gate ran 44 of 123 tests.
- **Decision:** `run_vital_tests` and `run_sabotage` add their own folder to the path. Any test file that contributes no tests is reported as EXCLUDED and fails the gate (FC-110, FC-111; sabotage S1-6).

## ADR-019: Infrastructure for parallel increments within one milestone (2026-09-29)
- **Context:** M5–M8 are built by several agents at once. Two things blocked this:
  - The gate treated every test of the current milestone as new, so one increment's unfinished tests broke another's gate.
  - The failure-catalogue rule forced every row of a started milestone to name a real test, including rows owned by other increments.
- **Decision:**
  - `run_vital_tests` takes `Increment` (new classes), `Baseline` (finished classes, treated like earlier milestones) and `Tag`. Unlisted current-milestone classes are skipped, and a typo is an error (`vital:test:unknownIncrement`). The full gate is unchanged.
  - Sabotages may be split into `sabotages_<part>.json` (`vital.test.loadSabotageSet`; duplicate ids are errors).
  - Catalogue rows of an **open** milestone may stay PLANNED. A **closed** milestone (`docs/MILESTONES.json`) must name real tests (`vital.io.checkCatalogue`). This is stricter than before for closed milestones.
  - FC-302's identifier became `vital:sim:nanState` (area-qualified, CONVENTIONS 11).
- **Tests:**
  - `tests/M1/tRunnerIncrements.m` (8 RED-expected, 1 justified VACUOUS guard)
  - `tests/M0/tCatalogueRules.m` (6 RED-expected)
  - Sabotages S1-7, S1-8 and S0-5.

## ADR-020: M5–M8 plan, contract and coordination (2026-09-29)
- **Context:** you asked for M5–M8 to be planned and implemented, with different agents coordinating and checking the work, and with the failure-test method throughout.
- **Decision:** the plan, the interface contract and the parallel-work rules are in `docs/PLAN_M5_M8.md`.
  - Implementation agents own disjoint packages and write proposals for shared documents as fragments in `reports/fragments/<agent>/`.
  - Review agents that did not write the code audit each increment and propose additional sabotages.
  - The coordinator merges the documents, runs the authoritative quiet-tree gates and sabotage checks, and closes milestones in `docs/MILESTONES.json`.

## ADR-021: Time-simulation semantics of vital.sim.run (2026-09-29; agent sim, M5-B)

**Context.** CONVENTIONS 10 requires fixed-step RK4 on a continuous plant, with discrete elements zero-order held. M5-C (rotating plant), M6 (time-domain metrics) and M7 (controllers) all build on `vital.sim.run`. They need a precise definition of what is sampled when, what a stop means, and which time a stop is reported at.

**Decision.**
1. **Integrator.** Classical RK4 (Butcher tableau in `+vital/+sim/rk4Step.m`) is shared by `vital.sim.rk4` (the order tests) and `vital.sim.run`. Times are `t_k = k*dt`, never accumulated. `tFinal/dt` must be within 1e-6 of a positive integer, otherwise `vital:sim:badStep` (FC-301).
2. **Inputs.**
   - A function handle `du = f(t)` is treated as smooth and evaluated at the stage times.
   - A piecewise specification (`vital.sim.doublet`, `vital.sim.stepInput`, or any struct with `channel`, `fcn`, `breakpoints`) must have every breakpoint on a step boundary (a multiple of dt within 1e-6 dt), otherwise `vital:sim:badStep`. It is evaluated at the step's interior point `t_k + dt/2`, and that value is used for all four stages. Stage 1 therefore sees the right limit at t_k and stage 4 the left limit at t_k+dt, so no stage straddles a switch.
3. **Controller.**
   - `{rate_hz, init, step}` is sampled at `t_k` with `mod(k, nHold) == 0`, where `nHold = 1/(rate_hz*dt)` must be a positive integer (within 1e-9), otherwise `vital:sim:badStep`. Nothing runs faster than the base step (correction E4).
   - The controller receives `u_ref = u0 + du(t_k)` and the plant output `y` at `(x_k, u_ref)`. This avoids an algebraic loop: u-dependent outputs such as nz reflect the reference command.
   - Its output is held across every stage until the next sample. With a controller present, inputs reach the plant only through `u_ref` at the samples.
4. **Log.**
   - Sample k logs `x_k`, the command applied at stage 1 of the step from t_k, and `y` from that same stage-1 evaluation, so logging costs no extra plant call.
   - The final sample logs the stage-4 command of the last step (left limit).
   - By default the log holds every real numeric or logical `y` field.
5. **Guards and stops.**
   - Guards are checked on every logged sample, including t = 0. A guard firing at t_k stops the run with `stopTime = t_k = t(end)`.
   - A step whose stage state or derivative is non-finite, or whose plant call raises, is rejected. Its `stopTime` is `t_k`, the last accepted finite state.
   - `vital:plant:nonFinite` raised by the plant is reported as `vital:sim:nanState`. Any other plant error is reported as `vital:sim:plantError`, with the identifier and message kept in `out.stopDetail`.
   - A guard whose `y` field is absent is disabled and listed as such in `out.guards`. A NaN guard value trips its guard.
   - Clamped tables (`y.outOfEnvelope`) are recorded (first time) and stop the run only with `Guards.stopOnOutOfEnvelope`, which gives `vital:sim:outOfEnvelope`.
   - Only an evaluation of the plant that rejects x0/u0 before any successful plant call is an exception (`vital:badInput`).
6. **Diagnostics added to `vital.plant.derivatives` y** (additive):
   - `quatNorm`: norm of the incoming quaternion
   - `phi`, `theta`, `psi`
   - `p`, `q`, `r`
   - `specificForce_b`: (aero + propulsion)/m in body axes
   - `nz = -specificForce_b(3)/env.g`: the body-axis normal load factor, positive up, gravity excluded. It equals cos(theta) in level unaccelerated flight, and is NaN when env.g <= 0.

**Consequences.**
- M5-C needs only to provide `y.quatNorm`, `y.h`, `y.alpha`/`y.beta` and `y.outOfEnvelope` to get the same guards.
- M7 controllers see a well-defined sampled system, and closed-loop linearization must use the same `u_ref`/`y` definition.
- Evidence: `tests/M5/tSimCore.m`, `tests/M5/tSimGuards.m`, `tests/M5/tF16Sim.m`.

## ADR-022: Linearization by a step-study central difference that detects table breakpoints (2026-09-29; agent linear, M5-A)
- **Context:** the NESC F-16 aero and propulsion tables are piecewise-multilinear. At a breakpoint the derivative is one-sided. A central difference there does NOT fail to plateau: for a piecewise-linear function it returns the average of the left and right slopes at every step. A plateau test alone therefore accepts a wrong number silently.
- **Decision:** `vital.linear.jacobian` evaluates each column at h0, h0/10, ..., h0/10^6.
  - Acceptance: three successive weighted estimates agree within RelTol = 1e-6 of the weighted column (plus AbsTol 1e-10). The middle estimate is accepted.
  - Breakpoint detection: the one-sided asymmetry s = ||W (f(z+h) - 2 f(z) + f(z-h))/h|| must shrink with h (ratio 1/10 per step for smooth functions). If s exceeds KinkTol = 1e-6 of the column at the accepted step and has not decayed (s_k >= 0.5 s_(k-1)), the column is a kink.
  - Any failed column is NaN and the status is `NOT_CONVERGED`, naming the column and its cause (FC-506, FC-510). A plausible number is never returned.
- **Rows and columns are weighted** by typical magnitudes, so that the acceptance norm does not mix units: FScale = [g g g, 1 rad/s^2 x3, 1 rad/s x3, V x3] and ZScale = [10 m/s x3, 1 rad/s x3, 1 rad x3, 1000 m x3, 0.1 rad x3, 1].
- **Consequence:** the F-16 README trim (alpha 2.65 deg, de -3.24 deg, beta 0, 13 ft above the 10,000 ft thrust-table breakpoint) linearizes with every column OK. The first 10 m altitude step straddles the breakpoint; the study converges at 0.1 m. beta = 0 is a breakpoint of the |beta| tables, but the NESC model makes Cl and Cn odd in beta (sign(beta) * table(|beta|)), and the da, dr products vanish at da = dr = 0, so no kink arises there.

## ADR-023: Flight modes are classified by participation factors, not eigenvector magnitudes (2026-09-29; agent linear, M5-A)
- **Context:** the AAMF classifier (StabilityAnalysis.m:448-696) decided longitudinal versus lateral, and picked the short period and Dutch roll, from raw right-eigenvector magnitudes summed across states with different units (m/s and rad/s). The result depends on the choice of units. It also labelled a real root as the "short period" with a period and damping.
- **Decision:** `vital.linear.modes` uses normalized participation factors p_k = |v_k w_k| (w = rows of inv(V)), which are invariant under a diagonal change of units. The classifier then works as follows:
  - Groups: lon if the participation in {u w q theta} exceeds 0.5.
  - Time scale inside a group:
    - Longitudinal: two pairs mean faster = short period.
    - Lateral: the real roots split as faster = roll, slower = spiral.
  - Participation signatures confirm each name:
    - short period: w + q > u + theta
    - phugoid: u + theta > w + q
    - Dutch roll: v + r > p + phi
    - roll: p is the largest
    - spiral: phi or r is the largest
  - A group of real roots where a pair is expected is `NOT_OSCILLATORY`, with wn, zeta and period NaN (FC-507).
  - Anything else is `other` / `UNCLASSIFIED`, with a reason.
  - An ill-conditioned eigenvector matrix (cond > 1e10) makes every mode UNCLASSIFIED.
- **Time constants:** tau = -1/lambda for real roots (negative means unstable). tHalf and tDouble are each NaN when they do not apply.

## ADR-024: Closed-loop linearization is limited to declared-static controllers (2026-09-29; agent linear, M5-X)
- **Decision:** `linearize(..., 'Controller', c)` follows the vital.sim.run semantics.
  - The controller output is u = step(0, x, y(x, u_ref), u_ref, state0), with y evaluated at (x, u_ref).
  - The closed loop is f = plant(x, u(x, u_ref)).
  - It returns closed-loop A and B, the open loop, and the controller Jacobians K and Kref.
- **Static only:** the controller must declare `static = true`, and every call must return the initial state.
  - Detection alone is not enough: an integrator of a trim-zero error is unchanged at the trim itself.
  - Otherwise the call fails with `vital:linear:dynamicController`.
- **Equilibrium:** a controller whose trim output differs from u0 is refused (`vital:linear:controllerNotAtTrim`).
- **Sampling:** it is a continuous approximation; the ZOH delay is not modelled.
- **Later:** dynamic controllers (filters, integrators) need an augmented-state linearization, which is left for M7.

## ADR-025: Optional height state in modal analysis (2026-09-29; agent linear, M5-X)
- **Decision:** `modes(lin, 'IncludeHeight', true)` analyses [u v w p q r phi theta h] and names the extra real root 'height'. The default stays at 8 states per the contract.
- **Reason:** the 8-state phugoid is 7 % off the nonlinear plant at the README trim (tLinearVsNonlinear).

## ADR-026: A controller measures the plant under the command actually applied (2026-09-30; coordinator, from review R1 M8)
- **Context:** ADR-021 gave a sampled controller the plant output y evaluated at (x_k, u_ref). Review R1 (finding M8) showed two problems with that:
  - An nz-feedback controller then sees Z_de times the new reference command instantly, before the airframe responds, which no sensor can do.
  - Tests could not detect y being evaluated at the wrong command.
- **Decision:** at sample k the controller receives y(x_k, u_applied), where u_applied is the command held over the step that ends at t_k. At k = 0 that is u_ref(0) = u0 + du(0). This is causal, has no algebraic loop in the simulation, and matches a sensor sampled just before the ZOH update.
- **Closed-loop linearization (ADR-024)** uses the continuous-time limit of the same semantics: u = step(x, y(x, u)). The loop is solved; a static controller whose loop has no unique solution gives an identified error.
- **Also:**
  - A controller that raises an error is a STOP (`vital:sim:controllerError`, identifier kept), not an exception.
  - A non-finite controller output is a STOP (`vital:sim:nanState`).
- **Tests:** an nz-feedback controller whose response depends on the choice. Closed-loop linearization and the sampled simulation must agree for it as dt → 0.

## ADR-027: Amendment to ADR-021 after review R1 (2026-09-30; agent sim; implements ADR-026)


Proposed replacement text for the ADR-021 items below. Everything else in ADR-021 stands.

**2. Inputs** (added sentence). A piecewise specification must also be *constant inside every step*. `vital.sim.run` samples each step's fcn at t_k + dt/4, dt/2 and 3dt/4 before the run and refuses any variation with `vital:sim:inputNotPiecewiseConstant` (R1 MINOR 4). A smooth input must be passed as a function handle.

**3. Controller** (replaces the second and third bullets).
- At sample k the controller receives `u_ref = u0 + du(t_k)` and y(x_k, u_applied). u_applied is the command held over the step that ends at t_k; at k = 0 it is u_ref(0) = u0 + du(0) (ADR-026).
- The per-sample logic is the public function `vital.sim.sampleController(ctrl, t, x, y, uref, state, nu)`. `vital.linear.linearize` can call it so that both use the same semantics.
- A controller that raises is a STOP `vital:sim:controllerError`, with its identifier and message kept in `out.stopDetail`.
- A non-finite output is a STOP `vital:sim:nanState`, with `stopDetail.stage` = 'controller sample'.
- A wrong-sized output is an exception `vital:badInput`, because it is a wiring error.
- A controller stop is at t_k. It logs x_k, the command applied up to t_k, and the y the controller saw.

**5. Guards and stops** (added bullet). Command limits (R1 M6):
- Every stage command is compared with `vital.sim.controlLimits(AC, n)`: `AC.limits.<name>_deg` in rad, or `AC.limits.<name>` in SI, matched by `AC.controlNames`.
- When the plant reports `y.u_applied` (a plant that maps a command vector to surfaces, e.g. NESC stage mode), that vector is checked instead.
- The first violation is recorded in `out.controlLimit` (`ever`, `firstTime`, `channel`, `value`, `limit`). The command is never clipped.
- `Guards.stopOnControlLimit` stops the run with `vital:sim:controlLimit`. `Guards.controlLimits` overrides the limits, and `struct()` disables them.

## ADR-028: Review R1 fixes to linearization and modes (2026-09-30; agent `linear`)
- **Equilibrium (R1 B1).** `linearize` requires ||W f0(1:8)||_inf <= TrimTol = 1e-8 for the (AC, env) it is given, with W = [1/g x3, 1 x5]. Otherwise it raises `vital:linear:notEquilibrium`.
  - The trim solver accepts a scaled residual < 1e-9, and R1 measured 3e-16.
  - A trim made with another CG or g is refused rather than silently linearized. That is exactly how R1-L12/L13 escaped.
- **MIL n/alpha (R1 B2).** `lin.n_alpha_ss` is MIL-F-8785C 6.2 n/alpha: the steady state at constant speed per pitch-control deflection, (V/g) q/alpha, including Z_de and Z_q. It is computed by `vital.linear.nAlphaSteady` and is identical to `vital.fq.metrics` n_alpha_g_per_rad.
  - It is defined for level trims only (NaN with status NOT_LEVEL otherwise).
  - `lin.n_alpha` stays as the alpha-only partial and is documented as NOT the MIL quantity.
- **Round-off-limited plateaus (R1 B3).** The step study refuses a plateau when the value-rounding error eps * max|W f| * ZScale / h exceeds 1 % of the plateau tolerance. The column status is ROUNDOFF and the model is NOT_CONVERGED.
- **Accuracy (R1 MINOR 10).** Accuracy is column-relative (inf-norm): entries are accurate to about RelTol of the column maximum, and sub-KinkTol kinks are averaged.
- **Per-column status (R1 M1).** `lin.columnStatus` gives one status per column (16).
  - `lin.status` stays NOT_CONVERGED if any column fails.
  - `modes` needs only the columns it uses: 1-8, plus 12 with IncludeHeight.
  - Consequence: a round-number altitude (thrust-table breakpoint in h) no longer blocks the 8-state modes.
- **Phugoid default (R1 M5).** `modes` stays 8-state (contract) and says so. `run_f16_modes` also prints the phugoid and height mode with altitude coupling (IncludeHeight), labelled 'phugoid (with h)'. M6 phugoid rules use IncludeHeight.
- **Closed loop (ADR-026).** The controller is called through `vital.sim.sampleController` with y evaluated at the applied command u. The algebraic loop u = step(x, y(x, u)) is solved by one fixed-point step and then Newton's method.
  - Converged: residual <= 1e-14 (1 + |u|), or a stalled residual <= 1e-11 (1 + |u|).
  - Otherwise `vital:linear:algebraicLoop`. A controller error gives `vital:linear:controllerError`.
- **Classifier and controller design constants (R1 MINOR 9; not published values):**
  - lonFraction 0.5
  - dominant: 80 % cumulative participation
  - oscillatory if |Im| > 1e-9 |lambda|
  - cond(V) > 1e10 means UNCLASSIFIED
  - third-oscillatory note at p_w + p_q > 0.2
  - controllerNotAtTrim at 1e-9 (1 + |u0|)
  - TrimTol 1e-8
  - round-off factor 0.01 of the plateau tolerance
- **Static-controller check (R1 MINOR 12).** The `isequal(state, state0)` test also refuses static laws that keep bookkeeping state. This is conservative.
- **Sampling (R1 MINOR 11).** The ZOH half-sample delay is not modelled in the closed loop. tClosedLoopSimAgreement shows the sim-vs-linear difference is first order in dt.

## ADR-029: Rotating-Earth simulation and the NESC check-cases (M5-C; agent nesc, 2026-09-30)
The agent's decisions are kept under their original labels (N1 to N11, with the post-run revisions N6r, N6c and N11r). No NESC band, tolerance or expected value was changed after any run.

### ADR-N1: Rotating-Earth state and equations (ECEF formulation)
- **State** of `vital.plant.derivativesRotating` (13): `x = [r_e (3) m; v_e (3) m/s; q_be (4); w_bi (3) rad/s]`
  - `r_e` CM position in ECEF; `v_e` CM velocity **relative to ECEF**, ECEF axes
  - `q_be` scalar-first quaternion ECEF -> body (C_be = quat2dcm(q_be))
  - `w_bi` body angular rate **relative to inertial space**, body axes
- **Equations** (`vital.eom.rotatingRigidBody`):
  - `rdot_e = v_e`
  - `vdot_e = C_eb F_b/m + g(r_e) - 2 w x v_e - w x (w x r_e)` with `w = [0 0 omega_E]`
  - `qdot_be = 1/2 Omega(w_be) q_be + k (1 - q'q) q_be`, `w_be = w_bi - C_be w`, k = 1 1/s (CONVENTIONS 3)
  - `J wdot_bi = M_cg - w_bi x J w_bi`
- **Why:** no explicit time dependence, so the plant keeps the M3 signature `[xdot, y] = f(x, u, AC, env)` and runs unchanged through `vital.sim.run`. ECI is recovered as `C_ei(t) = R3(omega t)`: ECI and ECEF coincide at t = 0 (TM Vol II p.603).
- **Environment** `env`: `earth` ('wgs84' | 'sphere' | a constants struct), `rotation` (logical), `gravity` ('J2' | 'central'), `wind_n`, `windGradient_n`, `deltaT`. Every field is required; a missing one is `vital:badInput` (no silent default).

### ADR-N2: Gravitation in the EOM; localGravity is its magnitude
- The rotating EOM uses **gravitation** (J2 for WGS-84, inverse square for the sphere); the centrifugal and Coriolis terms come from the EOM (CONVENTIONS 4).
- The NESC output `localGravity_ft_s2` is the **magnitude** of the gravitation vector. Checked at t = 0 against the CSVs before registration: case 11 SIM 4/5 32.1885754492 ft/s^2 equals |g| to 2e-11, while the geodetic-down component is 32.1885318 (4.4e-5 lower); case 1 and case 10 agree with both.

### ADR-N3: Rates used by the aerodynamics
- Aerodynamic damping (brick Clp/Cmq/Cnr; F-16 rate derivatives) uses the body rate **relative to the Earth-fixed airmass**, `w_be = w_bi - C_be w_ie`. The atmosphere rotates with the Earth; rotation relative to the air is what the damping physics needs.
- Consistency check made before registration: SIM 5's case-11 yaw moment at t = 0 (0.388 ft lbf) is of the size of Cnr times the Earth-relative yaw rate (about 0.3 ft lbf with rough coefficients); the inertial rate would give about 1.3 ft lbf and local-level rates 0.

### ADR-N4: Initial body rates
- Cases 1-10: the matrix field `rate_inertial_body_deg_s` (XLSX rows 23-25), which the CSVs report at t = 0 (`bodyAngularRateWrtEi`).
- F-16 cases: `w_bi = C_bn (w_ie^n + w_en^n)` with the transport rate `w_en^n = [v_E/(R_N+h), -v_N/(R_M+h), -v_E tan(lat)/(R_N+h)]`: the aircraft holds its Euler angles relative to local level. This is SIM 5's definition (TM Vol II p.228); it reproduces SIM 5's t = 0 rates to 10 digits in cases 11, 15 and 16 (checked with an independent Python evaluation).

### ADR-N5: NESC-environment trim of the F-16 (`vital.nesc.f16Trim`)
1. `vital.trim.solve` (alpha, de, throttle; wings level, beta = 0) with `env.g = vital.geo.levelFlightGravity(lat, lon, h, v_ned)` (proven for case 11 by `tF16Trim/rotatingEarthExplainsNescTrim`).
2. Map to the rotating state: position (lat, lon, h), NED velocity from the case, Euler (0, theta, course), rates per N4.
3. Polish (theta, de, throttle) by Newton iterations on the rotating plant until the NED-frame acceleration `dv_n/dt = C_ne vdot_e - w_en x v_n` has zero body-x and body-z components and the body pitch acceleration is zero (scaled residual < 1e-10: g and rad/s^2). Aileron and rudder stay 0 (the TM varies "pitch attitude, elevator position, and throttle setting", V2 p.62).
- Status: OK, NOT_CONVERGED, or OUT_OF_DATA_ENVELOPE when a table input is clamped. **Case 12 is accepted with OUT_OF_DATA_ENVELOPE** because the model is run as published on the subsonic tables (ADR-014); no other case may be.
- Why polish: the rate terms of N3/N4 give pitching moments of ~1 ft lbf that a flat trim ignores; SIM 5's case-11 pitching moment at t = 0 is -0.0019 ft lbf.

### ADR-N6: Execution of the NESC control laws (`vital.nesc.f16Controller`)
- **Rate (first choice, SUPERSEDED by ADR-N6r below):** 50 Hz, zero-order hold (the rate is NOT FOUND in the TM, which lists "a different execution rate for the control law" as a source of spread, V2 p.282/p.296). 50 Hz is a typical digital flight-control rate and lets every F-16 case run at dt = 0.02 s with one sample per step (runtime budget, N11).
- **Command timing:** a step at t_s takes effect at the first sample with t >= t_s (the sample at t_s itself), within 1e-9 s.
- **LQR reference states:** replaced by VITAL's trim, as SIM 5 did (TM V2 p.256). The DML constants cannot be inputs, so the substitution is implemented as exact input shifts: `alpha_in = alpha - alpha_trim + trimmedAlpha`, `theta_in = theta - theta_trim + trimmedTheta`, and (AP off only) `Vequiv_in = Vequiv - KEAS_trim + trimmedKEAS`. `trimmedPilotControl_long = -de_trim/25 deg`, `trimmedPilotControl_throttle = throttle_trim`.
- **KEAS:** `EAS = TAS sqrt(rho/rho0)`, rho0 = US 1976 sea-level density; in knots (kt = 1852/3600 m/s). It gives 287.98 KEAS at the case-11 IC, the TM's "trim solver's speed of 287.98 KEAS" (V2 p.256).
- **Rates fed to the law (first choice, SUPERSEDED by ADR-N6c):** body rates relative to the local NED frame, `w_bn = w_bi - C_bn (w_ie + w_en)`. The LQR was designed on a flat-earth model, whose body rates are relative to local level ("perfect state feedback", README). With inertial rates, the steady 3-nm circle of case 15 (inertial yaw rate 1.76 deg/s from the transport rate alone) would carry a spurious rudder and aileron bias.
- **Baseline commands:** altitude = trim altitude; KEAS = trim KEAS; course 45 deg with lateralDeviationError 0 (13.1-13.3). 13.1: +100 ft at 5 s. 13.2: -5 KEAS at 5 s (TM value; SIM 2 used -10 but is excluded). 13.3: course 60 deg from 15 s.
- **ADR-N6b (cases 15/16):** alt/KEAS commands are NOT FOUND in the TM; per ADR-014 they are recovered from the initial condition (10,000 ft, trim KEAS) and labelled `recovered`. AP and SAS on from the first sample.

### ADR-N7: Case 13.4 lateral-offset logic
- `lateralDeviationError = 0` for t < 20 s; for t >= 20 s it is `d - 2000 ft`, where `d` is the cross-track distance (+right) of the aircraft from the **rhumb line** through the initial position at the 45 deg base course.
- `d` is computed exactly in Mercator coordinates of the ellipsoid (longitude, isometric latitude): the perpendicular offset of the point from the straight line, times the local scale `(N + h) cos(lat)` evaluated at the latitude midway between the point and the foot of the perpendicular (`vital.nesc.crossTrack`).
- **Why a rhumb line:** before 20 s the autopilot holds the true course `chi = beta + psi` = 45 deg, i.e. it flies a loxodrome; the "original course" is therefore the loxodrome. A local tangent-plane line would drift from it by ~2 m over 10 km, and a spherical flat-plane approximation (the GNC's `deg_to_ft`) mis-states a 45 deg course by 0.13 deg on the ellipsoid.

### ADR-N8: Comparison mechanics (`vital.nesc.compare`)
- Reference samples are truncated to [0, duration] (sim 5 13.x files run to 60 / 239.9 s with float32 time stamps; sim 2 cases 11/12 to 200 s).
- VITAL is linearly interpolated onto each simulation's own time stamps; the residual `ref_s - VITAL` goes to `vital.verify.envelopeCheck` with the band exactly as in the JSON, `tBase` = the first included simulation's times, `refScale` = max |ref| over the included simulations.
- Angle residuals (Euler angles, longitude) are wrapped to (-180, 180] deg (TM eq. 37 does the same). 179.9 vs -179.9 deg is a 0.2 deg difference.
- A simulation without the column is skipped; if no included simulation records a band signal, the signal is `NOT_ASSESSABLE` with its reason, and the test **fails** on it (it is never skipped).
- A VITAL run that stopped before the duration fails every signal.

### ADR-N9: Vehicles and coefficient overrides (cases 1-10)
- Cannonball and brick masses, inertias and aero from `cannonball_*.dml` and `brick_*.dml`, compiled by `vital.nesc.generateModels` into `+vital/+models/+nesc`.
- Case 1: CD = 0. Case 2: CD = Cl = Cm = Cn = 0 (TM: "all the aerodynamic coefficient values in Table 5 to zero"; every CSV force and moment is 0). Case 3: CD = 0 with the published damping. Cases 4-10: as published (CD = 0.1).
- Drag acts along -v_air: `F_b = -qbar S CD v_air/|v_air|`, zero at zero airspeed. The brick's VRW is clamped at 0.5 ft/s by its own `minValue` (compiled as a saturation); `qbar` uses the true airspeed.
- Cases 2/3 start at 30,000 ft (ADR-008).

### ADR-N10: Wind (cases 7 and 8)
- Earth-fixed, horizontal, expressed in local NED: `w_n = wind_n + windGradient_n h`, h geometric height above the ellipsoid (no geoid is modelled).
- Case 7: 20 ft/s from the west, `wind_n = [0 +20 0] ft/s`. Case 8: East = (0.003 h_ft - 20) ft/s, so `wind_n = [0 -20 0] ft/s` and `windGradient_n = [0 0.003 0] 1/s`.
- `v_air = C_bn (v_n - w_n)`.

### ADR-N11: Step sizes and step-size study
- Cases 1-10: RK4 dt = 0.01 s. F-16: dt = 0.02 s, control law every step (50 Hz).
- **Registered criterion:** `max_t |VITAL(dt) - VITAL(dt')| / delta(t) <= 0.1` at every compared reference time, for every band signal:
  - cases 1-10: dt' = 0.02 s, full 30 s
  - cases 11, 12: dt' = 0.04 s, full 180 s
  - autopilot cases 13.x, 15, 16: dt' = 0.01 s (control law still 50 Hz, two steps per sample), over min(30 s, duration), which holds every commanded step
- Why: runtime. The rotating F-16 plant costs about 1.1 ms per call. The full F-16 set is 850 s of simulated time, and the study has to fit in the ~8-minute M5-C budget. With dt' = 2 dt and an integrator of order >= 1, the dt error is at most the measured change; with dt' = dt/2 it is at most the change times 2^p/(2^p - 1).

### ADR-N6r: The NESC control law is evaluated as a continuous-time static feedback (supersedes the 50 Hz rate of N6)
- **What happened:** with the 50 Hz ZOH of N6, cases 13.1-13.4, 15 and 16 fell outside their bands in 7-19 signals each, always in the transients after a command step or at engagement. Before and after the transients VITAL tracked SIM 4/5 closely (e.g. case 13.3 roll 30.0 deg, heading 59.92 deg at 30 s; case 15 L(0) = -225.8298 vs SIM 5 -225.8300 ft lbf).
- **Diagnosis (13.3, the rate is the only change; dt = 1/rate):** worst roll excess 2.60 deg at 50 Hz, 1.28 at 100 Hz, 0.30 at 200 Hz, 0.10 at 500 Hz; pitch-rate excess falls similarly. The response converges monotonically towards SIM 4/5 as the law is sampled faster: SIM 4 and 5 behave like the continuous-time limit. The transient is a saturated, high-gain roll loop (full aileron, |p| ~ 150 deg/s), where a sample-and-hold delay changes the overshoot.
- **Signs, units and definitions checked and not the cause** (NESC_EXTRACT_F16.md risks 8-16): the steady states agree (bank limit +30 deg, final course, Type-0 altitude offset), which rules out sign errors in ail ("left roll" = VITAL da, tF16Plant), rdr (TEL), baseChiCmd, latOffset or chiEst; the trim references, KEAS and "> 0.5" logic are hand-tested (tF16ControlLaw).
- **Decision:** the law has no dynamic states, so it is evaluated at every plant evaluation (every RK4 stage) through `AC.stageControl` of `vital.plant.derivativesRotating`. Commands enter as plant inputs `[altCmd_ft; keasCmd; baseChiCmd_deg; sidestepOn]`, stepped by `vital.sim.stepInput` exactly at t_step (a step boundary). The sampled form (vital.sim.run Controller, 50 Hz) remains available and tested.
- **Disclosure:** this is a modelling choice the TM leaves open (NOT FOUND), changed **after** the first comparison run on the evidence above. No band, tolerance or expected value was changed. The first-run failures are recorded in reports/fragments/nesc/NOTES.md.
- dt stays 0.02 s; the step-size study (N11, dt' = 0.01 s over min(30 s, duration)) decides whether that is enough.

### ADR-N11r: Revised F-16 step sizes and studies (supersedes the F-16 part of N11)
- **What happened:** (a) cases 11/12 at dt = 0.02 s failed the registered study against dt' = 0.04 s (ratio 0.39 for the case-12 aero roll moment, 0.22 for the case-11 side force; the transients are 1e-8 of the load scale); (b) with the stage-evaluated law of N6r, 13.3 at dt = 0.02 s gave study ratio 82. A dt scan of 13.3 gave ratios of 6.5 (0.01 vs 0.005) and 0.23 (0.005 vs 0.0025). The closed-loop rate feedback puts a pole near -40 1/s, and the aileron and rudder switch between their limits (|p| up to 150 deg/s), so RK4 converges slowly.
- **Decision:** the autopilot cases (13.x, 15, 16) run at dt = 0.005 s and are studied against dt' = 0.0025 s over min(30 s, duration). Cases 11/12 stay at dt = 0.02 s and are studied against dt' = 0.01 s over the first 30 s, which holds their only transient (engagement of the lateral residual, < 10 s).
- The criterion is unchanged: ratio <= 0.1. Where it still fails, the failure is reported. The study now brackets finer steps, so the dt error is bounded by the measured change times 16/15 for a 4th-order method.
- **Disclosure:** chosen after the first runs; no band or expected value changed. **Runtime** exceeds the ~8-minute target (numbers in NOTES.md).

### ADR-N6c: The control law receives Earth-relative body rates (supersedes the w_bn choice of N6)
- **What happened:** with w_bn (rates relative to local NED), case 15 left the 30 deg bank about 3 s before SIM 4/5 (roll excess 38 delta, latitude 18 delta) and held a steady bank bias (-29.99934 deg against -29.99554).
- **Diagnosis** (case 15, stage law, dt 0.005 s, first 40 s; the rate frame is the only change):
  - w_bn: roll -29.999339 deg at 20 s, capture at ~28 s
  - w_be: roll -29.995536 deg at 20-29 s (SIM 5 -29.995536, SIM 4 -29.995538), latitude 89.948753 deg at 20 s (SIM 5 89.948755), capture at 33 s as in SIM 4/5
  - w_bi: -29.995527 deg, slightly further from SIM 5
- **Decision:** `pb, qb, rb` of F16_control/F16_gnc are the body rates relative to the Earth, `w_be`, the same `bodyAngularRate_*` signal the aero model receives (ADR N3). The DML uses one S-119 name for both. The option `cd.controller.rateFrame` stays for diagnostics.
- **Disclosure:** changed after a comparison run, on the evidence above; no band or expected value changed. The rationale registered for w_bn ("LQR design model states") was wrong for the NESC tools.

## ADR-030: MIL-F-8785C flying-qualities engine (M6; agent fq, revised after review R2, 2026-10-06)
The agent's decisions are kept under their original labels; R2-1 to R2-8 are the revisions after review R2. The validity region in R2 (|h - 10,000 ft| <= 5,000 ft, |KEAS - 287.8| <= 20 %) is a labelled JUDGMENT.

### ADR-0xx: Rule records encode one Level boundary; the engine reports a Level per paragraph and Category (2026-09-29)
- **Context:** RULE_SCHEMA asks for one record per sub-paragraph, and the extract's 235 candidates are one per (paragraph, metric, Level, Category). MIL-F-8785C 6.7.1 defines the Level as the best Level whose boundary is satisfied, and a Level boundary of one paragraph can involve several metrics (Figures 1-3: CAP, omega_nsp floor, n/alpha edge; Table VI: zeta_d, zeta_d*omega_nd, omega_nd).
- **Decision:**
  - A curated record (`rules/mil_f_8785c/records/*.json`, 95 files) is one (paragraph, metric, Level, Category) boundary `lo <= y <= hi` (strict when the spec says "exceed"/"greater than"), with `source.candidate_id` and a verbatim `source.extract_quote`. "All", "A&C", "B&C" are expanded to one record per Category; Category A of 3.3.1.1 is split into the CO/GA row and the other-phase row (extract 6.2 item 8, the extract's interpretation).
  - Records sharing a `group` (paragraph + Category [+ phase subset]) form the unit whose Level is reported. At a point: Level = the smallest L whose records all pass (not-applicable counts as pass); none -> 4 ("worse than Level 3"). A group whose records define only Level 3 (3.2.1.1: Levels 1-2 are stick-force based) reports "Level 3 boundary met (Levels 1-2 not assessed)".
  - Margin m = min((y - lo)/scale, (hi - y)/scale), finite bounds only; scale = |lower bound|, else |upper bound|, else (bound 0) the next Level's non-zero bound (stated per record in `scale_basis`).
  - Table VI increment: lo_eff = lo + slope*max(0, omega_nd^2|phi/beta|_d - 20) with slope .014 (L1), .009 (L2). Level 3 has no base zeta_d*omega_nd ("-"), so its .005 increment is not encoded (coverage NO-REQUIREMENT; see NOTES).
  - The 3.3.1.4 CO/GA prohibition is a Q-PROXY record `coupled_roll_spiral_present <= 0`.
- **Why:** the record stays traceable 1:1 to a transcribed number, and the Level logic is the spec's own (6.7.1).
- **Evidence:** `tests/M6/tFqRules.m` (traceability to the candidate file and to the extract text, strictness, coverage), `tests/M6/tFqEngine.m`.

### ADR-0xx: Status-aware search; PARTIAL results; NOT_ASSESSABLE (2026-09-29)
- **Decision:** a point is used for a record only if its trim, linearization and point evaluation are OK and the metric status is OK with a non-NaN value. Every other point is EXCLUDED and counted by `<stage>:<status>`; a NOT_APPLICABLE metric (no coupled roll-spiral mode) is counted separately. The critical point is the smallest margin over USED points only (FC-702). Record/group status: ASSESSED, PARTIAL (some points excluded: the Level holds over the used points only and is an optimistic bound for the excluded region), NOT_ASSESSABLE (no used point, FC-701, or a Category the policy does not assess), NOT_APPLICABLE.
- **Consequence:** an excluded point can never improve or worsen a verdict silently; the report always lists how many points were excluded and why.
- **Optional refinement:** one step around every critical grid point, at the midpoints to the neighbouring grid values on every axis (never outside the axis range). A refined point is used only if OK.

### ADR-0xx: Category C is NOT_ASSESSABLE for the NESC F-16 (2026-09-29)
- **Context:** Category C (TO, CT, PA, WO, L) is defined by terminal-phase configurations. The NESC F-16 model (F16_aero.dml) has no gear, flap or speed-brake terms.
- **Decision:** the Category C records are curated (they are part of the spec and traceable) but `conditions_f16.json` sets `category_policy.C.assess = false`; every Category C record and group is NOT_ASSESSABLE with that reason. A clean configuration at approach speed is NOT used as an approach configuration. 3.2.1.3 (PA only) is listed OUT-OF-SIM in the coverage table.
- **Evidence:** `tests/M6/tF16Fq.m#categoryCNotAssessable`, `tests/M6/tFqEngine.m#categoryPolicyNotAssessable`.

### ADR-0xx: Condition space and Operational Flight Envelope proxy for the NESC F-16 (2026-09-29)
- **Context:** 3.1.10.1 requires Level 1 in the Operational Flight Envelope (Table I: e.g. CO from 1.4 V_S to V_MAT, MSL to combat ceiling). The NESC model defines neither V_S (no stall/buffet boundary), nor V_MAT or ceilings, and its aero tables have **no Mach dependence** (low-speed data; only the thrust table depends on Mach 0-1 and altitude 0-50,000 ft).
- **Decision:** `rules/mil_f_8785c/conditions_f16.json` registers an OFE PROXY: altitude 5,000-37,000 ft, Mach 0.30-0.76, CG 20-30 % MAC, level 1-g flight, standard day, flat Earth, zero wind (default grid 5 x 5 x 3 = 75 points). The grid values AND their refinement midpoints avoid the thrust-table breakpoints (every 10,000 ft and every 0.2 Mach): a first default grid on Mach 0.4/0.6/0.8 and 5,000/15,000/... ft lost 76 of 141 points to breakpoint NOT_CONVERGED linearizations (FC-510, by design). Mach 0.30 keeps trim alpha below about 21 deg; the upper limit stays below Mach 0.8 because Mach-independent aero data are not defensible beyond it. Points that do not trim are excluded and counted, never extrapolated. Small registered grids (`test`, `readme`, `mutation`) keep tests fast.
- **Consequence:** the reported Levels are "Levels over the proxy envelope", not a statement about the real F-16's OFE.

### ADR-0xx: Metric definitions for the bare-airframe NESC F-16 (2026-09-29)
- **n/alpha** follows 6.2 (p.77) literally: steady-state normal acceleration per alpha for an incremental pitch-control deflection at constant speed, from the [alpha q] rows of the air-axis model with the elevator column (includes the elevator's own lift). It is (V/g)(1/T_theta2) of the usual handbooks. It differs from the M5-A `lin.n_alpha` (alpha-only lift slope): 14.77 vs 14.90 g/rad at the README trim. Defined for level trims only (NOT_LEVEL otherwise).
- **Equivalent system (3.1.12):** the bare airframe's classical modes are used directly (no low-order fit).
- **Phugoid (3.2.1.2) and speed divergence (3.2.1.1)** use `vital.linear.modes(lin, 'IncludeHeight', true)` (coordinator instruction after M5-X: the nonlinear F-16 follows the 9-state phugoid, zeta 0.077, not the 8-state 0.095). All other metrics use the 8-state modes; `tF16Fq#heightCouplingOnlyMovesPhugoid` shows the 9-state model moves the short period by < 1e-3 relative and the lateral modes by < 1e-9.
- **Times to double** are Inf for modes that do not diverge (6.2.1 defines T2 only for divergence); ln 2 replaces the printed .693. An unstable roll root has tau_R = Inf (no convergence time constant; worse than every Level). The aperiodic speed divergence (3.2.1.1 Level 3) is the largest positive real longitudinal root whose participation is u/theta dominated (p_u + p_theta > p_w + p_q), whatever name the M5-A classifier gives it.
- **Non-OK modes** (NOT_OSCILLATORY, UNCLASSIFIED, missing) give a metric status, never a number (FC-703). An over-damped or split short period is therefore excluded, not rated.

### ADR-0xx: AeroScale mutation multipliers (2026-09-29)
- **Decision:** `vital.aircraft.f16.config('AeroScale', struct(...))` with Cm_q, Cl_p, Cn_beta (default 1; unknown names or values that are not finite reals >= 0 are vital:badInput). `vital.aircraft.f16.loads` applies each multiplier that is not 1 to ONE term of the generated NESC model:
  - Cm_q: `cm = cmt + cq2v*(Cm_q*cmq)` (the czq normal force and its moment arm to the CG are not scaled; at CG 25 % that arm contributes about 0.1*czq ~ -3 of the effective Cm_q,cg ~ -8, so "Cm_q x 0.3" reduces the total pitch damping to about 0.56 of its value)
  - Cl_p: `cl = cl1 + b2v*(Cl_p*clp*p + clr*r)`
  - Cn_beta: `cn = Cn_beta*cnt + dcnda*dail + dcndr*drdr + b2v*(cnp*p + cnr*r)` (cnt is the whole beta dependence of Cn, zero at beta = 0)
- With every multiplier equal to 1 the aero outputs are not touched (bit-identical; `tAeroScale#defaultIsBitIdentical`, and the full M2-M5 gate).

---

# Revisions after review R2 (2026-10-05; coordinator decisions)
The ADRs above are kept as first proposed. Where a revision below differs, the revision supersedes them.

### ADR-0xx (R2-1): A divergent point FAILS; it is never excluded
Supersedes the "split short period is excluded" part of the metric ADR.
- **Context (R2 B1):**
  - At 37,000 ft / Mach 0.5 / CG 30 % the bare F-16 has a real longitudinal root of about +0.2 1/s (T2 = 3.4 s). Its participation is not u/theta dominated.
  - The 3.2.1.1 speed metric ignored it, and the split short period was EXCLUDED as NOT_OSCILLATORY. No longitudinal group failed.
- **Decision:**
  - New metric status **DIVERGENT**: the requirement cannot be met at the point (an unstable real root where an oscillation is required).
    - The engine USES the point with margin -Inf. It fails every Level (Level 4) and is not counted as excluded.
    - A short period split into real roots with an unstable root makes zeta_sp, omega_nsp and CAP DIVERGENT.
    - A split phugoid with an unstable root makes zeta_p DIVERGENT, and T2_phugoid_s = ln2/lambda (6.2.1, first-order divergence).
    - A split with both roots stable stays NOT_OSCILLATORY (excluded and counted).
  - New metrics:
    - `lon_divergence_rate_1_s`: the largest real longitudinal root over the 8-state and 9-state modes, height root included.
    - `T2_aperiodic_divergence_s` = ln2/rate (Inf if the rate is <= 0).
    - `speed_divergence_rate_1_s`: the same over the u/theta-dominated roots, 9-state, height root included (R2 MINOR 10).
  - New records **3.2.2.2** (Q-PROXY; interpretation recorded in `source.interpretation`):
    - Source (p.13): "no tendency for the airplane pitch attitude or angle of attack to diverge aperiodically with controls fixed or with controls free".
    - No Level is named, so the requirement applies at all Levels (3.1.10.3.2).
    - Encoded as `lon_divergence_rate_1_s <= 0` at Levels 1–3, Categories A, B and C.
    - The level 1-g trim is taken as the n = 1 member of the steady pull-ups.
    - Controls free and the force/deflection sense remain OUT-OF-SIM.
  - New records **3.2.1.1 Levels 1–2** (R2 M1):
    - Source (p.11): "no tendency for airspeed to diverge aperiodically", controls fixed.
    - Encoded as `speed_divergence_rate_1_s <= 0`.
    - The force/position gradients (a sufficient demonstration) and the controls-free half stay in coverage.
  - Scale of the rate records: ln2/6 1/s, the rate of a 6-s time to double (the 3.2.1.1 Level 3 floor), stated in `scale_basis`.
  - Note: in the validity envelope the binding root of `lon_divergence_rate_1_s` is the slow, slightly stable height root (about -0.0013 1/s), so the in-envelope 3.2.2.2 margin is small (0.011) but positive.
- **Evidence:**
  - `tests/M6/tFqMetricsR2.m`
  - `tests/M6/tFqEngineR2.m#divergentMetricFailsNotExcluded`
  - `tests/M6/tF16FqR2.m#pitchDivergencePointFails`

### ADR-0xx (R2-2): Excluded points never hide a worse Level
Supersedes the "PARTIAL ... optimistic bound" wording.
- **Decision:**
  - A group with excluded (unrated) points is `complete = false`.
  - Its `levelHeadline` is NaN, unless a rated point is already worse than Level 3; then Level 4 is certain.
  - Its `levelText` reads "Level L or worse (k of n points unrated)" and is printed instead of a plain Level.
  - `worstLevel` keeps its meaning (the worst Level over the rated points).
  - A group whose rated points are all NOT_APPLICABLE but which has unrated points is PARTIAL, and both counts are given (R2 MINOR 2).
- **Roll mode fallback (R2 B2 b):**
  - When the classifier names no OK roll mode, tau_R uses the fastest lateral real root that is not a Dutch-roll root. The spiral is then the slowest.
  - The classifier disagreement is recorded in the metric reason and in the point notes.
  - The classifier's body-axis "p largest" signature is not a MIL definition: at alpha 25 deg the roll subsidence is about the stability axis.
  - With a coupled roll-spiral oscillation, tau_R and spiral_T2 are NOT_APPLICABLE (R2 MINOR 11).
- **Evidence:**
  - `tests/M6/tFqEngineR2.m#excludedPointNeverHidesWorseLevel`, `#missingModeNeverPasses` and `#notApplicableWithExclusionsIsPartial`
  - `tests/M6/tFqMetricsR2.m#rollFallbackFastestLateralRealRoot`
  - `tests/M6/tF16FqR2.m#lowSpeedRollModeRated`: at 29,000 ft / Mach 0.30 / CG 20 %, tau_R = 4.57 s and 3.3.1.2-CatB is Level 3.

### ADR-0xx (R2-3): The NESC model's validity envelope; headline Levels are in-envelope Levels
Supersedes the OFE-proxy ADR's grid and its "alpha below 21 deg".
- **Context (R2 M8):**
  - The NESC F16_package README (Assumptions and Limitations, README.html line 910) says: "Flight envelope is limited to the vicinity of 10,000 ft MSL and 287.8 knots equivalent airspeed".
  - The earlier report gave every Level from points at 25–37 kft and 92–232 KEAS without saying so.
- **Decision:**
  - `conditions_f16.json` registers `validity`:
    - **|h − 10,000 ft| <= 5,000 ft and |KEAS − 287.8| <= 20 % (230.24–345.36 KEAS); CG not restricted.**
    - The radius is a **JUDGMENT** by agent fq (the README gives none). It is labelled as such in the file, the report and the printout.
  - Every point is tagged `envelope: IN | EXTRAPOLATED` (`vital.fq.envelopeTag`; KEAS from `vital.fq.f16Factory`, US 1976).
  - Every record and group carries `.inEnvelope` and `.extrapolated` summaries.
  - The HEADLINE Level per group is the in-envelope Level. The EXTRAPOLATED Level and its critical condition are printed in a separate table, labelled "indicative only".
  - Grids:
    - `default`: h {5,000, 8,000, 13,000, 21,000, 29,000, 37,000} ft × Mach {0.30, 0.37, 0.45, 0.50, 0.55, 0.63, 0.76} × CG {20, 25, 30} %, i.e. 126 grid points; 30 points are IN after refinement.
    - `exploration`: the earlier wide 5 × 5 × 3 grid.
    - Grid values and refinement midpoints avoid the thrust-table breakpoints.
  - At the low-speed, high-altitude corner the trim alpha reaches about 25 deg (R2 MINOR 1: the earlier "below 21 deg" text was wrong).
- **Evidence:**
  - `tests/M6/tFqEngineR2.m#envelopeTagging`
  - `tests/M6/tF16FqR2.m#defaultGridHeadlineAndExtrapolation` and `#readmeRevisedRecords`

### ADR-0xx (R2-4): Report files are named by grid and AeroScale and never silently overwritten (R2 M9)
- **Decision:**
  - `run_f16_fq` writes `<ReportDir>/f16_fq_<grid>_<tag>.json/.md` (`vital.fq.reportName`). The tag is `baseline` or, e.g., `Cm_q0.3`; the grid is `user` for 'Axes'.
  - If such a file exists and 'Overwrite' is false (the default), the run is written under a timestamped name and the printout says the existing file was kept.
  - The delivered reports are `reports/fq/f16_fq_default_baseline.*` and `reports/fq/f16_fq_exploration_baseline.*`, regenerated on 2026-10-05 with 'Overwrite', true.
- **Evidence:** `tests/M6/tF16FqR2.m#reportNamingNeverOverwritesDefault`.

### ADR-0xx (R2-5): AeroScale 'Cn_beta' renamed 'Cnt_table' (R2 M5)
Supersedes the AeroScale ADR's Cn_beta bullet.
- **Decision:**
  - The knob scales the NESC static sideslip yawing-moment TABLE cnt(beta, alpha) about the MRC (35 % MAC).
  - The airplane's N_beta about the CG also contains the side-force transfer (cy0 = −0.02 beta(deg), arm 0.345 m at CG 25 %). So `Cnt_table` × 0.2 gives body N_beta × 0.335 at the README trim, not × 0.2.
  - The old name is vital:badInput.
  - The effective CG-derivative ratios are registered REG checks (`tests/M6/tF16FqR2.m#aeroScaleEffectiveDerivatives`):
    - Cnt_table × 0.2 → body N_beta × 0.335 ± 0.01
    - Cm_q × 0.3 → M_q × 0.556 ± 0.01
    - Cl_p × 0.4 → L_p × 0.400 ± 0.005
  - M8 must treat these multipliers as multipliers of MRC coefficients, not as CG-derivative uncertainties.

### ADR-0xx (R2-6): Table VI increments at every Level (R2 M4, MINOR 3)
- **Decision:**
  - The source (p.22): "the minimum zeta_d omega_nd shall be increased above the zeta_d omega_nd minimums listed above by" .014 / .009 / .005 (omega_nd²|phi/beta|_d − 20).
  - Where the base is printed "–", the increment is applied with base 0:
    - Level 3 (all groups): `zeta_d_omega_nd > 0 + .005 max(0, x − 20)`
    - Level 1 CO/GA: `zeta_d_omega_nd > 0 + .014 max(0, x − 20)`
  - Both are strict ("shall exceed").
  - This is the only reading that gives the printed lines an effect. It is recorded in `source.interpretation`.
- **Not changed (MINOR 3):**
  - CO/GA use the "A (CO and GA)" row only (the extract's interpretation). The "both rows" reading is not encoded, and the report says so.
  - The two readings differ only through the increment, when omega_nd < 1.74 rad/s. On the current grids zeta_d < 0.19 everywhere, so the Level is the same.

### ADR-0xx (R2-7): 3.3.1.4 prohibition for Category A phases other than CO/GA (R2 M2)
- **Decision:** add group `3.3.1.4-CatA-other` with the Q-PROXY prohibition `coupled_roll_spiral_present <= 0`.
- **Why:** this is the conservative reading of "such as CO and GA": the ζω permission is given to Categories B and C only.

### ADR-0xx (R2-8): Linear column status (R2 MINOR 6; linear ADR-028)
- **Decision:**
  - `vital.fq.metrics` accepts a linear model whose status is NOT_CONVERGED when the columns it uses (1–8, 13) are OK.
  - `vital.fq.evaluatePoint` then computes the 8-state metrics. The phugoid and speed metrics need the h column, so they get NOT_CONVERGED when column 12 is not OK.
- **Not implemented:** the second half of MINOR 6, i.e. evaluating zeta_p with both one-sided h columns at an altitude breakpoint and keeping the worse.
  - The registered grids avoid the altitude breakpoints.
  - At a breakpoint the phugoid metrics are reported as unrated, never as a two-sided average.

## ADR-031: Stability augmentation and design feedback (M7; agent ctrl, 2026-10-07)
The agent's decisions are kept under their original labels (ctrl-1 to ctrl-5).

### ADR-0xx (ctrl-1): M7 control laws are static deviation laws about the trim, built from the trim
- **Context.** ADR-024 linearizes only declared-static controllers, and ADR-026 has the controller measure y(x, u_applied). A SAS needs reference values (alpha0, q0, r0, KEAS0, theta0) that depend on the trim.
- **Decision.**
  - Every M7 law is built about an OK trim: `c = vital.ctrl.<law>(AC, env, tr, ...)`. The references are the plant outputs at the trim (`y0 = vital.plant.derivatives(tr.x, tr.u, AC, env)`, `vital.ctrl.refAtTrim`), so the law returns exactly `u_trim` at the trim. The closed-loop equilibrium is the open-loop trim, which makes ADR-024's `controllerNotAtTrim` check hold by construction. A trim that is not OK is `vital:ctrl:notTrimmed`.
  - The law is a deviation about the reference command u_ref of vital.sim.run:
    - pitchSas: `de = de_ref + Kq (q - q0) + Ka (alpha - alpha0)`
    - yawDamper: `dr = dr_ref + Kr (r - r0) + Kari (da_ref - da_trim)`
    - `vital.ctrl.combine` sums the deviations of several laws (same rate; static only if every member is).
  - Signs come from CONVENTIONS 7 and were derived before any run: +de gives a nose-down moment, so Kq > 0 damps and Ka > 0 stiffens; +dr gives a nose-left moment, so Kr > 0 damps the yaw. Negative gains are legal inputs. Their effect is reported (`vital.ctrl.closedLoop` UNSTABLE / destabilized, Level 4 in vital.fq.assess) and never presented as an improvement.
  - No washout, filter or integrator: every law is static (`static = true`, init `[]`). A washed-out yaw damper would need the augmented-state closed-loop linearization that ADR-024 defers. That is not built here. Consequence: the yaw damper also opposes the steady yaw rate of a turn, and the spiral becomes more stable.
  - Limits: no M7 law clips. vital.sim.run's control-limit monitor (ADR-027) flags any command beyond AC.limits, and tCtrlLaws shows a flagged, unclipped elevator command.
- **Evidence.** `tests/M7/tCtrlLaws.m`, `tests/M7/tCtrlClosedLoop.m`.

### ADR-0xx (ctrl-2): NASA's NESC LQR SAS on the flat-Earth plant (vital.ctrl.nescLqr)
- **Decision.**
  - The generated law `vital.models.f16.control` (F16_control.dml) is evaluated with sasOn = 1 and apOn = 0. The gains are never re-typed: tCtrlLaws checks that the source does not contain them.
  - The signal mapping is that of vital.nesc.f16Controller (N6, N6c), adapted to the flat Earth:
    - KEAS = `vital.nesc.equivalentAirspeed(V, 2 qbar / V^2)`. The flat-Earth plant has no y.rho, and this form is exact.
    - Body rates are y.p, y.q and y.r.
    - The LQR references alpha, theta and KEAS are shifted to the trim exactly as in N6.
  - The reference command u_ref enters through the law's own trim and pilot inputs:
    - `longStkTrim = -de_ref/25`, `throttleTrim = thr_ref`
    - `latStk = -da_ref/21.5`, `pedal = -(dr_ref - 0.008 da_ref)/30` (all in deg)
    - So u = u_ref when every LQR error is zero, and Kref = I.
  - NASA's own stick and throttle limiters are part of the published law and are kept. `c.lawState(y, u_ref)` reports when one is active. The law can command el = 25 deg, beyond AC.limits 24 deg; vital.sim.run flags that and never clips it.
- **Disclosure.** The LQR is a point design for 10,000 ft / 287.8 KEAS. It is analysed at the README trim, and in-envelope use is labelled as such.
- **Evidence.** `tests/M7/tCtrlLaws.m#nescLqrIsNasaPublishedLaw` (hand law from the NESC_EXTRACT_F16 C.2 gain table), `tests/M7/tCtrlClosedLoop.m#handClosedLoopNescLqr`, `tests/M7/tCtrlSimAgreement.m#nescLqrSimMatchesLinear`.

### ADR-0xx (ctrl-3): Equivalent system of the augmented aircraft (MIL-F-8785C 3.1.12)
- **Context.** M6 grades the bare airframe's classical modes directly (ADR-030, metric ADR). 3.1.12 asks for equivalent classical systems when the augmented aircraft has extra dynamics.
- **Decision.**
  - The M7 controllers are static, so the closed loop has the same 8 states and no added mode. The closed-loop modes from `vital.linear.modes` are used directly as the equivalent system.
  - `vital.fq.evaluatePoint` sets `info.closedLoop = true` and `info.equivalentSystem = 'CLASSICAL'` when the closed-loop modes are exactly the five classical modes, all OK. Otherwise it sets `'FLAGGED'`, with a note citing 3.1.12: for example a Dutch roll split by a large yaw-damper gain, or an 'other' mode.
  - `vital.ctrl.suggestGains` lists every flagged confirmation point.
  - A dynamic (non-static) controller is refused by the linearization (`vital:linear:dynamicController`). The point becomes an ERROR point and the groups are NOT_ASSESSABLE, never a Level.
  - n/alpha (6.2) is invariant under static elevator feedback, because it is the same physical steady state, reparametrized. The closed-loop metric equals the bare one (tCtrlFq, 1e-6). For the NESC LQR the closed-loop [alpha q] rows also contain the throttle feedback, so its n/alpha is that of the augmented aircraft.
- **Not done.** No low-order equivalent-system fit, since a static loop needs none. A dynamic SAS (washout, filters, actuators) would need both the fit and the augmented-state linearization.
- **Evidence.** `tests/M7/tCtrlFq.m#augmentedPointMetrics`, `#equivalentSystemFlag`, `#nonStaticLawIsNotAssessable`.

### ADR-0xx (ctrl-4): Closed-loop option of the fq factory; the default path is unchanged
- **Decision.**
  - `vital.fq.f16Factory('Controller', b)` takes a builder `ctrl = b(AC, env, tr)`, because the law needs the trim. The factory stores it as `ac.controllerFcn`.
  - `vital.fq.evaluatePoint` builds the controller after the trim and linearizes the closed loop.
  - With no controller (the default, `[]`) the ac struct has no new field, P.info has no new field, and the code path is the M6 one. Results are bit-identical: tCtrlFq checks isequal, and reproduces the stored in-envelope critical values of `reports/fq/f16_fq_default_baseline.json` to 1e-12. The full M6 gate also passes unchanged.

### ADR-0xx (ctrl-5): Design feedback, vital.ctrl.suggestGains, and what counts as success
- **Decision.**
  - **Targets** are (group, Level) pairs graded on the in-envelope points only. `vital.ctrl.inEnvelopeConditions` gives the default-grid values that hold all 30 IN points (36 points, 6 EXTRAPOLATED).
  - **Target margin.** A target's margin is the minimum over the group's records at the target Level of their in-envelope minimum margin. The arg-min record and condition form the active set.
  - **Protected groups.** Every other group with a finite bare headline Level must keep it. The constraint is margin to its bare Level >= min(Goal, bare margin)/2.
  - **Sensitivities.** Forward finite differences through the whole chain (factory, trim, closed-loop linearize, modes, metrics, assess). For every constraint and gain, the critical record and condition at k and at k + h are recorded, and a switch is reported.
  - **Step.** Minimum-norm step in normalized gains (`lsqlin`) under the linearized constraints, the box and a trust region of half the range. When that is infeasible, the least-squares step on the violated constraints is taken. A step is accepted only if the violation sum(max(0, req - m)) falls, with halving at most twice.
  - **Proposal and confirmation.** The best iterate is rounded to the resolution (0.01). A fresh `vital.fq.assess` is then run with the rounded gains. Only this confirmation run decides the status:
    - `TARGET_REACHED`: every target's in-envelope headline Level is at or below its target, and no protected group is worse than bare
    - `TARGET_NOT_REACHED`: anything else, with the reason, best margin and critical condition
    - `NOT_ASSESSABLE`: no bare in-envelope Level for a target
  - The search's own last assessment (made with unrounded gains) is kept separately as `s.search` and is never reported as the confirmation.
- **Pre-registration.** Targets, gain box, success criterion, expected sensitivity signs and the decoupling are in the header of `tests/M7/tCtrlSuggest.m`. They were written before the search existed.
- **Evidence.** `tests/M7/tCtrlSuggest.m`.


## ADR-032: Uncertainty analysis (M8; agent uq, 2026-10-07)

The M8 design itself is the coordinator's contract (docs/PLAN_M5_M8.md, "M8 uncertainty"). The decisions below are the agent's choices where the plan left room, and one deviation.

### ADR-0xx (uq-1): AeroScale field `Cnr_table` for the plan's parameter `Cn_r` (DEVIATION)
- **Context.** The plan names the new AeroScale field `Cn_r` (scales `cnr`). `tests/M6/tAeroScale.m#badAeroScaleRejected` uses `'Cn_r'` as its example of an UNKNOWN multiplier and must keep raising `vital:badInput`; an M8 agent may not edit M6 tests.
- **Decision.** The field is `Cnr_table` (consistent with `Cnt_table`, `Cm_table`, `Cl_table`: "scale the NASA table X"). The uncertainty parameter keeps the plan's name `Cn_r`; `uq/f16_uncertainty.json` maps it (`"name": "Cn_r", "aeroScale": "Cnr_table"`), and every report prints both.
- **To undo.** If the coordinator prefers `Cn_r`, change the unknown-name example in tAeroScale (e.g. to `'Cx_q'`), rename the field in config.m/loads.m and the spec file; tests/M8 reference `Cnr_table` in tAeroScaleUq, tUqSpec and tF16Uq.

### ADR-0xx (uq-2): AeroScale extension, order of operations
- `Cm_table`: `cm = (Cm_table*cmt) + cq2v*(Cm_q*cmq)`; `Cl_table`: `cl1 = Cl_table*clt + dclda*dail + dcldr*drdr`, `cl = cl1 + b2v*(Cl_p*clp*p + clr*r)`; `Cnr_table`: `cnr <- Cnr_table*cnr` before `cn` is rebuilt (with or without `Cnt_table`). Each block runs only when one of its multipliers is not 1, so the default path is the generated model, bit-identical (tests/M8/tAeroScaleUq.m#defaultPathBitIdentical; the M6 Cnt_table line and its sabotage S6F pattern are unchanged).
- `Cm_table` scales the WHOLE pitching-moment table cmt(el, alpha) about the MRC: M_alpha and M_de together, and the trim moment that balances the normal-force moment about the CG. A Cm_table change therefore moves the trim (tF16Uq failed hypothesis 5b), unlike Cm_q.

### ADR-0xx (uq-3): Search details not fixed by the plan
- LHS: own stratified construction `(randperm - rand)/n` per dimension from `RandStream('mt19937ar', 'Seed', 2026)` (no global rng, no lhsdesign).
- The fmincon starts are the NumStarts best DISTINCT points of the centre/corner/LHS phases (sort by margin, stable).
- fmincon: sqp, bounds = the box (sqp honours bounds in its finite differences; every evaluated point is inside the box, tBoundWorstToys#cliffOutsideNeverSeen), forward differences with step 1e-3 relative to theta (well above the step-study linearization noise), MaxFunctionEvaluations = the budget, and a hard budget in the objective wrapper. A non-OK point is NaN to the optimizer; a -Inf (divergent) point stops it (a definitive counterexample).
- A point's margin is the minimum over the candidate conditions that are OK; the point is OK only if all are. A start whose objective is not finite (e.g. +Inf: the 3.3.1.3 spiral T2 of a stable spiral) cannot be optimized and counts as not converged -> NOT_ASSESSABLE (FC-901), never OK.
- Status precedence: VIOLATED (any evaluated point or the confirmation below the reserve) > NOT_ASSESSABLE (non-OK point, non-OK confirmation, or FC-901) > OK.
- Margin of a group at a point = min over the group's records at the nominal Level L0 of their margin (NOT_APPLICABLE records ignored), the M7 levelMargin definition at one point; the in-envelope margin uses vital.ctrl.suggestGains' definition (vital.uq.F16Evaluator.levelMargin).
- Candidate ranking: per in-envelope point, the margin to L0; stable sort (ties in point order).
- Monte Carlo: `RandStream('mt19937ar', 'Seed', 2026)`, `randn(stream, N, d)`, identical to rng(2026, 'twister') + randn (tMonteCarloVerdict#seededSamples), global state untouched. A sample whose AeroScale would be negative is a vital:badInput exception -> a listed failure.
- Verdict: a finite bound-worst value below the reserve also counts as a violation (only reachable with a reserve > 0).
- Evaluations are cached by (theta, condition) in one vital.uq.F16Evaluator per analysis, so groups share the centre/corner/LHS points.
- The analysis is run on the conditions of vital.ctrl.inEnvelopeConditions (36 points, 30 IN); only IN points are candidates or count in the confirmation.

**Evidence.** tests/M8/tBoundWorstToys.m, tMonteCarloVerdict.m, tClopperPearson.m, tUqSpec.m, tAeroScaleUq.m, tF16Uq.m, tRunF16Uq.m.


## ADR-033 (agent uq2, 2026-10-09): M8 amendment after review R3, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment after review R3"). These are the choices where it left room.

### uq2-1: Moving limit, re-search (R3-M4)
- `vital.uq.boundWorst(..., 'MaxRounds', 3)`. A **round** = one full search (centre, earlier arg-mins as phase 'previous', 2^d corners, LHS, fmincon) followed by one confirmation. "At most 3 rounds" = at most 3 searches.
- If the confirmation moves (status OK and margin < the round's search value), the moved condition (`c.cond`, which confirmFcn must now return to allow a re-search) is added to the candidates, and the round's arg-min theta is re-evaluated first in the next round, so the moved condition is seen where it was found.
- Stop when: the confirmation does not move (settled); any round has a counterexample (definitive, no further rounds); MaxRounds is reached; confirmFcn returns no `cond`; or the moved condition is already a candidate (the point evaluation and the confirmation disagree). In the last three cases the status is `NOT_ASSESSABLE` with a reason starting `MOVING_LIMIT`, and the confirmation value replaces the search value (as before).
- `OK` needs all of these: every point of the final round OK, no non-OK point in any earlier round, every start of the final round converged, and a final confirmation that is OK and did not move.
- New fields: `bw.rounds` (round, candidates, nEvaluated, searchValue, theta, cond, record, converged, nNonOK, nViolating, confirmation), `bw.nRounds`, `bw.conditions/condLabels` (the final candidates), `bw.condition` (the arg-min's condition object), `bw.points.condIndex`. `bw.points` is the final round's point set.

### uq2-2: Longitudinal-only search (R3-M3(a))
- `vital.uq.searchPlan` gives mode 'longitudinal' to groups whose name starts with `3.2.` when `LonOnly` is true (the default). The searched parameters are the AeroScale fields in `LonFields` = {Cm_q, Cm_table} that are present in the box; if none is present, the mode is 'full'. Parameters are chosen by AeroScale field, so `uq/f16_uncertainty.json` is unchanged.
- The gate is tests/M8/tUqR3F16.m#lonLatInvariance: 3 IN conditions x lon {1, x1.5 lower corner} x 4 lateral corners of the x1.5 box. Every longitudinal metric must agree within 1e-9 relative; the measured worst deviation is 3.8e-14.
- `vital.uq.analyze` adds a runtime spot check at the group's critical condition: the margin with the lateral multipliers at the widest box's lower corner must equal the nominal one within 1e-9 relative. If it does not, the full box is searched and the plan says so.
- The result is reported over all six parameters (`bw.theta`, `bw.points.theta` and `bw.rounds.theta`, with the held parameters at 1), plus `bw.searchNames/searchIndex`. The `bw.optimizer` starts stay in the searched coordinates.
- The Monte Carlo is unchanged and still samples all six parameters; its samples of the first two parameters are identical either way.

### uq2-3: Surrogate search of +Inf groups (R3-M3(b))
- Mode 'surrogate' applies when the nominal in-envelope margin is +Inf and every metric of the group is `spiral_T2_s`. It searches all parameters.
- The surrogate is the real part of the mode the classifier names 'spiral' (`vital.linear.modes`, via `res.points.info.modes`). It is kept in the cached point summary (`S.spiralRe`).
  - If a point has no single 'spiral' mode, it is non-OK ('NO_SPIRAL').
  - The metric's fallback root is NOT used as a surrogate.
- `vital.uq.surrogateWorst(problem, marginFcn)` is generic. It runs boundWorst on -s with Reserve -Inf: the surrogate itself never "violates", and its moving limits are re-searched like margins. The confirmation is a fresh in-envelope assessment, taking the largest spiral Re over the IN points.
- Mapping to the true margin:
  - s_max <= 0: value +Inf. The status is OK (when the surrogate search is OK), with the reason "stable over the box (surrogate search) ...".
  - s_max > 0: the true margin at the arg-max (theta, condition). The status is VIOLATED if that margin is below the reserve, else the surrogate search's status.
  - No finite s anywhere: NOT_ASSESSABLE.
- The candidates and the Monte Carlo condition (the critical condition) are ranked by the surrogate, most unstable first (`F16Evaluator.inEnvelopeSurrogate`, `F16Evaluator.candidates`).

### uq2-4: "Sampled only" (R3-M2)
This is a label, not a verdict change. It applies when any metric has unit '0/1' (vital.fq.metricNames; 3.3.1.4), or when every evaluated margin is equal (flat).

### uq2-5: Kinked toy (R3-M2)
- R3 called it a "min-of-two-planes valley". A minimum of two planes is a ridge whose box minimum is at a vertex. So the interior V was built as the larger of two planes meeting along u1 = 0.3, which is the shape R3 found for 3.2.2.1.2-CatA.
- Pre-registered and observed: NOT_ASSESSABLE / FC-901. sqp exhausts 60 evaluations at the crease, with value 0.10024 against a true minimum of 0.10. Shifted below zero, the result is VIOLATED.

### uq2-6: Mahalanobis, coverage (R3-M5, m2)
- `vital.uq.mahalanobis` gives D in the x1 (judgment) sigmas, and the tail P(chi2_k >= D^2) with k = the number of searched parameters (2 for longitudinal groups, as in R3 3.5).
- `vital.uq.boxCoverage` gives prod erf(k_g/sqrt2) = 0.9707. It is identical at every width, because the box and the Monte Carlo sigma scale together.

### uq2-7: Effective CG-derivative ratios (R3-M5; tests/M8/tUqR3F16.m, bare trim 13,000 ft / M 0.45 / CG 30 %)

| multiplier (value) | effective CG-derivative ratio |
|---|---|
| Cm_table (0.8712) | M_alpha,cg x 1.0407 (note: above 1), M_de,cg x 0.8761 |
| Cm_table (1.1288) | M_alpha,cg x 0.9593, M_de,cg x 1.1239 |
| Cl_table (0.8483) | L_beta,cg x 0.848257 (exact) |
| Cnr_table (0.6965) | N_r,cg x 0.7100 |

At this condition the MRC part of M_alpha is destabilizing (A/(A+B) = -0.316). Scaling cmt down therefore makes M_alpha about the CG MORE stable, while it cuts elevator power by 12 %. The coupled Cm_table perturbation is not "less static stability". Accepted and documented (amendment R3-M5).

**Evidence.** tests/M8/tUqR3Fixes.m, tUqR3F16.m, tUqR3Report.m, tBoundWorstToys.m (3'), tF16Uq.m (9, m1 guard).


## ADR-034 (proposed; agent uq3, 2026-10-13): M8 amendment R4, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment R4: judgment-light robustness", R4-1..R4-6). These are the choices where it left room, and one contract inconsistency.

### uq3-1: CSR algorithm: bisection on alpha with the box searches (R4-1)
- **Decision.** `vital.uq.csr` brackets alpha* between box searches ("clean" / "failing") and refines every failing point along its ray from the nominal. Not the direct form (min ||p - pbar||_inf,m subject to margin(p) <= 0).
- **Why.**
  - The direct form only returns a failing point, i.e. an UPPER bound on alpha*. Claiming alpha* to +/- 0.01 also needs the box just below to be free of failures, which is a box search anyway. The bisection backs both ends with evidence: the lower end by a box searched clean (grid-certified or hybrid search estimate), the upper end by a failing point confirmed by a fresh in-envelope assessment.
  - It reuses everything the bound-worst already has: the grid certificate (R4-3), the hybrid search (R4-4), the moving-limit confirmation (R3-M4), the evaluator cache, and the x1 bound-worst result as a prior.
  - The scaled infinity norm is homogeneous, so a ray bisection from the nominal to a failing point (one point evaluation per step, not a box search) moves the upper end to the first sign change on that ray. For margins where the box corner touches first, the ray of the cap search's arg-min IS the CPV direction, and the bracket closes with one more box search (tests/M8/tUqCsr.m: K1, K2, K6 need 2 box searches).
- **Details.**
  - alphaStar := alphaLo, the largest box searched clean; alphaHi := the scaled norm of the CPV; OK means alphaHi - alphaLo <= 0.01 and a confirmed CPV.
  - Steps: the cap box R(3) first (clean: ROBUST_TO_CAP); then the box at alphaHi - 0.01 ("optimistic"), and after two consecutive failed optimistic steps the bisection midpoint; at most MaxSearches = 15 box searches per shape.
  - The nominal failing gives alpha* = 0 with CPV = the nominal.
  - DecideAt = 1 for the judged shape: if the bracket straddles 1 the box R(1) is searched, so "alpha*(judged) >= 1" is always decided by a search of exactly the judged box.
  - Priors: the x1 bound-worst result is the judged shape's prior; every judged search and the judged CPV are the equal shape's priors. A clean prior box that contains R(a) gives alphaLo >= a, and a prior failing point gives alphaHi <= its norm. If the judged cap box is clean, the equal shape is ROBUST_TO_CAP without a search (3 x k_g sigma >= 0.30 for every parameter).
  - Candidate conditions: the CSR keeps every condition its box searches added (moving limits). The CPV confirmation applies R3-M4: if its critical condition is not a candidate and its margin is smaller, the condition is added, the largest clean box is searched again, and after MaxRounds = 3 rounds the status is NOT_ASSESSABLE (MOVING_LIMIT).
  - A cap box that cannot be decided gives NOT_ASSESSABLE; the DecideAt boxes are still searched, so alphaLo is reported as a lower bound.
- **Evidence.** tests/M8/tUqCsr.m (11 tests, 9 known-answer cases).

### uq3-2: R4 verdict: "alpha*(judged) < 1 with a confirmed CPV" (R4-2)
- NOT_ROBUST when cpvConfirmed and alphaHi <= 1 (a confirmed failing point inside the closed judged box), or when the Clopper-Pearson lower bound is below 0.95. This holds even when the bracket was not resolved (CSR NOT_ASSESSABLE): a confirmed counterexample inside the judged box is definitive, as for the bound-worst.
- ROBUST when the CSR is OK with alphaStar >= 1, or ROBUST_TO_CAP, and the CP lower bound is >= 0.95. Anything else is NOT_ASSESSABLE.
- `vital.uq.verdict` dispatches on its first argument: a CSR result (field alphaStar) gives the R4 headline verdict; a bound-worst result gives the original box verdict. The box verdict is still reported per width (r.groups.widths.verdict) beside the headline (r.groups.verdict). The R3 truth tables (tMonteCarloVerdict, tUqR3) are unchanged.

### uq3-3: Grid certification (R4-3)
- The grid is an integer lattice on the box coordinate t = (theta - lo)/(hi - lo): 11 points per dimension, refined by halving down to 1/2^8 of the base spacing, so keys are exact and the box corners are on the grid.
- Local refinement around the minimum: the cells touching the best lattice point are halved three times (GridLocalLevels).
- Lipschitz estimate: per axis i, L_i = 2 x the largest |dm|/dt_i over every grid edge ever evaluated (a running maximum, so refining never lowers it). Cell bound = min(vertex margins) - sum_i L_i dt_i / 2: every point of the cell is within dt_i/2 of a vertex along each axis (separable Lipschitz bound).
- Cells whose bound is below the reserve are halved and the slopes re-measured, until:
  - certified (OK);
  - a grid point violates (VIOLATED);
  - a grid point is not OK (NOT_ASSESSABLE);
  - the finest spacing or the GridBudget (5000 lattice points; 2000 in vital.uq.analyze) is reached (NOT_ASSESSABLE, reason starting 'GRID').
- The label is always 'grid-certified (Lipschitz estimate)': the slope bound is an estimate from measured secants, not a proof.
- Evidence: tests/M8/tUqGridCert.m. The uq2 kinked valley (FC-901 under sqp) is now certified OK.

### uq3-4: Hybrid search (R4-4)
- **Global stage:** `vital.uq.diffEvolution`, DE/rand/1/bin (Storn and Price 1997), F 0.7, CR 0.9, seeded with Seed + 1. Its initial population is the round's LHS points (no extra cost), topped up with seeded uniform points if needed.
  - Bounds: a component is reflected at the bound it crossed, and drawn uniformly if it is still outside, so every point lies in the box.
  - The budget is fixed (no early stop). Convergence (the population spread) is reported, not required.
- **Local stage:** `fminsearch` from the NumStarts best distinct points of all earlier stages, on z with theta = lo + (hi - lo)(1 + sin(z - 3))/2, budget MaxEvals per start, TolX (in z; 1e-3 in boundWorst, 1e-2 in vital.uq.analyze) and TolFun 1e-4.
  - The offset 3 was found necessary during the implementation. fminsearch's first simplex is 5 % of each non-zero component but only 0.00025 for a zero one, so a start at the exact centre (z = 0) stopped at once with "converged". The offset gives first steps of 0.07-0.23 rad (regression test tUqHybrid#centreStartDoesNotStopAtOnce).
  - A point that is not OK is +Inf to Nelder-Mead.
- **Status:** OK needs every Nelder-Mead start to end with exit flag 1; otherwise FC-901 (as for sqp). The stage table (bw.stages) lists each stage's points and convergence.
- **Measured cost:** at a vertex optimum the sin transform is flat. Nelder-Mead needs about 60-140 evaluations in 3-D and about 140-400 in 7-D to meet the tolerances (scratch characterization with MATLAB's fminsearch; failed hypothesis tUqHybrid 2).
- Evidence: tests/M8/tUqHybrid.m.

### uq3-5: Method rule and the R4-3 / R4-5 inconsistency (DEVIATION NOTE)
- `vital.uq.searchMethod(d)`: 'grid' for d <= GridMaxDim (2) searched parameters, 'hybrid' above. The rule goes by the number of SEARCHED parameters, as R4-3 ("groups searched over 2 parameters") and R4-4 ("more than 2 parameters") state it.
- **Inconsistency.** R4-3 calls the 2-parameter groups "(longitudinal)", but R4-5 makes the longitudinal search {Cm_q, Cm_basic, Cm_de}, i.e. 3 parameters. With the R4 spec, no default F-16 group has <= 2 searched parameters, so every group is searched by the hybrid method and R4-3 is exercised only by the toys and by tUqR4F16#endToEndCsr (a 1-parameter spec).
- `vital.uq.analyze('GridMaxDim', 3)` grids the longitudinal groups instead. Its cost is 11^3 = 1331 lattice points per box before refinement, times 4 candidates. The coordinator decides; nothing in the contract was changed.

### uq3-6: Cm_basic / Cm_de (R4-5)
- loads.m evaluates the generated model a second time with el = 0 (the same alpha, beta, rates and Mach), but only when Cm_basic or Cm_de is not 1. Then:
  - cmt <- Cm_basic cmt0 + Cm_de (cmt - cmt0)
  - then the legacy Cm_table multiplies the result
  - cm = cmt + cq2v Cm_q cmq
- With both at 1 the block is skipped, so the generated model and the R3 Cm_table path are bit-identical (tUqR4F16#splitPitchingMomentTable, #defaultPathAndRename; tAeroScaleUq).
- Spec v2 (`f16_uncertainty_v2`): pitchStatic = {Cm_basic, Cm_de}, sigma 0.05 each, d = 2, so k_g = 3.0349 and the x1 half-width is 0.1517 (was 0.1288 for Cm_table).
- The joint x1 box coverage becomes 0.97579 (was 0.97070).
- The term labels are 'cmt(el=0)' and 'cmt-cmt(el=0)'.

### uq3-7: R3-era tests pinned to the R3 design
- tF16Uq and tUqR3Report test the R3 design's numbers: Cm_table, sqp, the x0.5/x1/x1.5 widths, and the CAP corner -0.0058793. They now run it explicitly on an embedded v1 spec (Cn_r field), with 'Method' 'sqp' and 'CSR' false. Their expectations are unchanged.
- tRunF16Uq and tUqR3#monteCarloSigmaScalesWithWidth add 'Method' 'sqp' and 'CSR' false to keep their runtime.
- tUqR3F16#lonLatInvariance builds the R3 x1.5 box from the R3 table.
- The R4 design on the F-16 is tested in tests/M8/tUqR4F16.m.

### uq3-8: Default budgets of vital.uq.analyze / run_f16_uq (stated in the header and the report)
- WidthScales 1.
- NumLHS 32, NumCandidates 4, MaxRounds 3, N = 200, seed 2026: unchanged.
- grid: 11 points, 3 local levels, 8 refinement levels, 2000 points.
- hybrid: DE 16 x 8, then Nelder-Mead from 2 starts x 150 evaluations, with TolX 1e-2 in z (about 0.5 % of the box in the interior and finer near a bound) and TolFun 1e-4.
- CSR: AlphaMax 3, resolution 0.01, EqualPct 0.10, MaxSearches 15.
- MaxEvals is 150, not 60: measured from a 7-D vertex start, Nelder-Mead needs 92 evaluations with TolX 1e-2 and 142 with TolX 1e-3. With 60, every 7-D box would be FC-901.


## ADR-035 (proposed; agent uq4, 2026-10-14): M8 amendment R4b, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment R4b": R4-3 corrected, R4-7, R4-8, R4-9). These are the choices where it left room, and the interpretations I had to make. No contract decision was changed.

### uq4-1: The shared adaptive lattice (R4-3 corrected; `vital.uq.lattice`)
- **One lattice, one evaluation per (point, condition).** Integer lattice over the AlphaMax box of the judged shape (nominal +/- 3 k_g sigma), GridPoints 11 per axis (odd: the nominal is a lattice point), K = 10 x 2^MaxLevel. `pointFcn(theta, cond)` returns EVERY group's margin from one call (in the F-16: one `F16Evaluator.pointSummary`), and an evaluation store guarantees no (point, condition) pair is evaluated twice. A point is evaluated at a condition only when a group that has the condition needs it (lazily). Box queries (`res.box`) read the final lattice and never evaluate (tUqLattice#sharedLatticeEvaluatedOnce).
- **Certificate: literal "cell minimum - L h".** bound = min(vertex margins) - sum_i L_i h_i with h_i the full cell edge along axis i, L_i = 2 x the measured local slope. This is twice as conservative as the geometric bound (each point is within h_i/2 of a vertex); I kept the contract text literally. Cost consequence: see uq4-6.
- **"Local slopes".** L_i = 2 x max(the cell's own edge slopes along i, the base-lattice edge slopes along i of the base cells within one base cell of it, i.e. its 3^d base neighbourhood). The own edges alone miss a kink inside a cell whose vertices are equal; the neighbourhood sees it (tUqLattice#kinkedHiddenBand).
- **Refinement set (interpretation).** The contract says "subdivided while its certified lower bound < 0 and its sampled minimum > 0, i.e. only near the zero level set". Taken literally, cells that already straddle the zero level set (some vertex failing) are never subdivided, so alpha* cannot be resolved to +/- 0.01 (a 1-D counterexample: margin 1.5 - s on the base cell [1.2, 1.8] keeps alpha* in [1.2, 1.8]). I therefore also subdivide straddling cells, but only cells that can still move alpha* of some shape: entry alpha (smallest alpha whose R(alpha) meets the cell) below min(alphaHi - 0.01, the first cell with a non-OK vertex); with no failure known, every uncertified cell meeting the cap box; and, for the judged shape, cells meeting R(1) while 1 lies inside the bracket (the DecideAt rule of uq3-1). Cells with a non-OK vertex are never subdivided (they block, honestly).
- **Anisotropic subdivision.** Only the axes whose term L_i h_i is at least half the largest are halved; a cell whose dominant axis is at the finest spacing is exhausted. This keeps face-first touching cheap (one axis matters).
- **Caps (stated).** MaxLevel 10 halvings per axis; MaxPoints per GROUP (the points of the group's own cells, base included): 20000 for the toys (vital.uq.lattice default), 6000 in vital.uq.analyze / run_f16_uq (LatticeMaxPoints). The cap is per group so that sharing never changes an answer (tUqLattice header 9d holds exactly). A capped group reports NOT_ASSESSABLE with a reason starting 'GRID' and the bracket.
- **Box "meets" (clarification).** A cell meets a box when their interiors intersect; a cell that only touches the box boundary does not need a certificate, because every box point on its boundary also lies in a cell whose interior meets the box and the certificate holds on closed cells. Hence R(alphaLo) itself is certified (tUqLattice#boxStatus).
- **alpha* and the CPV.** alphaStar = alphaLo = min(AlphaMax, smallest entry alpha of an uncertified cell); alphaHi = the smallest scaled infinity norm of a failing lattice point within the cap (the CPV; ties: smaller margin). OK when alphaHi - alphaLo <= 0.01 and the CPV confirmation (fresh in-envelope assessment) is OK with margin < 0. "A box search only to confirm the CPV" is read as: no bisection of box searches; the CPV is confirmed by the fresh assessment (R4-1's confirmation). ROBUST_TO_CAP needs every cell meeting R(3) certified and the confirmation at the cap-box arg-min not moving.
- **Moving limit (R3-M4).** Each round: refine, then confirm every CPV, cap-box arg-min and width-box arg-min. A smaller confirmed margin at a non-candidate condition adds it to that group; the lattice is evaluated there once; at most MaxRounds 3.
- **Candidates.** The lattice uses the analysis' NumCandidates per group (2 in stage 1 of the staged run); the union over the longitudinal groups is evaluated. Lattice groups need no stage 2 (R4-8), so stage-1 candidates plus the moving-limit confirmations are final for them.
- **Fallback.** A longitudinal group whose equal-percentage cap box would leave the lattice box (judged half-width below 0.10) or whose cap box has a negative multiplier uses vital.uq.searchMethod instead; its plan says so (never the case for the default spec: half-widths 0.2576 / 0.1517 / 0.1517).

### uq4-2: Breakpoint bracketing (R4-7; `vital.uq.bracket`, `vital.uq.breakpoints`, `F16Evaluator`)
- Breakpoints are parsed from the generated model file (`which('vital.models.f16.aero')`): every `vital.daveml.lookup` line maps its k-th breakpoint vector `K.fN_bpk` to its k-th input; alpha = union over v_alpha inputs (-10:5:45), el = union over v_el inputs (-24:12:24). Never retyped.
- Eligible: status NOT_CONVERGED at stage 'linearize' and trim alpha or elevator within 0.01 deg (inclusive). d = 1e-3, then 2e-3, 5e-3, 1e-2 ("increased up to 1e-2 if needed"), the next d only when the sides are OK but do not straddle or a side's linearization is NOT_CONVERGED. A side that is a physical failure (stage trim, or a status other than OK/NOT_CONVERGED) stops: not bracketed. When both alpha and el are near breakpoints, BOTH must be straddled.
- The F16Evaluator caches raw single-point summaries separately from the final (possibly bracketed) summaries, so a side is never itself bracketed and nPointEvals counts every raw evaluation (3 for the known case). Worse of two sides per group: OK only if both OK (else the non-OK side's entry), Level max, margin min per Level (NaN if either is NaN), record of the worse side; spiral Re max.
- Both side values are reported (E.bracketed -> r.bracketed -> the report table "BRACKETED points").
- **Not bracketed: the fresh assessment (`E.assessAt`, the confirmation).** vital.fq.assess is read-only for M8; a CPV that lands exactly on such a point would give a NOT_OK confirmation (open issue, NOTES.md).

### uq4-3: Staged run (R4-8; `vital.uq.stageBudget`, `vital.uq.stagePlan`, `analyze('Staged', true)`)
- Stage-1 budget: NumCandidates min(full, 2), differential evolution min(full, 8) members x min(full, 4) generations (full: 16 x 8); everything else unchanged, in particular the Monte Carlo N = 200 (the stated N: the R4 verdict needs N >= 59 for a Clopper-Pearson lower bound of 0.95, so a smaller stage-1 N would make every verdict NOT_ROBUST by budget alone). 'Stage1' overrides the three values.
- Stage 2 (full budget) when stagePlan says so: judged CSR bracket [alphaLo, alphaHi] overlaps [0.8, 1.2] (closed intervals; a NOT_ASSESSABLE bracket like [0, 2.76] overlaps), or the judged CSR (no CSR: the x1 bound-worst) is NOT_ASSESSABLE with 'FC-901' or 'budget' in its reason. Lattice groups never. Stage 2 is skipped when its budget equals stage 1's (it could add nothing). Stage-2 groups keep a stage-1 summary in g.stage.stage1. The report column "decided by" gives 'stage 1', 'stage 2' or 'stage 1 (lattice)'.
- `analyze` keeps 'Staged' false by default (direct calls run one stage); `run_f16_uq` defaults to true (the default run).

### uq4-4: Lateral groups without Cm_q (R4-9)
- `searchPlan(..., 'LatDropCmq', true)`: groups named 3.3.x drop Cm_q when the box has it and at least one other parameter (mode 'lateral'; a 'surrogate' group keeps its mode). Default false in searchPlan (R3/R4 plans unchanged), true in analyze and run_f16_uq.
- Class gate: tUqR4bF16#lateralInvarianceCmq, 9 lateral metrics + Re(spiral), 3 conditions x lateral {1, x1 lower corner} x Cm_q at 1 -/+ 3 k1 sigma: largest relative deviation 9.4e-15 (limit 1e-9).
- Runtime gate per group at its critical condition (vital.uq.invarianceCheck, 1e-9 relative; the margin, or the spiral surrogate for a surrogate group) with Cm_q at the extremes of every box searched; fallback vital.uq.gatePlan restores all parameters (plan.latCheck).
- The R3-pinned classes tF16Uq and tUqR3Report now pass 'LatDropCmq' false (their expectations unchanged).

### uq4-5: Defaults switched on
analyze: Lattice true, LatDropCmq true, Bracket true, Staged false. run_f16_uq: all four true. F16Evaluator: Bracket true. Stub-phase defaults were the old behaviour (so the RED baseline was unchanged).

### uq4-6: Cost of the lattice (measured; see CHANGELOG.md and NOTES.md)
Toy, 3-D, corner-first linear: about 19,000 lattice points for both shapes to 0.01 (about 1,000 new points per halving level near the touching corner, because the literal certificate needs margin > 2 sum |dm_i| per cell). The F-16 numbers are in the CHANGELOG.

**Evidence.** tests/M8/tUqLattice.m (11), tUqBracket.m (11), tUqStaged.m (5), tUqR4bF16.m (3).


## ADR-036 (proposed; agent uq5, 2026-10-14/15): M8 amendment R5, implementation decisions

The design is the coordinator's binding amendment (docs/PLAN_M5_M8.md, "Amendment R5": R5-1..R5-6, after review R5, reports/review/R5_REVIEW.md). These are the choices where it left room. No contract decision was changed.

### uq5-1: h/2 certificate (R5-1; `vital.uq.lattice` 'Certificate')
- Default `'half'`: bound = min(vertex margins) - sum_i L_i h_i / 2, L = 2 x the measured local slopes (own edges + 3^d base neighbourhood, as built). `'full'` keeps the R4b form (used only to show the superseded value).
- tUqLattice header 4: 0.08 -> 0.14 (superseded text kept; the full-h 0.08 is still checked with 'full'). tUqR5 header 1.
- Side effect: tUqLattice runs in about 38 s (was 86 s; review R5 m7).

### uq5-2: verdict from R(1) (R5-2; `vital.uq.lowerEnd`, `verdict`, lattice refinement order)
- Every CSR result (lattice and `vital.uq.csr`) carries `lowerCertified` and `lowerReason`: R(alphaLo) is certified clean over the FINAL candidate conditions.
  - Lattice: the cells meeting R(alphaLo) are certified by construction of alphaLo; in addition no confirmation item of the final round moved, and no check inside R(alphaLo) (corners, box arg-mins with alpha <= alphaLo, the cap arg-min when alphaLo is the cap) has a failing or non-OK point evaluation or fresh confirmation. A status OK / ROBUST_TO_CAP whose lower end is not certified becomes NOT_ASSESSABLE.
  - csr.m: R(lo) was searched clean; a moving limit invalidates it until a box >= lo is searched clean again with the new candidate; the nominal must be OK and pass.
- `vital.uq.verdict(csr, mc)`: ROBUST = lowerCertified and alphaLo >= 1 (and CP >= 0.95); NOT_ROBUST unchanged (confirmed CPV with norm <= 1, or CP < 0.95, NaN counts as low); else NOT_ASSESSABLE. `vital.uq.lowerEnd` reads a legacy R4 struct (no lowerCertified) as before (certified = status OK / ROBUST_TO_CAP, lo = alphaStar), so the R4 truth table is unchanged.
- Superseded: tUqCsr header 9 (K9, R(1) searched clean): verdict NOT_ASSESSABLE -> ROBUST.
- Lattice refinement priority per group: (1) the cells deciding R(DecideAt = 1) of the judged shape, (2) the judged shape to 0.01, (3) the other shapes at what the per-group / global caps leave. The equal shape is reported as a bracket; its status is OK only if it was resolved.

### uq5-3: piecewise certificate (R5-3; `problem.switches`, `q.switchVals`)
- Generic interface: `problem.switches` (name, breakpoints), `q.switchVals` per (point, condition). The side of a point = number of breakpoints strictly below its value (a value exactly on a breakpoint counts on the lower side).
- analyze ('Piecewise' true) passes the trim [alpha_deg de_deg] of every lattice point (F16Evaluator point summary, so a BRACKETED point carries its raw trim) against the alpha and el lists of `vital.uq.breakpoints` (R4-7's lists).
- Slopes are never measured over an edge whose ends lie on different sides (own edges and the 3^d base neighbourhood; this also applies to non-straddling cells next to a jump).
- A straddling cell: per condition and per side, min(margins of that side's vertices) - sum L_i h_i with the FULL edge (a planar cut leaves each side a vertex within one edge), L = 2 x the slopes at that condition from the non-crossing edges; the cell bound is the minimum over conditions and sides. A vertex whose side is unknown (NaN) is counted on every side (conservative).
- Report: `res.groups(g).discontinuity` (present, nCells, nCertified, variables, breakpoints, maxJump, crossings, text); analyze `plan.lattice.discontinuity`; the report states the discontinuity.
- Limit (stated in the report): a breakpoint surface that enters and leaves a cell through the same side of the vertices is invisible (the narrow-feature limit).

### uq5-4: stage-1 band (R5-4; `vital.uq.stageBand`)
- Rule: e = max measured |stage-1 - stage-2| of the judged CSR bracket ends (alpha units); band = [min(0.8, 1 - 2e), max(1.2, 1 + 2e)].
- Measurement (reports/work/uq5/r5band_toys.txt, r5band_f16.txt, r5band_f16_spiral.txt): 
  - F-16 (the smoke groups that have a stage 2; budgets of the R4b smoke: NumLHS 8, NumStarts 1, MaxEvals 120; stage 1 NumCandidates 2, DE 8 x 4; stage 2 NumCandidates 4, DE 16 x 8): 3.3.1.1-CatA-other judged alpha* 2.75 in both stages (bracket identical, |d| = 0); 3.3.1.3-CatA judged 1.7976 [1.7976, 1.8076] in both stages (|d| = 0); equal ROBUST_TO_CAP in both. The lattice groups have no stage 2. Runtimes: 3.3.1.1 + 3.3.1.3 both stages about 2 h; 3.3.1.3 alone 3,573 s (5,296 evaluations).
  - Toys (6 parameters, hybrid search, 4 conditions, defaults otherwise): LIN 0 / 0 (both NOT_ASSESSABLE [0, 1.002]), QUAD 0 (both OK 1.2175), COND3 0 (both OK 0.3914; the critical condition is the 3rd by nominal margin, found by the moving limit in stage 1), KINK |d alphaHi| = 0.07505 (both NOT_ASSESSABLE; [0, 1.5033] vs [0, 1.4283]), MIXED 0.
  - Largest measured error e = 0.075 (a bracket end of an undecided toy); every decided judged alpha* agreed exactly.
- Result: 2e = 0.15 < 0.2, so the band stays the floor [0.8, 1.2] (vital.uq.stageBand([0 0 0 0 0 0.07505 0])). analyze / run_f16_uq default Stage2Band [0.8 1.2]; tests/M8/tUqR5F16.m#endToEndR5 pins r.stages.band = stageBand(the measured errors). Caveat: two F-16 groups and five toys at reduced LHS/NM budgets; the measurement does not show the stage-1 error is small for every lateral group, only that none was seen.

### uq5-5: corner assessments, scope, minors (R5-5)
- M2: every round confirms each lattice group at the 2^d corners of R(1) and R(alphaLo) of the judged shape (option 'CornerChecks' / analyze 'LatticeCorners', default true). Corners are lattice points when they lie on the lattice, else EXTRA check points (evaluated by pointFcn at the group's conditions, never cell vertices, not counted in nPoints). They go through the same moving-limit line as the CPV and arg-min items (so S8Q-9's defect affects them too). Fresh assessments are shared between groups at the same theta (`F16Evaluator.assessShared`).
- Scope statement: `res.groups(g).scope`, `plan.lattice.scope` and `vital.uq.statements('limits')`.
- M4: tests for S8Q-1,2,3,5,6,7,8,9 (tUqR5, tUqR5F16); sabotages_R5.json with the R5 ids. S8Q-7's pattern was adapted (the robustCsr line was rewritten by R5-2; same defect at the same place). N-R5 is kept as a documented null control in tests/M8/nullcontrol_R5.json (NOT in a sabotages*.json, because run_sabotage requires every registered entry to be detected); it stays NOT DETECTED (reports/work/uq5/nullcontrol_R5.txt).
- S8Q-8 test: a controller with a small two-way crossfeed (dr += 1e-3 q, de += 1e-3 r) couples the axes so the lateral margin moves by 1.6e-5 relative with Cm_q: the 1e-9 gate fails (correct), a 1e-2 gate would pass.
- m1/m4/m6/m10: `vital.uq.statements('judgments'|'limits')` printed verbatim by headline/writeReport; `loadSpec` carries spec.judgments (the spec file uq/f16_uncertainty.json is outside uq5's write access; the coordinator may add the text there too). Stale report texts replaced.
- m2: any exception inside a lattice point is an ERROR point; a malformed result raises vital:uq:badPointResult.
- m3: an all-+Inf cell is not certified and not refined.
- m5: global lattice budget 'MaxTotalPoints' (analyze 'LatticeTotalPoints' 12000; the per-group cap 6000 stays). With the global cap binding, sharing CAN change an answer (unlike the per-group cap, ADR-035 uq4-1); the reason says 'global'.
- m7: tUqLattice 86 -> 38 s; tF16Uq (452 s) unchanged (its budgets pin R3 values).
- m8: tF16Uq pins the M7 confirmation values (tF16Uq.pinnedSas) instead of reading reports/.
- m9: `vital.version` = '0.8.0-M8rc' (no test pins the old string).

### uq5-6: R5-6
- reports/uq/f16_uq_default.json/.md renamed to f16_uq_default_superseded_2026-10-09.json/.md, with a SUPERSEDED banner at the top of the .md. No code or test referenced the old name (run_f16_uq's default label writes a fresh f16_uq_default.*).

**Evidence.** tests/M8/tUqR5.m (20), tUqR5F16.m (4); superseded items in tUqLattice header 4 and tUqCsr header 9.


## ADR-037 (proposed; agent oop, 2026-10-19): object layer outside, functional core inside; Aerospace Toolbox use; atmosisa as the core atmosphere

**Status:** proposed (user decisions of 2026-10-19 in docs/PLAN_OOP_TOOLBOX.md). **Supersedes part of ADR-005:** ADR-005 (pure functions on flat structs everywhere) still holds for the numeric core; it no longer forbids classes in the user-facing layer.

**Context.** VITAL was all functions on flat numeric structs (ADR-005), for speed and code generation. The user asked for a MATLAB object model on the outside, for MATLAB built-ins in the core where the conventions match, and for atmosisa in place of VITAL's own US 1976.

**Decision 1: object layer (value classes) that delegates to the existing functions.**

| Class | Wraps | Notes |
|---|---|---|
| `vital.Aircraft` | `vital.aircraft.f16.config` | `toRuntime()` returns the exact config struct (isequal). `trim`, `linearize`, `modes` and `assess` call `vital.trim.solve`, `vital.linear.linearize`, `vital.linear.modes` and `vital.fq.assess`. `toFixedWing()` returns an `Aero.FixedWing` (S, b, cbar) and an `Aero.FixedWing.State` (mass, inertia J, CG r_cg) |
| `vital.FlightCondition` | env + trim condition | `toEnv`/`toTrimCond` build exactly the structs of `vital.fq.f16Factory`. `fromFeet` takes NESC README units. `toFixedWingState(ac[, tr])` uses `fixedWingState` with `aircraftEnvironment(fw,'ISA',H)`, where H is the **geopotential** height |
| `vital.TrimResult`, `vital.LinearModel` | trim / linearize structs | `toStruct()` returns the struct unchanged |
| `vital.modes.Mode` and subclasses `ShortPeriod`, `Phugoid`, `DutchRoll`, `Roll`, `Spiral` | `vital.linear.modes` entries | `LinearModel.modes` returns a **cell** array (the subclasses are heterogeneous). Names outside the five, such as `height` or `other`, give the base `Mode` |
| `vital.rules.Rule`, `vital.rules.RuleSet` | `vital.fq.loadRules` records | `Rule.evaluate(metrics, policy)` restates the engine's per-record rule; it is proven equal to `vital.fq.assess` on all 118 records at the README point. `RuleSet.levels` gives the group Levels |
| `vital.fq.Assessment` | `vital.fq.assess` result | |
| `vital.atmos.Atmosphere` (abstract), `vital.atmos.IsaAtmosphere` | `vital.env.atmosphere` | |
| `vital.ctrl.ControlLaw` (abstract), `PitchSasLaw`, `YawDamperLaw`, `NescLqrLaw`, `CombinedLaw` | the M7 laws | `build` makes the existing controller struct; `builder()` gives the handle that `f16Factory('Controller', ...)` takes. The class names end in "Law" because `PitchSas.m` and `pitchSas.m` would be the same file on Windows |
| `vital.uq.Study` | `run_f16_uq` | Forwards the options unchanged. `EntryPoint` can be replaced for dry runs |

- The hot loop (`plant.derivatives`, loads, eom, lookups) is unchanged and stays on structs.
- **Not used:** `linearize`, `analyzeFlyingQualities` and `Aero.FixedWing.Specification` all need `ss` (Control System Toolbox, not installed).
- `Aero.FixedWing`'s linear coefficient model cannot reproduce the NASA F-16 tables, so it does **not** replace VITAL's aero. `toFixedWing` leaves the coefficients empty, so `staticStability` would be meaningless and is not offered.

**Decision 2: built-in frame and geodesy functions are NOT switched into the core (measured).** User decision 2 allowed a switch only if per-call speed is not materially worse (and codegen-compatible). Measured per call in R2025b on the development machine (`matlab -batch`, 20,000 calls each):

| VITAL | µs | Toolbox | µs | ratio |
|---|---|---|---|---|
| `vital.frames.quat2dcm` | 2.3 | `quat2dcm` | 44 | 19x |
| `vital.frames.dcm2quat` | 3.7 | `dcm2quat` | 235 | 64x |
| `vital.frames.dcm321` | 4.0 | `angle2dcm` | 29 | 7x |
| `vital.geo.lla2ecef` | 3.4 | `lla2ecef` | 24 | 7x |
| `vital.geo.ecef2lla` | 5.7 | `ecef2lla` | 32 | 6x |
| `vital.geo.dcmEcefToNed` | 1.8 | `dcmecef2ned` | 71 | 39x |

- Every toolbox function is 6 to 64 times slower per call, so none qualifies, and the VITAL functions stay. Their conventions were already proven identical to the toolbox (`tests/M1/tFrames`, `tGeo`; INDEP), so those tests remain genuinely independent.
- The toolbox frames are used at the OOP boundary only. `FlightCondition.toFixedWingState` is checked against VITAL's C_bn in `tOopAircraft#fixedWingStateConsistent` (INDEP).
- No `codegen` test of the plant exists in this tree; a search of `tests/` and `+vital` found none. Nothing in this change was made codegen-incompatible in the plant beyond atmosisa itself (see Decision 3, Consequences).

**Decision 3: atmosisa is the core atmosphere.**
- New function `vital.env.atmosphere(h, 'DeltaT', dT)`:
  - converts geometric height to geopotential first (`vital.env.geometricToGeopotential`);
  - pre-checks the range, so H outside [-5000, 84852] m raises `vital:env:altitudeOutOfRange`;
  - then calls `atmosisa(H, 'action', 'None')`, which never warns and never holds a value;
  - applies ISA + dT with atmosisa's own R.
- All six core callers were migrated: `plant.derivatives`, `plant.derivativesRotating`, `fq.f16Factory`, `viz.axisChecks`, plus `run_f16_models.m` and `SciComp/fit_f16_coefficients.m`.
- `vital.env.atmosphereUS76` is kept as a **thin alias** returning `vital.env.atmosphere`. Nine existing test files call it, and keeping the name avoids editing tests that do not assess the atmosphere. A test proves that no `+vital` file calls the alias.
- VITAL's former US 1976 implementation is frozen test-side as `tests/reference/us76Reference.m`. It is the INDEP oracle of the new atmosphere and is never called from `+vital`.
- **Speed.** atmosisa's `arguments` block (enumeration types) costs about 0.3 ms per call, roughly 10 times VITAL's former function and about 40 % of a plant call. A one-entry cache on the exact scalar geopotential height makes repeated-altitude calls cheap. This is exact, because atmosisa is a pure function of H. Repeated altitudes are the pattern of trim, linearization, flying qualities and the M8 uncertainty run.
- **Agreement with US 1976:**
  - T and a agree within 1e-6 relative over 0 to 32 km.
  - p and rho agree within 1e-6 only below about 10 km. At 32 km the difference is 3.3e-6 in p and 2.6e-6 in rho.
  - Cause: atmosisa's R = p0/(rho0 T0) = 287.0529 differs from US 1976's R*/M0 = 287.0531 by 7e-7, and that enters the barometric exponent.
  - The pre-registered 1e-6 below 32 km was therefore a FAILED HYPOTHESIS for p and rho above 10 km. The test now asserts 1e-6 below 10 km and 5e-6 over 0 to 32 km, with the failed hypothesis recorded in the test.
  - The NESC Atmos_01 bands still hold.

**Consequences.**
- Plant speed against the 0.8.0 plant in the same run: fixed altitude ratio about 1.0 (gated at 1.10). Every call at a new altitude (time simulation) is about 1.45 times slower; this is reported, not gated.
- atmosisa is code-generation capable according to MathWorks, but the persistent cache and the `arguments` block were not tried with `codegen`.
- Tests that asserted US 1976-specific constants of the old implementation were edited (see the CHANGELOG fragment for each edit and its justification).
