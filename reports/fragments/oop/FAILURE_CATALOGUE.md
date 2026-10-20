# FAILURE_CATALOGUE fragment (agent oop, 2026-10-19): 0.8.1-OOP rows (next free numbers after FC-974)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-975 | M8 | Geometric height fed to atmosisa, whose input is geopotential | `vital.env.atmosphere` converts first; exact comparison with atmosisa(H) | verification failure | `tests/M8/oop/tOopAtmosphere.m#geometricConvertedToGeopotential` |
| FC-976 | M8 | atmosisa holds the boundary value outside [-5000, 84852] m with only a warning (silent clamp) | range pre-check before atmosisa; atmosisa called with 'action', 'None' | `vital:env:altitudeOutOfRange` | `tests/M8/oop/tOopAtmosphere.m#outOfRangeIsError` |
| FC-977 | M8 | The atmosphere speed cache returns a stale value for a new altitude | cache keyed on the exact geopotential height; scalar sequence compared with a fresh vector call | verification failure | `tests/M8/oop/tOopAtmosphere.m#scalarCacheNeverStale` |
| FC-978 | M8 | atmosisa disagrees with US 1976 beyond the accepted tolerance | frozen test-side US 1976 reference (INDEP) | verification failure | `tests/M8/oop/tOopAtmosphere.m#agreesWithUs76Below32km` |
| FC-979 | M8 | The object layer hands the core a different aircraft struct than the functional chain | isequal with vital.aircraft.f16.config | verification failure | `tests/M8/oop/tOopAircraft.m#toRuntimeIsTheConfigStruct` |
| FC-980 | M8 | Euler/DCM convention mismatch between VITAL and Aero.FixedWing.State | toolbox InertialToBodyMatrix vs VITAL C_bn at a trim | verification failure | `tests/M8/oop/tOopAircraft.m#fixedWingStateConsistent` |
| FC-981 | M8 | Object constructors accept an invalid aircraft or condition | validation in the class or the core | `vital:badInput` | `tests/M8/oop/tOopAircraft.m#flightConditionMatchesFactory` |
| FC-982 | M8 | A failed trim linearized through the object layer | the core's check, unchanged | `vital:linear:notTrimmed` | `tests/M8/oop/tOopAircraft.m#failedTrimNotLinearized` |
| FC-983 | M8 | vital.rules.Rule disagrees with the M6 engine (margin, class or pass) | per-record comparison with vital.fq.assess on all records | verification failure | `tests/M8/oop/tOopRules.m#ruleEvaluateMatchesEngine` |
| FC-984 | M8 | An object control law builds a different controller than the M7 function | step output and info compared (isequal) | verification failure | `tests/M8/oop/tOopCtrlUq.m#lawsEqualFunctional` |
| FC-985 | M8 | vital.uq.Study drops or invents run_f16_uq options | injected entry point receives the exact list; unknown option rejected | `vital:badInput` | `tests/M8/oop/tOopCtrlUq.m#studyForwardsOptions` |
| FC-986 | M8 | The plant becomes materially slower (more than 10 % at a fixed altitude) | same-run timing against the frozen 0.8.0 plant | verification failure | `tests/M8/oop/tOopPerformance.m#plantWithinTenPercent` |
