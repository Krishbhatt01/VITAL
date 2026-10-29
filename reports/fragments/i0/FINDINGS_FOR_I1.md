# Findings for I1 (agent i0, 2026-10-27; saved by the coordinator)

These need a production change, so they were left out of I0 (no behaviour change).

| # | Finding |
|---|---|
| F-1 | The plant takes exactly 4 controls, so the P1 twin can't go through the plant, trim or linearize |
| F-2 | Trim has fixed unknowns: no engine-out or lateral trim |
| F-3 | The flight context built under toRuntime has empty X, C_bn and Env, so components must read fl.Air |
| F-4 | Trim and linearize read F-16-named limit fields |
| F-5 | runCase has no vehicle option, so nescModelRun duplicates its signal mapping |
| F-6 | toRuntime takes r_mrc from the first aero component only, so the logged M_aero_cg is wrong when two aero components sit at different points (diagnostic only) |
| F-7 | The runtimeLoads diagnostics count only AeroTable and Propulsor components: for the analytic aircraft, y.F_aero reads 0 while the body force is about -1.1 kN (a silent wrong number) |
| F-8 | The compiled y has no F_aero, M_aero, F_prop or M_prop |
| F-9 | The 1,100-state equivalence gate checks plumbing only (both sides call f16.loads) |
| F-10 | Linearize takes exactly 4 inputs |
| F-11 | tCorePerformance measured 1.239 against its 1.25 limit; it may be flaky under load |
