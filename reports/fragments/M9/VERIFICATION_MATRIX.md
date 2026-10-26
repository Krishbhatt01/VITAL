# VERIFICATION_MATRIX fragment (agent m9a, 2026-10-25): M9-A rows

| Claim | Evidence | Source | Test |
|---|---|---|---|
| Simulink VitalPlant equals vital.sim.run, open loop (E <= 1e-9; measured 0) | ode4 + ZOH independent implementation | INDEP | tests/M9/tSlxEquivalence.m#e1OpenLoopDoublet |
| ... closed loop M7 SAS 100 Hz, 10 s (measured 0) | | INDEP | #e2ClosedLoopSas |
| ... M7 SAS 50 Hz multi-rate (measured 0) | | INDEP | #e3SasFiftyHz |
| ... NESC LQR 200 Hz (measured 0) | | INDEP | #e4NescLqr |
| Trimmed start stays trimmed through Simulink (tF16Sim bounds) | | REG | #e5TrimHold |
| Pitch/roll/yaw signs through Simulink | CONVENTIONS 7 | ANALYTIC | tests/M9/tSlxAttitude.m |
| Generated model reproducible and unedited | structure hash | REG | tests/M9/tSlxBuild.m |
| Guards and identifiers | | INDEP / exact ids | tests/M9/tSlxGuards.m |
