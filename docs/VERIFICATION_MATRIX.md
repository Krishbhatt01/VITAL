# VITAL verification matrix

For each capability: what evidence establishes it, the evidence type, and where the evidence comes from.

Evidence types:
- **PUB:** a published reference.
- **INDEP:** an independent implementation.
- **ANALYTIC:** a closed form.
- **REG:** a pre-registered expectation.

Verification ("built right") and validation ("right model") are listed separately. A validation claim is never made from verification evidence alone.

| Capability | Milestone | Evidence | Type | Source |
|---|---|---|---|---|
| Test gate logic (RED/GREEN classification) | M0 | Synthetic fixtures with known outcomes | ANALYTIC | tests/fixtures |
| Tests can fail (not vacuous) | M0+ | Registered sabotages turn targets RED in separate processes | REG | tests/Mk/sabotages.json |
| Reference data integrity | M0 | SHA-256 against manifest | ANALYTIC | data/MANIFEST.json |
| Frames, DCM, quaternion, Euler | M1 | Round trips; orthonormality; Aerospace Toolbox `angle2dcm`/`quat2dcm` | ANALYTIC, INDEP | MATLAB Aerospace Toolbox |
| WGS-84 geodesy, J2 gravitation | M1 | `lla2ecef`/`ecef2lla`/`gravitywgs84`; TM Table 73 constants | INDEP, PUB | TM Vol II p.93 |
| Load transfer and summation | M1 | Couple invariance, round trip, hand cases | ANALYTIC | — |
| Mass properties | M1 | Point-mass and box analytic results | ANALYTIC | — |
| US 1976 atmosphere | M1 | Table values; `atmoscoesa` | PUB, INDEP | NASA-TM-X-74335 |
| Air data, CAS/EAS/TAS, vanes | M1 | Closed forms; `correctairspeed`; exact kinematics | ANALYTIC, INDEP | — |
| DAVE-ML import of the F-16 | M2 | Every embedded checkData case reproduced | PUB | F16_*.dml (NESC) |
| Rigid-body EOM, flat | M3 | Torque-free invariants; datum invariance | ANALYTIC | — |
| Rotating-Earth EOM; RK4 order | M5 | Coriolis/centripetal closed forms; dt⁴ order; NESC cases 1–10 within band | ANALYTIC, PUB | TM Vol II App. C/D |
| F-16 plant (aero, engine) | M3 | checkData; datum invariance; CG shift | PUB, ANALYTIC | F16_*.dml |
| Trim | M4 | NESC README Table 11; NESC case 11 pitch attitude | PUB | README.html; TM case 11 |
| Linearization, modes | M5 | linear vs nonlinear response; analytic mode systems | INDEP, ANALYTIC | — |
| Time-domain F-16 with NESC controller | M5 | NESC cases 11–13.4 within band (15, 16 as registered in the case matrix) | PUB | TM Vol II App. D |
| MIL-F-8785C Level assessment | M6 | Analytic engine cases; pre-registered mutations | ANALYTIC, REG | MIL-F-8785C (user-supplied) |
| Design feedback (SAS lever) | M7 | Closed-loop eigenvalues; confirmed re-run | ANALYTIC, REG | — |
| Uncertainty verdicts | M8 | Toy counterexamples; Clopper–Pearson closed form | ANALYTIC | Review 3/4 counterexamples |
| Simulink equivalence, visualization | M9 | Simulink vs MATLAB RK4; packet decode; attitude tests | INDEP, ANALYTIC | — |

**Validation (not only verification):** VITAL's F-16 is validated only to the extent the NESC multi-simulator results allow. They show that VITAL implements the same published model the way NASA's tools do. That is not a validation against F-16 flight data, and no report may present it as one.
