# CORE_AUDIT: independent read-only audit of VITAL 0.9.1-CORE and its consumers

Date: 2026-10-27. Auditor: independent agent (read-only on `C:\VITAL`; this file is the only file written in the repo).
MATLAB R2025b, `matlab -batch` only; no full suite run. The coordinator's measurements (747/747 GREEN, all sabotages detected, compiled model = `vital.plant.derivatives` exactly over 1,100 states, 1.17x) were not repeated.

Probe scripts and their outputs are in
`C:\Users\krish\AppData\Local\Temp\claude\C--AIRCRAFT-FlightSIm-aircraft-flight-simulator--claude-worktrees-silver-scythe-simulator-b01f5a\20f339ab-72b1-407b-8bbd-70f553903c44\scratchpad\audit\`:
`probe_physics.m` (hand known answers), `probe_consumers.m` (the twin through every consumer, the toRuntime bridge, timing), `probe_brick.m` (a non-F-16 PUB vehicle as an AircraftModel), `probe_slx.m` (Simulink timing), `probe_scale.m` (cost per propulsor), `run_shadow.m` with `shadowA/B/C` (three sabotages run against the current core tests by path shadowing; nothing under `C:\VITAL` was changed).

## 1. Answer to the user's question, in short

- **Would it work?** The core physics is correct. Every hand-computed check agreed to 1e-12 or better. That covers tilted, toed-in and offset engines with torque on a chained wing axis; combine() with rotated self-inertia; about() a rotated, offset axis; the wind, stability, station and bodyInNed axes; and weight with a rotated CG axis.
- **Does following this approach meet the framework goals?** Not yet. The objects are aircraft-agnostic, but every consumer from M4 to M9 still hard-codes the F-16's four controls [de da dr throttle].
  - In the probe, the hypothetical twin failed at every consumer: plant, trim, linearize, sim.run with the default plant, Simulink, and the fq factory. The one exception was `vital.sim.run` with the `'Plant'` option.
  - The certification layer silently applies Class IV numbers to any aircraft.
  - The M8 uncertainty is defined by F-16 table-term names inside `vital.aircraft.f16.loads`.
  - `toRuntime()` is not a safe bridge. It ignores edits to some AC fields and honours others.
- **Can it better ensure Simulink and visualisation work for any aircraft?** Yes, but only after the per-model widths and a pose/scene API exist (Section 5). The core tests also have blind spots: three real sabotages in the core pass the current tests (Finding M2).

## 2. Verdict table

Rating: OK / CONCERN / BLOCKER. "Agnostic" is judged against (i) the twin (`tests/reference/coreTwinFixture.m`) and (ii) an X-57-like aircraft: about 14 propulsors, flaps, a non-DAVE-ML aero model in stability axes, Class I.

| Section | Works (F-16) | Aircraft-agnostic | Performance | Evidence quality |
|---|---|---|---|---|
| M1 frames, geo, mass, atmosphere, air data | OK | OK | OK | OK (PUB/INDEP/ANALYTIC) |
| M2 DAVE-ML import | OK | CONCERN (DAVE-ML only; a non-DAVE-ML model needs a hand adapter; F-16 AeroScale is wired into `f16/loads.m`) | CONCERN (the generated F-16 aero is 477 of 810 us per plant call) | OK |
| M3 EOM | OK | CONCERN (`rigidBodyDerivs` supports h_rot but no component provides it) | OK | OK |
| M4 plant | OK | **BLOCKER** (`derivatives.m:33` requires 4 controls; toRuntime split-brain; bridge context drops X) | OK | OK |
| M5 trim / linearize / modes | OK | **BLOCKER** (trim unknowns fixed to alpha, de, throttle with u = [de 0 0 thr]; linearize has 4 inputs and 16 columns; n/alpha uses column 1 / column 13) | OK (trim 0.06–0.11 s, linearize 0.12–0.19 s) | OK |
| M6 sim and NESC | OK | CONCERN (`sim.run` is nu-generic but its default plant is 4-control; NESC is F-16/sphere/brick by design; `derivativesRotating` is nu-agnostic) | OK | OK (PUB NESC) |
| M7 FQ, rules, control laws | OK (6 spot checks against the extract are correct) | **BLOCKER** (Class IV thresholds applied to any aircraft; `applicability` is never read; laws and metrics index u(1), u(3), u(4)) | OK | CONCERN (all 118 records `"verified": false`) |
| M8 uncertainty | CONCERN (6 lateral groups NOT_ASSESSABLE, FC-901) | **BLOCKER** (parameters are F-16 term multipliers inside `f16/loads.m`; `F16Evaluator`, `f16Factory`) | CONCERN (62,580 s = 17.4 h per default run) | CONCERN (sigmas are JUDGMENT, labelled honestly) |
| M9-A Simulink | OK (E = 0) | **BLOCKER** (u width 4 in `build.m:84` and `simulate.m:38-41,162`; flat 13-state only; one global context) | CONCERN (1.13x real time at 100 Hz for the F-16, normal mode, extrinsic) | OK |
| 0.9.1-CORE objects | OK (all probes ≤ 1e-12) | CONCERN (no local inflow, no stability/wind-axis data, no h_rot, component mass unused, one Ref, no inter-component coupling) | OK (direct 1.02x; through toRuntime 1.21x; FlightContext 106 us) | **CONCERN** (rotation path and rotated-CG weight untested: 3 sabotages undetected; equivalence gate is plumbing-only) |

## 3. Core physics, re-derived independently (Section 1 of the brief)

All checks are in `probe_physics.m`. The hand answers are written out in the probe.

| Check | Hand answer | Result |
|---|---|---|
| Axis chain: `toRoot` gives `o ← p.Origin + p.Cᵀ o`, `C ← C·p.C`; `dcmTo = C_b,root C_a,rootᵀ`; `originIn = C_b(o_a − o_b)` | passive DCM algebra (CONVENTIONS 3) | correct by inspection (Axis.m:106-115, 81-95) |
| Point vs Vector: Point.expressIn = o + C r; Vector.expressIn = C v | — | correct (Point.m:37-40, Vector.m:46) |
| Loads.transform: `[C,r] = b.poseIn(a)`; M_b = C_baᵀ... = C_ba (M − r_b×F), r in **a** components | M_B = M_A + (r_A − r_B)×F, here r_A − r_B = −r | correct (Loads.m:66-73) |
| Twin engines: y = ±3 m, toe-in ±5°, tilt 3°, torque ±500 N·m, left engine chained on a 5° dihedral wing axis | ΣF, M_cg = Σ(r×F + Q d) − r_cg×ΣF; Euler-equation xdot | F error 7e-12 N (of 4.96e4); M_cg error 3e-12 N·m; xdot(1:6) object and compiled paths both 1.8e-15 |
| combine(): m1 = 100 kg at [1 0 0], J = diag(10,20,30) on an axis yawed 90°; m2 = 300 kg at [−1 2 0], J = 5·I | m 400, CG [−0.5 1.5 0], J = [325 300 0; 300 315 0; 0 0 635] (J12 = −Ixy, Ixy = −300) | exact (0) |
| about(b), b rotated [0.2 −0.1 0.4] rad and offset [2 0 1] | C (J_cg + m(dᵀd I − d dᵀ)) Cᵀ with d in ref components | 4.6e-13 |
| Parallel-axis direction | about() shifts **from** the CG (d = CG in b); combine shifts each part **to** the composite CG with its own self-inertia rotated in first | correct (MassProperties.m:242-246, 300-311) |
| Wind axis, α = 12°, β = −7° | v_w = [V 0 0] | [100 1e-15 0]; C_sw = R3(−β) as expected |
| Stability axis | v_s = [V 0 0] at β = 0 | exact. The doc string "C_sb = R2(alpha)" (Axis.m:36) is R2(−α) in VITAL's passive R2. The matrix itself is right (Stevens & Lewis C_sb) |
| bodyInNed | body x in NED = [cθcψ, cθsψ, −sθ] | exact |
| Station frame (180° about y) | point (15, 0.5, 3) with datum (5, 0, 2) maps to (−10, 0.5, −1); Ixy and Iyz flip, Ixz keeps its sign | exact |
| weightLoads with a CG axis pitched 0.3 rad | F = m C_bn g in body axes; M about the BFRP = r_cg × W | exact |
| AircraftModel.compile/derivatives | M_R = C M + r × (C F); then `sumLoadsAtCG` gives M_cg = ΣM_R − r_cg × ΣF; J about the CG in body axes | correct; matches the hand result above |
| Stale cache | `Compiled` is private and is invalidated by `withComponentEnabled`; value class | no stale path found. ADR-040 and the guide say "rebuilt on every call", which is inaccurate: it is built once in `compile()`, and that is safe only because the object is immutable |

## 4. Findings (ranked by severity)

### BLOCKERS

**B1. The plant contract is fixed at 4 controls, so `toRuntime()` cannot carry any non-F-16 control set.**
- Where:
  - `+vital/+plant/derivatives.m:33-35` (`numel(u) ~= 4` gives an error);
  - `+vital/FlightContext.m:98` (the bridge's `cell2struct` with the model's 5 names against the plant's 4 values);
  - `+vital/AircraftModel.m:36-38`, which documents the limit.
- Evidence (`probe_consumers.m`, twin with 5 controls):

| Call | Result |
|---|---|
| `plant.derivatives`, 5 u | `vital:badInput: controls must be [de da dr throttle], got 5` |
| `plant.derivatives`, 4 u | `MATLAB:Cell2Struct:NumberOfNamesMismatch`, a raw MATLAB identifier (breaks CONVENTIONS 11) |
| `trim.solve` | `status ERROR` (same Cell2Struct) |
| `linearize` | `vital:badInput: ... 4 controls u` |
| `sim.run` (default plant) | `vital:badInput` |
| `sim.run` with `'Plant', @(x,u,A,e) twin.derivatives(x,u,e)` | **OK** |
| `slx.simulate` | `vital:badInput: u0 must be 4 ...` |

- Fix:
  - The plant checks `numel(u) == numel(AC.controlNames)`, defaulting to 4 when the field is absent.
  - Better: give `vital.plant.derivatives` a dispatch on `isa(AC, 'vital.AircraftModel')` that calls `model.derivatives`.
  - The bridge raises `vital:model:controlCount`.

**B2. Trim supports only the F-16's symmetric, single-throttle problem.**
- Where: `+vital/+trim/solve.m`:
  - `:44` — `UNKNOWNS = {'alpha','de','throttle'}`;
  - `:59` — the unknowns are required;
  - `:67-69` — bounds from `AC.limits.de_deg` and `.throttle`;
  - `:158` — `uu = [zz(2); 0; 0; zz(3)]`.
- Effects:
  - A twin cannot be trimmed with two throttles.
  - No aircraft can be trimmed engine-out, because lateral unknowns (da, dr, φ or β) are not supported even though CONVENTIONS 9 describes them.
  - Engine-out trim and V_MC are central to the twin and to the later FAA rule sets.
  - An X-57 with 14 throttles and a flap setting cannot be expressed at all.
- Fix:
  - Name the unknowns from `model.Controls`, plus attitude unknowns.
  - Add a declared control allocation, e.g. a `thrust` role mapping one unknown to several channels with weights, and a `pitch`/`roll`/`yaw` role per channel.
  - Fix the scheduled (non-trimmed) controls such as flaps per condition.
  - Keep the squareness check (FC-504).

**B3. Linearization and the FQ metrics assume 4 inputs and that column 13 is the elevator.**
- Where:
  - `+vital/+linear/linearize.m`:
    - `:129` (`numel(tr.u) ~= 4`);
    - `:141` (`inputNames = {'de','da','dr','throttle'}`);
    - `:148` (`h0` with 16 entries);
    - `:210-211` (`Ju(:,13:16)`);
    - `:269` (`inputRange` from `de_deg/da_deg/dr_deg/throttle`);
    - `:317-319` (`zeros(4)`);
    - `:343` (the controller must return 4).
  - `+vital/+linear/nAlphaSteady.m:37,47` (`Bair(:,1)` is the pitch control).
  - `+vital/+fq/metrics.m:87,135` (`used = [1:8 13]`, `lin.lon.air.B(2:3,1)`).
  - `+vital/+fq/evaluatePoint.m:53-54,71` (`tr.u(1)`, `tr.u(4)`, `need = [1:8 13]`).
  - `+vital/+ctrl/closedLoop.m:46`, `pitchSas.m:68`, `yawDamper.m:38,52`, `nescLqr.m:61,94` (u indices).
- Effects:
  - For the twin, every one of these lines rejects or misreads the input.
  - For an X-57 whose first control is a flap, n/α would silently be computed per **flap** deflection.
- Fix:
  - Input names come from the model.
  - Each control declares a role (pitch / roll / yaw / thrust / config).
  - Metrics and laws look up columns by role and fail with `vital:model:noRole` when one is missing.

**B4. The Simulink plant is fixed at 4 controls, flat-Earth 13 states, and one global context.**
- Where:
  - `+vital/+slx/build.m:76,84` (`zeros(13,1)`, `zeros(4,1)` in the generated chart code);
  - `+vital/+slx/simulate.m:38-41` (`nu = 4`), `:152,162` (log widths);
  - `+vital/+slx/context.m:11` (a single `persistent` store, so two models cannot run in one session).
- Effects: the twin is rejected (B1 table), and the X-57 cannot be expressed.
- Fix: see Section 5.

**B5. Certification: Class IV thresholds are applied to any aircraft, silently.**
- Where:
  - `+vital/+fq/loadRules.m:38-77` never reads `applicability.aircraft_class` (it is checked for presence only, in `vital.io.validateRule`).
  - Every record's `ruleset.basis` is "Class IV", and the curated rows are the Class IV rows (e.g. `MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatA-other.json`, `aircraft_class: ["IV"]`).
- Effects:
  - An X-57 (Class I) or a transport twin (Class II/III) would get Class IV numbers with no warning.
  - For Class II/III, Table VII Cat A, Fig. 3 (Class II-L/III boxes about 0.7 / 2.0), and the Table VI CO/GA rows differ.
- Fix:
  - The aircraft declares `Class` (and its phase categories).
  - The loader filters records by applicability and refuses a mismatch with `vital:fq:classNotCovered`.
  - Add the Class I/II/III rows from the extract.
  - Tests: one record per Class with a known Level.

### MAJOR

**M1. `toRuntime()` is a split-brain bridge.**
- Where: `+vital/AircraftModel.m:264-279`. The closure captures the compiled struct `c` and ignores its `AC_` argument (`%#ok<INUSD>`), but `vital.plant.derivatives` reads `AC.mass`, `AC.J` and `AC.r_cg` from the struct.
- Evidence (`probe_consumers.m`), edits made on the toRuntime struct:

| Edit | Effect |
|---|---|
| `AC.aeroScale.Cm_q = 0.3` | **ignored**: q̇ −0.282674, the nominal value; `config(Cm_q 0.3)` gives −0.157137 |
| `AC.S × 2` | **ignored** |
| `AC.r_mrc` | **ignored** |
| `AC.mass`, `AC.r_cg` | honoured |

- Effect: every M6/M8 perturbation that edits AC after construction would give a silent wrong answer once consumers move to toRuntime. Today M8 rebuilds through `config('AeroScale', s)`, so no current result is affected.
- Fix:
  - Remove the bridge by migrating the consumers (Section 6).
  - Until then, make toRuntime's AC carry a hash of the plant-relevant fields and check it in the closure (`vital:model:staleRuntime`).
  - Perturbations go only through `model.withParameters(...)`.

**M2. The core tests are blind to the rotation path of the compiled model and to a rotated CG axis.**
- Every component axis in `tCoreModel` and `coreTwinFixture` is `eye(3)`, and the default F-16 has r_mrc = r_engine = 0, so `c.identity` is always true.
- Sabotages run with the real tests (tCoreModel without the example, tCoreMass, tCoreLoads; `run_shadow.m`):

| Sabotage | Current tests | `probe_physics.m` |
|---|---|---|
| A: compiled path uses Cᵀ instead of C (`AircraftModel.m:336`) | 21/21 PASS (undetected) | xdot error 0.293 |
| B: `weightLoads` uses `CgAxis.dcmTo(root)` instead of `root.dcmTo(CgAxis)` (`MassProperties.m:258`) | 21/21 PASS (undetected) | weight error about 2.8e4 N |
| C: compiled path drops the component rotation entirely (`if false`) | 21/21 PASS (undetected) | xdot error 0.147 |

- The guide's "a test proves the two equal" (12c) and "eight sabotages ... each caught" are true but overstated: the proof does not cover rotated components.
- Fix:
  - Add `probe_physics` P1/P2/P4 as ANALYTIC tests (a hand twin with tilt, toe-in and a chained wing; a rotated CG; combine with rotated self-inertia).
  - Register these as SC-9, SC-10 and SC-11.

**M3. M8 uncertainty is defined by F-16 table-term names.**
- Where:
  - `+vital/+aircraft/+f16/config.m:251-264` and `loads.m:97-131` (the AeroScale build-up);
  - `+vital/+uq/F16Evaluator.m` and `+vital/+fq/f16Factory.m:65`;
  - `uq/f16_uncertainty.json` (`"aeroScale": "Cm_q"`, `"term": "cmq"`).
- The model only reaches the F-16 aero component through the opaque `CoeffArgs {AC}`.
- Fix:
  - Give `Component` a `parameters()` interface returning `{name, nominal, sigma, source, meaning}`, and give the model `m.withParameters(struct)` returning a new compiled model.
  - Make the F-16's eight multipliers the parameters of its aero component, with the same names, so M8 is bit-identical.
  - Add a generic `DerivativeIncrementComponent` at the MRC (ΔC_mq·q̂, ΔC_lp·p̂, ΔC_nr·r̂, ΔC_mα·α, ...) that gives any aircraft, DAVE-ML or not, a standard derivative-level uncertainty set.

**M4. The two FlightContext constructors give different contexts.**
- Where: `+vital/FlightContext.m:98` (`setBridge`). Under toRuntime (trim, linearize) `X`, `C_bn` and `Env` are empty; under `model.derivatives` they are set.
- Effect: a component that reads `fl.X`, `fl.C_bn` or `fl.Env` (landing gear, a propeller's local inflow, ground effect) works in `model.derivatives` and fails or misbehaves under trim and linearize.
- Fix: one constructor. The plant passes x and C, and the rotating plant passes its own state layout explicitly (its X is ECEF, so the meaning must be declared).

**M5. The component interface is not yet sufficient for an X-57.**
- Where: `+vital/Component.m`, `AeroTableComponent.m:129-135`, `PropulsorComponent.m:174-180`.
  - No component receives its own pose. Local inflow `v_air + ω × r_k`, which a propeller in rotation or a blown wing needs, is not available.
  - AeroTableComponent takes **body-axis** coefficients only. CONVENTIONS 8 requires declared data axes (stability/wind via C_bs(α), C_bw(α, β)), and X-57-style data is usually CL/CD in stability axes.
  - PropulsorComponent has no rotor angular momentum, although `vital.eom.rigidBodyDerivs` accepts h_rot. With 14 counter-rotating props this matters for asymmetric failures.
  - There is no coupling between components (prop wash on the wing), except by a component reading another's control channel.
  - `Component.MassProps` is ignored, so there is no fuel, battery or CG build-up.
  - One model `Ref` sets p̂, q̂ and r̂ for all components.
- Fix:
  - Pass `(fl, pose)` with `pose.C`, `pose.r` (compiled) and helpers `fl.localVelocity(r)` / `fl.localRate()`.
  - Add `DataAxes = 'body'|'stability'|'wind'` to AeroTableComponent.
  - Add `angularMomentum(fl)` to propulsors, summed into h_rot.
  - Add an explicit ordered evaluation with a shared "induced" field for coupling.
  - Make the model mass the `combine()` of the component masses when they are given.

**M6. Simulink and real-time performance.**
- `probe_slx.m`, F-16, 2 s at 100 Hz, open loop:

| Run | Wall time |
|---|---|
| `vital.sim.run` | 0.78 s (2.6x real time) |
| `slx.simulate`, first run | 24.25 s |
| `slx.simulate`, second run | 2.54 s, simulation part 1.78 s (**1.13x real time**); x identical (0 difference) |

- Per derivative call (`probe_scale.m`):
  - a trivial-physics model costs about 300 us of framework overhead plus about 25 us per component;
  - 14 propulsors take 620 us, 28 take 929 us;
  - `FlightContext` alone costs 106 us of the F-16's 810 us (`probe_consumers.m`).
- Effect: joystick plus Cesium in normal-mode extrinsic Simulink has no real-time margin for the F-16, and less for the X-57.
- Fix: Section 5 (a compiled, code-generable tier), and make `FlightContext` cheap (no `cell2struct`; a compiled channel-index map).

**M7. M8 run cost and the lateral NOT_ASSESSABLE groups.**
- The open issue (FC-901): Nelder-Mead hits its 150-evaluation cap on the 6-D lateral box.
- The default run takes 62,580 s for 80,241 single-point assessments (about 0.78 s each, dominated by trim + linearize plant calls).
- Other observations:
  - (a) The 6 groups have nominal margins of 0.54–4.27 and 200/200 Monte Carlo passes. The undecided part is the CSR bracket, not a hidden failure (consistent with R3).
  - (b) The hybrid stage gets no benefit from the lateral metrics' smoothness. A gradient method (sqp from the DE best, with central differences) or a 2-D active subspace (screening showed the lon multipliers act only through the trim α) would likely certify these groups at a lower cost than raising the cap.
  - (c) Through `toRuntime` the inner loop would cost +21%, about 3.6 h. Directly through `model.derivatives` it would cost +2%.
  - (d) All 118 rule records carry `"verified": false`. The 6 spot checks below agree with the extract, but nobody has signed off the transcription.

### MINOR

- **m1.** The Axis root is identified by value (`Axis.m:41`, `checkRoots`). Two aircraft whose roots are both named 'bfrp' count as one tree, so loads from different aircraft can be aggregated without an error. Fix: give the root a unique `TreeId`.
- **m2.** `withComponentEnabled` returns an **uncompiled** model (`AircraftModel.m:190-198`). Until `compile()` is called, `derivatives` silently uses the object path, which is 3.8x slower (3,099 us vs 823 us). Fix: recompile automatically, or warn.
- **m3.** `weightLoads` assumes the tree root is body-parallel (`MassProperties.m:252-259`, CONVENTIONS 2), but nothing enforces it. `AircraftModel.validate` should assert that the root has no parent and that `C = I`, which it does by construction, and should document that a station root is not allowed.
- **m4.** Documentation:
  - ADR-040 Decision 4 and guide 12c say "rebuilt on every call". It is built once in `compile()`.
  - Axis.m:36 says "C_sb = R2(alpha)"; the matrix is R2(−α) in VITAL's passive convention.
- **m5.** The equivalence gate is circular for physics: both sides call `vital.aircraft.f16.loads`. It proves the plumbing, which is its stated purpose. The physics anchor stays the NESC cases (PUB) and M5's linear-vs-nonlinear checks.
- **m6.** `MATLAB:Cell2Struct:NumberOfNamesMismatch` escapes as an error identifier (B1 table). This breaks CONVENTIONS 11.

### Certification spot checks (M7; against docs/MIL8785C_EXTRACT.md)

| Record | Extract | Record | OK |
|---|---|---|---|
| 3.2.2.1.2 ζ_sp L1 Cat A | 0.35–1.30 (Table IV) | min 0.35, max 1.3, non-strict | yes |
| 3.2.2.1.2 ζ_sp L1 Cat B | 0.30–2.00 | 0.3, 2 | yes |
| 3.2.2.1.1 CAP L1 Cat A / L3 Cat C | 0.28–3.6 / ≥ 0.096 | 0.28, 3.6 / 0.096 | yes |
| 3.2.2.1.1 ω_nsp, n/α L1 Cat C | ≈ 0.86 / ≈ 2.7 (graphical) | 0.86, 2.7, `approximate: true` | yes |
| 3.3.1.2 τ_R L2 Cat B | ≤ 3.0 ("no greater than") | max 3, non-strict | yes |
| 3.3.1.3 spiral T2 L1 Cat A / B | > 12 s / > 20 s ("greater than") | 12 / 20, strict | yes |
| 3.3.1.1 Cat A-other L1 | ζ_d > 0.19, ζ_dω_nd > 0.35 + 0.014(ω²\|φ/β\| − 20) | two records, strict, increment slope 0.014, threshold 20 | yes (max of the two is enforced by "all pass") |
| 3.2.1.2 phugoid L2 / L3 | ζ_p ≥ 0 / T2 ≥ 55 s | 0 / 55 | yes |

- **Level logic** (`RuleSet.m:44-67`, `assess.m:290-305`): the best Level whose records all pass or are not applicable; an EXCLUDED record makes the point unrated, never a better Level (FC-702); 4 means worse than Level 3. This is correct.
- **Coverage:** `coverage.json` (65 entries) gives an honest reason for every uncovered paragraph: no cockpit/feel model, time-history requirements, qualitative requirements, and Category C not assessed for lack of an approach configuration. Note that 3.3.4.1 roll performance is listed as "needs time histories", but `vital.sim.run` exists. It is the most consequential Class IV requirement still missing.
- **Agnosticism of the evaluation:** the Rule/RuleSet engine itself is agnostic (it reads metric names, Category and policy). The Class (B5) and the factory are not.

## 5. Simulink and visualisation for any aircraft: recommended design

**Today:**
- One MATLAB Function block calls `coder.extrinsic('vital.slx.kernel')`, which calls `vital.plant.derivatives` with a global context.
- It runs in normal mode only, with one MATLAB round trip per RK4 stage plus one per FCS sample.
- It is exact (E = 0) and slow (1.13x real time), and fixed at 4 controls and 13 flat-Earth states.

**Recommended design:**
1. **`vital.slx.build(model)` generates `VitalPlant_<model.Name>`**:
   - `nu = numel(model.Controls)`; the u port is a bus or vector whose element names come from `model.Controls`;
   - the state layout is declared by the plant (`flat13` or `rotating13`);
   - widths are passed as `Simulink.Parameter`s, never typed into chart code.
   - The context is stored in a `containers.Map` keyed by a run id passed as a block parameter (re-entrant).
   - **Gate:** the F-16 model stays E = 0 against `vital.sim.run`, and the twin (5 controls) has E = 0 against `vital.sim.run(..., 'Plant', twin.derivatives)`.
2. **Two plant tiers:**
   - **Reference:** today's extrinsic kernel, exact, normal mode.
   - **Compiled:**
     - `model.compile()` already produces numeric `C(:,:,k)`, `r(:,k)`, `J`, `r_cg` and mass. These become a tunable parameter struct.
     - Each component class gets a code-generable `computeLoadsCG(params, airdata, u)`. The generated DAVE-ML functions are plain MATLAB and are a good starting point; check them with `coder.screener`.
     - The block then runs without extrinsic calls in accelerator / rapid accelerator, or as generated code for real time.
   - **Gate:** compiled tier versus reference tier to 1e-9 (scaled) on the M9-A scenarios, with a measured real-time factor of at least 10x for the F-16 at 100 Hz.
3. **Visual output, generic:** an outport `pose`:
   - lat/lon/h from the flat-Earth origin (`vital.geo`), or directly from the rotating state;
   - φ, θ, ψ relative to local NED, which equals Cesium heading/pitch/roll, with heading = ψ measured clockwise from north;
   - plus `surfaces` = the deflections of the controls with role `surface`.
   - The CG versus the visual origin: the state position is the CG, so the BFRP (the model origin) in NED is `p_n − C_bnᵀ r_cg`. Put this in one function with an ANALYTIC test.
4. **Scene graph from the axis tree:**
   - `model.sceneGraph()` returns, per axis, `{name, parent, C, r}` (from `toStruct`, which already exists), plus per component `{node, hingeAxis, channel, gain}` for movable surfaces and `{node, spinAxis, rpm}` for propellers.
   - A fixed `C_gltf_body` (glTF is y-up, right-handed) is declared once and tested.
   - The same tree drives `Axis.triad` (the MATLAB debugging view, already through `vital.viz.displayMap`) and the Cesium/glTF nodes, so any aircraft draws its engines and surfaces where the physics puts them.
5. **Joystick:**
   - A mapping table from device axes to named controls and roles, with limits from `model.Limits`.
   - Because laws and metrics then use roles (B3), the same stick drives the F-16, the twin (throttle role mapped to two channels) and the X-57 (thrust role mapped to 14 channels).

## 6. Migration plan: AircraftModel to every section, as gated red-green increments

**Regression anchors, unchanged in every increment:**
- README trim to 1e-12;
- the M7 Levels, all groups identical;
- the M8 verdict table, identical on the R5 smoke configuration (and on the default run before closure);
- the NESC bands of M6;
- Simulink E = 0;
- the 1,100-state equivalence (E = 0).

Each increment writes its tests first and shows the RED run and its criteria, and the user approves each phase before it starts.

| # | Increment | Success criteria (pre-registered) | Sabotages it must detect |
|---|---|---|---|
| I0 | **Test hardening, no behaviour change.** Add ANALYTIC known-answer tests: tilted/toed-in/chained twin (P1), combine with rotated self-inertia (P2), rotated-CG weight (P4). Add **non-F-16 known-answer aircraft**: (a) the NESC brick and cannonball as AircraftModels (`probe_brick.m` shows they build, with zero controls) reproducing the M6 NESC bands through `toRuntime` + `derivativesRotating` (PUB); (b) an analytic "linear-derivative" aircraft (constant dimensional derivatives) whose trim, short period, phugoid approximation, Dutch roll and roll/spiral roots are closed-form. | All new tests pass on the current code; NESC brick/cannonball within the M6 bands; analytic aircraft xdot exact (1e-12) and its eigenvalues from linearize within 1e-8 of closed form | SC-9 compiled Cᵀ (sabotage A), SC-10 weight transpose (B), SC-11 compiled rotation dropped (C), SC-12 bridge drops X (M4) |
| I1 | **Plant contract by name.** `vital.plant.derivatives` accepts an `AircraftModel` (dispatch) or an AC with `controlNames` (nu = their count, default 4); one FlightContext constructor; toRuntime struct hash-guarded (`vital:model:staleRuntime`). | F-16 E = 0 (1,100 states); twin xdot through the plant = `twin.derivatives` exactly; editing `AC.aeroScale`/`AC.S` on a toRuntime struct raises an error; per-call cost of the direct path ≤ 1.05x the plant | width check removed; hash check removed; bridge context differs from the direct one |
| I2 | **Trim by name and role** (alpha, attitude, controls by role; thrust allocation; lateral unknowns φ or β with da, dr; fixed scheduled controls such as flaps). | F-16 README and M6/M7 trims unchanged to 1e-12; twin symmetric trim = F-16 trim (half thrust each); twin engine-out: ΣM = 0 and the analytic dN = d·T/2 balanced by rudder; analytic aircraft trim closed form 1e-10; refusal when not square | allocation sign flip; residual index swap; squareness check off |
| I3 | **Linearize, modes and metrics by name/role.** Inputs from the model; pitch column by role; `nAlphaSteady` and `metrics` by role; control laws (pitchSas, yawDamper) address channels by role. | F-16 A, B bit-identical (same order); M7 Levels identical; twin B has 5 columns with the two throttle columns summing to the F-16 throttle column (1e-9); analytic aircraft eigenvalues 1e-8 | pitch role mapped to the wrong channel; B column swap |
| I4 | **Certification agnostic.** The aircraft declares Class and categories; the loader filters by `applicability` and refuses uncovered Classes; add Class I/II/III rows (Tables VI–VIII, Fig. 3 II-L/III); `fq.modelFactory(builder)` replaces `f16Factory` (kept as a thin wrapper); records verified with reviewer and date. | F-16 M7 Levels identical; Class I analytic aircraft gets its known Level (hand); Class mismatch gives `vital:fq:classNotCovered` | applicability ignored; Class rows swapped; verified flag forged |
| I5 | **Uncertainty on component parameters.** `Component.parameters()`, `model.withParameters`; the F-16 AeroScale becomes the aero component's parameter set (same names); generic derivative-increment component; `F16Evaluator` becomes `ModelEvaluator`. Optionally the lateral-search change (sqp/active subspace) as a separate, separately approved increment. | M8 verdicts identical (smoke config bit-identical margins; default-run table identical); runtime ≤ 1.05x; analytic aircraft: CSR alpha* known in closed form for a 1-parameter derivative increment | parameter applied to the wrong component; withParameters returns a stale compiled model; sigma read from the wrong group |
| I6 | **Simulink per model** (Section 5, items 1–2). | F-16 E = 0; twin E = 0 against `sim.run`; compiled tier vs reference 1e-9, ≥ 10x real time | width mismatch; channel order reversed; context leakage between two simultaneous runs |
| I7 | **Visualisation and joystick** (Section 5, items 3–5). | BFRP pose = p_n − C_bnᵀ r_cg (ANALYTIC); scene graph = axis tree (every node's pose equals `originIn`/`dcmTo`); axis-check images unchanged for the F-16 | CG/BFRP offset dropped; glTF axis map transposed; surface hinge sign flipped |
| I8 | **X-57 enablers, then the X-57** (M5: pose to components, DataAxes, h_rot, coupling field, component mass via `combine`). | Each enabler with its own analytic test (e.g. a spinning-disc gyroscopic moment ω × h; a stability-axis CL/CD table equal to the body-axis form); X-57 against its published data (PUB), never against itself | DataAxes ignored; h_rot sign; local inflow without ω × r |

**Performance rule for the migration:**
- Consumers call `model.derivatives` directly (measured 1.02x the plant), never through toRuntime (1.21x).
- Reduce `FlightContext`'s 106 us before I5, so that the M8 inner loop does not grow beyond the 17.4 h it takes today.
