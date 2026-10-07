# Proposed ADRs from agent `ctrl` (M7)

## ADR-0xx (ctrl-1): M7 control laws are static deviation laws about the trim, built from the trim
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

## ADR-0xx (ctrl-2): NASA's NESC LQR SAS on the flat-Earth plant (vital.ctrl.nescLqr)
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

## ADR-0xx (ctrl-3): Equivalent system of the augmented aircraft (MIL-F-8785C 3.1.12)
- **Context.** M6 grades the bare airframe's classical modes directly (ADR-030, metric ADR). 3.1.12 asks for equivalent classical systems when the augmented aircraft has extra dynamics.
- **Decision.**
  - The M7 controllers are static, so the closed loop has the same 8 states and no added mode. The closed-loop modes from `vital.linear.modes` are used directly as the equivalent system.
  - `vital.fq.evaluatePoint` sets `info.closedLoop = true` and `info.equivalentSystem = 'CLASSICAL'` when the closed-loop modes are exactly the five classical modes, all OK. Otherwise it sets `'FLAGGED'`, with a note citing 3.1.12: for example a Dutch roll split by a large yaw-damper gain, or an 'other' mode.
  - `vital.ctrl.suggestGains` lists every flagged confirmation point.
  - A dynamic (non-static) controller is refused by the linearization (`vital:linear:dynamicController`). The point becomes an ERROR point and the groups are NOT_ASSESSABLE, never a Level.
  - n/alpha (6.2) is invariant under static elevator feedback, because it is the same physical steady state, reparametrized. The closed-loop metric equals the bare one (tCtrlFq, 1e-6). For the NESC LQR the closed-loop [alpha q] rows also contain the throttle feedback, so its n/alpha is that of the augmented aircraft.
- **Not done.** No low-order equivalent-system fit, since a static loop needs none. A dynamic SAS (washout, filters, actuators) would need both the fit and the augmented-state linearization.
- **Evidence.** `tests/M7/tCtrlFq.m#augmentedPointMetrics`, `#equivalentSystemFlag`, `#nonStaticLawIsNotAssessable`.

## ADR-0xx (ctrl-4): Closed-loop option of the fq factory; the default path is unchanged
- **Decision.**
  - `vital.fq.f16Factory('Controller', b)` takes a builder `ctrl = b(AC, env, tr)`, because the law needs the trim. The factory stores it as `ac.controllerFcn`.
  - `vital.fq.evaluatePoint` builds the controller after the trim and linearizes the closed loop.
  - With no controller (the default, `[]`) the ac struct has no new field, P.info has no new field, and the code path is the M6 one. Results are bit-identical: tCtrlFq checks isequal, and reproduces the stored in-envelope critical values of `reports/fq/f16_fq_default_baseline.json` to 1e-12. The full M6 gate also passes unchanged.

## ADR-0xx (ctrl-5): Design feedback, vital.ctrl.suggestGains, and what counts as success
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
