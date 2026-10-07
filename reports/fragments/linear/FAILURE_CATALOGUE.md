# Failure-catalogue rows proposed by agent `linear` (M5-A)

Replace the two PLANNED rows FC-506 and FC-507:

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-506 | M5 | Linearization step-size plateau not found | step study: three successive central-difference estimates must agree within RelTol 1e-6 of the weighted column | `NOT_CONVERGED` (linearization; column NaN, reason names it) | `tests/M5/tLinearJacobian.m#noisyFunctionHasNoPlateau` |
| FC-507 | M5 | Mode is not oscillatory (e.g. short period split into real roots) | mode classifier: roots of the group are real | `NOT_OSCILLATORY` (wn, zeta, period NaN) | `tests/M5/tModes.m#shortPeriodSplitIsNotOscillatory` |

New rows (IDs proposed; the coordinator may renumber):

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-510 | M5 | Linearization at a table breakpoint (left and right slopes differ; a central difference would silently return their average) | one-sided asymmetry (f(z+h) - 2f(z) + f(z-h))/h does not shrink with h at the plateau | `NOT_CONVERGED` (reason "kink/breakpoint"; column NaN) | `tests/M5/tLinearJacobian.m#kinkAtPointIsDetectedNotAveraged` |
| FC-511 | M5 | Linearization requested about a trim that is not OK | trim status check | `vital:linear:notTrimmed` | `tests/M5/tF16Linearize.m#untrimmedIsRefused` |
| FC-512 | M5 | Modal analysis of a linear model that is not converged | lin.status check | `vital:linear:notConverged` | `tests/M5/tModes.m#refusesBadLinearization` |

Additional evidence for FC-510 on the real plant: `tests/M5/tF16Linearize.m#tableBreakpointIsReportedAsKink` (F-16 plant at alpha = 5 deg, a breakpoint of every NESC alpha table).

## M5-X rows (IDs proposed; the coordinator may renumber)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-513 | M5 | A dynamic (stateful) controller would be linearized as static | `static = true` declaration required; returned state compared with the initial state at every call | `vital:linear:dynamicController` | `tests/M5/tClosedLoopLinearize.m#dynamicControllerRefused` |
| FC-514 | M5 | Closed-loop linearization about a point that is not a closed-loop equilibrium | controller output at the trim vs trim controls (1e-9) | `vital:linear:controllerNotAtTrim` | `tests/M5/tClosedLoopLinearize.m#controllerNotAtTrimRefused` |

## Review R1 rows (IDs proposed; the coordinator may renumber)

| ID | Milestone | Failure mode | Detection | Error / status ID | Test |
|---|---|---|---|---|---|
| FC-515 | M5 | Linearization about a state that is not an equilibrium of the given aircraft/environment (stale trim: other CG, g) | ||W f0(1:8)||_inf > TrimTol 1e-8 | `vital:linear:notEquilibrium` | `tests/M5/tLinearizeR1.m#cgMismatchIsNotAnEquilibrium` |
| FC-516 | M5 | Step-study plateau limited by round-off of the function values (quantized, wrong derivative) | eps max|W f| ZScale / h > 0.01 RelTol scale + AbsTol | `NOT_CONVERGED` (column status ROUNDOFF, "round-off limited") | `tests/M5/tJacobianR1.m#roundoffLimitedPlateauIsRefused` |
| FC-517 | M5 | Closed-loop algebraic loop u = step(x, y(x, u)) has no unique static solution | Newton on the loop does not converge, or its Jacobian is singular | `vital:linear:algebraicLoop` | `tests/M5/tClosedLoopR1.m#unsolvableLoopIsRefused` |
| FC-518 | M5 | Closed-loop or controller step study fails (e.g. a controller kink at the trim) | per-study status propagated to lin.status and lin.columnStatus | `NOT_CONVERGED` (reason names the controller) | `tests/M5/tClosedLoopR1.m#controllerKinkIsReported` |

- **Change for FC-506 / FC-510:** add the end-to-end reference through `linearize`, `tests/M5/tLinearizeR1.m#breakpointTrimIsNotConverged` (20,000 ft, the h column on the thrust-table breakpoint).
- **Change for FC-507:** the split phugoid, split Dutch roll and all-real longitudinal branches are now covered by `tests/M5/tModesR1.m` (splitPhugoidIsNotOscillatory, splitDutchRollIsNotOscillatory, fourRealLongitudinalRoots).
- **Not tested:** `vital:linear:controllerError` (a controller that raises inside linearize) has no dedicated test yet. See NOTES 17.
