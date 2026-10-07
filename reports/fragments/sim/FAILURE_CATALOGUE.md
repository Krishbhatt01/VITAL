# Failure-catalogue rows from agent `sim` (M5-B)

**Replacements for the PLANNED rows:**

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-301 | M5 | Invalid time step or final time (non-positive, non-finite, tFinal not an integer number of steps), an input switch off a step boundary, or a controller rate that is not an integer divisor of the base rate | validation before integration | `vital:sim:badStep` | `tests/M5/tSimGuards.m#badStepErrors` |
| FC-302 | M5 | Non-finite state during integration (stage state, stage derivative, or `vital:plant:nonFinite` from the plant) | guard (stop at the last finite state, record reason) | `vital:sim:nanState` | `tests/M5/tSimGuards.m#nanStateStopsAtLastFiniteState` |
| FC-601 | M5 | Quaternion norm drift beyond tolerance | guard on `y.quatNorm` | `vital:sim:quatNorm` | `tests/M5/tSimGuards.m#quatNormStops` |
| FC-602 | M5 | State leaves the declared envelope | guard (stop, record reason) | `vital:sim:envelope` | `tests/M5/tSimGuards.m#envelopeStopsAtFirstExcursion` |

**Proposed new rows.** The IDs are suggestions; the coordinator assigns the final ones.

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-303 | M5 | Controller sample rate not an integer divisor of the base rate, or faster than the base step | validation | `vital:sim:badStep` | `tests/M5/tSimGuards.m#badControllerRate` |
| FC-304 | M5 | Plant raises an error during a time simulation | caught per step; identifier and message kept | `vital:sim:plantError` | `tests/M5/tSimGuards.m#plantErrorStopsAndKeepsIdentifier` |
| FC-603 | M5 | Aircraft descends below the ground limit | guard on `y.h` | `vital:sim:ground` | `tests/M5/tSimGuards.m#groundStops` |
| FC-604 | M5 | A guard's plant output is missing (guard would silently not run) | guard disabled and recorded in `out.guards` | `active = false` with reason | `tests/M5/tSimGuards.m#absentGuardFieldIsDisabledAndRecorded` |
| FC-605 | M5 | Table lookups clamped during a simulation | first time recorded; optional stop | `vital:sim:outOfEnvelope` | `tests/M5/tSimGuards.m#outOfEnvelopeRecordedNotStopped` |
| FC-606 | M5 | Bad initial state or controls given to a simulation | validation plus the first plant evaluation | `vital:badInput` | `tests/M5/tSimGuards.m#badInputErrors` |

## Rows added after review R1 (2026-09-30)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-305 | M5 | A discrete controller raises an error during a simulation | caught at the sample; identifier and message kept | `vital:sim:controllerError` | `tests/M5/tSimR1.m#controllerErrorIsAStop` |
| FC-306 | M5 | A discrete controller returns a non-finite command | checked at the sample (stop) | `vital:sim:nanState` | `tests/M5/tSimR1.m#nonFiniteControllerOutputIsNanState` |
| FC-307 | M5 | A command leaves its control limit (no silent clipping) | recorded in `out.controlLimit`; optional stop | `vital:sim:controlLimit` | `tests/M5/tSimR1.m#aileronBeyondLimitIsRecordedNotClipped` |
| FC-308 | M5 | A piecewise input struct varies inside a step (silently 2nd order) | checked before the run | `vital:sim:inputNotPiecewiseConstant` | `tests/M5/tSimR1.m#piecewiseStructMustBeConstant` |
| FC-309 | M5 | A discrete controller returns the wrong number of commands | validation | `vital:badInput` | `tests/M5/tSimR1.m#wrongSizeControllerOutputIsBadInput` |

FC-302 now also covers a NaN from the controller (R1 section 5): `tests/M5/tSimR1.m#nonFiniteControllerOutputIsNanState`.
