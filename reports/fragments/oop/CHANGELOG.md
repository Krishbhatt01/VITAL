# CHANGELOG fragment (agent oop, 2026-10-19): 0.8.1-OOP

## Implemented
- **Object layer** (ADR-037): vital.Aircraft, FlightCondition, TrimResult, LinearModel; vital.modes.Mode and subclasses ShortPeriod, Phugoid, DutchRoll, Roll, Spiral; vital.rules.Rule and RuleSet; vital.fq.Assessment; vital.atmos.Atmosphere and IsaAtmosphere; vital.ctrl.ControlLaw with PitchSasLaw, YawDamperLaw, NescLqrLaw, CombinedLaw; vital.uq.Study.
- **Atmosphere:** vital.env.atmosphere (an atmosisa wrapper with geopotential conversion, a range error and an exact one-entry cache). Every core caller uses it. vital.env.atmosphereUS76 is a thin alias.
- **Air data:** vital.airdata.tasToCasEas now uses the ISA sea-level constants (rho0 = 1.225, R = p0/(rho0 T0)), so CAS = EAS = TAS at sea level stays exact with atmosisa. tAirData was NOT edited.
  - vital.nesc.equivalentAirspeed keeps its US 1976 rho0, because it reproduces the NESC TM KEAS (proposed ADR N6).
- **Frames and geodesy:** NOT switched to the toolbox; each toolbox function measured 6-64x slower per call (ADR-037).
- **Version:** 0.8.1-OOP.

## User decisions 2026-10-19 and their execution
1. **Level tables re-run with atmosisa:** the default and exploration grids (run_f16_fq) and the M7 SAS suggestion (run_f16_sas('Suggest', true)).
   - Comparison: reports/work/oop/levels_compare.md. **0 Level or status changes.** This covers every group, record verdict, point status and envelope class, the SAS status, the rounded gains [0.02 0.14 0.82] and the confirmation Levels.
   - Margins moved by <= 6e-6, except the near-neutral spiral group 3.3.1.3 on the default grid (up to 3.4e-3; still Level 1, same verdict).
   - The regenerated reports are stored alongside the originals; nothing was overwritten: reports/fq/f16_fq_default_baseline_atmosisa.json/.md, f16_fq_exploration_baseline_atmosisa.json/.md, reports/ctrl/f16_sas_suggestion_atmosisa.json/.md.
2. **Re-baselined tests.** Each has the comment "re-baselined 2026-10-19 for atmosisa (ADR-037), was X, now Y, user-approved". Source tags are kept.
   - tests/M1/tAtmosphere.m:
     - seaLevel: rho0 changed to the ISA defining value 1.225.
     - deltaIsaShiftsTemperatureOnly: ISA's R.
     - tropopauseAnalytic: ISA closed form with ISA's R.
     - matchesAtmoscoesa: p and rho checked at 1e-6 below 10 km, 5e-6 over 0-32 km, and 1e-5 over 0-84.5 km. This tolerance was LOOSENED because atmosisa's R differs from US 1976 by 7e-7 and that enters the barometric exponent (measured 8.6e-6 at 84.5 km). T and a keep 1e-6.
   - tests/M1/tAirData.m#seaLevelCasEqualsTas: not edited; fixed in the core (tasToCasEas, above).
   - tests/M6/tF16FqR2.m#factoryMachUsesLocalSpeedOfSound: closed form with ISA's R.
   - tests/M7/tCtrlFq.m#defaultPathBitIdentical: CAP and zeta_d re-pinned (cited to the _atmosisa report).
   - tests/M7/tCtrlSuggest.m: now reads f16_fq_default_baseline_atmosisa.json. The pins work by reading this report file.
   - tests/M8/tF16Uq.m#pinnedSas: achievedMargin re-pinned from f16_sas_suggestion_atmosisa.json.
   - tests/M8/tUqR4bF16.m#bracketKnownCase: side alphas re-pinned to [5.000695 4.999390].
   - tests/M5/tLinearizeR1.m#windAirAxisConverters: 1e-8 changed to 5e-8 abs. This tolerance was LOOSENED. The reason is the rounding of the central-difference reference: |V| eps/h = 3.9e-8 with h = 1e-6. The measured error was 1.42e-8 = 2^-26, one rounding step.
3. **Atmosphere tolerance:** the revised tolerance (1e-6 below 10 km, 5e-6 over 0-32 km) was accepted. The original 1e-6 claim stays recorded as a failed hypothesis in tOopAtmosphere.
4. **Cache test and sabotage:** tOopAtmosphere#scalarCacheNeverStale added (FC-977), with sabotage SOOP-3 (stale cache). The guide fragment counts (25 tests, 9 sabotages) are now correct.

## Gates
- **RED:** reports/work/oop/M8_red_oop.txt. 24 new tests, all RED_EXPECTED, 0 RED_UNEXPECTED. scalarCacheNeverStale was added after the user's decision and did not go through a RED run; its sabotage SOOP-3 shows that it can fail.
- **First GREEN:** M8_green_oop.txt. 687 tests, 676 passed, 11 failed: the atmosisa value pins listed above.
- **Final GREEN:** M8_green_oop_final.txt (counts in the final report).
- **Sabotage:** M8_sabotage_oop.txt and M1_sabotage.txt.
