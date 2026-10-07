# Notes from agent `nesc` (M5-C): open issues, failed hypotheses, doubts

## 1. Result in one paragraph
- **Cases 1-10:** every one of the 25 band signals is inside its pre-registered envelope on the first run, with no tuning. The dt study (0.01 vs 0.02 s) is <= 0.0023 of delta.
- **F-16:** VITAL's NESC-environment trim reproduces SIM 5's initial state to its recording precision: case 11 t = 0 rates to 10 digits; case 15 L(0) = -225.8298 vs -225.8300 ft lbf.
  - Positions, velocities, attitudes and air data are inside the bands in 11, 12, 15 and 16, and in 13.x except 13.4 longitude/NED velocity and some attitude transients.
  - **53 of 200 F-16 band signals (36 in 11-13.4, 17 in 15-16) remain outside** (table in section 5). They are recorded as FAILED pre-registered expectations: `KNOWN` in tests/M5/tNescF16Cases.m and tNescF16Circles.m.
  - Each is asserted by a labelled known-discrepancy test (still outside, no worse than 1.05 x the registered excess). The original <= 0 check stays in force for every other signal. **The coordinator decides.**

## 2. Failed hypotheses and decisions changed after a run (all disclosed in DECISIONS.md)
1. **ADR N6, control-law rate 50 Hz ZOH: FAILED.**
   - 13.x/15/16 were outside in 7-19 signals each.
   - 13.3 roll excess 2.60 / 1.28 / 0.30 / 0.10 deg at 50 / 100 / 200 / 500 Hz (rate the only change), converging to SIM 4/5.
   - Superseded by N6r: the stateless law is evaluated at every RK4 stage (`AC.stageControl`).
2. **ADR N6, control-law rates relative to local NED (w_bn): FAILED.** Case 15 left the 30 deg bank ~3 s early, with a bank bias of -29.99934 vs -29.99554 deg.
   - With Earth-relative rates w_be, roll matches SIM 5 to 7 digits (-29.995536) and latitude to 2e-6 deg through the capture.
   - Superseded by N6c (w_be = the aero model's bodyAngularRate signal).
3. **ADR N11 step sizes: FAILED at first.**
   - Cases 11/12 at 0.02 s vs the registered dt' = 0.04 s gave ratio 0.39 (case 12 L) and 0.22 (case 11 Y force). Against 0.01 s the ratio is 0.02, so 0.04 s itself is too coarse.
   - The stage law at 0.02 s gave ratio 82 in 13.3.
   - N11r: autopilot cases at 0.005 s (study vs 0.0025 s); 11/12 at 0.02 s (study vs 0.01 s over 30 s).
   - **Still FAILED at 0.005 s** for 9 signal studies of 13.3/13.4 (ratios 0.11-0.28, `KNOWN_STUDY`). There the dt error is ~0.25 delta, small next to the 2-650 delta excesses.
4. **Test-construction errors found in the first GREEN attempt** (expected values and tolerances unchanged):
   - tRotatingEom/j2Gravitation...: a component-wise relative tolerance hit exactly-zero components on the Equator. It is now 1e-12 x |g| absolute, as registered ("1e-12 relative" to g).
   - tF16ControlLaw/lqrSumsAndMixer: the chosen "small" inputs saturated the stick and throttle, contrary to the registered "no limit active". The inputs were corrected and an assertion that no limit is active was added.
5. **tF16ControlLaw expectations 10 and 12 revised with N6c.** "At trim the law commands exactly the trim controls" holds only for w_bn. The expectation is now the trim plus the hand-evaluated LQR rate terms of the trim's Earth-relative rates (header "REVISION").
6. **Sabotage S5C-4 was initially NOT DETECTED; the test was fixed.** `saturationsAreApplied` drove each limit to one side only, so removing `min(totLongStk, 1)` changed nothing it looked at. `everyLimitIsObservableAndApplied` now covers it (independent hand evaluator, 22 limits x both sides, observability asserted per limit, control and GNC laws); the original test is kept. Registered: S5C-4, S5C-8 ... S5C-12, S5C-14.
7. **Comparison failure-mode tests** (unknownCaseRejected, signalWithoutReferenceIsNotAssessable, shortRunFailsEverySignal) were written after the RED run, alongside code that already existed. They could not be RED against a stub without a contrived stub. Their dependence on the behaviour is shown by sabotages S5C-6 and S5C-7, which remove exactly that behaviour.

## 3. Evidence that the remaining F-16 discrepancies are not a VITAL defect (my reading; the coordinator decides)
- **(a) First frame at engagement or command onset** (13.1/13.2 Y force, L, N at t = 0; 13.4 N 654 delta at exactly t = 20.00; 15/16 forces and moments at 0-0.2 s).
  - The static law acts at the sample itself, while SIM 4/5 record the pre-command state at that sample.
  - In 13.4 the sims' offset command appears one frame later than the step, consistent with "user logic" running after the FCS in each frame (NESC_EXTRACT_F16 risk 16).
  - I did not shift VITAL's command timing to the data.
- **(b) Saturated transients about 1 s long** (13.1 pitch rate at 5.2 s; 13.3 at 15.3-16.5 s; 13.4 at 20-21.5 s; 15 at the capture, 31 s).
  - VITAL follows SIM 5 closely. At 15.3 s in 13.3: roll 31.96 vs S5 32.34 and S4 32.21 deg; pitch rate -3.81 vs S5 -3.87 and S4 -5.26 deg/s.
  - Where SIM 4 and SIM 5 agree the envelope is only floor wide (0.05 deg, 0.01 deg/s), and a ~5 ms lead of the sims in a 1500 deg/s^2 roll-in exceeds it.
- **(c) Cases 11/12 pitching and rolling moments of 1e-4 to 2e-2 ft lbf** (1e-10 to 1e-8 of qSc).
  - At t = 1.6 s SIM 4 and SIM 5 cross near zero and delta shrinks to 4e-6 ft lbf.
  - Elsewhere VITAL tracks SIM 5 to ~1e-5 ft lbf (e.g. -1.60e-4 vs -1.54e-4 at 5 s).

## 4. Unverified or assumed
- The control-law execution form of SIM 4/5 is unknown. "Continuous" is my inference from the convergence trend, not a documented fact.
- Case 12 trims on clamped tables (status OUT_OF_DATA_ENVELOPE, accepted for case 12 only per ADR-014). The run records outOfEnvelope from t = 0 and is not stopped (`Guards.stopOnOutOfEnvelope = false`).
- Mass 637.1595 slug (DML) vs 637.26 (TM Table 7): the DML value is used, as in M4.
- At zero airspeed (cases 1-6 at t = 0) the plant reports alpha = beta = NaN (undefined; no plausible number is invented). No NESC signal needs them.
- vital.sim.run ADR-026/027 (controller y at u_applied, control-limit monitor):
  - the NESC law is stage-evaluated in the plant, so the controller path is unused for the NESC cases;
  - the control-limit monitor reads `y.u_applied` (rdr reaches 29.83 deg < 30; ail sits at +/-21.5 = the limit, not beyond).
  - The GREEN run after the change confirms the results (section 5).
- `vital:nesc:notTrimmed` is now tested (`tNescF16Cases/nonOkTrimIsRefusedAndOverrideIsScoped`: case 11 at 106 ft/s through the `Override` option of runCase; sabotage S5C-13). No registered NESC case produces a failed trim.
- dt: the step-size study now runs at dt/2. The dt error at the working dt is at most the measured change x 16/15 for order 4, and less at the saturation switches, where the order drops.

## 5. Runtime and the per-case table
See CHANGELOG.md (final GREEN gate) for the per-case table and test-file durations.
- M5-C takes 714.5 s (11.9 min) against the ~8-minute target, which is **not met**.
- The stage-evaluated law needs dt = 0.005 s for 360 s of circle flight (cases 15 and 16: 350 s). No dt or tolerance was relaxed. The only pure-overhead saving found (about 2 %) was taken.
- The remaining cost is the F-16 table lookup (22 %, vital.daveml.lookup, an M2 file) and the compiled control law (16 %). A faster lookup in M2 is the lever.
