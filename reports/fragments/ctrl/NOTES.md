# Open issues, doubts and unverified items (agent `ctrl`, M7)

1. **Failed pre-registered hypotheses.** Each is kept in its test header, and a corrected check with an independent justification was added. No tolerance was loosened.
   - **tCtrlClosedLoop (b), LQR phugoid.** The prediction "zeta_p(LQR) > zeta_p(bare)" assumed the phugoid stays oscillatory. NASA's LQR (theta and KEAS feedback) splits it into two stable real roots, -16.0 and -0.76 1/s, so zeta_p is NaN.
     - Corrected check: the slowest closed-loop longitudinal root decays faster than the bare phugoid. It holds: -0.76 vs -0.0071 1/s.
     - The zeta_d prediction held: 0.117 -> 0.231.
   - **tCtrlLaws 4, NESC hand law.** The registered perturbation drove NASA's law into its own stick limiters (lateral total about -3.7, longitudinal about 1.9, clamped to +/-1), where a linear hand law cannot apply. The mismatch was 1.7 rad.
     - Corrected check: the same tolerance (1e-10) at a perturbation ten times smaller, with lawState asserting that no limiter is active. The test also shows the original perturbation sets the saturation flags.
     - A second fixture error was found while correcting: du = +0.1 m/s takes the throttle total below idle, because the KEAS-to-throttle gain is about 1 per kt. The corrected fixture uses du = -0.05 m/s.
   - **tCtrlSimAgreement 1, nescLqr longitudinal q.** e(0.0025 s) = 0.0367 > 2e-2. The LQR loop is far faster than the estimate assumed: short period -23.4 +/- 17.1i, roll-spiral -37.2 +/- 37.1i 1/s.
     - The registered ratio check held (2.08, and 1.97 for the next halving), so the discrepancy is pure first-order sampling.
     - Corrected check: Richardson-extrapolated (dt -> 0) trajectories vs expm(A_cl t), at the same 2e-2. Measured 3.0e-3 on q.
   - **tCtrlFq 1, RED_SUSPICIOUS in RED.** isequal on evaluatePoint results failed on identical structs, because P holds NaN metric values (isequal(NaN, NaN) is false). Changed to isequaln before implementation; this is a test bug, not physics. After the change the test is a VACUOUS guard on the M6 path, as registered ("expected VACUOUS in RED").
   - **tCtrlSuggest 1 and 4.** Two test-code bugs were fixed after the first GREEN run: jsondecode returns a cell for "Inf", and a for-loop over a transposed struct array. No expectation changed.
2. **Added after GREEN (guard, not RED-first).** `tCtrlSuggest#regressionIsNotASuccess`, written for failure row FC-816: a fixed wrong-sign Kq makes the confirmation report "worse than bare" and TARGET_NOT_REACHED.
3. **CAP is reachable with static feedback.** The brief anticipated that a static pitch SAS might reach CAP "only partly". With alpha feedback (Ka) it reaches Level 1 easily, because CAP = omega_sp^2 / (n/alpha) and Ka raises omega_sp^2 while n/alpha is invariant (tCtrlFq 2, 1e-6). Pitch-rate feedback alone raises CAP only weakly: dm/dKq = 1.67 vs dm/dKa = 2.17 per unit gain at k = 0, and Kq mainly moves damping (dm(zeta_sp)/dKq = 3.5). This is an augmented-aircraft result with ideal sensors and no actuator. A real alpha-feedback SAS also changes the stick-force gradient, which VITAL does not assess (OUT-OF-SIM).
4. **The suggested design.** Kq 0.02 s, Ka 0.14, Kr 0.82 s was confirmed over the 30 in-envelope points. The CAP and CO/GA margins are about 0.05, the registered design goal: it sits close to the boundary by construction (minimum-norm step). It is static, with no washout: the yaw damper fights steady turns (spiral root -0.0101 -> -0.062 1/s at the README trim). Gains are ideal (no actuator, no sensor dynamics, continuous loop; the ZOH delay is ignored in the Levels, ADR-024/026).
5. **NESC LQR flying qualities (README point, indicative).** STABLE, but the closed loop is not a classical set: split phugoid and a coupled roll-spiral oscillation at -37.2 +/- 37.1i 1/s. evaluatePoint FLAGs it (3.1.12). The resulting Levels:
   - 3.3.1.4 worse than Level 3 (coupled roll-spiral)
   - 3.2.2.1.1 Level 3 (CAP far above 3.6; omega_sp 29 rad/s)
   - 3.2.1.2 NOT_ASSESSABLE (no oscillatory phugoid)
   These grade an attitude-hold LQR with bare-airframe criteria. They show what the chain says; they are not a claim about NASA's design. The LQR's n/alpha includes its throttle feedback (ADR ctrl-3).
6. **Runtime.** tCtrlSuggest takes about 5 to 6 minutes: about 13 closed-loop assessments of 36 points at about 0.7 s per point, since a closed-loop linearization is about 6 times an open one. That is far above the ~60 s per file target. The search runs once per class. tCtrlSimAgreement takes about 35 s.
7. **Edits to fq files** (assigned by the task): `+vital/+fq/f16Factory.m` ('Controller' option) and `+vital/+fq/evaluatePoint.m` (closed-loop path, info.closedLoop and info.equivalentSystem only in that path). The default path is unchanged and the M6 gate passes. No M6 test file was edited.
8. **Not done.**
   - No washout or dynamic SAS, and no augmented-state closed-loop linearization (ADR-024 still applies).
   - No low-order equivalent-system fit.
   - No aileron-rudder interconnect in the suggestion (Kari exists in yawDamper but is not searched).
   - suggestGains does not search the Level 2-to-1 margin of the bare-airframe Level 1 groups beyond protecting them.
   - The protected-group requirement min(Goal, m_bare)/2 is a design choice (the 3.2.2.2 height-root margin of 0.011 is protected at 0.0056).
9. **Sabotage scope.** run_sabotage('M7', 'Parts', {'ctrl'}) on a quiet tree. S7C-4 and S7C-5 run tCtrlSuggest, so each takes about 6 minutes.
